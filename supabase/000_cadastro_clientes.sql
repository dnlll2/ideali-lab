-- ============================================================
-- Ideali Laboratorio - Cria a tabela cadastro_clientes de verdade
-- no banco e migra os clientes hoje hardcoded em shared.js,
-- preservando o mesmo numero de "reg" ja usado em pedidos e
-- ordens_exocad (cliente_reg). Rode ANTES de 001_portal_convites.sql
-- (que depende dessa tabela existir com reg como PRIMARY KEY).
--
-- Rode este arquivo inteiro, uma vez, no SQL Editor do Supabase.
-- E seguro rodar de novo depois (CREATE TABLE IF NOT EXISTS +
-- INSERT ... ON CONFLICT DO NOTHING).
-- ============================================================

create table if not exists cadastro_clientes (
  reg          int primary key,
  nome         text not null,
  cpf          text,
  cro          text,
  end_str      text,
  bairro       text,
  cidade       text,
  uf           text,
  cep          text,
  tel          text,
  email        text,
  obs          text,
  regra_padrao text,
  status       text not null default 'ativo',
  criado_em    timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

insert into cadastro_clientes
  (reg, nome, cpf, cro, end_str, bairro, cidade, uf, cep, tel, email, obs, regra_padrao)
values
  (1,  'Ricardo Cader',                         '013.436.277-29',           '',                 'Av. Nossa Senhora de Copacabana, 749 - Sala 409', 'Copacabana',                 'Rio de Janeiro',        'RJ', '22050-002', '',                     null, '', null),
  (2,  'Leonardo Moll',                         '087.058.557-64',           'RJ 36.484',        'Av. Ernani do Amaral Peixoto, 455 - Sala 711',    'Centro',                     'Niteroi',               'RJ', '',          '(21) 99541-9481',      null, '', null),
  (3,  'Anthony Borges',                        '378.641.768-79',           '126.653',          'Av. Silvestre Pires de Freitas, 800',             'Jardim Paraiso',             'Guarulhos',             'SP', '07144-000', '',                     null, 'Costa Borges Odontologia', null),
  (4,  'Dr. Andre Ricardo G. Da Silva',         '169.303.098-50',           'SP 56824',         'Rua da Fonte, 199 - Sala 04',                     'Jardim Oriental',            'Osasco',                'SP', '',          '(11) 3609-2030',       null, 'dr.andrericardo@gmail.com', null),
  (5,  'Javier Garrido',                        'CNPJ: 48.257.718/0001-94', '75033',            'Av. Conselheiro Rodrigues Alves, 518',            'Vila Mariana',               'Sao Paulo',             'SP', '04014-001', '+55 (11) 98611-2003',  null, 'Padrao', null),
  (6,  'Renan Gerhard',                         '133.262.117-16',           '',                 'Av. Geremario Dantas, 832 - Sala 207',            'Pechincha',                  'Rio de Janeiro',        'RJ', '22743-010', '',                     null, '', null),
  (7,  'Bruno Rocco Giusto',                    '300.066.978-79',           '',                 'Av. Agua Fria, 1896',                             'Agua Fria',                  'Sao Paulo',             'SP', '02332-001', '',                     null, 'Entregar via motoboy (Katia)', null),
  (8,  'Fernando 021 Dental Barra',             'CNPJ: 37.568.571/0001-37', '',                 'Av. das Americas, 3665 - Loja 214',                'Barra da Tijuca',            'Rio de Janeiro',        'RJ', '22631-000', '',                     null, 'Padrao', null),
  (9,  'Danilo Tuttis T. G. dos Santos',        '338.114.288-70',           '',                 'Rua Prado Rochi, 145',                            'Vila Assis',                 'Jau',                   'SP', '17210-270', '(14) 99749-3400',      null, '', null),
  (10, 'Caio Vinicius Barreto dos Santos',      '376.257.418-93',           '',                 'Av. Inconfidencia Mineira, 1241',                 'Vila Antonieta',             'Sao Paulo',             'SP', '',          '(11) 98216-2905',      null, 'Lab Barreto', null),
  (11, 'Dr. Renato Oliveira Ferreira da Silva', '261.834.798-61',           '',                 'Rua Guilherme de Almeida, 2-31',                  'Vila Cidade Universitaria',  'Bauru',                 'SP', '17012-500', '',                     null, 'Padrao', null),
  (12, 'Luiz Tolentino',                        '',                         '',                 'Rua Prefeito Jose Guilherme, 15',                 'Centro',                     'Capela do Alto',        'SP', '18195-036', '',                     null, '', null),
  (13, 'Rodrigo Guimaraes',                     '006.571.367-27',           '',                 'Av. Dr. Mario Guimaraes, 428 - Sala 813',         'Centro',                     'Nova Iguacu',           'RJ', '26255-230', '',                     null, '', null),
  (15, 'Julia Ando',                            '080.218.698-01',           'CRO-SP TPD 9449',  'Rua Santa Catarina, 240 - 5 andar, Sala 504',      'Galeria Metropole',          'Sao Paulo',             'SP', '',          '(11) 96387-3845',      null, '', null),
  (16, 'Luiz Junior',                           '127.496.107-61',           '',                 'Rua Academico Walter Goncalves, 1 - Sala 404',    'Centro',                     'Niteroi',               'RJ', '24020-290', '',                     null, 'Padrao', null),
  (17, 'Talia Estefanelli Sampaio (Dr. Alfeu)', '223.215.228-60',           'CRO-SP 98329',     'Rua Salem Bechara, 140 - Sala 1504',               'Centro',                     'Osasco',                'SP', '',          '',                     null, 'Dr. Alfeu', null),
  (18, 'Henrique Falcao',                       '029.583.461-70',           'CRO 5045',         'Rua Sao Francisco Xavier, 168',                    'Tijuca',                     'Rio de Janeiro',        'RJ', '',          '',                     null, 'Clinica Odonto Premier', null),
  (19, 'Pedro Henrique de Araujo Cruz',         '446.153.318-27',           '162.968',          'Av. Antonio Sylvio Cunha Bueno, 597',              'Jardim Inamar',              'Diadema',               'SP', '',          '',                     null, '', null),
  (20, 'Adriana Tavares de Almeida',            '146.607.018-83',           'CRO-SP 92640',     'Rua Dezesseis de Dezembro, 10 - Sala 3',           'Jd. Rubio',                  'Sao Paulo',             'SP', '',          '',                     null, '', null),
  (21, 'Juliano Balseiro',                      '195.269.398-59',           'CRO 65000',        'Av. Onze de Junho, 1199',                          '',                           'Sao Paulo',             'SP', '04041-054', '',                     null, '', null),
  (22, 'Gilberto Ferreira Esquivel',            'CNPJ: 13.265.402/0001-60', 'CRO-BA 7329',      'Rua Henqueque Alves, 315',                         'Castalia',                   'Itabuna',               'BA', '',          '',                     null, '', null),
  (23, 'Alexandre Miranda Souza',               '364.961.048-59',           '',                 'Av. Brasil, 1336 - 1 Andar',                       '',                           'Ferraz de Vasconcelos', 'SP', '',          '(11) 97723-2657',      null, '', null),
  (24, 'Jose Ricardo de Miranda Pires',         '013.432.346-70',           'CRO-BA 8586',      'Rua Manuel Vilaboim, 121',                         'Centro',                     'Cruz das Almas',        'BA', '44380-000', '',                     null, '', 'Não cimentar componente — enviar sempre sem cimentar.'),
  (25, 'Tiago Muller Pereira',                  '025.981.860-79',           '',                 'Av. Salgado Filho, 2839',                          '',                           'Caxias do Sul',         'RS', '',          '',                     null, '', null),
  (26, 'Raquel Ghesso Brentzel',                '435.301.458-74',           '119391',           'Rua Ibitirama, 166 - Cj 902 Torre Office',         'Vila Prudente',              'Sao Paulo',             'SP', '03134-000', '',                     null, '', null),
  (27, 'Kleber Luander',                        '144.031.517-52',           'CRO-RJ 43164',     'Av. Rotary, 947',                                  'Centro',                     'Sao Joao da Barra',     'RJ', '28200-000', '',                     null, 'Lente Novo', null),
  (28, 'Luiz Carlos Figueiredo Seixas',         '107.126.347-11',           'CRO-RJ 35796',     'Rua Conde de Bonfim, 255 - Sala 810',              'Tijuca',                     'Rio de Janeiro',        'RJ', '20520-051', '',                     null, '', null),
  (29, 'Paulo Pagano',                          '',                         '',                 'Rua Salvador Bicudo, 109',                         'Tucuruvi',                   'Sao Paulo',             'SP', '',          '',                     'paulopagano0@gmail.com', '', null),
  (30, 'Juliana Barros',                        '',                         '',                 '',                                                 '',                           '',                      '',   '',          '',                     null, '', null),
  (31, 'Pedro Silva',                           '',                         '',                 '',                                                 '',                           '',                      '',   '',          '',                     null, '', null),
  (32, 'Carlos Vinicios Camelo',                '',                         '',                 '',                                                 '',                           '',                      '',   '',          '',                     null, '', null),
  (33, 'Clinica Dr Rosmar',                     '',                         '',                 '',                                                 '',                           'Rio de Janeiro',        'RJ', '',          '',                     null, '', null),
  (34, 'Roberto Isao',                          '',                         '',                 '',                                                 '',                           '',                      '',   '',          '',                     null, '', null),
  (35, 'Rafael Heino Santos',                   '',                         '',                 '',                                                 '',                           '',                      '',   '',          '',                     null, '', null),
  (36, 'Oral 360 Copa',                         '',                         '',                 'R. Figueiredo de Magalhães, 226 - 201',            'Copacabana',                 'Rio de Janeiro',        'RJ', '22031-012', '',                     null, '', null),
  (37, 'Zivana Castilhos dos Santos',           '',                         '',                 '',                                                 '',                           '',                      '',   '',          '',                     null, '', null),
  (38, 'José Vitor Ortega',                     '349.656.358-33',          '115567',           'Av. Eugen Wissmann, 600 - 1º andar, loja 8',       'São Luiz',                   'Itu',                   'SP', '13304-270', '',                     null, '', null)
on conflict (reg) do nothing;
