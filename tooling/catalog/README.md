# tooling/catalog — ferramentas do catálogo editorial (#64)

Python 3, somente stdlib, sem rede e sem credenciais. Todas as ferramentas são
read-only em relação a qualquer sistema externo: nenhuma possui `--apply` —
a opção sequer existe e falha via argparse.

| Ferramenta | Função |
|---|---|
| `build_review_dataset.py` | Reemite `catalog_review_v1.json`/`jsonl` a partir da fonte versionada; aborta se o SHA-256 divergir. |
| `validate_catalog.py` | Pré-validador fail-closed: JSON Schema contratual + regras editoriais (draft, sem geo, sem vínculo, foto só com licença, sem PII, proveniência). |
| `reconcile_places.py` | Compara o dataset com um export **sanitizado** de `places` (`[{"id","name","status"}]`) e emite candidatos a verificação manual. Nunca escreve. |
| `jsonschema_lite.py` | Subconjunto mínimo de JSON Schema usado pelo validador (sem dependência externa). |
| `tests/` | `python3 -m unittest discover -s tooling/catalog/tests -v` |

## Uso

```bash
# Validar o dataset versionado (gate editorial)
python3 tooling/catalog/validate_catalog.py

# Reconciliar com export sanitizado de places (gerado manualmente, fora desta tarefa)
python3 tooling/catalog/reconcile_places.py caminho/places_export.json --out candidatos.json
```

O export de `places` deve conter apenas `id`, `name`, `status` — qualquer campo
extra (ex.: `owner_name`) faz a carga falhar. O relatório produz candidatos com
`action: manual_review_required`; decidir equivalência é ato humano, nunca
escrita automática.
