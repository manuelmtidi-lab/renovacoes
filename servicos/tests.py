import io
from datetime import timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.contrib.auth.models import Group
from django.core import mail
from django.core.management import call_command
from django.test import TestCase, override_settings
from django.urls import reverse
from django.utils import timezone

from .models import Alerta, Cliente, Projecto, Renovacao, Servico
from .permissoes import GESTOR, TECNICO
from .renovar import registar_renovacao

User = get_user_model()
SENHA = 'teste12345'


def criar_servico(projecto, dias, tipo=Servico.Tipo.HOSTING):
    """Serviço que expira daqui a 'dias' dias (negativo = já expirou)."""
    hoje = timezone.localdate()
    return Servico.objects.create(
        projecto=projecto,
        tipo=tipo,
        custo=Decimal('100.00'),
        preco_venda=Decimal('150.00'),
        inicio=hoje - timedelta(days=300),
        expira_em=hoje + timedelta(days=dias),
    )


class BaseTestCase(TestCase):
    @classmethod
    def setUpTestData(cls):
        call_command('criar_perfis', stdout=io.StringIO())
        cls.cliente = Cliente.objects.create(nome='Cliente de Teste')
        cls.projecto = Projecto.objects.create(cliente=cls.cliente, nome='Projecto A')


# Teste 1: cálculo dos dias e do estado
class DiasParaExpirarTests(BaseTestCase):
    def test_dias_para_expirar(self):
        self.assertEqual(criar_servico(self.projecto, 10).dias_para_expirar(), 10)
        self.assertEqual(criar_servico(self.projecto, -3).dias_para_expirar(), -3)

    def test_estado_nos_limites(self):
        casos = {
            -3: 'atrasado', 0: '7 dias', 7: '7 dias', 8: '30 dias',
            30: '30 dias', 31: '60 dias', 60: '60 dias', 61: 'ok',
        }
        for dias, esperado in casos.items():
            with self.subTest(dias=dias):
                servico = criar_servico(self.projecto, dias)
                self.assertEqual(servico.estado_alerta(), esperado)


# Teste 2: o técnico só vê o que lhe está atribuído
class FiltroTecnicoTests(BaseTestCase):
    @classmethod
    def setUpTestData(cls):
        super().setUpTestData()
        grupo = Group.objects.get(name=TECNICO)
        cls.ana = User.objects.create_user('ana', password=SENHA)
        cls.rui = User.objects.create_user('rui', password=SENHA)
        cls.ana.groups.add(grupo)
        cls.rui.groups.add(grupo)
        cls.p_ana = Projecto.objects.create(
            cliente=cls.cliente, nome='Da Ana', tecnico=cls.ana
        )
        cls.p_rui = Projecto.objects.create(
            cliente=cls.cliente, nome='Do Rui', tecnico=cls.rui
        )
        cls.s_ana = criar_servico(cls.p_ana, 10)
        cls.s_rui = criar_servico(cls.p_rui, 10)

    def setUp(self):
        self.client.login(username='ana', password=SENHA)

    def test_lista_de_projectos(self):
        resposta = self.client.get(reverse('servicos:projecto_lista'))
        self.assertEqual([p.pk for p in resposta.context['projectos']], [self.p_ana.pk])

    def test_lista_de_servicos(self):
        resposta = self.client.get(reverse('servicos:servico_lista'))
        self.assertEqual([s.pk for s in resposta.context['servicos']], [self.s_ana.pk])

    def test_projecto_de_outro_da_404(self):
        url = reverse('servicos:projecto_detalhe', args=[self.p_rui.pk])
        self.assertEqual(self.client.get(url).status_code, 404)

    def test_tecnico_nao_acede_a_clientes(self):
        resposta = self.client.get(reverse('servicos:cliente_lista'))
        self.assertEqual(resposta.status_code, 403)


# Teste 3: o mesmo alerta nunca é enviado duas vezes
@override_settings(ALERTAS_DESTINATARIOS=[])
class AlertasTests(BaseTestCase):
    @classmethod
    def setUpTestData(cls):
        super().setUpTestData()
        gestor = User.objects.create_user(
            'gestor', email='gestor@exemplo.com', password=SENHA
        )
        gestor.groups.add(Group.objects.get(name=GESTOR))

    def correr_comando(self):
        call_command('enviar_alertas', stdout=io.StringIO(), stderr=io.StringIO())

    def test_alerta_nao_duplica(self):
        criar_servico(self.projecto, 5)
        self.correr_comando()
        self.correr_comando()
        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(Alerta.objects.count(), 1)
        self.assertEqual(Alerta.objects.get().dias_antes, 7)

    def test_servico_longe_nao_recebe_aviso(self):
        criar_servico(self.projecto, 90)
        self.correr_comando()
        self.assertEqual(len(mail.outbox), 0)

    def test_renovacao_permite_novo_aviso(self):
        servico = criar_servico(self.projecto, 5)
        self.correr_comando()
        registar_renovacao(
            servico, Decimal('150.00'),
            timezone.localdate() + timedelta(days=55), None,
        )
        self.correr_comando()
        self.assertEqual(len(mail.outbox), 2)
        self.assertEqual(Alerta.objects.count(), 2)


# Extra: registar uma renovação
class RenovacaoTests(BaseTestCase):
    def test_registar_renovacao(self):
        utilizador = User.objects.create_user('gestor2', password=SENHA)
        servico = criar_servico(self.projecto, 5)
        nova = servico.expira_em + timedelta(days=365)
        registar_renovacao(servico, Decimal('150.00'), nova, utilizador)
        servico.refresh_from_db()
        self.assertEqual(servico.expira_em, nova)
        renovacao = Renovacao.objects.get()
        self.assertEqual(renovacao.utilizador, utilizador)
        self.assertEqual(renovacao.nova_expiracao, nova)
