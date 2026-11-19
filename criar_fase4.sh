#!/usr/bin/env bash
# Fase 4 do projecto renovacoes: login por perfil, renovações, alertas e testes.
# Correr a partir da raiz do projecto (onde está o manage.py):
#   bash criar_fase4.sh
#
# Ficheiros NOVOS:     permissoes.py, renovar.py, alertas.py, templatetags/perfis.py,
#                      comandos criar_perfis e enviar_alertas, templates de login,
#                      403 e renovar
# Ficheiros SUBSTITUÍDOS: forms.py, views.py, urls.py (da app), config/urls.py,
#                      tests.py e os templates base, servico_*, projecto_*, cliente_list
# Ficheiro ACTUALIZADO: config/settings.py (acrescenta um bloco no fim, só 1 vez)
# NÃO toca em models.py nem no .env. Não há migrations novas.

set -e

if [ ! -f manage.py ] || [ ! -d servicos ] || [ ! -d config ]; then
    echo "ERRO: corre este script na raiz do projecto (onde está o manage.py)."
    exit 1
fi

mkdir -p servicos/templatetags
mkdir -p servicos/management/commands
mkdir -p servicos/templates/servicos
mkdir -p servicos/templates/registration
touch servicos/templatetags/__init__.py
touch servicos/management/__init__.py
touch servicos/management/commands/__init__.py

# ---------------------------------------------------------------------------
# Definições (login e email), acrescentadas ao fim do settings.py uma só vez
# ---------------------------------------------------------------------------
if ! grep -q "Fase 4: autenticação e email" config/settings.py; then
cat >> config/settings.py << 'FIM_FICHEIRO'


# --- Fase 4: autenticação e email ---
LOGIN_URL = 'login'
LOGIN_REDIRECT_URL = 'servicos:servico_lista'
LOGOUT_REDIRECT_URL = 'login'

# Em desenvolvimento os emails aparecem no terminal (backend 'console').
# Em produção, define EMAIL_BACKEND e os dados do SMTP no .env.
EMAIL_BACKEND = config(
    'EMAIL_BACKEND', default='django.core.mail.backends.console.EmailBackend'
)
EMAIL_HOST = config('EMAIL_HOST', default='')
EMAIL_PORT = config('EMAIL_PORT', default=587, cast=int)
EMAIL_HOST_USER = config('EMAIL_HOST_USER', default='')
EMAIL_HOST_PASSWORD = config('EMAIL_HOST_PASSWORD', default='')
EMAIL_USE_TLS = config('EMAIL_USE_TLS', default=True, cast=bool)
DEFAULT_FROM_EMAIL = config('DEFAULT_FROM_EMAIL', default='renovacoes@localhost')

# Emails que recebem os alertas, separados por vírgulas. Se ficar vazio, usam-se
# os emails dos administradores e gestores comerciais.
ALERTAS_DESTINATARIOS = [
    e.strip()
    for e in config('ALERTAS_DESTINATARIOS', default='').split(',')
    if e.strip()
]
FIM_FICHEIRO
fi

# ---------------------------------------------------------------------------
cat > servicos/permissoes.py << 'FIM_FICHEIRO'
"""Perfis (grupos) e regras de acesso.

Administrador     : tudo (inclui apagar)
Gestor comercial  : cria, edita e renova; vê todos os projectos e serviços
Técnico           : só vê os projectos que lhe foram atribuídos, sem preços
Superuser         : conta como Administrador
"""
from django.contrib.auth.mixins import LoginRequiredMixin, UserPassesTestMixin

from .models import Projecto, Servico

ADMINISTRADOR = 'Administrador'
GESTOR = 'Gestor comercial'
TECNICO = 'Técnico'
GRUPOS = (ADMINISTRADOR, GESTOR, TECNICO)


def _grupos(user):
    """Nomes dos grupos do utilizador (guardados em cache no próprio objecto)."""
    if not user.is_authenticated:
        return set()
    if not hasattr(user, '_grupos_cache'):
        user._grupos_cache = set(user.groups.values_list('name', flat=True))
    return user._grupos_cache


def e_administrador(user):
    return user.is_authenticated and (
        user.is_superuser or ADMINISTRADOR in _grupos(user)
    )


def e_gestor(user):
    return user.is_authenticated and GESTOR in _grupos(user)


def e_tecnico(user):
    return user.is_authenticated and TECNICO in _grupos(user)


def pode_gerir(user):
    """Criar, editar, renovar e ver clientes."""
    return e_administrador(user) or e_gestor(user)


def pode_apagar(user):
    return e_administrador(user)


def pode_ver(user):
    return pode_gerir(user) or e_tecnico(user)


def projectos_visiveis(user):
    """Projectos que o utilizador pode ver (o técnico só vê os seus)."""
    qs = Projecto.objects.select_related('cliente', 'tecnico')
    if pode_gerir(user):
        return qs
    if e_tecnico(user):
        return qs.filter(tecnico=user)
    return qs.none()


