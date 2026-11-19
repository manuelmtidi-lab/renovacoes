#!/usr/bin/env bash
# Cria os ficheiros da Fase 3 do projecto renovacoes.
# Correr a partir da raiz do projecto (onde está o manage.py):
#   bash criar_fase3.sh
#
# Ficheiros que SUBSTITUI: servicos/admin.py, servicos/views.py, config/urls.py
# Ficheiros que NÃO toca: servicos/models.py, config/settings.py, .env

set -e

if [ ! -f manage.py ] || [ ! -d servicos ] || [ ! -d config ]; then
    echo "ERRO: corre este script na raiz do projecto (onde está o manage.py)."
    exit 1
fi

mkdir -p servicos/management/commands
mkdir -p servicos/templates/servicos
touch servicos/management/__init__.py
touch servicos/management/commands/__init__.py

# ---------------------------------------------------------------------------
cat > servicos/management/commands/carregar_csv.py << 'FIM_FICHEIRO'
import csv
from datetime import datetime
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError

from servicos.models import Cliente, Projecto, Servico


class Command(BaseCommand):
    help = 'Carrega serviços de um CSV (dados de teste).'

    def add_arguments(self, parser):
        parser.add_argument('caminho', nargs='?', default='scripts/servicos.csv')

    def handle(self, *args, **opcoes):
        caminho = Path(opcoes['caminho'])
        if not caminho.exists():
            raise CommandError(f'Ficheiro não encontrado: {caminho}')

        criados = 0
        with caminho.open(encoding='utf-8-sig', newline='') as f:
            for linha in csv.DictReader(f):
                cliente, _ = Cliente.objects.get_or_create(
                    nome=linha['cliente'].strip()
                )
                projecto, _ = Projecto.objects.get_or_create(
                    cliente=cliente, nome=linha['projeto'].strip()
                )
                _, criado = Servico.objects.get_or_create(
                    projecto=projecto,
                    tipo=linha['tipo_servico'].strip().lower(),
                    expira_em=datetime.strptime(
                        linha['data_expiracao'], '%Y-%m-%d'
                    ).date(),
                    defaults={
                        'fornecedor': linha['fornecedor'].strip(),
                        'custo': linha['custo'],
                        'preco_venda': linha['preco_venda'],
                        'inicio': datetime.strptime(
                            linha['data_inicio'], '%Y-%m-%d'
                        ).date(),
                    },
                )
                criados += criado

        self.stdout.write(self.style.SUCCESS(f'{criados} serviços criados.'))
FIM_FICHEIRO

# ---------------------------------------------------------------------------
cat > servicos/admin.py << 'FIM_FICHEIRO'
from django.contrib import admin

from .models import Alerta, Cliente, Projecto, Renovacao, Servico


@admin.register(Cliente)
class ClienteAdmin(admin.ModelAdmin):
    list_display = ('nome', 'email', 'telefone')
    search_fields = ('nome', 'email')


@admin.register(Projecto)
class ProjectoAdmin(admin.ModelAdmin):
    list_display = ('nome', 'cliente', 'estado', 'tecnico')
    list_filter = ('estado',)
    search_fields = ('nome', 'cliente__nome')


@admin.register(Servico)
class ServicoAdmin(admin.ModelAdmin):
    list_display = (
        'projecto', 'tipo', 'expira_em',
        'dias_para_expirar', 'estado_alerta', 'margem',
    )
    list_filter = ('tipo', 'estado')
    search_fields = ('projecto__nome', 'projecto__cliente__nome')
    ordering = ('expira_em',)


admin.site.register(Renovacao)
admin.site.register(Alerta)
FIM_FICHEIRO

# ---------------------------------------------------------------------------
cat > servicos/forms.py << 'FIM_FICHEIRO'
from django import forms

from .models import Cliente, Projecto, Servico


class ClienteForm(forms.ModelForm):
    class Meta:
        model = Cliente
        fields = ['nome', 'email', 'telefone', 'notas']


class ProjectoForm(forms.ModelForm):
    class Meta:
        model = Projecto
        fields = ['cliente', 'nome', 'url', 'estado', 'tecnico']


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
FIM_FICHEIRO

# ---------------------------------------------------------------------------
cat > servicos/views.py << 'FIM_FICHEIRO'
from django.contrib import messages
from django.db.models import ProtectedError
from django.shortcuts import redirect
from django.urls import reverse_lazy
from django.views.generic import (
    CreateView, DeleteView, DetailView, ListView, UpdateView,
)

from .forms import ClienteForm, ProjectoForm, ServicoForm
from .models import Cliente, Projecto, Servico


class FormularioMixin:
    template_name = 'servicos/form.html'


class ApagarMixin:
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


# ---------- Clientes ----------
class ClienteListView(ListView):
    model = Cliente
    context_object_name = 'clientes'
    ordering = ['nome']


class ClienteDetailView(DetailView):
    model = Cliente


class ClienteCreateView(FormularioMixin, CreateView):
    model = Cliente
    form_class = ClienteForm
    success_url = reverse_lazy('servicos:cliente_lista')
    extra_context = {'titulo': 'Novo cliente'}


