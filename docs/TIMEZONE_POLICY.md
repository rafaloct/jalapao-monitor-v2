# Política de Timezone — Jalapão Monitor Hub

## Regra central

| Camada | Timezone | Justificativa |
|--------|----------|---------------|
| Armazenamento (PocketBase) | **UTC** | Padrão universal; evita ambiguidade em relatórios, backups e integrações |
| App Flutter (tablet) | **BRT automático** | `DateTime.now()` usa o fuso do dispositivo; PocketBase recebe com offset |
| Hub Next.js (exibição) | **BRT — America/Sao_Paulo** | Toda hora/data exibida usa o helper `tz.ts` |
| CSV de backup | **BRT** | Exportado no horário que o operador de campo reconhece |

## Brasil = UTC-3 (sem horário de verão desde 2019)

BRT = UTC-3, o ano inteiro. Referência IANA: `America/Sao_Paulo`.

## Por que não configurar o servidor para BRT?

O VPS roda em UTC. Configurar o OS para BRT resolveria localmente mas:
- Quebraria se o servidor migrar de região
- Não documentaria a intenção no código

A abordagem via `Intl.DateTimeFormat` com `timeZone: 'America/Sao_Paulo'` é
explícita, portável e autodocumentada em cada função.

## src/lib/tz.ts — Funções disponíveis

```ts
todayBRT()               // "2026-03-19" — data atual em BRT
todayBRTRange()          // ["2026-03-19 03:00:00.000Z", "2026-03-20 02:59:59.999Z"]
dateBRTRange("2026-03-19") // mesmo, para data específica
hourBRT(d: Date)         // 7 — hora local BRT (0-23)
dateBRTStr(d: Date)      // "2026-03-19"
fmtTimeBRT(d: Date)      // "07:30"
fmtDateBRT(d: Date)      // "2026-03-19"
dayLabelBRT(d: Date)     // "Qui 19/03"
lastNDaysBRT(7)          // [{key, label}, ...] últimos 7 dias em BRT
```

## Filtros PocketBase e virada de dia

PocketBase armazena em UTC. "Hoje em BRT" começa às 03:00 UTC.
Portanto os filtros usam `dateBRTRange()`:

```ts
// ERRADO — inclui 00h-03h UTC do dia anterior ao BRT atual
filter: `arrival_time >= "${today} 00:00:00.000Z"`

// CORRETO — cobre exatamente o dia de Brasília
const [start, end] = dateBRTRange(todayBRT());
filter: `arrival_time >= "${start}" && arrival_time <= "${end}"`
```

## Dados históricos de teste

Registros de desenvolvimento inseridos antes de 2026-03-20 podem exibir
horário deslocado (UTC em vez de BRT). Isso não afeta operação de campo —
são dados de testes. Dados de produção (a partir de 2026-03-25) serão corretos.
