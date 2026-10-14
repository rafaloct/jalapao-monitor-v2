# Catálogo editorial Jalapão + Serras Gerais — `jalapao_serras_2026`

Dataset **editorial de revisão**, versionado a partir do pacote entregue pelo
mantenedor em 13/10/2026 (issue #64). Não é cadastro operacional e **não alimenta
`places`**: nenhum registro aqui pode ser publicado, vinculado a `places` ou
usado com foto antes de revisão humana e do gate da arquitetura (#2).

## Proveniência

| Item | Valor |
|---|---|
| Pacote | `pacote_jalapao_serras_62_catalogo_atualizado.zip` (branch `rafaloct-patch-1` @ 92d4344) |
| Pacote de revisão | `jalapao_monitor_v2_catalogo_backend_80_review.zip` (branch `rafaloct-patch-2` @ 7d58c09), SHA-256 `137ebfe12e74c6a14a698b6b162d0831fc57f7d2b110d25995de9c23778dcb81` |
| Fonte canônica | `source/original_80_review_2026-10-13.json` (idêntica a `jalapao_catalogo_62_mais_anteriores.json`) |
| SHA-256 da fonte | `8000419b79b040b7c934a4eb059d7991f4878ad85290db29336ef741272d5a23` |
| Versão da fonte | `0.2.0-review` (2026-10-13), status `rascunho_verificavel_nao_publicar_automaticamente` |
| Registros | 80 = 62 pontos transcritos do mapa + 28 do catálogo anterior − 10 sobreposições |

A fonte é preservada em `source/` também com o nome citado na issue
(`original_80_review_2026-10-13.json`): conteúdo byte a byte idêntico a
`jalapao_catalogo_62_mais_anteriores.json`, mesmo SHA-256. O pacote completo é
preservado em `source/`, incluindo os zips de transporte e as visões derivadas de
revisão (`*.csv`, `*.xlsx`, `galeria_*.html`); o JSON é a fonte canônica e os
demais são evidências regeneráveis. `SHA256SUMS.txt` cobre todos os artefatos
(`sha256sum -c source/SHA256SUMS.txt` → 8 OK).

## Arquivos

- `source/` — pacote original completo + manifesto de checksums.
- `catalog_review_v1.json` — dataset normalizado (envelope + 80 registros draft).
- `catalog_review_v1.jsonl` — um registro por linha, mesma ordem e conteúdo do JSON.
- `editorial_review_queue.csv` — fila de trabalho editorial (80 registros, verbatim do pacote de revisão).
- `reports/` — evidências da validação do pacote original: `preflight.json`, `operational_linkage_preview.json`, `tests_stdout.txt`, `tests_stderr.txt`.
- Schema: `docs/contracts/catalog/catalog_review_v1.schema.json`.

## Regras editoriais (resumo; enforcement em `tooling/catalog/validate_catalog.py`)

1. Todo registro é `editorial_state: draft`. Nenhuma publicação automática.
2. `latitude`/`longitude`/`google_place_id` são `null`: o mapa é material
   ilustrativo, não levantamento oficial. `google_maps_search_url` é link de
   busca, não coordenada.
3. `operational_binding` é sempre `null`: o reconciliador só emite candidatos.
4. Fotos só existem com `foto_licenciada` + autor/licença/atribuição explícitos.
   Galerias institucionais ficam como link pendente de autorização.
5. Município `pendente`/`herdado` permanece explícito; nada é inferido.
6. Sem PII: este dataset é potencialmente público após revisão; campos como
   `owner_name`/`telefone`/`email` são rejeitados pelo validador.

## Regenerar e validar

```bash
python3 tooling/catalog/build_review_dataset.py   # reemite JSON/JSONL (determinístico)
python3 tooling/catalog/validate_catalog.py        # PASS/FAIL fail-closed
python3 -m unittest discover -s tooling/catalog/tests -v
```
