# ADR 0001 — Backend autoritativo sem banco local no cliente

- **Status:** `PROPOSED` — aguarda aprovação explícita de Rafael na
  [Issue #2](https://github.com/rafaloct/jalapao-monitor-v2/issues/2),
  indicando commit/versão desta ADR. Nenhuma implementação estrutural está autorizada.
- **Data:** 2026-10-06
- **Tarefa de elaboração:** [Issue #18](https://github.com/rafaloct/jalapao-monitor-v2/issues/18)
- **Base de evidência:** `main @ a6d9bfe1507f9d75e6d4a872c17501c435204634`;
  execução do baseline registrada em `docs/evidence/BASELINE_EXECUTION.md`
  (entregue no [PR #27](https://github.com/rafaloct/jalapao-monitor-v2/pull/27),
  ainda em revisão — não presume integração).
- **Decisões transversais pendentes:** matriz de acesso/ameaças (#19, aprovação na
  #13), contrato canônico de sessão (#23), remoção do fallback de credencial (#24),
  plano de CI (#20/#21).

## 1. Contexto

O Jalapão Monitor coleta fluxo turístico em ~10 atrativos com tablets em área de
**conectividade irregular**. A arquitetura observada é offline-first:

- **App Flutter** (`lib/`) persiste tudo em **Hive** e sincroniza a cada 30 s com
  **PocketBase** (`sync_service.dart`, `place_provider.dart`).
- **PocketBase** (VPS, `:8090`) é o backend central; armazena em UTC; regras de
  collection abertas e `_superusers` para administração.
- **Hub Next.js** (VPS, `:3000`) lê o PocketBase e apresenta ao coordenador.

A arquitetura alvo definida na Issue #2 elimina o banco local do cliente e torna o
backend a única fonte autoritativa, **sem esconder o risco da conectividade**.

### Nota de fundamentação

A revisão citada na #2 sustenta arquiteturas distribuídas e processamento próximo
da fonte (Kumar & Vaishnava, 2025, DOI 10.1109/MRIE66930.2025.11156708;
Hernández-Cabrera et al., 2024, DOI 10.1007/978-3-031-52607-7_13), mas **recomenda
explicitamente considerar operação offline e sincronização posterior** em destinos
remotos. Portanto "sem banco local" é tratado aqui como **restrição de produto a
testar**, não como recomendação da literatura: esta ADR precisa demonstrar
integridade transacional, UX honesta e continuidade operacional sob essa restrição.

### Requisito crítico (da #2)

> Sem persistência local, uma operação não confirmada pelo servidor não pode
> aparecer como definitivamente salva. UX explícita para conexão degradada.

## 2. Arquitetura observada × arquitetura alvo

Diagrama C4 de contêineres das duas arquiteturas:
[`0001-c4-container.md`](./0001-c4-container.md).

| Aspecto | Observado (baseline `a6d9bfe`) | Alvo (proposta) |
|---|---|---|
| Persistência no cliente | Hive (durável, autoridade local até o sync) | **Nenhuma durável**; apenas cache transitório em memória |
| Autoridade | Dividida (cliente grava primeiro) | **Somente o servidor**; cliente envia comandos e recebe confirmações |
| API | SDK PocketBase (CRUD direto em collections abertas) | API de comandos REST/OpenAPI, versionada por `schema_version` |
| Estado operacional no Hub | Poll REST + merge `visits`/`place_visits` | Eventos realtime (SSE/WebSocket) + leitura REST |
| Conectividade | Sync periódico tolerante a falha; operação continua offline | Estados explícitos de conectividade (§5); operação pendente nunca aparece salva |
| Autenticação | PIN local com fallback + PocketBase | Autenticação individual + dispositivo cadastrado, conforme matriz da #19 (gate #13) |
| Transporte | HTTP cleartext configurável (`PB_URL` http) | HTTPS obrigatório em qualquer ambiente real |
| Schema/dados | Collections `places`, `visits` (legado), `place_visits`, `reservations` em UTC | Mesmas entidades migradas para store autoritativo; UTC preservado; política BRT da `tz.ts` mantida |

## 3. Opções consideradas

Nenhuma opção abaixo está aprovada; a coluna "decisão" registra recomendação para
avaliação do mantenedor.

### Opção A — Manter PocketBase self-hosted (baseline evoluído)

Backend atual no VPS existente, endurecido: regras de collection fechadas,
autenticação real, HTTPS, hooks de confirmação/idempotência via `pb_hooks`.

- **Prós:** zero migração de stack; realtime nativo; admin UI; custo marginal zero
  (VPS já provisionado); menor time-to-pilot.
- **Contras:** idempotência/dedup de comandos depende de hooks não versionados hoje
  (nenhum `pb_hooks/`/`pb_migrations/` no checkout — lacuna registrada na #17);
  contrato de API implícito no SDK, não em OpenAPI; matriz papel×recurso da #19
  teria de ser traduzida em regras de collection (capacidade menor que RBAC/RLS
  explícito); SPOF em VPS único.

### Opção B — Postgres gerenciado + camada de API gerenciada

Store autoritativo em Postgres gerenciado (Neon, DigitalOcean, Supabase ou
equivalente), acessado via camada gerenciada (PostgREST/Data API do provedor) ou
API mínima.

- **Prós:** durabilidade/backups gerenciados; RLS nativo alinha-se à matriz #19;
  escala sem administrar banco.
- **Contras:** latência para o Jalapão (regiões fora do Brasil na maioria dos
  provedores — verificar região antes da decisão); realtime e semântica de comando
  ainda exigem camada própria; custo mensal adicional contínuo; lock-in parcial de
  realtime/auth se usar Supabase.

### Opção C — FastAPI + Postgres (API própria autoritativa)

API REST/OpenAPI escrita em FastAPI (comandos, idempotência, dedup, confirmação,
SSE para realtime) sobre Postgres — self-hosted no VPS ou gerenciado.

- **Prós:** contrato de comandos explícito e testável (alinha com o contrato
  canônico da #23); controle total de idempotência, deduplicação e confirmação
  server-side; OpenAPI gera clientes e documenta a API; independe do realtime de
  um BaaS; PostgreSQL puro facilita RLS, auditoria e exportações para pesquisa (#11).
- **Contras:** mais código para construir e operar (auth, realtime, backups);
  exige provisionamento versionado (hoje inexistente); maior esforço até o piloto.

### Custos estimados (USD/mês — fontes consultadas em 2026-10-06)

| Opção | Componentes | Estimativa | Fonte |
|---|---|---|---|
| A — PocketBase atual | VPS já provisionado (Hostinger KVM 1 como referência: 1 vCPU/4 GB) | US$ 6,49/mês (intro; renova US$ 11,99) → **incremental ~US$ 0** | [hostinger.com/pricing/vps-hosting](https://www.hostinger.com/pricing/vps-hosting) |
| B — Postgres gerenciado | DB gerenciado mínimo + VPS p/ API/camada | DO Managed PG single node **desde US$ 15,15**; Neon Launch pay-as-you-go **US$ 0,106/CU-hora + US$ 0,35/GB** (ex. de uso ~US$ 23,47); Supabase Pro **desde US$ 25**. + VPS ~US$ 6,49 → **~US$ 21–35/mês** | [digitalocean.com/pricing/managed-databases](https://www.digitalocean.com/pricing/managed-databases), [neon.com/pricing](https://neon.com/pricing), [supabase.com/pricing](https://supabase.com/pricing) |
| C — FastAPI + Postgres | VPS único (FastAPI+PG self-managed) ou VPS + PG gerenciado | **~US$ 6,49–12** self-managed; **~US$ 21–28** com PG gerenciado | mesmas fontes |

Custos não incluem tempo de operação/backup — Opção A/C self-managed transferem
esse custo para o mantenedor. Estimativas servem para comparação de ordem de
grandeza; o orçamento exato é decisão pendente (§10).

### Recomendação registrada para avaliação

**Opção C (FastAPI + Postgres)** é a recomendada para avaliação: é a única que
torna explícitos, no próprio contrato, os requisitos críticos da #2 (comandos,
idempotência, deduplicação, confirmação server-side), alinha-se ao contrato
canônico da #23 e à matriz da #19 sem depender de regras de collection. A Opção A
é o caminho de menor custo/prazo se o piloto exigir rapidez — os requisitos seriam
atendidos via `pb_hooks` versionados. **A escolha final é decisão humana na #2.**

## 4. Cliente sem banco local e cache transitório

- **Permitido:** estado em memória — fila de comandos pendentes, última leitura de
  catálogo (`places`), progresso de UI. Reiniciar o app descarta tudo.
- **Proibido:** qualquer store durável no cliente (Hive/SQLite/arquivo). Se uma
  janela de continuidade operacional for exigida no piloto, ela vira decisão
  explícita — não workaround silencioso.
- **Perda de estado ao reiniciar (consequência assumida):** comandos enviados e
  não confirmados são esquecidos pelo cliente. A recuperação é **server-side**:
  o cliente consulta o estado autoritativo por chave natural (ex.: visita aberta
  da sessão/grupo, reserva do dia) e reconfirma; um comando reenviado com a mesma
  `idempotency_key` retorna a confirmação original sem duplicar efeito (§6).
- **UX honesta:** comandos pendentes exibem estado `pendente de confirmação`
  (nunca "salvo"); operação sem confirmação não altera contadores definitivos nem
  aparece em relatórios do cliente.

## 5. Modelo de falhas de conectividade

Estados do cliente (transições observáveis e exibidas na UI):

```
CONECTADO ⇄ DEGRADADO → OFFLINE → RECONEXÃO → CONECTADO
    └──────── TIMEOUT_APOS_ENVIO (subestado de todo envio)
```

| # | Cenário de falha | Detecção | Comportamento do cliente | Comportamento do servidor | UX |
|---|---|---|---|---|---|
| F1 | Offline antes de enviar | Sem socket/timeout imediato | Enfileira em memória como `pendente`; não inventa resposta | Não recebe nada | Banner "offline"; ação marcada pendente |
| F2 | Degradado (latência/perda) | Timeout parcial, retries esgotados | Mantém `pendente`, backoff exponencial com jitter, limite de tentativas | Idem | Banner "conexão instável"; pendente visível |
| F3 | **Timeout após envio** | ACK não recebido; servidor pode ter aplicado | **Não assume falha nem sucesso**: reenvia o mesmo comando com a mesma `idempotency_key` | Dedup por `idempotency_key`: se já aplicado, retorna a confirmação original | Estado permanece `pendente` até confirmação; nunca "salvo" |
| F4 | Restart com pendentes | Fila vazia após boot | Consulta resultado por chave natural/idempotency conhecida | Responde estado real do recurso | Lista reflete só o confirmado; operador re-submete o que faltar |
| F5 | Resposta de conflito (estado mudou) | 409/erro de validação | Exibe conflito; não reaplica cegamente | Rejeita com motivo estruturado | Mensagem clara + estado real do servidor |
| F6 | Offline prolongado | Contagem/idade dos pendentes | Sobe nível de alerta; decisão de continuar coletando é política (§10) | — | Indicador persistente; dados pendentes listáveis |
| F7 | Reconexão | Primeiro request bem-sucedido | Reenvia pendentes em ordem, um round de sync | Aplica idempotente; emite eventos | Pendentes viram `confirmado` individualmente |

Validação desta ADR incluiu revisão desta tabela contra os requisitos da #2;
nenhuma chamada a ambiente operacional foi feita (escopo da #18).

## 6. Comandos, idempotência e realtime

- **Comandos REST/OpenAPI:** `POST /v1/...` com corpo de comando; OpenAPI é
  contrato versionado (`schema_version`). Respostas têm envelope:
  `event_id`, `status` (`applied|duplicate|rejected`), `server_timestamp` (UTC),
  `entity`, `entity_id`, `version`.
- **Idempotency:** o cliente gera `idempotency_key` (UUID v4) por intenção de
  operação, **antes** do primeiro envio; retry usa a mesma chave. O servidor
  garante unicidade (`idempotency_key` única por ator+dispositivo) e chaves
  naturais únicas (ex.: uma visita aberta por sessão+grupo) como segunda linha.
- **Consulta de resultado:** `GET` por `idempotency_key` e por chave natural —
  necessária no F3/F4.
- **Realtime:** SSE (unidirecional, simples, atravessa proxies) para estados
  operacionais do Hub/TV; WebSocket como alternativa se exigir bidirecional —
  decisão pendente (§10).
- **Confirmação server-side:** somente o `200`+envelope `applied|duplicate` move
  o item de `pendente` para `confirmado`.

## 7. Coexistência, migração e rollback

**Princípio:** Hive e os fluxos atuais permanecem intactos até o gate da #2; a
migração é faseada e reversível.

| Fase | Conteúdo | Critério de saída |
|---|---|---|
| 0 — Preservação | Código atual intacto; novo backend provisionado em ambiente descartável (nunca o PocketBase real) | Provisionamento versionado; CI do novo backend verde |
| 1 — Sombra | App novo escreve no novo backend; PocketBase/Hive continuam operando; comparadores verificam paridade de contagens | Diferenças explicadas em evidência de teste |
| 2 — Piloto | Um atrativo no novo backend; dados históricos migrados de `visits`/`place_visits`/`reservations` via export (UTC preservado) | Piloto com critérios de aceite de campo definidos em tarefa própria |
| 3 — Cutover | Demais atrativos; PocketBase entra em modo leitura | Nenhum registro divergente por período acordado |

**Rollback:** em qualquer fase ≤2, voltar é ligar de novo o caminho Hive→PocketBase
(dados nunca deixaram de existir lá). Após cutover, rollback exige exportação
reversa; por isso o modo leitura do PocketBase é mantido por janela acordada.

## 8. Contrato de APIs e eventos (esboço, a detalhar na #23)

- Recursos: `monitoring_sessions`, `place_visits`, `reservations`, `places`,
  `devices`, `actors`.
- Eventos emitidos pelo servidor: `session.opened/closed`, `visit.queued/
  entered/exited`, `reservation.checked_in/out`, `place.updated` — envelope com
  `event_id`, `schema_version`, `occurred_at` (UTC), `actor`, `device_id`,
  `idempotency_key`.
- Autorização por papel conforme matriz #19 (pendente de aprovação na #13).
- Contratos de **monitoramento** não cobrem cartografia — domínio separado.

## 9. Riscos

| Risco | Mitigação nesta proposta |
|---|---|
| Conectividade Jalapão pior que o previsto; restrição "sem banco local" inviabiliza operação | Piloto faseado com critérios de abortar; F1–F7 modelados; decisão de fila-local-mínima fica explícita (§10) em vez de workaround |
| Timeout pós-envio duplica coleta | Idempotency key + dedup server-side (F3) |
| Restart perde pendências | Aceito por desenho; recuperação por consulta de resultado (F4) |
| Dois tablets no mesmo atrativo | Limitação persiste — dedup por chave natural reduz, mas a recomendação de 1 tablet/local permanece |
| SPOF no VPS / falta de backups | Opção B/C com PG gerenciado, ou backup versionado na Opção A — decisão de custo (§10) |
| Transporte cleartext atual | HTTPS obrigatório no alvo |
| Regras abertas/PIN fallback do baseline | Registrados como riscos; remoção condicionada a #19/#24 |
| Latência de DB gerenciado fora do Brasil | Verificar região antes de optar por B |

## 10. Decisões pendentes (para aprovação na #2 e correlatas)

1. Opção de backend (A/B/C) e orçamento mensal aprovado.
2. Política offline: tamanho/limite da fila transitória e comportamento em F6.
3. Transporte realtime: SSE × WebSocket.
4. Região/provedor se Postgres gerenciado.
5. Janela de migração, período de sombra e de modo-leitura do PocketBase.
6. Matriz de acesso (#19→#13) e modelo de provisionamento de credenciais (#24).
7. Contrato canônico de sessão/eventos (#23).
8. Requisito de continuidade mínima offline — inclui o teste de campo da restrição
   "sem banco local" conforme a tensão bibliográfica da #2.

## 11. Validação desta entrega

- Links internos revisados; diagrama referenciado: [`0001-c4-container.md`](./0001-c4-container.md).
- Tabela de cenários de falha em §5; nenhuma chamada a ambiente operacional.
- Status `PROPOSED`; nenhuma mudança funcional, de schema ou de credencial foi feita.