def servicos_visiveis(user):
    """Serviços que o utilizador pode ver (o técnico só vê os dos seus projectos)."""
    qs = Servico.objects.select_related('projecto', 'projecto__cliente')
    if pode_gerir(user):
        return qs
    if e_tecnico(user):
        return qs.filter(projecto__tecnico=user)
    return qs.none()


# Utilizador sem sessão -> vai para o login. Com sessão mas sem perfil -> 403.
class AcessoVerMixin(LoginRequiredMixin, UserPassesTestMixin):
    def test_func(self):
        return pode_ver(self.request.user)


class AcessoGerirMixin(LoginRequiredMixin, UserPassesTestMixin):
    def test_func(self):
        return pode_gerir(self.request.user)


class AcessoApagarMixin(LoginRequiredMixin, UserPassesTestMixin):
    def test_func(self):
        return pode_apagar(self.request.user)
FIM_FICHEIRO

# ---------------------------------------------------------------------------
cat > servicos/templatetags/perfis.py << 'FIM_FICHEIRO'
from django import template

from servicos import permissoes

register = template.Library()


@register.filter(name='pode_gerir')
def pode_gerir(user):
    return permissoes.pode_gerir(user)


@register.filter(name='pode_apagar')
def pode_apagar(user):
    return permissoes.pode_apagar(user)
FIM_FICHEIRO

# ---------------------------------------------------------------------------
cat > servicos/renovar.py << 'FIM_FICHEIRO'
from django.db import transaction
from django.utils import timezone

from .models import Renovacao


def sugerir_nova_expiracao(expira_em):
    """Sugere a expiração actual + 1 ano (trata o 29 de Fevereiro)."""
    try:
        return expira_em.replace(year=expira_em.year + 1)
    except ValueError:
        return expira_em.replace(year=expira_em.year + 1, day=28)


@transaction.atomic
def registar_renovacao(servico, valor, nova_expiracao, utilizador):
    """Cria a Renovação e actualiza o serviço, tudo ou nada.

    Como o 'expira_em' muda, o UniqueConstraint do Alerta
    (servico, dias_antes, expira_em) deixa de bloquear os avisos do novo ciclo.
    """
    renovacao = Renovacao.objects.create(
        servico=servico,
        data=timezone.localdate(),
        valor=valor,
        nova_expiracao=nova_expiracao,
        utilizador=utilizador,
    )
    servico.expira_em = nova_expiracao
    servico.save(update_fields=['expira_em'])
    return renovacao
FIM_FICHEIRO

# ---------------------------------------------------------------------------
cat > servicos/alertas.py << 'FIM_FICHEIRO'
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.db.models import Q
from django.utils import timezone

from .models import Alerta, Servico
from .permissoes import ADMINISTRADOR, GESTOR

PRAZOS = (7, 30, 60)


def prazo_aplicavel(dias):
    """Devolve o prazo (7, 30 ou 60) em que o serviço está, ou None.

    Em vez de exigir exactamente 60/30/7 dias, devolve a janela actual:
    se o comando falhar um dia, o aviso é enviado no dia seguinte.
    """
    if dias < 0:
        return None
    for prazo in PRAZOS:
        if dias <= prazo:
            return prazo
    return None


def servicos_para_alertar(hoje=None):
    """Pares (serviço, prazo) que ainda não tiveram aviso nesse prazo."""
    hoje = hoje or timezone.localdate()
    candidatos = list(
        Servico.objects.filter(
            estado=Servico.Estado.ACTIVO,
            expira_em__gte=hoje,
            expira_em__lte=hoje + timedelta(days=max(PRAZOS)),
        ).select_related('projecto', 'projecto__cliente', 'projecto__tecnico')
    )
    ja_enviados = set(
        Alerta.objects.filter(servico__in=candidatos).values_list(
            'servico_id', 'dias_antes', 'expira_em'
        )
    )
    for servico in candidatos:
        prazo = prazo_aplicavel((servico.expira_em - hoje).days)
        if prazo is None:
            continue
        if (servico.pk, prazo, servico.expira_em) in ja_enviados:
            continue
        yield servico, prazo


def destinatarios_do_alerta(servico):
    emails = list(getattr(settings, 'ALERTAS_DESTINATARIOS', []))
    if not emails:
        User = get_user_model()
        emails = list(
            User.objects.filter(is_active=True)
            .filter(Q(is_superuser=True) | Q(groups__name__in=[ADMINISTRADOR, GESTOR]))
            .exclude(email='')
            .values_list('email', flat=True)
            .distinct()
        )
    tecnico = servico.projecto.tecnico
    if tecnico and tecnico.is_active and tecnico.email:
        emails.append(tecnico.email)
    return list(dict.fromkeys(emails))  # sem repetidos, mantém a ordem


