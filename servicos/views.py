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
