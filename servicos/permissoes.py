"""Perfis (grupos) e regras de acesso.

Administrador     : tudo (inclui apagar)
Gestor comercial  : cria, edita e renova; vê todos os projectos e serviços
Técnico           : só vê os projectos que lhe foram atribuídos, sem preços
Superuser         : conta como Administrador
"""
from django.contrib.auth.mixins import LoginRequiredMixin, UserPassesTestMixin

from .models import Projecto, Servico

ADMINISTRADOR = 'Administrador'
GESTOR = 'Gestor comercial'
TECNICO = 'Técnico'
GRUPOS = (ADMINISTRADOR, GESTOR, TECNICO)


def _grupos(user):
    """Nomes dos grupos do utilizador (guardados em cache no próprio objecto)."""
    if not user.is_authenticated:
        return set()
    if not hasattr(user, '_grupos_cache'):
        user._grupos_cache = set(user.groups.values_list('name', flat=True))
    return user._grupos_cache


def e_administrador(user):
    return user.is_authenticated and (
        user.is_superuser or ADMINISTRADOR in _grupos(user)
    )


def e_gestor(user):
    return user.is_authenticated and GESTOR in _grupos(user)


def e_tecnico(user):
    return user.is_authenticated and TECNICO in _grupos(user)


def pode_gerir(user):
    """Criar, editar, renovar e ver clientes."""
    return e_administrador(user) or e_gestor(user)


def pode_apagar(user):
    return e_administrador(user)


def pode_ver(user):
    return pode_gerir(user) or e_tecnico(user)


def projectos_visiveis(user):
    """Projectos que o utilizador pode ver (o técnico só vê os seus)."""
    qs = Projecto.objects.select_related('cliente', 'tecnico')
    if pode_gerir(user):
        return qs
    if e_tecnico(user):
        return qs.filter(tecnico=user)
    return qs.none()


def servicos_visiveis(user):
    """Serviços que o utilizador pode ver (o técnico só vê os dos seus projectos)."""
    qs = Servico.objects.select_related('projecto', 'projecto__cliente')
    if pode_gerir(user):
        return qs
    if e_tecnico(user):
        return qs.filter(projecto__tecnico=user)
    return qs.none()


# Utilizador sem sessão -> vai para o login. Com sessão mas sem perfil -> 403.
class AcessoVerMixin(LoginRequiredMixin, UserPassesTestMixin):
    def test_func(self):
        return pode_ver(self.request.user)


class AcessoGerirMixin(LoginRequiredMixin, UserPassesTestMixin):
    def test_func(self):
        return pode_gerir(self.request.user)


class AcessoApagarMixin(LoginRequiredMixin, UserPassesTestMixin):
    def test_func(self):
        return pode_apagar(self.request.user)