def montar_email(servico, prazo):
    projecto = servico.projecto
    dias = servico.dias_para_expirar()
    quando = 'expira hoje' if dias == 0 else f'expira em {dias} dia(s)'
    assunto = (
        f'[Renovações] {servico.get_tipo_display()} de '
        f'{projecto.cliente.nome} {quando}'
    )
    corpo = (
        f'Aviso de renovação ({prazo} dias)\n\n'
        f'O serviço abaixo {quando}.\n\n'
        f'Cliente: {projecto.cliente.nome}\n'
        f'Projecto: {projecto.nome}\n'
        f'Serviço: {servico.get_tipo_display()}\n'
        f'Fornecedor: {servico.fornecedor or "-"}\n'
        f'Expira em: {servico.expira_em:%d/%m/%Y}\n'
        f'Preço de venda: {servico.preco_venda}\n\n'
        'Contacta o cliente para tratar da renovação antes da data limite.\n'
    )
    return assunto, corpo
FIM_FICHEIRO

# ---------------------------------------------------------------------------
cat > servicos/management/commands/criar_perfis.py << 'FIM_FICHEIRO'
from django.contrib.auth.models import Group
from django.core.management.base import BaseCommand

from servicos.permissoes import GRUPOS


class Command(BaseCommand):
    help = 'Cria os grupos Administrador, Gestor comercial e Técnico.'

    def handle(self, *args, **opcoes):
        for nome in GRUPOS:
            _, criado = Group.objects.get_or_create(name=nome)
            estado = 'criado' if criado else 'já existia'
            self.stdout.write(f'{nome}: {estado}')
FIM_FICHEIRO

# ---------------------------------------------------------------------------
cat > servicos/management/commands/enviar_alertas.py << 'FIM_FICHEIRO'
from django.core.mail import send_mail
from django.core.management.base import BaseCommand

from servicos.alertas import (
    destinatarios_do_alerta, montar_email, servicos_para_alertar,
)
from servicos.models import Alerta


class Command(BaseCommand):
    help = 'Envia os alertas de renovação (60, 30 e 7 dias) sem repetir avisos.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--simular', action='store_true',
            help='Mostra o que seria enviado, sem enviar nem registar nada.',
        )

    def handle(self, *args, **opcoes):
        simular = opcoes['simular']
        enviados = sem_destino = falhas = 0

        for servico, prazo in servicos_para_alertar():
            destinatarios = destinatarios_do_alerta(servico)
            rotulo = f'{servico} (aviso dos {prazo} dias)'

            if not destinatarios:
                sem_destino += 1
                self.stderr.write(f'Sem destinatários: {rotulo}')
                continue

            if simular:
                self.stdout.write(f'[simulação] {rotulo} -> {", ".join(destinatarios)}')
                continue

            # Regista primeiro: o UniqueConstraint impede dois envios em simultâneo.
            alerta, criado = Alerta.objects.get_or_create(
                servico=servico, dias_antes=prazo, expira_em=servico.expira_em
            )
            if not criado:
                continue

            assunto, corpo = montar_email(servico, prazo)
            try:
                send_mail(assunto, corpo, None, destinatarios, fail_silently=False)
            except Exception as erro:
                alerta.delete()  # sem envio não há aviso: tenta de novo na próxima vez
                falhas += 1
                self.stderr.write(f'Falhou: {rotulo}: {erro}')
                continue
            enviados += 1

        resumo = (
            f'Enviados: {enviados} | sem destinatários: {sem_destino} '
            f'| falhas: {falhas}'
        )
        self.stdout.write(self.style.SUCCESS(resumo))
FIM_FICHEIRO

# ---------------------------------------------------------------------------
cat > servicos/forms.py << 'FIM_FICHEIRO'
from django import forms
from django.contrib.auth import get_user_model

from .models import Cliente, Projecto, Servico
from .permissoes import TECNICO


class ClienteForm(forms.ModelForm):
    class Meta:
        model = Cliente
        fields = ['nome', 'email', 'telefone', 'notas']


class ProjectoForm(forms.ModelForm):
    class Meta:
        model = Projecto
        fields = ['cliente', 'nome', 'url', 'estado', 'tecnico']

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Só se pode atribuir o projecto a utilizadores do grupo Técnico.
        self.fields['tecnico'].queryset = (
            get_user_model().objects.filter(groups__name=TECNICO).order_by('username')
        )


class ServicoForm(forms.ModelForm):
    class Meta:
        model = Servico
        fields = [
            'projecto', 'tipo', 'fornecedor', 'custo', 'preco_venda',
            'inicio', 'expira_em', 'estado',
        ]
        widgets = {
            'inicio': forms.DateInput(attrs={'type': 'date'}, format='%Y-%m-%d'),
            'expira_em': forms.DateInput(attrs={'type': 'date'}, format='%Y-%m-%d'),
        }


