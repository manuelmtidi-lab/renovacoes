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
