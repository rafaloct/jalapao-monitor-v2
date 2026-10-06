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

O Jalapão Monitor é o componente tecnológico do projeto *"O uso da inteligência
artificial e os desafios no gerenciamento do fluxo de visitantes em áreas de
interesse turístico no Jalapão"* — pesquisa e extensão universitária no contexto
**UFT/NERUDS**, Edital nº 02/2024 FAPT/SEPLAN, Projeto **REDE DESER**, com atuação
em **Mateiros e São Félix do Tocantins** (orientação acadêmica: Cleiton Milagres).
O histórico do projeto registra **duas frentes com requisitos distintos**:

- **Monitoramento turístico:** registros de visitação/movimentação, carga e
  ocupação dos atrativos — escopo desta ADR.
- **Cartografia social / Diagnóstico Rural Participativo:** atividades mediadas
  por pesquisadores e facilitadores com comunidades — domínio separado (§8),
  cujos requisitos ficam identificados aqui sem serem cobertos por esta ADR:
  uso em grupos, registros de campo consolidados posteriormente e **necessidade
  histórica de operação offline**. O planejamento de ~6 tablets para cartografia
  **não comprova** que os mesmos equipamentos estejam distribuídos ou operando
  permanentemente nos atrativos turísticos.

Em ambas as frentes a conectividade é irregular e interrupções precisam entrar
nos cenários de planejamento e validação. A arquitetura observada é offline-first:

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

**Recomendada: Opção C — API própria em FastAPI sobre PostgreSQL**
(FastAPI servindo comandos REST/OpenAPI + SSE; Postgres como store autoritativo,
self-hosted no VPS existente ou gerenciado). A comparação acima reconhece que a
Opção A **também** pode cumprir os requisitos da #2 (via `pb_hooks` versionados);
a preferência por C não se apoia em unicidade, mas em vantagens concretas:

- **Contrato como artefato:** OpenAPI versionado e revisionável documenta e
  testa o protocolo de comandos; em A, a semântica ficaria distribuída entre SDK
  e hooks difíceis de auditar fora do servidor.
- **Idempotência e confirmação como endpoints de primeira classe:** dedup,
  consulta de resultado e reconciliação pós-restart (§4.3) são parte da API,
  não comportamento de hook.
