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