class ClienteUpdateView(FormularioMixin, UpdateView):
    model = Cliente
    form_class = ClienteForm
    success_url = reverse_lazy('servicos:cliente_lista')
    extra_context = {'titulo': 'Editar cliente'}


class ClienteDeleteView(ApagarMixin, DeleteView):
    model = Cliente
    success_url = reverse_lazy('servicos:cliente_lista')


# ---------- Projectos ----------
class ProjectoListView(ListView):
    model = Projecto
    context_object_name = 'projectos'
    queryset = Projecto.objects.select_related('cliente', 'tecnico').order_by('nome')


class ProjectoDetailView(DetailView):
    model = Projecto


class ProjectoCreateView(FormularioMixin, CreateView):
    model = Projecto
    form_class = ProjectoForm
    success_url = reverse_lazy('servicos:projecto_lista')
    extra_context = {'titulo': 'Novo projecto'}


class ProjectoUpdateView(FormularioMixin, UpdateView):
    model = Projecto
    form_class = ProjectoForm
    success_url = reverse_lazy('servicos:projecto_lista')
    extra_context = {'titulo': 'Editar projecto'}


class ProjectoDeleteView(ApagarMixin, DeleteView):
    model = Projecto
    success_url = reverse_lazy('servicos:projecto_lista')


# ---------- Serviços ----------
class ServicoListView(ListView):
    model = Servico
    context_object_name = 'servicos'
    queryset = Servico.objects.select_related(
        'projecto', 'projecto__cliente'
    ).order_by('expira_em')


class ServicoDetailView(DetailView):
    model = Servico


class ServicoCreateView(FormularioMixin, CreateView):
    model = Servico
    form_class = ServicoForm
    success_url = reverse_lazy('servicos:servico_lista')
    extra_context = {'titulo': 'Novo serviço'}


class ServicoUpdateView(FormularioMixin, UpdateView):
    model = Servico
    form_class = ServicoForm
    success_url = reverse_lazy('servicos:servico_lista')
    extra_context = {'titulo': 'Editar serviço'}


class ServicoDeleteView(ApagarMixin, DeleteView):
    model = Servico
    success_url = reverse_lazy('servicos:servico_lista')
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
    path('', include('servicos.urls')),
]
FIM_FICHEIRO

# ---------------------------------------------------------------------------
# Templates
# ---------------------------------------------------------------------------
cat > servicos/templates/base.html << 'FIM_FICHEIRO'
<!DOCTYPE html>
<html lang="pt">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{% block titulo %}Renovações{% endblock %}</title>
</head>
<body>
  <nav>
    <a href="{% url 'servicos:servico_lista' %}">Serviços</a> |
    <a href="{% url 'servicos:projecto_lista' %}">Projectos</a> |
    <a href="{% url 'servicos:cliente_lista' %}">Clientes</a> |
    <a href="{% url 'admin:index' %}">Admin</a>
  </nav>
  <hr>
  {% if messages %}
    <ul>{% for m in messages %}<li>{{ m }}</li>{% endfor %}</ul>
  {% endif %}
  {% block conteudo %}{% endblock %}
</body>
</html>
FIM_FICHEIRO

cat > servicos/templates/servicos/form.html << 'FIM_FICHEIRO'
{% extends 'base.html' %}
{% block conteudo %}
<h1>{{ titulo }}</h1>
<form method="post">
  {% csrf_token %}
  {{ form.as_p }}
  <button type="submit">Guardar</button>
  <a href="javascript:history.back()">Cancelar</a>
</form>
{% endblock %}
FIM_FICHEIRO

cat > servicos/templates/servicos/confirmar_apagar.html << 'FIM_FICHEIRO'
{% extends 'base.html' %}
{% block conteudo %}
<h1>Apagar</h1>
<p>Tens a certeza que queres apagar <strong>{{ object }}</strong>?</p>
<form method="post">
  {% csrf_token %}
  <button type="submit">Sim, apagar</button>
  <a href="javascript:history.back()">Cancelar</a>
</form>
{% endblock %}
FIM_FICHEIRO

cat > servicos/templates/servicos/servico_list.html << 'FIM_FICHEIRO'
{% extends 'base.html' %}
{% block conteudo %}
<h1>Serviços</h1>
<a href="{% url 'servicos:servico_criar' %}">Novo serviço</a>
<table border="1" cellpadding="4">
  <tr>
    <th>Cliente</th><th>Projecto</th><th>Tipo</th><th>Expira em</th>
    <th>Dias</th><th>Estado</th><th>Margem</th><th></th>
  </tr>
  {% for s in servicos %}
  <tr>
    <td>{{ s.projecto.cliente.nome }}</td>
    <td>{{ s.projecto.nome }}</td>
    <td><a href="{% url 'servicos:servico_detalhe' s.pk %}">{{ s.get_tipo_display }}</a></td>
    <td>{{ s.expira_em|date:"d/m/Y" }}</td>
    <td>{{ s.dias_para_expirar }}</td>
    <td>{{ s.estado_alerta }}</td>
    <td>{{ s.margem }}</td>
    <td>
      <a href="{% url 'servicos:servico_editar' s.pk %}">Editar</a>
      <a href="{% url 'servicos:servico_apagar' s.pk %}">Apagar</a>
    </td>
  </tr>
  {% empty %}
  <tr><td colspan="8">Sem serviços.</td></tr>
  {% endfor %}
