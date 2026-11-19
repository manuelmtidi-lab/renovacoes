from django import template

from servicos import permissoes

register = template.Library()


@register.filter(name='pode_gerir')
def pode_gerir(user):
    return permissoes.pode_gerir(user)


@register.filter(name='pode_apagar')
def pode_apagar(user):
    return permissoes.pode_apagar(user)
