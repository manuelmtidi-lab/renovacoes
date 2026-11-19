from django.contrib import admin

from .models import Alerta, Cliente, Projecto, Renovacao, Servico


@admin.register(Cliente)
class ClienteAdmin(admin.ModelAdmin):
    list_display = ('nome', 'email', 'telefone')
    search_fields = ('nome', 'email')


@admin.register(Projecto)
class ProjectoAdmin(admin.ModelAdmin):
    list_display = ('nome', 'cliente', 'estado', 'tecnico')
    list_filter = ('estado',)
    search_fields = ('nome', 'cliente__nome')


@admin.register(Servico)
class ServicoAdmin(admin.ModelAdmin):
    list_display = (
        'projecto', 'tipo', 'expira_em',
        'dias_para_expirar', 'estado_alerta', 'margem',
    )
    list_filter = ('tipo', 'estado')
    search_fields = ('projecto__nome', 'projecto__cliente__nome')
    ordering = ('expira_em',)


admin.site.register(Renovacao)
admin.site.register(Alerta)
