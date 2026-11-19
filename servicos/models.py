from django.conf import settings
from django.db import models
from django.utils import timezone


class Cliente(models.Model):
    nome = models.CharField(max_length=200)
    email = models.EmailField(blank=True)
    telefone = models.CharField(max_length=30, blank=True)
    notas = models.TextField(blank=True)

    def __str__(self):
        return self.nome


class Projecto(models.Model):
    class Estado(models.TextChoices):
        ACTIVO = 'activo', 'Activo'
        INACTIVO = 'inactivo', 'Inactivo'

    cliente = models.ForeignKey(
        Cliente, on_delete=models.PROTECT, related_name='projectos'
    )
    nome = models.CharField(max_length=200)
    url = models.URLField(blank=True)
    estado = models.CharField(
        max_length=20, choices=Estado.choices, default=Estado.ACTIVO
    )
    tecnico = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True,
        on_delete=models.SET_NULL, related_name='projectos',
    )

    def __str__(self):
        return f'{self.nome} ({self.cliente})'


class Servico(models.Model):
    class Tipo(models.TextChoices):
        DOMINIO = 'dominio', 'Domínio'
        HOSTING = 'hosting', 'Hosting'
        SSL = 'ssl', 'SSL'
        MANUTENCAO = 'manutencao', 'Manutenção'
        LICENCA = 'licenca', 'Licença'

    class Estado(models.TextChoices):
        ACTIVO = 'activo', 'Activo'
        INACTIVO = 'inactivo', 'Inactivo'

    projecto = models.ForeignKey(
        Projecto, on_delete=models.PROTECT, related_name='servicos'
    )
    tipo = models.CharField(max_length=20, choices=Tipo.choices)
    fornecedor = models.CharField(max_length=200, blank=True)
    custo = models.DecimalField(max_digits=12, decimal_places=2)
    preco_venda = models.DecimalField(max_digits=12, decimal_places=2)
    inicio = models.DateField()
    expira_em = models.DateField()
    estado = models.CharField(
        max_length=20, choices=Estado.choices, default=Estado.ACTIVO
    )

    def __str__(self):
        return f'{self.get_tipo_display()} - {self.projecto}'

    @property
    def margem(self):
        return self.preco_venda - self.custo

    def dias_para_expirar(self):
        return (self.expira_em - timezone.localdate()).days

    def estado_alerta(self):
        dias = self.dias_para_expirar()
        if dias < 0:
            return 'atrasado'
        elif dias <= 7:
            return '7 dias'
        elif dias <= 30:
            return '30 dias'
        elif dias <= 60:
            return '60 dias'
        return 'ok'


class Renovacao(models.Model):
    servico = models.ForeignKey(
        Servico, on_delete=models.PROTECT, related_name='renovacoes'
    )
    data = models.DateField()
    valor = models.DecimalField(max_digits=12, decimal_places=2)
    nova_expiracao = models.DateField()
    utilizador = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True,
        on_delete=models.SET_NULL,
    )

    def __str__(self):
        return f'Renovação de {self.servico} em {self.data}'


class Alerta(models.Model):
    class DiasAntes(models.IntegerChoices):
        SESSENTA = 60, '60 dias'
        TRINTA = 30, '30 dias'
        SETE = 7, '7 dias'

    servico = models.ForeignKey(
        Servico, on_delete=models.CASCADE, related_name='alertas'
    )
    dias_antes = models.PositiveSmallIntegerField(choices=DiasAntes.choices)
    expira_em = models.DateField()
    enviado_em = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['servico', 'dias_antes', 'expira_em'],
                name='alerta_unico_por_servico_prazo_e_expiracao',
            )
        ]

    def __str__(self):
        return f'Alerta {self.dias_antes}d - {self.servico}'