class RenovacaoForm(forms.Form):
    valor = forms.DecimalField(max_digits=12, decimal_places=2, min_value=0)
    nova_expiracao = forms.DateField(
        label='Nova expiração',
        widget=forms.DateInput(attrs={'type': 'date'}, format='%Y-%m-%d'),
    )

    def __init__(self, *args, servico, **kwargs):
        self.servico = servico
        super().__init__(*args, **kwargs)

    def clean_nova_expiracao(self):
        nova = self.cleaned_data['nova_expiracao']
        if nova <= self.servico.expira_em:
            raise forms.ValidationError(
                'A nova expiração tem de ser depois da expiração actual.'
            )
        return nova
FIM_FICHEIRO

# ---------------------------------------------------------------------------
cat > servicos/views.py << 'FIM_FICHEIRO'
from django.contrib import messages
from django.db.models import Prefetch, ProtectedError
from django.shortcuts import get_object_or_404, redirect
from django.urls import reverse_lazy
from django.utils.functional import cached_property
from django.views.generic import (
    CreateView, DeleteView, DetailView, FormView, ListView, UpdateView,
)

from .forms import ClienteForm, ProjectoForm, RenovacaoForm, ServicoForm
from .models import Cliente, Renovacao, Servico
from .permissoes import (
    AcessoApagarMixin, AcessoGerirMixin, AcessoVerMixin,
    projectos_visiveis, servicos_visiveis,
)
from .renovar import registar_renovacao, sugerir_nova_expiracao


class FormularioMixin:
    template_name = 'servicos/form.html'


class ApagarMixin:
    """Em vez de rebentar com ProtectedError, mostra uma mensagem."""
    template_name = 'servicos/confirmar_apagar.html'

    def form_valid(self, form):
        try:
            return super().form_valid(form)
        except ProtectedError:
            messages.error(
                self.request,
                'Não é possível apagar: há registos ligados a este.',
            )
            return redirect(self.get_success_url())


# ---------- Clientes (só administrador e gestor) ----------
class ClienteListView(AcessoGerirMixin, ListView):
    model = Cliente
    context_object_name = 'clientes'
    ordering = ['nome']


class ClienteDetailView(AcessoGerirMixin, DetailView):
    model = Cliente


class ClienteCreateView(AcessoGerirMixin, FormularioMixin, CreateView):
    model = Cliente
    form_class = ClienteForm
    success_url = reverse_lazy('servicos:cliente_lista')
    extra_context = {'titulo': 'Novo cliente'}


class ClienteUpdateView(AcessoGerirMixin, FormularioMixin, UpdateView):
    model = Cliente
    form_class = ClienteForm
    success_url = reverse_lazy('servicos:cliente_lista')
    extra_context = {'titulo': 'Editar cliente'}


class ClienteDeleteView(AcessoApagarMixin, ApagarMixin, DeleteView):
    model = Cliente
    success_url = reverse_lazy('servicos:cliente_lista')


# ---------- Projectos ----------
class ProjectoListView(AcessoVerMixin, ListView):
    context_object_name = 'projectos'

    def get_queryset(self):
        return projectos_visiveis(self.request.user).order_by('nome')


class ProjectoDetailView(AcessoVerMixin, DetailView):
    def get_queryset(self):
        return projectos_visiveis(self.request.user)


class ProjectoCreateView(AcessoGerirMixin, FormularioMixin, CreateView):
    form_class = ProjectoForm
    success_url = reverse_lazy('servicos:projecto_lista')
    extra_context = {'titulo': 'Novo projecto'}

    def get_queryset(self):
        return projectos_visiveis(self.request.user)


class ProjectoUpdateView(AcessoGerirMixin, FormularioMixin, UpdateView):
    form_class = ProjectoForm
    success_url = reverse_lazy('servicos:projecto_lista')
    extra_context = {'titulo': 'Editar projecto'}

    def get_queryset(self):
        return projectos_visiveis(self.request.user)


class ProjectoDeleteView(AcessoApagarMixin, ApagarMixin, DeleteView):
    success_url = reverse_lazy('servicos:projecto_lista')

    def get_queryset(self):
        return projectos_visiveis(self.request.user)


# ---------- Serviços ----------
class ServicoListView(AcessoVerMixin, ListView):
    context_object_name = 'servicos'

    def get_queryset(self):
        return servicos_visiveis(self.request.user).order_by('expira_em')


class ServicoDetailView(AcessoVerMixin, DetailView):
    def get_queryset(self):
        return servicos_visiveis(self.request.user).prefetch_related(
            Prefetch(
                'renovacoes',
                queryset=Renovacao.objects.select_related('utilizador').order_by(
                    '-data', '-id'
                ),
            )
        )


class ServicoCreateView(AcessoGerirMixin, FormularioMixin, CreateView):
    model = Servico
    form_class = ServicoForm
    success_url = reverse_lazy('servicos:servico_lista')
    extra_context = {'titulo': 'Novo serviço'}


class ServicoUpdateView(AcessoGerirMixin, FormularioMixin, UpdateView):
    model = Servico
    form_class = ServicoForm
    success_url = reverse_lazy('servicos:servico_lista')
    extra_context = {'titulo': 'Editar serviço'}


