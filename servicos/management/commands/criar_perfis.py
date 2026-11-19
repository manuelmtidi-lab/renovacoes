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
