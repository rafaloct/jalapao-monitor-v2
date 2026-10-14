# Jalapão Monitor V2 — catálogo editorial, contrato proposto (revisão, não migração)

**Repo auditado:** `rafaloct/jalapao-monitor-v2`, branch `main`, SHA `66f62e1b8e96009a44cf1a6fb38052d0801153a1` (consulta em 13/10/2026).

**Gate:** `AGENTS.md` exige issue `type:task` + `agent:ready` + `HUMAN_GATE=NO`, branch isolada, draft PR e revisão. A ADR `docs/adr/0001-authoritative-backend.md` permanece `PROPOSED` na issue #2. Este pacote **não altera o repositório, a instância PocketBase, o Flutter ou a VPS**.

## A. Estado comprovado no código

- Backend usado no momento: **PocketBase**, coleção `places` (schema versionado em `ops/pocketbase/pb_migrations/1791517999_collections_snapshot.js`).
- Campos obrigatórios de `places`: `name`, `type` (enum), `latitude`, `longitude`, `capacity_total` >= 1, `owner_name`, `status`, `created_at_v2`. Campos de mídia `photo_ids` e `approved_at` opcionais.
- `PlaceProvider.syncDownActivePlaces` carrega `places` com `status = "active"`. Operação ocorre em `place_visits` ligada pelo PocketBase `places.id`.
- `hub/src/lib/places-service.ts` / `hub/src/lib/types.ts` consultam `places` e visitas; apps e Hub não possuem API editorial territorial específica.
- O campo `capacity_total` é **limite operacional**, não capacidade ambiental. As 80 entradas não incluem limites aprovados.
- Arquitetura alvo da ADR #2: backend autoritativo, leitura pública sanitizada, sem persistência local durável. A decisão de trocar PocketBase ainda não está aprovada, portanto não criar backend paralelo nem alterar Hive neste pacote.

## B. Camadas de dados propostas

1. **Inventário editorial (`tourism_catalog`, nome provisório):** nomes, categoria turística, município (verificado ou pendente), fontes, imagens candidatas/licenças, geoponto verificado opcional, status editorial. Alimentado por importação versionada **server-side**, nunca embutido em Dart. Guardar revisão e autoria; campos desconhecidos são `null`.
2. **Operação (`places`, já existe):** vínculo opcional `operational_place_id` para um local já aprovado. Não criar automaticamente, nem modificar seu tipo, status, capacidade, proprietário ou coordenadas. Gestão e fluxo usam `place_visits` como hoje.
3. **Consulta pública:** projeção *somente* de registros `published`, com descrição revisada, coordenadas autorizadas e mídia com crédito/licença. Sem `owner_name`, `contact_phone`, registros de visita, dados pessoais nem atributos editoriais internos.

A nova coleção é **proposta**, não declarada como existente. Se a ADR #2 aprovar FastAPI + PostgreSQL, manter exatamente o contrato lógico em tabelas/API equivalentes, **sem replicar duas fontes autoritativas**.

## C. Contrato de migração sugerido para implementação posterior (dependente do gate)

**`tourism_catalog`** (novo recurso backend, NOT DEPLOYED), com índices e permissões sugeridos:

| Campo | Tipo | Regra |
|---|---|---|
| `id` | ID próprio do backend | distinto de `external_key`, distinto de `places.id` |
| `external_key` | string única, obrigatória | chave de idempotência estável do inventário; índice UNIQUE |
| `canonical_name`, `aliases` | texto / JSON | exibição e variantes, jamais FK por nome |
| `category_code`, `classification` | select/text + JSON | taxonomia turística, independente de `places.type` |
| `municipality`, `geolocation` | JSON / lat,lon opcionais | sem números falsos, com fonte + status de verificação |
| `publication_state`, `editorial_review_state` | enum | `draft` inicial; `published` só após curadoria explícita |
| `visitation_authorized` | bool opcional | `null` significa **desconhecido**, nunca `true` por padrão |
| `operational_place_id` | relation opcional → `places` | só após reconciliação manual e aprovação do gestor |
| `sources`, `media_candidates` | JSON ou collections filhas | autor, link, licença, validade, representatividade, data de validação |
| `created_at`, `updated_at`, `reviewer`, `source_version` | auditoria | versionados pelo servidor; preservar correções e fontes |