- **Independência de BaaS:** realtime (SSE), auth e auditoria não herdam lock-in
  nem limites do PocketBase; Postgres puro oferece RLS, auditoria e exportação
  direta para a frente de pesquisa (#11).
- **Continuidade institucional:** OpenAPI + Postgres abertos permitem operação
  e transição por outra equipe sem o BaaS original — relevante em projeto
  acadêmico com rotatividade.

Justificativa nos cinco eixos exigidos pelo mantenedor:

| Eixo | Análise da recomendação |
|---|---|
| Funcionamento nas condições reais de campo | Torna explícito, no contrato OpenAPI versionado, o modelo de falhas F1–F7 (comandos, `idempotency_key`, dedup, consulta de resultado, confirmação server-side) — requisito da #2 e condição para UX honesta sob conectividade irregular. A Opção A pode atender aos mesmos requisitos funcionais via `pb_hooks`; a vantagem de C é que o contrato é artefato versionado e testável, não convenção embutida no SDK/hooks. |
| Custos de implantação e manutenção | ~US$ 6,49–12/mês self-managed no VPS (incremental ~zero) ou ~US$ 21–28 com PG gerenciado — tabela acima. Orçamento global do projeto **não é** autorização de infraestrutura; aprovação específica é pré-condição. |
| Capacidade da equipe de operar | Maior superfície operacional (auth, realtime, backups próprios); mitigada por provisionamento versionado e pelo conhecimento prévio da equipe em FastAPI/Postgres (propostas anteriores do projeto). Se a capacidade for o gargalo, a Opção A é o fallback honesto. |
| Migração e preservação dos dados | Fases 0–3 da §7 preservam Hive/PocketBase até cutover; exportação UTC e modo-leitura garantem reversibilidade e continuidade da série histórica da pesquisa. |
| Continuidade após a etapa de pesquisa | Contrato OpenAPI + Postgres aberto permitem operação, exportação e transição institucional sem depender de BaaS ou do mantenedor atual — relevante para um projeto acadêmico com rotatividade. |

A **Opção A — PocketBase self-hosted endurecido** é o caminho de menor custo e
prazo se o piloto exigir rapidez: os mesmos requisitos seriam atendidos via
`pb_hooks` versionados + regras fechadas, com contrato implícito no SDK como
consequência assumida. **A escolha final é decisão humana na #2** — propostas
anteriores do histórico não constituem aprovação de migração.

## 4. Cliente sem banco local e cache transitório

- **Permitido:** estado em memória — fila de comandos pendentes, última leitura de
  catálogo (`places`), progresso de UI. Reiniciar o app descarta tudo.
- **Proibido:** qualquer store durável no cliente (Hive/SQLite/arquivo). Se uma
  janela de continuidade operacional for exigida no piloto, ela vira decisão
  explícita — não workaround silencioso.
- **Perda de estado ao reiniciar (consequência assumida):** todo o estado em
  memória é descartado — **inclusive as `idempotency_key`s geradas pelo
  cliente**. A recuperação distingue três casos (detalhe em §4.3):
  rascunhos não enviados se perdem; registros confirmados reaparecem na próxima
  leitura; envios com resultado incerto só são recuperáveis por consulta
  server-side por **chave natural** — a chave de idempotência esquecida não pode
  ser reutilizada nem reconstruída pelo cliente (§6).
- **UX honesta:** comandos pendentes exibem estado `pendente de confirmação`
  (nunca "salvo"); operação sem confirmação não altera contadores definitivos nem
  aparece em relatórios do cliente.

### 4.1 Respostas às perguntas de campo da restrição

Perguntas do mantenedor (inputs de 2026-10-06) respondidas para a arquitetura
alvo desta proposta — a tolerância concreta a interrupções ainda exige validação
com a equipe de campo (§10, item 9):

| Pergunta | Resposta sob a restrição "sem banco local" |
|---|---|
| Quais atividades sem conexão? | Visualizar catálogo já carregado em memória (`places`), preencher formulários e preparar comandos. Tudo que exija estado autoritativo — abrir sessão, confirmar registros, ver contagens oficiais — depende de conexão (F1). |
| Quais dependem do servidor? | Autenticação do dispositivo/ator, confirmação de qualquer comando, consulta de resultado, atualização de catálogo, dados do Hub/TV. |
| Queda durante o preenchimento? | O rascunho permanece em memória como `pendente`; se enviado sem conexão fica `pendente de confirmação` (F1/F2); o app permite continuar editando e tentando enviar. |
| App fecha ou tablet reinicia? | Todo o estado em memória é descartado: **rascunhos não enviados se perdem**; confirmados reaparecem na próxima leitura; envios com resultado incerto são recuperáveis **somente por chave natural** — a `idempotency_key` era estado de memória e se perdeu junto (F4, §4.3). |
| Como o usuário sabe que o registro chegou? | Somente o envelope `applied\|duplicate` do servidor move o item para `confirmado`; a UI exibe estado individual e lista de pendências — nenhum contador mostra "salvo" sem ACK. |

### 4.2 Consequência explícita da restrição

Se a validação de campo demonstrar que a janela de interrupção tolerada exige
sobreviver a restart do app/tablet, **algum armazenamento persistente no
dispositivo será necessário** — e chamar esse armazenamento de "cache" ou "fila"
não resolve o significado da restrição: ele seria, funcionalmente, um banco local.
As saídas honestas são:

- **Interpretação estrita (padrão desta proposta):** nenhuma persistência; perda
  de rascunhos em restart é aceita; continuidade vem da confirmação server-side.
- **Exceção nomeada:** um store local delimitado (ex.: fila de saída com TTL e
  visibilidade total ao usuário) passa a ser decisão explícita do mantenedor,
  com escopo e critérios — **equivalente a redefinir a restrição da #2**.

Esta ADR adota a interpretação estrita como padrão até que dados de campo
indiquem o contrário; a redefinição, se ocorrer, registra-se nesta ADR ou numa
sucessora — nunca como implementação silenciosa.

### 4.3 Recuperação após reinício — identificação por tipo de operação

Após restart, o cliente não possui mais a `idempotency_key` de envios anteriores
(era estado de memória). A reconciliação ocorre **exclusivamente por consulta
server-side sobre chaves naturais**, definidas por tipo de operação:

| Tipo de operação | Não enviado (rascunho) | Confirmado | Enviado com resultado incerto |
|---|---|---|---|
| `session.open` | Perdido; operador reabre sessão | Sessão ativa aparece na leitura | Consulta: sessão **aberta** para `device_id + actor` — se existir, o envio foi aplicado; se não, reenviar com chave nova |
| `visit.entry`/`visit.queued` | Perdido; grupo precisa ser re-registrado | Visita aberta aparece na fila/em campo | Consulta: visita **aberta** (`queued|visiting`) para `session + grupo` (chave natural única por sessão+grupo) |
| `visit.exit` | Perdido | Visita consta `exited` | Consulta: estado da visita aberta do grupo — se ainda `visiting`, o exit não foi aplicado; reenviar |
| `reservation.check_in`/`check_out` | Perdido | Reserva consta com novo estado | Consulta: reserva do dia para `place + grupo/hóspede`; estado servidor é a verdade |
| `place.update` (gestor/coordenador) | Perdido | Valor servidor prevalece | Consulta: recurso pelo `place_id` + comparação de `updated_at`/versão |
| `device.pair` | Perdido | Dispositivo consta pareado | Consulta: dispositivo por `device_id`; se não pareado, novo código |

Requisito derivado para o contrato (#23): **todo comando deve declarar uma chave
natural consultável** (`GET` por chave natural por tipo) — não basta a consulta
por `idempotency_key`, que só serve a retries dentro da mesma sessão de memória
(F3). Sem chave natural definida, um tipo de operação não é recuperável pós-
restart e isso deve constar como limitação explícita do contrato.

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
| F4 | Restart com pendentes | Fila e `idempotency_key`s vazias após boot | Consulta resultado **por chave natural** conforme §4.3 (a chave de idempotência foi esquecida) | Responde estado real do recurso | Lista reflete só o confirmado; operador re-submete o que faltar |
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
- **Consulta de resultado:** `GET` por `idempotency_key` (retries na mesma
  sessão de memória — F3) **e** por chave natural (obrigatória para o F4, pois o
  cliente esquece a chave de idempotência ao reiniciar — §4.3).
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
| 2 — Piloto | Um atrativo no novo backend; dados históricos migrados de `visits`/`place_visits`/`reservations` via export (UTC preservado) | Piloto com critérios de aceite de campo definidos em tarefa própria; **caminho de reconciliação piloto→PocketBase testado antes da entrada** (rollback abaixo) |
| 3 — Cutover | Demais atrativos; PocketBase entra em modo leitura | Nenhum registro divergente por período acordado |

**Rollback — promessa limitada ao que tem caminho definido:**

- **Fases 0–1 (sombra):** totalmente reversível — os registros no backend novo
  são dados de comparação, descartáveis por desenho; basta religar
  Hive→PocketBase.
- **Fase 2 (piloto):** reversível **somente** porque existe caminho de
  reconciliação definido: exportação dos registros produzidos no backend novo
  → reimportação no PocketBase/Hive com mapeamento de chaves e UTC preservado,
  com evidência de contagem reconciliada. **Esse caminho precisa ser construído
  e testado antes do piloto entrar** — sem ele, a promessa de reversibilidade
  não vale para a fase 2 e o piloto não deve começar.
- **Fase 3 (após cutover):** rollback exige exportação reversa completa; por
  isso o modo leitura do PocketBase é mantido por janela acordada.

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

Decisões **separadas** — cada uma pode ser aprovada/rejeitada isoladamente;

a integração deste documento `PROPOSED` não aprova nenhuma delas:

| # | Decisão | Conteúdo a aprovar | Consequência de cada via |
|---|---|---|---|
| D-A | **Escolha da arquitetura** | Opção A/B/C conforme §3 | A: menor custo/prazo, contrato implícito; B: durabilidade gerenciada, custo contínuo e latência por região; C (recomendada): contrato explícito e continuidade, mais superfície operacional |
| D-B | **Comportamento durante interrupções** | Política F1–F7: fila transitória em memória, limites de retry/backoff e comportamento em F6 | Aprovar: pendências nunca parecem salvas; rejeitar/alterar: redefine UX de campo |
| D-C | **Aceitação operacional da perda de rascunhos** | Interpretação estrita da §4.2: restart perde rascunhos/pendentes; recuperação só por chave natural (§4.3) | Aprovar: restrição mantida integralmente; escolher exceção nomeada: redefine a restrição "sem banco local" antes de qualquer código |
| D-D | **Orçamento e provedor** | Teto mensal e provedor/região (tabela de custos §3) | Orçamento do projeto não autoriza; sem aprovação específica, nenhum provisionamento ocorre |
| D-E | **Autorização de provisionamento/migração** | Início das fases 0–3 da §7 em ambiente descartável; piloto só com reconciliação testada | Autorizar: trabalho de implementação pode começar na fase 0; negar/adiar: sistema segue no baseline |
| D-F | Transporte realtime | SSE × WebSocket (§6) | SSE recomendado por simplicidade/proxy; WS se exigir bidirecional |
| D-G | Janelas de migração | Período de sombra, de piloto e de modo-leitura do PocketBase | Define cronograma de cutover e janela de rollback |
| D-H | Tolerância concreta a interrupções | Depende do inventário de campo (#15): cobertura real, duração das interrupções, rotina de sync — itens sem evidência seguem como perguntas territoriais para a equipe | Alimenta D-C e os critérios de aceite do piloto |
| D-I | Frente de cartografia social | Fora do escopo desta ADR; exige ADR própria (necessidade histórica offline pode divergir da interpretação estrita) | Mantém domínios separados conforme governança |

Decisões transversais em outras issues: matriz de acesso (#19→#13), provisionamento de credenciais (#24), contrato canônico de sessão/eventos (#23) — este último deve incorporar a exigência de chave natural consultável por operação (§4.3).

## 11. Validação desta entrega

- Links internos revisados; diagrama referenciado: [`0001-c4-container.md`](./0001-c4-container.md).
- Tabela de cenários de falha em §5; nenhuma chamada a ambiente operacional.
- Status `PROPOSED`; nenhuma mudança funcional, de schema ou de credencial foi feita.
- Revisão 2026-10-06 (2ª rodada): recuperação pós-restart corrigida para chave
  natural por tipo de operação (§4.3) — a idempotency_key se perde com a memória;
  rollback do piloto condicionado a reconciliação testada (§7); decisões
  separadas D-A–D-I (§10); justificativa da recomendação sem "única opção".
- Revisão 2026-10-06: incorporados inputs do mantenedor — contexto institucional
  (NERUDS/UFT, REDE DESER, Mateiros/São Félix), duas frentes do projeto,
  respostas às perguntas de campo (§4.1), consequência explícita da restrição
  (§4.2) e recomendação nomeada por componentes nos cinco eixos (§3).