class ServicoDeleteView(AcessoApagarMixin, ApagarMixin, DeleteView):
    model = Servico
    success_url = reverse_lazy('servicos:servico_lista')


class RenovarServicoView(AcessoGerirMixin, FormView):
    template_name = 'servicos/renovar.html'
    form_class = RenovacaoForm

    @cached_property
    def servico(self):
        return get_object_or_404(
            Servico.objects.select_related('projecto', 'projecto__cliente'),
            pk=self.kwargs['pk'],
        )

    def get_form_kwargs(self):
        kwargs = super().get_form_kwargs()
        kwargs['servico'] = self.servico
        return kwargs

    def get_initial(self):
        return {
            'valor': self.servico.preco_venda,
            'nova_expiracao': sugerir_nova_expiracao(self.servico.expira_em),
        }

    def get_context_data(self, **kwargs):
        contexto = super().get_context_data(**kwargs)
        contexto['servico'] = self.servico
        return contexto

    def form_valid(self, form):
        registar_renovacao(
            self.servico,
            form.cleaned_data['valor'],
            form.cleaned_data['nova_expiracao'],
            self.request.user,
        )
        messages.success(self.request, 'Renovação registada.')
        return redirect('servicos:servico_detalhe', pk=self.servico.pk)
FIM_FICHEIRO

# ---------------------------------------------------------------------------
cat > servicos/urls.py << 'FIM_FICHEIRO'
from django.urls import path

from . import views

app_name = 'servicos'

urlpatterns = [
    path('', views.ServicoListView.as_view(), name='servico_lista'),
    path('servicos/novo/', views.ServicoCreateView.as_view(), name='servico_criar'),
    path('servicos/<int:pk>/', views.ServicoDetailView.as_view(), name='servico_detalhe'),
    path('servicos/<int:pk>/editar/', views.ServicoUpdateView.as_view(), name='servico_editar'),
    path('servicos/<int:pk>/apagar/', views.ServicoDeleteView.as_view(), name='servico_apagar'),
    path('servicos/<int:pk>/renovar/', views.RenovarServicoView.as_view(), name='servico_renovar'),

    path('clientes/', views.ClienteListView.as_view(), name='cliente_lista'),
    path('clientes/novo/', views.ClienteCreateView.as_view(), name='cliente_criar'),
    path('clientes/<int:pk>/', views.ClienteDetailView.as_view(), name='cliente_detalhe'),
    path('clientes/<int:pk>/editar/', views.ClienteUpdateView.as_view(), name='cliente_editar'),
    path('clientes/<int:pk>/apagar/', views.ClienteDeleteView.as_view(), name='cliente_apagar'),

    path('projectos/', views.ProjectoListView.as_view(), name='projecto_lista'),
    path('projectos/novo/', views.ProjectoCreateView.as_view(), name='projecto_criar'),
    path('projectos/<int:pk>/', views.ProjectoDetailView.as_view(), name='projecto_detalhe'),
    path('projectos/<int:pk>/editar/', views.ProjectoUpdateView.as_view(), name='projecto_editar'),
    path('projectos/<int:pk>/apagar/', views.ProjectoDeleteView.as_view(), name='projecto_apagar'),
]
FIM_FICHEIRO

# ---------------------------------------------------------------------------
cat > config/urls.py << 'FIM_FICHEIRO'
from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    path('admin/', admin.site.urls),
    path('contas/', include('django.contrib.auth.urls')),
    path('', include('servicos.urls')),
]
FIM_FICHEIRO

# ---------------------------------------------------------------------------
# Testes
# ---------------------------------------------------------------------------
cat > servicos/tests.py << 'FIM_FICHEIRO'
import io
from datetime import timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.contrib.auth.models import Group
from django.core import mail
from django.core.management import call_command
from django.test import TestCase, override_settings
from django.urls import reverse
from django.utils import timezone

from .models import Alerta, Cliente, Projecto, Renovacao, Servico
from .permissoes import GESTOR, TECNICO
from .renovar import registar_renovacao

User = get_user_model()
SENHA = 'teste12345'


def criar_servico(projecto, dias, tipo=Servico.Tipo.HOSTING):
    """Serviço que expira daqui a 'dias' dias (negativo = já expirou)."""
    hoje = timezone.localdate()
    return Servico.objects.create(
        projecto=projecto,
        tipo=tipo,
        custo=Decimal('100.00'),
        preco_venda=Decimal('150.00'),
        inicio=hoje - timedelta(days=300),
        expira_em=hoje + timedelta(days=dias),
    )


class BaseTestCase(TestCase):
    @classmethod
    def setUpTestData(cls):
        call_command('criar_perfis', stdout=io.StringIO())
        cls.cliente = Cliente.objects.create(nome='Cliente de Teste')
        cls.projecto = Projecto.objects.create(cliente=cls.cliente, nome='Projecto A')


