# Matriz de acesso — papel × recurso × ação

- **Status:** `APROVADO` — ata de decisão registrada pelo mantenedor na
  [Issue #13](https://github.com/rafaloct/jalapao-monitor-v2/issues/13)
  (2026-10-06): matriz de acesso e modelo de provisionamento §5 aprovados
  na versão entregue pelo [PR #29](https://github.com/rafaloct/jalapao-monitor-v2/pull/29)
  (merge `793958c`). Decisões institucionais D1–D4 e D6–D7 continuam pendentes (§8).
- **Tarefa de elaboração:** [Issue #19](https://github.com/rafaloct/jalapao-monitor-v2/issues/19)
- **Base:** `main @ a6d9bfe1507f9d75e6d4a872c17501c435204634`; reconciliada com a
  ADR 0001 (`docs/adr/0001-authoritative-backend.md`, [PR #28](https://github.com/rafaloct/jalapao-monitor-v2/pull/28)).
- **Escopo:** definição de acesso. Não altera usuários, regras de banco, segredos
  ou dispositivos.

## 1. Papéis

| Papel | Quem é | Dispositivo/vínculo |
|---|---|---|
| `operador` | Monitor/guarda operando um atrativo | Tablet cadastrado, 1 atrativo por sessão |
| `gerente` | Responsável por um empreendimento/atrativo | App; auth individual |
| `coordenador` | Coordenação territorial (UFT/FAPT/SEPLAN) | Hub web; auth individual |
| `pesquisador` | Equipe de pesquisa | Exportações/visões de pesquisa; sem PII operacional |
| `agencia_guia` | Agência ou guia com reservas/check-in | Token de empreendimento ou conta limitada |
| `display_tv` | Tela pública do atrativo | Dispositivo de exibição, sem pessoa |
| `turista` | Público; acesso via QR/token público | Sessão anônima de leitura |
| `admin` | Administrador técnico | Acesso privilegiado auditado |

## 2. Classes de dados

| Classe | Conteúdo | Exemplos no schema atual |
|---|---|---|
| `publico` | Nome do local, tipo, capacidade, ocupação/status agregado, horário | `places.name/type/capacity_total/operating_hours`, status de fila agregado |
| `operacional` | Eventos de fluxo, tempos, pax, notas operacionais | `visits`, `place_visits`, `reservations` (sem contato) |
| `pii` | Identificadores de pessoa | `reservations.guest_name`, `reservations.contact_phone`, `places.owner_name`, `places.contact_phone`, `visits.group_name`, `place_visits.group_name`, `reservations.notes` (campos livres que **podem conter nomes/telefones** — tratar como PII até minimização declarada) |
| `pesquisa` | Dados para estudo, preferencialmente agregados/anonimizados | `origin_city`, séries temporais agregadas |
| `admin` | Credenciais, tokens, regras, backups | Secrets, tokens de sessão, exports completos |

**Regra central:** `pii` nunca entra em visões públicas (TV, turista, agregados)
nem em exportações de `pesquisa` sem minimização — separação exigida pela #13.

## 3. Matriz papel × recurso × ação

Legenda de ações: `C`=criar, `R`=ler, `U`=atualizar, `X`=excluir, `A`=aprovar/administrar,
`E`=exportar, `S`=assinar eventos. Escopo entre parênteses: `atr`=próprio atrativo,
`emp`=próprio empreendimento, `ter`=território, `self`=próprios registros, `agg`=agregado.
`—` = proibido. Ref `T#` = cenário de teste planejado (§7).

| Recurso / ação | operador | gerente | coordenador | pesquisador | agencia_guia | display_tv | turista | admin |
|---|---|---|---|---|---|---|---|---|
| `places` catálogo público (D:publico) | R(atr) T1 | R(emp) T2 | R(ter) T3 | R(ter) T4 | R(agg) T5 | R(atr) T6 | R(atr) T7 | R(ter) |
| `places` criar/editar cadastro | — | C,U(emp) **exceto `status`/`approved_at`** T2 | A(ter) T3 | — | — | — | — | A(ter) |
| `places` alterar `status`/`approved_at` | — | — | A(ter) T3 | — | — | — | — | A(ter) |
| `places` aprovar/rejeitar | — | — | A(ter) T3 | — | — | — | — | A(ter) |
| `place_visits`/`visits` registrar fluxo | C,U(atr) T1 | — | R(ter) T3 | — | — | — | — | R(ter) |
| `place_visits`/`visits` ler operacional | R(atr) T1 | R(emp) T2 | R(ter) T3 | R(agg) T4 | — | R(agg,atr) T6 | — | R(ter) |
| `reservations` criar/check-in/out | C,U(atr) T1 | C,U(emp) T2 | R(ter) T3 | — | C,U(self) T5 | — | R(self) T7 | R(ter) |
| `reservations` PII (nome/telefone) | R(atr) T1 | R(emp) T2 | R(ter) T3 | — | R(self)¹ T5 | — | — T7 | R(ter) |
| API de comandos (alvo #18) | executar(atr) T1 | executar(emp) T2 | R(ter) | — | executar(self) T5 | — | — (auto-serviço só após desenho do #5 — D7) | R(ter) |
| Eventos realtime operacionais | S(atr) T1 | S(emp) T2 | S(ter) T3 | — | — | S(agg,atr) T6 | — | S(ter) |
| Hub dashboard | — | R(emp) T2 | R(ter) T3 | — | — | — | — | R(ter) |
| Exportação CSV completa (D:operacional+pii) | — | E(emp) T2 | E(ter) T3 | — | — | — | — | E(ter) |
| Exportação de pesquisa (D:pesquisa, minimizada) | — | — | E(ter) T3 | E(ter) T4 | — | — | — | E(ter) |
| Display/TV visão pública (D:publico+agg) | — | — | — | — | — | R(atr) T6 | R(atr) T7 | — |
| QR/voucher (futuro #5) | emitir(atr) | emitir(emp) | R(ter) | — | emitir(emp) T5 | — | apresentar(self) T7 | R(ter) |
| Impressora térmica (futuro #6) | imprimir(atr) T1 | imprimir(emp) | — | — | — | — | receber via operador T7 | — |
| Mídia/snapshots (futuro #10) | capturar sob consentimento | — | R(ter, política) | R(minimizada) | — | — | consultar própria (direito) | administrar retenção |
| `devices` cadastro/pareamento/revogação | — | — | C,U(ter) T9 | — | — | — | — | A(ter) T9 |
| Administração backend (regras, backups, usuários) | — | — | — | — | — | — | — | A(ter) T8 |

¹ `R(self)` na linha de PII restringe-se a nome/telefone **dentro das reservas
criadas pela própria agência/guia** (dado que ela mesma informou no ato da
reserva). PII fora desse escopo é proibida — ver N3.

## 4. Casos negativos explícitos

| # | Caso proibido | Teste |
|---|---|---|
| N1 | Operador lê/escreve atrativo que não é o seu | T1 |
| N2 | Gerente acessa dados de outro empreendimento | T2 |
| N3 | Turista/TV recebe qualquer PII; agência recebe `guest_name`/`contact_phone` **fora** das reservas próprias (`self`) | T5–T7 |
| N4 | Pesquisador exporta PII operacional | T4 |
| N5 | Agência edita reserva que não é sua (`self`) | T5 |
| N6 | Display/TV recebe registro individual ou PII | T6 |
| N7 | Turista escreve qualquer recurso fora do próprio voucher | T7 |
| N8 | Qualquer papel ≠ admin altera regras, usuários ou backups | T8 |
| N9 | Token público enumerável acessa dados de outros turistas | T7 |
| N10 | Sync/write sem autenticação de dispositivo | T1/T8 |

## 5. Provisionamento e recuperação (sem credencial privilegiada no cliente)

Proposta para substituir o modelo atual — nada embarcado no APK concede privilégio:

1. **Cadastro de dispositivo:** admin/coordenador gera código de pareamento único e
   curto (uso único, expiração curta) por tablet.
2. **Pareamento:** o app troca o código por token de dispositivo vinculado
   (tablet + papel `operador` + atrativo), de vida curta e rotacionável — nunca
   credencial de usuário privilegiado.
3. **Renovação:** refresh rotativo server-side; token vazado revoga-se sem
   redistribuir app.
4. **Recuperação/perda:** revoga o token do dispositivo e emite novo pareamento;
   nenhuma credencial fica "no cliente" além do próprio token revogável.
5. **Contas pessoais (gerente/coordenador/pesquisador):** credenciais individuais
   no backend, MFA avaliável para `admin`/`coordenador`; sem conta compartilhada.
6. **Transição:** o fallback de PIN local só pode ser removido após este modelo
   aprovado (#24) — ver risco R1.

## 6. Riscos documentados do baseline (a verificar, não padrão)

| # | Risco observado em `a6d9bfe` | Evidência |
|---|---|---|
| R1 | ~~Fallback de PIN local com valor padrão literal não vazio; login local ocorre antes da auth PocketBase e concede fluxo de gestor sem servidor~~ **Resolvido na #24**: autenticação exclusiva por conta PocketBase; ver `docs/security/CREDENTIAL_TRANSITION.md` | `lib/services/auth_service.dart` |
| R2 | Regras de collection **abertas** (`""`) documentadas — qualquer cliente escreve/lê sem autenticação; `SyncService` envia sem token | `docs/POCKETBASE_SCHEMA.md`, `lib/services/sync_service.dart` |
| R3 | ~~Aprovação de `places` em modo PIN retorna sucesso silencioso apenas local (falso positivo operacional)~~ **Resolvido na #24**: aprovação exige resposta do servidor | `auth_service.approvePlace` |
| R4 | Transporte HTTP cleartext configurável (`PB_URL` http; exceção cleartext no `network_security_config.xml`) | `lib/config/app_config.dart`, `android/` |
| R5 | Hub protegido por senha única compartilhada (`NEXT_PUBLIC_HUB_PASSWORD`), sem papel nem auditoria | `hub/README.md`, middleware |
| R6 | Duplicata multi-tablet na janela de sync de 30s — mitigável por dedup server-side (#18), continua limitação | `docs/ARCHITECTURE.md` |
| R7 | Dados pessoais (`guest_name`, `contact_phone`) coexistem sem separação PII×pesquisa | `docs/POCKETBASE_SCHEMA.md` |

## 7. Cenários de teste planejados (sem implementação nesta tarefa)

| # | Cenário | Verifica |
|---|---|---|
| T1 | Operador autenticado no atrativo A cria/lê fluxo de A; tenta ler/escrever atrativo B | linha operador; N1, N10 |
| T2 | Gerente do empreendimento E edita `places` de E e exporta dados de E; tenta empreendimento F | linha gerente; N2 |
| T3 | Coordenador lê/aprova/exporta em todo o território | linha coordenador |
| T4 | Pesquisador acessa exportação minimizada; tenta campo `contact_phone` | linha pesquisador; N4 |
| T5 | Agência cria/edita reserva própria; tenta reserva de terceiro | linha agencia_guia; N3, N5 |
| T6 | TV assina feed do atrativo; feed não contém registro individual nem PII | linha display_tv; N6 |
| T7 | Turista via token de voucher lê próprio status; enumera tokens alheios e endpoints internos | linha turista; N3, N7, N9 |
| T8 | Dispositivo sem token válido tenta escrever; papel comum tenta alterar regra/backup | linha admin; N8, N10 |
| T9 | Coordenador/admin cadastra dispositivo e emite código de pareamento; tablet pareado é revogado; token seguinte é rejeitado e re-pareamento emite novo | linha `devices`; §5 provisionamento |
| T10 | Operação em modo offline nunca marca item como salvo sem confirmação (cruza com ADR §5) | integridade transacional |

## 8. Decisões pendentes que exigem responsável (sem aprovação inventada)

| # | Decisão | Onde se registra |
|---|---|---|
| D1 | Finalidade e base legal por classe de dado (LGPD), com responsável nomeado | #13 / documento jurídico próprio |
| D2 | Retenção de `pii` em `reservations` e de mídia (#10) | #13, epic #10 |
| D3 | Política de consentimento para mídia/snapshot e avisos ao turista | #10 |
| D4 | Direitos do titular (acesso/correção/exclusão) e prazo de resposta | #13 |
| D5 | ~~Aprovação desta matriz (versão/commit) e do modelo de provisionamento §5~~ **Resolvido**: ata na #13 (2026-10-06) | #13, depois #24 |
| D6 | MFA para `admin`/`coordenador`; política de sessão/token | #13 |
| D7 | Prazo de validade e escopo dos tokens públicos (QR); turista é leitura `self` — auto-reserva via QR (epic #5) só após desenho com confirmação do operador | #5 |

**Contexto institucional (inputs do mantenedor, 2026-10-06):** o projeto atua no
âmbito UFT/NERUDS (Edital 02/2024 FAPT/SEPLAN, REDE DESER), com referência
acadêmica de Cleiton Milagres. **Nenhuma das decisões D1–D4 foi atribuída
automaticamente** a pesquisador ou orientador: a atribuição formal de
responsabilidade por proteção de dados, a base legal e os prazos de retenção
exigem validação da instância competente (UFT/NERUDS e, se aplicável, assessoria
jurídica). O agente pode preparar a minuta de perguntas e organizar finalidades
e categorias de dados; a aprovação é humana e institucional.
