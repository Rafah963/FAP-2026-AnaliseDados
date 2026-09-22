-- Autor: Fabio Rafael Dutra Soares
-- Comandos em SQL - Módulo 03 - Análise de Dados
-- Ferramenta: DuckDB
-- Fontes de Dados: Base de dados de acidentes da PRF (2023, 2024, 2025)



-- Criação da tabela principal unindo os 3 arquivos CSV com os parâmetros corretos.
CREATE OR REPLACE TABLE acidentes_prf_historico AS
SELECT * FROM read_csv_auto(
    ['dados brutos/datatran2023.csv', 'dados brutos/datatran2024.csv', 'dados brutos/datatran2025.csv'],
    delim = ';',
    header = true,
    encoding = 'latin-1'
);


-- Remoção de colunas administrativas e geodésicas desnecessárias para a modelagem.
CREATE OR REPLACE VIEW vw_acidentes_limpa AS
SELECT * EXCLUDE (latitude, longitude, regional, delegacia, uop)
FROM acidentes_prf_historico;



-- Criação de novas colunas baseadas em regras de negócio e datas.
CREATE OR REPLACE VIEW vw_acidentes_enriquecida AS
SELECT 
    *,
    -- Variável-alvo binária
    CASE WHEN mortos >= 1 THEN 1 ELSE 0 END AS acidente_fatal,
    
    -- Extração de ano e mês
    EXTRACT(YEAR FROM CAST(data_inversa AS DATE)) AS ano_acidente,
    EXTRACT(MONTH FROM CAST(data_inversa AS DATE)) AS mes_acidente,
    
    -- Sinalizador de fim de semana
    CASE WHEN LOWER(dia_semana) IN ('sábado', 'domingo', 'sabado') THEN 1 ELSE 0 END AS fim_de_semana,
    
    -- Categorização de datas comemorativas
    CASE 
        -- Fim de Ano: 20/12 a 31/12 OU 01/01 a 02/01
        WHEN (EXTRACT(MONTH FROM CAST(data_inversa AS DATE)) = 12 AND EXTRACT(DAY FROM CAST(data_inversa AS DATE)) >= 20)
          OR (EXTRACT(MONTH FROM CAST(data_inversa AS DATE)) = 1 AND EXTRACT(DAY FROM CAST(data_inversa AS DATE)) <= 2)
        THEN 'Fim de Ano'
        -- Carnaval: Aproximação para fevereiro e março
        WHEN EXTRACT(MONTH FROM CAST(data_inversa AS DATE)) IN (2, 3) 
        THEN 'Carnaval'
        ELSE 'Normal'
    END AS data_comemorativa
FROM vw_acidentes_limpa;


-- Tendência Anual e Severidade
SELECT 
    ano_acidente,
    COUNT(*) AS total_acidentes,
    SUM(mortos) AS total_vitimas_fatais,
    ROUND((SUM(acidente_fatal) * 100.0) / COUNT(*), 2) AS taxa_letalidade_percentual
FROM vw_acidentes_enriquecida
GROUP BY ano_acidente
ORDER BY ano_acidente DESC;


-- Identifica o mês com a maior taxa de letalidade, agora quebrado por ano.
SELECT 
    ano_acidente,
    mes_acidente,
    COUNT(*) AS total_acidentes,
    SUM(mortos) AS total_vitimas_fatais,
    ROUND((SUM(acidente_fatal) * 100.0) / COUNT(*), 2) AS taxa_letalidade_percentual
FROM vw_acidentes_enriquecida
GROUP BY ano_acidente, mes_acidente
ORDER BY ano_acidente DESC, taxa_letalidade_percentual DESC;


-- Verifica a letalidade por fase do dia ao longo dos anos.
SELECT 
    ano_acidente,
    fase_dia,
    COUNT(*) AS total_acidentes,
    ROUND((SUM(acidente_fatal) * 100.0) / COUNT(*), 2) AS taxa_letalidade_percentual
FROM vw_acidentes_enriquecida
GROUP BY ano_acidente, fase_dia
ORDER BY ano_acidente DESC, taxa_letalidade_percentual DESC;

-- Compara a letalidade entre fins de semana e dias úteis.
SELECT 
    ano_acidente,
    fim_de_semana,
    CASE WHEN fim_de_semana = 1 THEN 'Final de Semana' ELSE 'Dias Úteis' END AS tipo_dia,
    COUNT(*) AS total_acidentes,
    ROUND((SUM(acidente_fatal) * 100.0) / COUNT(*), 2) AS taxa_letalidade_percentual
FROM vw_acidentes_enriquecida
GROUP BY ano_acidente, fim_de_semana, tipo_dia
ORDER BY ano_acidente DESC, taxa_letalidade_percentual DESC;

