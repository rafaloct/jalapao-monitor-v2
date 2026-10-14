# Catálogo visual para validação do Jalapão Monitor V2

Atualizado em 13/10/2026. **Não publicar automaticamente em produção.**

## Resumo
- 62 atrativos transcritos do mapa fornecido pelo usuário.
- 28 entradas do catálogo visual anterior, incluindo fervedouros não representados na segunda lista.
- 10 correspondências vinculadas entre os dois conjuntos.
- **80 entradas totais** após consolidação, mantendo a equivalência Morro da Pedra Furada/Pedra Furada como pendente, sem fusão automática.
- 16 fotografias vinculadas e com licença indicada. Fotos herdadas do catálogo anterior precisam de checagem final antes da publicação.
- 5 galerias oficiais encontradas, mas com reprodução no aplicativo bloqueada até autorização/licença.
- 59 registros ainda sem imagem com licença informada.

## Arquivos
- `jalapao_catalogo_62_mais_anteriores.json`: dados estruturados para uma etapa de importação ao app; contempla `foto_status`, `google_maps_busca`, `municipio_status`, `nota_validacao`, links e IDs.
- `jalapao_catalogo_62_mais_anteriores.csv`: CSV UTF-8 com BOM, delimitador ponto e vírgula.
- `jalapao_catalogo_62_mais_anteriores.xlsx`: planilha revisável, com aba completa e aba dos 62 pontos do mapa.
- `galeria_jalapao_serras_62_expandida.html`: pré-visualização com busca, filtros e links.

## Fontes e alertas
- PDITS polo Jalapão (planejamento, não condição atual de acesso): https://central3.to.gov.br/arquivo/553119/
- Galerias Prefeitura de Almas: https://www.almas.to.gov.br/galerias
- Guia turístico municipal de Dianópolis: https://www.dianopolis.to.gov.br/guiacidade/pontos-turisticos/1
- Observatório do Turismo de Tocantins, Serras Gerais: https://observatorio.turismo.to.gov.br/observatorio/pesquisas/plano-desenvolvimento-regional/serras-gerais/
- Lagoa da Serra, Wikimedia Commons: https://commons.wikimedia.org/wiki/File:Lagoa_da_Serra,_em_Rio_da_Concei%C3%A7%C3%A3o,_Tocantins.jpg

### Travas para o app
1. O mapa é **material ilustrativo de divulgação turística**, não prova de acesso livre, registro oficial atual ou coordenadas.
2. `google_maps_busca` é **link de pesquisa**, não localização geográfica validada nem Place ID.
3. `foto_status=galeria_institucional_uso_pendente`: pode abrir a galeria via link, mas não utilizar imagem de arquivo no app sem autorização.
4. Para fotos do Wikimedia, apresentar **autor, licença, URL da fonte e indicação de modificações** quando aplicável.
5. **Urubu Rei:** arquivos do Wikimedia encontrados são de Cavalcante/GO, diferente do atrativo de Almas/TO.
6. **Terra Ronca:** exige desambiguação territorial, não atribuir fotos da Terra Ronca em Goiás automaticamente.
7. **Morro da Pedra Furada:** equivalência com Pedra Furada é provisória, revisar antes de fundir no banco canônico.
8. **Produção de Cachaça e Licores:** experiência produtiva sem POI identificável; requer endereço específico.
9. Evitar cache permanente de fotografias do Google Places fora das regras vigentes da plataforma.