</table>
{% endblock %}
FIM_FICHEIRO

cat > servicos/templates/servicos/cliente_list.html << 'FIM_FICHEIRO'
{% extends 'base.html' %}
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
      <a href="{% url 'servicos:cliente_apagar' c.pk %}">Apagar</a>
    </td>
  </tr>
  {% empty %}
  <tr><td colspan="4">Sem clientes.</td></tr>
  {% endfor %}
</table>
{% endblock %}
FIM_FICHEIRO

cat > servicos/templates/servicos/projecto_list.html << 'FIM_FICHEIRO'
{% extends 'base.html' %}
{% block conteudo %}
<h1>Projectos</h1>
<a href="{% url 'servicos:projecto_criar' %}">Novo projecto</a>
<table border="1" cellpadding="4">
  <tr><th>Projecto</th><th>Cliente</th><th>Estado</th><th>Técnico</th><th></th></tr>
  {% for p in projectos %}
  <tr>
    <td><a href="{% url 'servicos:projecto_detalhe' p.pk %}">{{ p.nome }}</a></td>
    <td>{{ p.cliente.nome }}</td>
    <td>{{ p.get_estado_display }}</td>
    <td>{{ p.tecnico|default:"-" }}</td>
    <td>
      <a href="{% url 'servicos:projecto_editar' p.pk %}">Editar</a>
      <a href="{% url 'servicos:projecto_apagar' p.pk %}">Apagar</a>
    </td>
  </tr>
  {% empty %}
  <tr><td colspan="5">Sem projectos.</td></tr>
  {% endfor %}
</table>
{% endblock %}
FIM_FICHEIRO

cat > servicos/templates/servicos/cliente_detail.html << 'FIM_FICHEIRO'
{% extends 'base.html' %}
{% block conteudo %}
<h1>{{ cliente.nome }}</h1>
<p>Email: {{ cliente.email|default:"-" }} | Telefone: {{ cliente.telefone|default:"-" }}</p>
{% if cliente.notas %}<p>{{ cliente.notas }}</p>{% endif %}

<h2>Projectos e serviços</h2>
{% for p in cliente.projectos.all %}
  <h3><a href="{% url 'servicos:projecto_detalhe' p.pk %}">{{ p.nome }}</a></h3>
  <ul>
    {% for s in p.servicos.all %}
      <li>
        <a href="{% url 'servicos:servico_detalhe' s.pk %}">{{ s.get_tipo_display }}</a>
        - expira em {{ s.expira_em|date:"d/m/Y" }}
        ({{ s.dias_para_expirar }} dias, {{ s.estado_alerta }})
      </li>
    {% empty %}
      <li>Sem serviços.</li>
    {% endfor %}
  </ul>
{% empty %}
  <p>Sem projectos.</p>
{% endfor %}
{% endblock %}
FIM_FICHEIRO

cat > servicos/templates/servicos/projecto_detail.html << 'FIM_FICHEIRO'
{% extends 'base.html' %}
{% block conteudo %}
<h1>{{ projecto.nome }}</h1>
<p>Cliente: <a href="{% url 'servicos:cliente_detalhe' projecto.cliente.pk %}">{{ projecto.cliente.nome }}</a></p>
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

cat > servicos/templates/servicos/servico_detail.html << 'FIM_FICHEIRO'
{% extends 'base.html' %}
{% block conteudo %}
<h1>{{ servico.get_tipo_display }}: {{ servico.projecto.nome }}</h1>
<p>Cliente: {{ servico.projecto.cliente.nome }}</p>
<p>Fornecedor: {{ servico.fornecedor|default:"-" }}</p>
<p>Custo: {{ servico.custo }} | Preço: {{ servico.preco_venda }} | Margem: {{ servico.margem }}</p>
<p>Início: {{ servico.inicio|date:"d/m/Y" }} | Expira em: {{ servico.expira_em|date:"d/m/Y" }}</p>
<p>Dias restantes: {{ servico.dias_para_expirar }} ({{ servico.estado_alerta }})</p>

<h2>Histórico de renovações</h2>
<ul>
  {% for r in servico.renovacoes.all %}
    <li>{{ r.data|date:"d/m/Y" }}: {{ r.valor }} (nova expiração {{ r.nova_expiracao|date:"d/m/Y" }})</li>
  {% empty %}
    <li>Ainda sem renovações.</li>
  {% endfor %}
</ul>
{% endblock %}
FIM_FICHEIRO

echo ""
echo "Ficheiros criados. A verificar o projecto..."
python manage.py check
echo ""
echo "Tudo pronto. Próximos passos:"
echo "  python manage.py carregar_csv"
echo "  python manage.py runserver"