-- Calcula o Lift anual comparando o tipo de acidente com a taxa global do mesmo ano.
WITH TaxaAnual AS (
    SELECT ano_acidente, (SUM(acidente_fatal) * 1.0) / COUNT(*) AS taxa_global_ano
    FROM vw_acidentes_enriquecida
    GROUP BY ano_acidente
)
SELECT 
    v.ano_acidente,
    v.tipo_acidente,
    COUNT(*) AS total_acidentes,
    ROUND((SUM(v.acidente_fatal) * 100.0) / COUNT(*), 2) AS taxa_letalidade_tipo_pct,
    ROUND(((SUM(v.acidente_fatal) * 1.0) / COUNT(*)) / MAX(t.taxa_global_ano), 2) AS lift_letalidade
FROM vw_acidentes_enriquecida v
JOIN TaxaAnual t ON v.ano_acidente = t.ano_acidente
GROUP BY v.ano_acidente, v.tipo_acidente
HAVING COUNT(*) >= 100
ORDER BY v.ano_acidente DESC, lift_letalidade DESC;

--Ranking de Causas Associadas à Letalidade Retorna as causas com maior Lift, separadas por ano.
WITH TaxaAnual AS (
    SELECT ano_acidente, (SUM(acidente_fatal) * 1.0) / COUNT(*) AS taxa_global_ano
    FROM vw_acidentes_enriquecida
    GROUP BY ano_acidente
)
SELECT 
    v.ano_acidente,
    v.causa_acidente,
    COUNT(*) AS total_acidentes,
    ROUND((SUM(v.acidente_fatal) * 100.0) / COUNT(*), 2) AS taxa_letalidade_causa_pct,
    ROUND(((SUM(v.acidente_fatal) * 1.0) / COUNT(*)) / MAX(t.taxa_global_ano), 2) AS lift_letalidade
FROM vw_acidentes_enriquecida v
JOIN TaxaAnual t ON v.ano_acidente = t.ano_acidente
GROUP BY v.ano_acidente, v.causa_acidente
HAVING COUNT(*) >= 100
ORDER BY v.ano_acidente DESC, lift_letalidade DESC;


-- Avalia letalidade em retas vs curvas ao longo dos anos.
SELECT 
    ano_acidente,
    tracado_via,
    COUNT(*) AS total_acidentes,
    ROUND((SUM(acidente_fatal) * 100.0) / COUNT(*), 2) AS taxa_letalidade_percentual
FROM vw_acidentes_enriquecida
GROUP BY ano_acidente, tracado_via
HAVING COUNT(*) > 500
ORDER BY ano_acidente DESC, taxa_letalidade_percentual DESC;



-- 8. Condições Agravantes (Pista vs. Clima) separados por Ano
SELECT 
    ano_acidente,
    tipo_pista,
    condicao_metereologica, 
    COUNT(*) AS total_acidentes,
    ROUND((SUM(acidente_fatal) * 100.0) / COUNT(*), 2) AS taxa_letalidade_percentual
FROM vw_acidentes_enriquecida
GROUP BY ano_acidente, tipo_pista, condicao_metereologica
HAVING COUNT(*) >= 50
ORDER BY ano_acidente DESC, taxa_letalidade_percentual DESC;


-- Ranking das rodovias com mais mortes à noite, separado por ano.
SELECT 
    ano_acidente,
    br,
    COUNT(*) AS total_acidentes_noturnos,
    SUM(mortos) AS total_vitimas_fatais
FROM vw_acidentes_enriquecida
WHERE LOWER(fase_dia) = 'plena noite'
GROUP BY ano_acidente, br
ORDER BY ano_acidente DESC, total_vitimas_fatais DESC;


-- Analise do impacto dos feriados ao longo dos anos.
SELECT 
    ano_acidente,
    data_comemorativa,
    COUNT(*) AS total_acidentes,
    SUM(mortos) AS total_vitimas_fatais,
    ROUND((SUM(acidente_fatal) * 100.0) / COUNT(*), 2) AS taxa_letalidade_percentual
FROM vw_acidentes_enriquecida
GROUP BY ano_acidente, data_comemorativa
ORDER BY ano_acidente DESC, taxa_letalidade_percentual DESC;


-- Busca estados com acidentes de 3+ mortos, separados por ano.
SELECT 
    ano_acidente,
    uf,
    causa_acidente,
    COUNT(*) AS total_acidentes_gravissimos,
    SUM(mortos) AS total_mortos
FROM vw_acidentes_enriquecida
WHERE mortos >= 3
GROUP BY ano_acidente, uf, causa_acidente
ORDER BY ano_acidente DESC, total_acidentes_gravissimos DESC;


-- Ranking dos municípios de PE com mais acidentes fatais, desdobrado por ano (2024 e 2025).
SELECT 
    ano_acidente,
    municipio,
    COUNT(*) AS total_acidentes_fatais,
    SUM(mortos) AS total_mortos
FROM vw_acidentes_enriquecida
WHERE uf = 'PE' 
  AND ano_acidente IN (2024, 2025)
  AND acidente_fatal = 1
GROUP BY ano_acidente, municipio
ORDER BY ano_acidente DESC, total_acidentes_fatais DESC;