# Contrato — catálogo editorial de atrativos (`catalog_review_v1`)

Proposta da issue #64. Status: **proposta para revisão** — nenhum schema,
collection ou endpoint foi criado. Depende da decisão de arquitetura da #2 e de
gate próprio antes de qualquer publicação ou importação.

## Separação de domínio

`places` é a collection **operacional**: locais em monitoramento, com
`status=active` sincronizados pelo app (`syncDownActivePlaces`), `capacity_total`
e `owner_name` obrigatórios. Misturar atrativos editoriais ali injetaria locais
não operacionais no tablet e exporia campos indevidos.

O catálogo editorial é um **domínio à parte**: fonte curada de atrativos
turísticos para referência pública/pesquisa, com ciclo de revisão próprio.

```
editorial (draft → reviewed → published)   ≠   operacional (places.status)
```

Nenhum registro do dataset possui coordenada, capacidade, proprietário ou vínculo
operacional. `operational_binding` é estruturalmente `null` e o reconciliador
emite apenas candidatos a verificação humana.

## Proposta de recurso (alvo, não implementado)

Compatível com PocketBase vigente e com o backend autoritativo da ADR #2:

| Aspecto | Proposta |
|---|---|
| Recurso | `catalog_attractions` (collection ou endpoint read-only equivalente) |
| Chave | `external_key` (slug estável), imutável após publicação |
| Estado | `editorial_state`: `draft` → `reviewed` → `published`; transições exigem papel editorial, nunca o app de campo |
| Campos | os do schema `catalog_review_v1.schema.json`; geo só entra após verificação de campo, com `location_status` próprio |
| Mídia | `media.photo` somente com licença e atribuição completas; galerias institucionais permanecem como link |
| Vínculo | relação opcional `place` criada **manualmente** após revisão; nunca pelo reconciliador |
| PII | proibida por contrato (validador rejeita `owner_name`/`telefone`/`email` etc.) |

No PocketBase atual isso caberia como collection separada com regras de leitura
pública só após `published`; na arquitetura da #2, como recurso editorial servido
pelo backend autoritativo. A escolha final pertence à ADR — este contrato não
a substitui.

## Gates obrigatórios

1. **#2 (ADR arquitetura)**: define onde e como o recurso editorial existe.
   Nenhuma migration/schema antes da aprovação.
2. **Revisão editorial humana**: cada registro sai de `draft` por decisão
   registrada; equivalências (`possivel`, `confirmada_por_nome`) exigem
   confirmação antes de fusão — ex.: Morro da Pedra Furada ↔ Pedra Furada segue
   pendente propositalmente.
3. **Licenças de mídia**: fotos herdadas e galerias institucionais só publicam
   com autorização/licença verificada (travas no LEIA-ME da fonte).
4. **Importação**: converter dataset → backend é tarefa futura com escopo
   próprio; este PR não contém código de importação nem `--apply`.

## Arquivos do contrato

- `catalog_review_v1.schema.json` — schema do dataset (envelope + registro).
- `BACKEND_INTEGRATION.md` — proposta de integração backend preservada verbatim do pacote de revisão original; os comandos da seção G referem-se às ferramentas internas do pacote (`tools/`), equivalentes no repo a `tooling/catalog/`.
- Dataset: `data/catalog/jalapao_serras_2026/` (fonte + `catalog_review_v1`).
- Enforcement: `tooling/catalog/validate_catalog.py` (fail-closed).
