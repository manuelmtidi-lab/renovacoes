import csv
from datetime import datetime, date


with open('servicos.csv', 'r', encoding='utf-8-sig') as csvfile:
    reader = csv.DictReader(csvfile)
    receita = 0
    hoje = date.today()
    receitas_por_tipo = {
        'dominio': 0,
        'hosting': 0,
        'SSL': 0,
        'manutencao': 0,
        'licenca': 0,
    }

    for linha in reader:
        preco = int(linha["preco_venda"])
        custo = int(linha["custo"])
        data_expiracao = datetime.strptime(
            linha["data_expiracao"], '%Y-%m-%d'
        ).date()

        qd = (data_expiracao - hoje).days
        margem = preco - custo
        print(f'cliente: {linha["cliente"]}')
        print(f'tipo de serviço: {linha["tipo_servico"]}')
        print(f'preço: {preco}')
        print(f'margem: {margem}')
        print(f'Dias restantes: {qd}')
        if qd < 0:
            estado = 'estado serviço está atrasado.'
        elif qd <= 7:
            estado = 'estado: Alerta falta 7 dias'

        elif qd <= 30:
            estado = 'estado: falta 30 dias'
        elif qd <= 60:
            estado = 'estado: falta 60 dias'
        else:
            estado = 'ok'
        print(f'Estado: {estado}')
        print('_'*30)
        receita += preco
        if linha['tipo_servico'] == 'dominio':
            receitas_por_tipo['dominio'] += preco
        elif linha['tipo_servico'] == 'hosting':
            receitas_por_tipo['hosting'] += preco
        elif linha['tipo_servico'] == 'SSL':
            receitas_por_tipo['SSL'] += preco
        elif linha['tipo_servico'] == 'manutencao':
            receitas_por_tipo['manutencao'] += preco
        elif linha['tipo_servico'] == 'licenca':
            receitas_por_tipo['licenca'] += preco

    print(f'receita: {receita}')
    print(f'receitas_por_tipo: {receitas_por_tipo}')