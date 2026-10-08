# Contrato canônico — sessão de monitoramento

- **Status:** `PROPOSED` — primeiro recorte do contrato de comandos previsto na
  ADR 0001 (§6, §8). Aguarda revisão na [#23](https://github.com/rafaloct/jalapao-monitor-v2/issues/23)
  e alinhamento com a decisão D-A aprovada (Opção C — API REST/OpenAPI própria).
- **Escopo:** comandos `session.open`, `session.close` e `session.correct` do
  recurso `monitoring_sessions`, mais o **envelope comum** reutilizável pelos
  demais comandos. Cobre **monitoramento turístico** apenas — cartografia/DRP
  é domínio separado (ADR §1, decisão D-I) e não tem contrato aqui.
- **Depende de:** ADR 0001 aprovada (ata na #2), matriz de acesso aprovada
  (ata na #13). Nenhuma API implementada — este documento é especificação.
- **Exemplos:** [`examples/`](./examples/) — identificadores **sintéticos**.
- **Schema executável:** [`schema/command-envelope.schema.json`](./schema/command-envelope.schema.json).

## 1. Envelope do comando (request)

Todo comando é um `POST` para `/v1/commands` com corpo único:

| Campo | Tipo | Obrig. | Regra |
|---|---|---|---|
| `schema_version` | string | sim | SemVer do contrato, ex.: `"1.0.0"`; servidor rejeita major incompatível |
| `command` | string | sim | `<entidade>.<verbo>` — ex.: `"session.open"` |
| `idempotency_key` | string (UUID v4) | sim | Gerada pelo cliente **antes** do primeiro envio; retries usam a mesma |
| `actor_id` | string | sim | Identidade autenticada do operador (matriz #19) |
| `device_id` | string | sim | Dispositivo pareado que executa o comando |
| `occurred_at` | string (RFC 3339, UTC) | sim | Momento do ato no cliente; informativo — a verdade temporal é do servidor |
| `payload` | object | sim | Específico do comando (§4–§6) |

`actor_id`/`device_id` no corpo devem **coincidir** com as credenciais do
transporte; divergência é `403`, não `400` — não é erro de forma, é de posse.

## 2. Envelope da resposta

| Campo | Tipo | Regra |
|---|---|---|
| `event_id` | string (UUID) | ID único e imutável do evento aplicado; âncora de auditoria e correção. Em `rejected` (nenhum evento persistido) usa-se o **UUID nulo** `00000000-0000-4000-8000-000000000000` |
| `status` | `"applied" \| "duplicate" \| "rejected"` | Ver §3 |
| `server_timestamp` | string (RFC 3339, UTC) | Única fonte autoritativa de tempo |
| `entity` | string | Ex.: `"monitoring_session"` |
| `entity_id` | string | ID do recurso afetado |
| `version` | integer | Versão otimista do recurso após o comando |
| `error` | object \| null | `{"code","message","details?"}` quando `rejected` |

## 3. Semântica de idempotência, conflito e timeout

- **`applied`** — o servidor aplicou e confirmou; único caminho que move o
  item do cliente de `pendente` para `confirmado` (ADR §6).
- **`duplicate`** — a `idempotency_key` já foi aplicada por este
  `actor_id + device_id`: o servidor responde **a confirmação original**,
  sem reexecutar efeito algum. Cobre retry F3 (timeout pós-envio).
- **`rejected`** — falha de validação (`4xx` estruturado) ou conflito de
  estado (F5). O cliente exibe o motivo e **não reaplica cegamente**.
- **Timeout do lado do cliente:** segue o modelo F1–F7 da ADR — nunca
  assume sucesso nem falha; reenvia com a mesma `idempotency_key` e, após
  restart (F4), reconcilia pela **consulta por chave natural** (§7).
- **Timeout do lado do servidor:** comando que não conclui dentro do
  deadline interno não grava evento parcial; uma aplicação tardia é
  detectável pela consulta de resultado antes do reenvio.

## 4. `session.open` — abrir sessão de monitoramento

Vincula um `actor_id + device_id` a um `place_id` por um intervalo — é o
recipiente ao qual `visit.*` e `reservation.*` posteriores se associam.

```json
"payload": { "place_id": "plc_0001", "shift": "morning" }
```

| Aspecto | Regra |
|---|---|
| Pré-condição | `place_id` existe e está ativo; ator autorizado a operar aquele `place_id` (matriz #19); nenhuma sessão `open` para o mesmo `device_id` |
| Chave natural | `device_id + actor_id` → **no máximo uma sessão aberta** por dispositivo (ADR §4.3) |
| Transição | cria `monitoring_session(state=open, opened_at=server_timestamp)`; emite `session.opened` |
| Idempotência | mesma `idempotency_key` → `duplicate` com a confirmação original |
| Conflitos | `SESSION_ALREADY_OPEN` (409) se já existe sessão aberta no dispositivo — a resposta inclui `entity_id` da sessão vigente; `PLACE_INACTIVE` (409); `FORBIDDEN_PLACE` (403) |

## 5. `session.close` — encerrar sessão

```json
"payload": { "session_id": "ses_0001" }
```

| Aspecto | Regra |
|---|---|
| Pré-condição | `session_id` está `open` e pertence ao `device_id` do comando |
| Chave natural | `session_id` — estado `open` é o recurso |
| Transição | `open → closed`, `closed_at=server_timestamp`; emite `session.closed`. Visitas `queued|visiting` na sessão **não** são fechadas implicitamente — encerrar com pendências retorna `SESSION_HAS_OPEN_VISITS` (409) com a lista de `entity_id`s; o operador resolve antes (política de campo) ou um comando futuro de fechamento forçado é desenhado explicitamente |
| Conflitos | `SESSION_NOT_OPEN` (409) — já fechada ou de outro dispositivo; `SESSION_HAS_OPEN_VISITS` (409) |

## 6. `session.correct` — correção auditável

**Nenhum evento é apagado.** Correção é um evento compensatório que referencia
o original — a série imutável é a trilha de auditoria (LGPD/pesquisa, #11).

```json
"payload": { "supersedes_event_id": "evt_0001", "field": "place_id", "value": "plc_0002", "reason": "local selecionado incorreto" }
```

| Aspecto | Regra |
|---|---|
| Pré-condição | `supersedes_event_id` existe e é corrigível; ator com papel corretor (coordenador/admin, matriz #19) |
| Efeito | grava `session.corrected` com `supersedes_event_id`; aplica a correção com `version` incrementado; leitura corrente reflete o último estado, a trilha preserva todos os eventos |
| Proibição | nenhum endpoint `DELETE`/edição de evento; "estorno" também é evento compensatório |

## 7. Consultas de resultado (obrigatórias para F3/F4)

| Consulta | Uso |
|---|---|
| `GET /v1/commands/{idempotency_key}` | Retry na mesma sessão de memória (F3) — responde a confirmação original |
| `GET /v1/monitoring_sessions?device_id={d}&state=open` | Reconciliação pós-restart (F4) — chave natural de `session.open` |
| `GET /v1/monitoring_sessions/{session_id}` | Estado corrente + `version` |

Sem chave natural consultável, um tipo de operação não é recuperável pós-
restart — exigência derivada registrada na ADR §4.3.

## 8. Projeções por audiência

O **envelope completo** (com `actor_id`, `device_id`, `idempotency_key`) só
circula no stream **operacional** (app autenticado, Hub do coordenador):

| Audiência | Recebe | Exclui |
|---|---|---|
| Operacional | `session.opened/closed/corrected` completos + snapshot REST | — |
| Pública (TV/QR) | Ocupação/fila por `place_id`; snapshot inicial + stream incremental ou cursor | `actor_id`, `device_id`, `idempotency_key`, motivos de correção |
| Pesquisa | Exportação dedicada de-identificada (sessões agregadas por período/atrativo) | nomes, contatos, identificadores de dispositivo |

## 9. Autorização (resumo; matriz completa em `docs/security/ACCESS_MATRIX.md`)

| Papel | `session.open` | `session.close` | `session.correct` | leitura operacional |
|---|---|---|---|---|
| Monitor/operador | próprio `device_id` + `place_id` autorizado | idem | não | sua sessão |
| Gestor do empreendimento | seus locais | seus locais | não | seus locais |
| Coordenador | — | qualquer sessão (encerramento remoto) | sim | tudo |
| Admin técnico | — | sim | sim | tudo + auditoria |

Turista: nenhum comando (matriz #19 — auto-serviço depende do desenho da #5, D7).

## 10. Plano de validação automatizada (sem API ainda)

1. **Schema executável:** `schema/command-envelope.schema.json` (Draft 2020-12)
   valida requests e respostas; exemplos de `examples/` passam por checagem em
   CI (ver `tooling/` — job a adicionar quando o contrato for estável).
2. **Conformidade futura:** cada aceite deste contrato vira caso de teste da
   API na implementação: envelope obrigatório, dedup por `idempotency_key`,
   unicidade de chave natural, códigos de conflito, projeções por audiência.
3. **Revisão cruzada:** exemplos revisados contra ADR §4.3 (chaves naturais),
   §6 (envelope), §8 (projeções) e matriz #19 (papéis).

## 11. Fora de escopo

- Demais comandos (`visit.*`, `reservation.*`, `place.update`, `device.pair`)
  — recortes seguintes do contrato, na sequência da fila.
- Transporte realtime (D-F pendente), janelas (D-G), provisionamento (D-E).
- Cartografia/DRP — domínio separado.