# Teste 1: cálculo dos dias e do estado
class DiasParaExpirarTests(BaseTestCase):
    def test_dias_para_expirar(self):
        self.assertEqual(criar_servico(self.projecto, 10).dias_para_expirar(), 10)
        self.assertEqual(criar_servico(self.projecto, -3).dias_para_expirar(), -3)

    def test_estado_nos_limites(self):
        casos = {
            -3: 'atrasado', 0: '7 dias', 7: '7 dias', 8: '30 dias',
            30: '30 dias', 31: '60 dias', 60: '60 dias', 61: 'ok',
        }
        for dias, esperado in casos.items():
            with self.subTest(dias=dias):
                servico = criar_servico(self.projecto, dias)
                self.assertEqual(servico.estado_alerta(), esperado)


# Teste 2: o técnico só vê o que lhe está atribuído
class FiltroTecnicoTests(BaseTestCase):
    @classmethod
    def setUpTestData(cls):
        super().setUpTestData()
        grupo = Group.objects.get(name=TECNICO)
        cls.ana = User.objects.create_user('ana', password=SENHA)
        cls.rui = User.objects.create_user('rui', password=SENHA)
        cls.ana.groups.add(grupo)
        cls.rui.groups.add(grupo)
        cls.p_ana = Projecto.objects.create(
            cliente=cls.cliente, nome='Da Ana', tecnico=cls.ana
        )
        cls.p_rui = Projecto.objects.create(
            cliente=cls.cliente, nome='Do Rui', tecnico=cls.rui
        )
        cls.s_ana = criar_servico(cls.p_ana, 10)
        cls.s_rui = criar_servico(cls.p_rui, 10)

    def setUp(self):
        self.client.login(username='ana', password=SENHA)

    def test_lista_de_projectos(self):
        resposta = self.client.get(reverse('servicos:projecto_lista'))
        self.assertEqual([p.pk for p in resposta.context['projectos']], [self.p_ana.pk])

    def test_lista_de_servicos(self):
        resposta = self.client.get(reverse('servicos:servico_lista'))
        self.assertEqual([s.pk for s in resposta.context['servicos']], [self.s_ana.pk])

    def test_projecto_de_outro_da_404(self):
        url = reverse('servicos:projecto_detalhe', args=[self.p_rui.pk])
        self.assertEqual(self.client.get(url).status_code, 404)

    def test_tecnico_nao_acede_a_clientes(self):
        resposta = self.client.get(reverse('servicos:cliente_lista'))
        self.assertEqual(resposta.status_code, 403)


# Teste 3: o mesmo alerta nunca é enviado duas vezes
@override_settings(ALERTAS_DESTINATARIOS=[])
class AlertasTests(BaseTestCase):
    @classmethod
    def setUpTestData(cls):
        super().setUpTestData()
        gestor = User.objects.create_user(
            'gestor', email='gestor@exemplo.com', password=SENHA
        )
        gestor.groups.add(Group.objects.get(name=GESTOR))

    def correr_comando(self):
        call_command('enviar_alertas', stdout=io.StringIO(), stderr=io.StringIO())

    def test_alerta_nao_duplica(self):
        criar_servico(self.projecto, 5)
        self.correr_comando()
        self.correr_comando()
        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(Alerta.objects.count(), 1)
        self.assertEqual(Alerta.objects.get().dias_antes, 7)

    def test_servico_longe_nao_recebe_aviso(self):
        criar_servico(self.projecto, 90)
        self.correr_comando()
        self.assertEqual(len(mail.outbox), 0)

    def test_renovacao_permite_novo_aviso(self):
        servico = criar_servico(self.projecto, 5)
        self.correr_comando()
        registar_renovacao(
            servico, Decimal('150.00'),
            timezone.localdate() + timedelta(days=55), None,
        )
        self.correr_comando()
        self.assertEqual(len(mail.outbox), 2)
        self.assertEqual(Alerta.objects.count(), 2)


# Extra: registar uma renovação
class RenovacaoTests(BaseTestCase):
    def test_registar_renovacao(self):
        utilizador = User.objects.create_user('gestor2', password=SENHA)
        servico = criar_servico(self.projecto, 5)
        nova = servico.expira_em + timedelta(days=365)
        registar_renovacao(servico, Decimal('150.00'), nova, utilizador)
        servico.refresh_from_db()
        self.assertEqual(servico.expira_em, nova)
        renovacao = Renovacao.objects.get()
        self.assertEqual(renovacao.utilizador, utilizador)
        self.assertEqual(renovacao.nova_expiracao, nova)
FIM_FICHEIRO

