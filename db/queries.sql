-- 1. Serviços a expirar nos próximos 30 dias (com cliente e projecto)
SELECT c.nome AS cliente, p.nome AS projecto, s.tipo, s.expira_em,
       s.expira_em - CURRENT_DATE AS dias
FROM servicos s
JOIN projectos p ON s.projecto_id = p.id
JOIN clientes c ON p.cliente_id = c.id
WHERE s.expira_em - CURRENT_DATE BETWEEN 0 AND 30
ORDER BY dias;

-- 2. Serviços em atraso
SELECT c.nome AS cliente, p.nome AS projecto, s.tipo, s.expira_em,
       CURRENT_DATE - s.expira_em AS dias_de_atraso
FROM servicos s
JOIN projectos p ON s.projecto_id = p.id
JOIN clientes c ON p.cliente_id = c.id
WHERE s.expira_em < CURRENT_DATE
ORDER BY s.expira_em;

-- 3. Receita prevista por mês
SELECT DATE_TRUNC('month', expira_em) AS mes,
       SUM(preco_venda) AS receita
FROM servicos
GROUP BY mes
ORDER BY mes;

-- 4. Margem por tipo de serviço
SELECT tipo, SUM(preco_venda - custo) AS margem
FROM servicos
GROUP BY tipo
ORDER BY margem DESC;
