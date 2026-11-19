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