# ---------------------------------------------------------------------------
# Templates
# ---------------------------------------------------------------------------
cat > servicos/templates/base.html << 'FIM_FICHEIRO'
{% load perfis %}<!DOCTYPE html>
<html lang="pt">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{% block titulo %}Renovações{% endblock %}</title>
</head>
<body>
  <nav>
    {% if user.is_authenticated %}
      <a href="{% url 'servicos:servico_lista' %}">Serviços</a> |
      <a href="{% url 'servicos:projecto_lista' %}">Projectos</a> |
      {% if user|pode_gerir %}
        <a href="{% url 'servicos:cliente_lista' %}">Clientes</a> |
      {% endif %}
      {% if user.is_staff %}
        <a href="{% url 'admin:index' %}">Admin</a> |
      {% endif %}
      <span>{{ user.get_username }}</span>
      <form method="post" action="{% url 'logout' %}" style="display:inline">
        {% csrf_token %}
        <button type="submit">Sair</button>
      </form>
    {% else %}
      <a href="{% url 'login' %}">Entrar</a>
    {% endif %}
  </nav>
  <hr>
  {% if messages %}
    <ul>{% for m in messages %}<li>{{ m }}</li>{% endfor %}</ul>
  {% endif %}
  {% block conteudo %}{% endblock %}
</body>
</html>
FIM_FICHEIRO

cat > servicos/templates/registration/login.html << 'FIM_FICHEIRO'
{% extends 'base.html' %}
{% block titulo %}Entrar{% endblock %}
{% block conteudo %}
<h1>Entrar</h1>
{% if form.errors %}<p>Utilizador ou senha incorrectos.</p>{% endif %}
<form method="post">
  {% csrf_token %}
  {{ form.as_p }}
  <input type="hidden" name="next" value="{{ next }}">
  <button type="submit">Entrar</button>
</form>
{% endblock %}
FIM_FICHEIRO

cat > servicos/templates/403.html << 'FIM_FICHEIRO'
{% extends 'base.html' %}
{% block conteudo %}
<h1>Sem permissão</h1>
<p>O teu utilizador não tem acesso a esta página. Se achas que devia ter,
fala com o administrador para te atribuir um perfil.</p>
{% endblock %}
FIM_FICHEIRO

cat > servicos/templates/servicos/renovar.html << 'FIM_FICHEIRO'
{% extends 'base.html' %}
{% block conteudo %}
<h1>Registar renovação</h1>
<p>
  {{ servico.get_tipo_display }} de {{ servico.projecto.cliente.nome }}
  ({{ servico.projecto.nome }}), expira em {{ servico.expira_em|date:"d/m/Y" }}.
</p>
<form method="post">
  {% csrf_token %}
  {{ form.as_p }}
  <button type="submit">Registar renovação</button>
  <a href="{% url 'servicos:servico_detalhe' servico.pk %}">Cancelar</a>
</form>
{% endblock %}
FIM_FICHEIRO

cat > servicos/templates/servicos/servico_list.html << 'FIM_FICHEIRO'
{% extends 'base.html' %}
{% load perfis %}
{% block conteudo %}
<h1>Serviços</h1>
{% if user|pode_gerir %}<a href="{% url 'servicos:servico_criar' %}">Novo serviço</a>{% endif %}
<table border="1" cellpadding="4">
  <tr>
    <th>Cliente</th><th>Projecto</th><th>Tipo</th><th>Expira em</th>
    <th>Dias</th><th>Estado</th>{% if user|pode_gerir %}<th>Margem</th>{% endif %}<th></th>
  </tr>
  {% for s in servicos %}
  <tr>
    <td>{{ s.projecto.cliente.nome }}</td>
    <td>{{ s.projecto.nome }}</td>
    <td><a href="{% url 'servicos:servico_detalhe' s.pk %}">{{ s.get_tipo_display }}</a></td>
    <td>{{ s.expira_em|date:"d/m/Y" }}</td>
    <td>{{ s.dias_para_expirar }}</td>
    <td>{{ s.estado_alerta }}</td>
    {% if user|pode_gerir %}<td>{{ s.margem }}</td>{% endif %}
    <td>
      {% if user|pode_gerir %}
        <a href="{% url 'servicos:servico_renovar' s.pk %}">Renovar</a>
        <a href="{% url 'servicos:servico_editar' s.pk %}">Editar</a>
      {% endif %}
      {% if user|pode_apagar %}
        <a href="{% url 'servicos:servico_apagar' s.pk %}">Apagar</a>
      {% endif %}
    </td>
  </tr>
  {% empty %}
  <tr><td colspan="8">Sem serviços.</td></tr>
  {% endfor %}
</table>
{% endblock %}
FIM_FICHEIRO

cat > servicos/templates/servicos/servico_detail.html << 'FIM_FICHEIRO'
{% extends 'base.html' %}
{% load perfis %}
{% block conteudo %}
<h1>{{ servico.get_tipo_display }}: {{ servico.projecto.nome }}</h1>
<p>Cliente: {{ servico.projecto.cliente.nome }}</p>
<p>Fornecedor: {{ servico.fornecedor|default:"-" }}</p>
{% if user|pode_gerir %}
  <p>Custo: {{ servico.custo }} | Preço: {{ servico.preco_venda }} | Margem: {{ servico.margem }}</p>
{% endif %}
<p>Início: {{ servico.inicio|date:"d/m/Y" }} | Expira em: {{ servico.expira_em|date:"d/m/Y" }}</p>
<p>Dias restantes: {{ servico.dias_para_expirar }} ({{ servico.estado_alerta }})</p>

