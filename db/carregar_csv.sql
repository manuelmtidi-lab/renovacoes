CREATE TEMP TABLE staging (
    cliente TEXT,
    projeto TEXT,
    tipo_servico TEXT,
    fornecedor TEXT,
    custo NUMERIC(12,2),
    preco_venda NUMERIC(12,2),
    data_inicio DATE,
    data_expiracao DATE
);

\copy staging FROM 'scripts/servicos.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

INSERT INTO clientes (nome)
SELECT DISTINCT cliente FROM staging;

INSERT INTO projectos (cliente_id, nome)
SELECT DISTINCT c.id, s.projeto
FROM staging s
JOIN clientes c ON c.nome = s.cliente;

INSERT INTO servicos (projecto_id, tipo, fornecedor, custo, preco_venda, inicio, expira_em)
SELECT p.id, LOWER(s.tipo_servico), s.fornecedor, s.custo,
       s.preco_venda, s.data_inicio, s.data_expiracao
FROM staging s
JOIN clientes c ON c.nome = s.cliente
JOIN projectos p ON p.cliente_id = c.id AND p.nome = s.projeto;
