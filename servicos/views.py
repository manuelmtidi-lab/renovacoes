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