{% if user|pode_gerir %}
  <p><a href="{% url 'servicos:servico_renovar' servico.pk %}">Registar renovação</a></p>
{% endif %}

<h2>Histórico de renovações</h2>
<ul>
  {% for r in servico.renovacoes.all %}
    <li>
      {{ r.data|date:"d/m/Y" }}: {{ r.valor }}
      (nova expiração {{ r.nova_expiracao|date:"d/m/Y" }})
      {% if r.utilizador %}por {{ r.utilizador.get_username }}{% endif %}
    </li>
  {% empty %}
    <li>Ainda sem renovações.</li>
  {% endfor %}
</ul>
{% endblock %}
FIM_FICHEIRO

cat > servicos/templates/servicos/projecto_list.html << 'FIM_FICHEIRO'
{% extends 'base.html' %}
{% load perfis %}
{% block conteudo %}
<h1>Projectos</h1>
{% if user|pode_gerir %}<a href="{% url 'servicos:projecto_criar' %}">Novo projecto</a>{% endif %}
<table border="1" cellpadding="4">
  <tr><th>Projecto</th><th>Cliente</th><th>Estado</th><th>Técnico</th><th></th></tr>
  {% for p in projectos %}
  <tr>
    <td><a href="{% url 'servicos:projecto_detalhe' p.pk %}">{{ p.nome }}</a></td>
    <td>{{ p.cliente.nome }}</td>
    <td>{{ p.get_estado_display }}</td>
    <td>{{ p.tecnico|default:"-" }}</td>
    <td>
      {% if user|pode_gerir %}
        <a href="{% url 'servicos:projecto_editar' p.pk %}">Editar</a>
      {% endif %}
      {% if user|pode_apagar %}
        <a href="{% url 'servicos:projecto_apagar' p.pk %}">Apagar</a>
      {% endif %}
    </td>
  </tr>
  {% empty %}
  <tr><td colspan="5">Sem projectos.</td></tr>
  {% endfor %}
</table>
{% endblock %}
FIM_FICHEIRO

cat > servicos/templates/servicos/projecto_detail.html << 'FIM_FICHEIRO'
{% extends 'base.html' %}
{% load perfis %}
{% block conteudo %}
<h1>{{ projecto.nome }}</h1>
<p>Cliente:
  {% if user|pode_gerir %}
    <a href="{% url 'servicos:cliente_detalhe' projecto.cliente.pk %}">{{ projecto.cliente.nome }}</a>
  {% else %}
    {{ projecto.cliente.nome }}
  {% endif %}
</p>
<p>Estado: {{ projecto.get_estado_display }} | Técnico: {{ projecto.tecnico|default:"-" }}</p>
{% if projecto.url %}<p><a href="{{ projecto.url }}">{{ projecto.url }}</a></p>{% endif %}

<h2>Serviços</h2>
<ul>
  {% for s in projecto.servicos.all %}
    <li>
      <a href="{% url 'servicos:servico_detalhe' s.pk %}">{{ s.get_tipo_display }}</a>
      - expira em {{ s.expira_em|date:"d/m/Y" }} ({{ s.dias_para_expirar }} dias)
    </li>
  {% empty %}
    <li>Sem serviços.</li>
  {% endfor %}
</ul>
{% endblock %}
FIM_FICHEIRO

cat > servicos/templates/servicos/cliente_list.html << 'FIM_FICHEIRO'
{% extends 'base.html' %}
{% load perfis %}
{% block conteudo %}
<h1>Clientes</h1>
<a href="{% url 'servicos:cliente_criar' %}">Novo cliente</a>
<table border="1" cellpadding="4">
  <tr><th>Nome</th><th>Email</th><th>Telefone</th><th></th></tr>
  {% for c in clientes %}
  <tr>
    <td><a href="{% url 'servicos:cliente_detalhe' c.pk %}">{{ c.nome }}</a></td>
    <td>{{ c.email }}</td>
    <td>{{ c.telefone }}</td>
    <td>
      <a href="{% url 'servicos:cliente_editar' c.pk %}">Editar</a>
      {% if user|pode_apagar %}
        <a href="{% url 'servicos:cliente_apagar' c.pk %}">Apagar</a>
      {% endif %}
    </td>
  </tr>
  {% empty %}
  <tr><td colspan="4">Sem clientes.</td></tr>
  {% endfor %}
</table>
{% endblock %}
FIM_FICHEIRO

echo ""
echo "Ficheiros criados. A verificar o projecto..."
python manage.py check
echo ""
echo "Tudo pronto. Próximos passos:"
echo "  sudo -u postgres psql -c \"ALTER USER renovacoes_user CREATEDB;\""
echo "  python manage.py criar_perfis"
echo "  python manage.py test"
echo "  python manage.py enviar_alertas --simular"
