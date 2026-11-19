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
