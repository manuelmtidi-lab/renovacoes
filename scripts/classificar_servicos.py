import csv
from datetime import datetime, date


def classificar(dias):
    """Devolve o estado do serviço conforme os dias que faltam."""
    if dias < 0:
        return 'atrasado'
    elif dias <= 7:
        return '7 dias'
    elif dias <= 30:
        return '30 dias'
    elif dias <= 60:
        return '60 dias'
    return 'ok'


hoje = date.today()
receita_total = 0
receitas_por_tipo = {}
margens_por_tipo = {}

with open('servicos.csv', 'r', encoding='utf-8-sig') as csvfile:
    reader = csv.DictReader(csvfile)

    for linha in reader:
        tipo = linha['tipo_servico'].strip().lower()
        preco = float(linha['preco_venda'])
        custo = float(linha['custo'])
        data_expiracao = datetime.strptime(
            linha['data_expiracao'], '%Y-%m-%d'
        ).date()

        dias = (data_expiracao - hoje).days
        margem = preco - custo
        estado = classificar(dias)

        print(f'cliente: {linha["cliente"]}')
        print(f'tipo de serviço: {tipo}')
        print(f'preço: {preco:.2f}')
        print(f'margem: {margem:.2f}')
        print(f'dias restantes: {dias}')
        print(f'estado: {estado}')
        print('_' * 30)

        receita_total += preco
        receitas_por_tipo[tipo] = receitas_por_tipo.get(tipo, 0) + preco
        margens_por_tipo[tipo] = margens_por_tipo.get(tipo, 0) + margem

print(f'receita total: {receita_total:.2f}')
print('receita por tipo:')
for tipo, valor in receitas_por_tipo.items():
    print(f'  {tipo}: {valor:.2f}')
print('margem por tipo:')
for tipo, valor in margens_por_tipo.items():
    print(f'  {tipo}: {valor:.2f}')
