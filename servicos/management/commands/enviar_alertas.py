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
