create or replace table acidentes_prf_2025_teste as
select * from read_csv_auto(
    'C:\Users\danso\OneDrive\Documentos\GitHub\FAP-2026-AnaliseDados\Projeto_PRF\dados_brutos\acidentes2025.csv',
    delim = ';',
    header = true,
    encoding = 'latin-1',
    sample_size = -1
);

create or replace table acidentes_prf_2026_teste as
select * from read_csv_auto(
    'C:\Users\danso\OneDrive\Documentos\GitHub\FAP-2026-AnaliseDados\Projeto_PRF\dados_brutos\acidentes2026.csv',
    delim = ';',
    header = true,
    encoding = 'latin-1',
    sample_size = -1
);

CREATE view acidentes_prf_consolidade AS
    SELECT * FROM acidentes_prf_2025_teste
    UNION
    SELECT * FROM acidentes_prf_2026_teste;

select * from acidentes_prf_2025_teste;

select * from acidentes_prf_2026_teste;


select * from acidentes_prf_consolidade;

select causa_acidente as "Causa dos Acidentes", 
    count(id) as "Total de Acidentes",
    count(mortos) filter (where mortos >= 1) as "Total de Acidentes Fatais",
    sum(mortos) as "Total de Mortos",
    replace(printf('%.2f%%', 
        ((count(mortos) filter (where mortos >= 1)) / count(id)) 
            * 100.0), '.', ',')
        as "Taxa de Acidentes Fatais"
    from acidentes_prf_consolidade
    group by causa_acidente
    order by (count(mortos) filter (where mortos >= 1)) / count(id) desc;

select uf as "Estados", 
    count(id) as "Total de Acidentes",
    count(mortos) filter (where mortos >= 1) as "Total de Acidentes Fatais",
    sum(mortos) as "Total de Mortos",
    replace(printf('%.2f%%', 
        ((count(mortos) filter (where mortos >= 1)) / count(id)) 
            * 100.0), '.', ',')
        as "Taxa de Acidentes Fatais"
    from acidentes_prf_consolidade
    group by uf
    order by (count(mortos) filter (where mortos >= 1)) / count(id) desc;