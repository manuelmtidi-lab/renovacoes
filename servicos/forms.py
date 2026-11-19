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