**Segurança:** criar/editar/publicar exclusivamente por coordenador/admin conforme `docs/security/ACCESS_MATRIX.md` (gate #13). Lista pública filtrada `publication_state == published`, sem leaks de imagens não autorizadas, documentos privados, dados de donos ou telefones. Para curadoria, acesso autenticado e segregado; dados pendentes nunca são listáveis publicamente. Migrar regras abertas de `places` é uma frente de segurança separada, não corrigir como efeito colateral do seed.

**Transações/upsert:** servidor deve buscar por `external_key` único; se inexistente cria **somente registro editorial draft**; se existente faz diff e revisão com trilha de alterações sem sobrescrever manualmente dados homologados. SHA do arquivo e versão são armazenados na execução de importação. Não usar `upsert` por `name`, fuzzy match, `google_maps_busca` ou `photo_reference`.

## D. API dinâmica proposta (não implementada)

- `GET /v1/catalog/attractions?page=1&per_page=30&region=...&category=...`: responde itens `published` sem PII, com paginação e data de revisão.
- `GET /v1/catalog/attractions/{external_key}`: detalhes públicos com `photo_url`, `credit`, `license_code`, `source_page`, quando liberados.
- `GET /v1/catalog/attractions/{external_key}/operational-status`: fluxo *somente se `operational_place_id` apontar para `places.active`*; limites operacionais separados de ambientais.
- `POST /v1/admin/catalog/imports/preview` → plano de diff com `creates`, `updates`, `conflicts`, `unverified` e SHA. `apply` separado, autenticado, auditado, protegido por revisão e backup.

Esses caminhos são **interface proposta**, não endpoints em execução. O Flutter deve consumir repositório/API de catálogo com paginação, estado de conexão e placeholders. O hub consulta a mesma autoridade. Sem `assets/*.json` e sem `const attractions = [...]` no cliente. O cache, se existir, segue a futura ADR; sem esconder ausência de confirmação server-side.

## E. Uso de Google Maps e imagens

- `links.maps_search_url` é **link de busca**, não `lat/lon` confirmado nem Place ID. Não confundir link público com localização real.
- `media_candidates` são propostas de imagens. **Todas `publish_approved = false`**. Até as 16 imagens com licença Wikimedia declarada requerem checagem final de autoria, licença, representatividade e atribuição; três nomes têm risco explícito de foto genérica não correspondente.
- 5 galerias institucionais: página para consulta, não redistribuir imagem sem licença ou consentimento documentado.
- Google Places Photos deve respeitar atribuições, condições da API, quotas e cache. Fotos do Maps não são assets do projeto por padrão; chave de API permanece server-side.
- Não presumir que estar numa comunidade quilombola autorize visita ou divulgação de práticas culturais. Registrar consentimento/decisão comunitária quando aplicável.

## F. Gates antes de importar ou publicar

1. Aprovar issue de tarefa restrita ao **contrato e dataset** (independente do ADR), incluindo testes de esquema/dedup, sem deploy.
2. Resolver gate de arquitetura #2 para implementação de nova collection/projeção; revisar matriz #13 e exposições do backend.
3. Confrontar as 80 chaves com export sanitizado do PocketBase real **somente via procedimento read-only e autorizado**, sem chamar produção neste pacote.
4. Homologar município/identidade, coordenadas e licenças de mídia por fonte, com responsável e data.
5. Revisar e aprovar publicação item a item. Separadamente, o gestor aprova qualquer vínculo em `places`.
6. Testar ingestão em ambiente sintético/isolado, repetição idempotente, rollback, regras públicas e não divulgação de dados de pesquisa/PII.

## G. Execução local desta entrega

```sh
python tools/build_catalog.py
python tools/validate_catalog.py
python tools/reconcile_places_preview.py                         # sem dados de servidor
python tools/reconcile_places_preview.py --existing-places /caminho/export-places-sanitizado.json  # offline e read-only
python -m unittest discover -s tests -v
```

A execução acima não depende de segredos, internet, PostgreSQL, PocketBase ou emulador. Export real deve ser autorizado separadamente e **sanitizado**: basta `id`,`name`,`status` (não incluir dados pessoais).
