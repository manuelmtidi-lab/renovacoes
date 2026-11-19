CREATE TABLE clientes (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome TEXT NOT NULL,
    email TEXT,
    telefone TEXT,
    notas TEXT
);

CREATE TABLE projectos (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cliente_id INTEGER NOT NULL REFERENCES clientes(id),
    nome TEXT NOT NULL,
    url TEXT,
    estado TEXT NOT NULL DEFAULT 'activo',
    tecnico TEXT
);

CREATE TABLE servicos (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    projecto_id INTEGER NOT NULL REFERENCES projectos(id),
    tipo TEXT NOT NULL
        CHECK (tipo IN ('dominio', 'hosting', 'ssl', 'manutencao', 'licenca')),
    fornecedor TEXT,
    custo NUMERIC(12,2) NOT NULL,
    preco_venda NUMERIC(12,2) NOT NULL,
    inicio DATE NOT NULL,
    expira_em DATE NOT NULL,
    estado TEXT NOT NULL DEFAULT 'activo'
);

CREATE TABLE renovacoes (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    servico_id INTEGER NOT NULL REFERENCES servicos(id),
    data DATE NOT NULL,
    valor NUMERIC(12,2) NOT NULL,
    nova_expiracao DATE NOT NULL,
    utilizador TEXT
);

CREATE TABLE alertas (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    servico_id INTEGER NOT NULL REFERENCES servicos(id),
    dias_antes INTEGER NOT NULL CHECK (dias_antes IN (60, 30, 7)),
    expira_em DATE NOT NULL,
    enviado_em TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (servico_id, dias_antes, expira_em)
);
