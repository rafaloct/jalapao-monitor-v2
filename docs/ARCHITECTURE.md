# Arquitetura do Sistema — Jalapão Monitor

## Visão geral

```
┌─────────────────────┐     sync 30s     ┌──────────────────────┐
│  Tablet Android     │ ─────────────→   │  PocketBase (VPS)    │
│  Flutter + Hive     │ ←─────────────   │  :8090               │
│  (offline-first)    │                  └──────────┬───────────┘
└─────────────────────┘                             │ REST API
                                                    ▼
                                        ┌──────────────────────┐
                                        │  Hub Next.js (VPS)   │
                                        │  :3000               │
                                        │  (coordenador)       │
                                        └──────────────────────┘
```

## Componentes

### 1. App Flutter (`lib/`)

**Propósito:** Interface de campo para monitores. Roda em tablets Android sem depender de internet.

**Tecnologias:**
- Flutter (Dart) — UI cross-platform
- Hive — banco local (NoSQL, sem SQLite)
- Provider — gerenciamento de estado
- PocketBase Dart SDK — sync com backend
- Geolocator — GPS para cadastro de locais

**Fluxo de inicialização:**
```
main.dart → HomeRouter
  ├─ !isConfigured → OnboardingScreen (configura tabletId)
  ├─ sem activeSessionPlaceId → SessionSelectorScreen
  ├─ place.type = fervedouro → DashboardScreen
  ├─ place.type ∈ {restaurante, pousada, fazenda, chacaras} → PlaceReservationScreen
  └─ outros tipos → CounterScreen
```

**Sync (SyncService):**
- `_syncUp()` — envia registros Hive pendentes ao PocketBase
- `_syncDown()` — puxa atualizações do PocketBase
- Intervalo: 30 segundos
- Offline resiliente: dados ficam no Hive e são enviados quando sinal retornar
- Banner laranja no topo = sem conectividade (não impede operação)

### 2. PocketBase (VPS `:8090`)

**Propósito:** Backend central. Recebe dados de todos os tablets, serve o Hub.

**Collections:**

| Collection | Quem escreve | Quem lê |
|---|---|---|
| `places` | Gestor (via app) | App + Hub |
| `visits` | DashboardScreen (fervedouro) | App + Hub |
| `place_visits` | CounterScreen + PlaceReservationScreen | App + Hub |
| `reservations` | PlaceReservationScreen | App + Hub |

**Auth:** `_superusers` (PocketBase v0.23+). Regras de collection abertas para simplificar o campo.

**Timezone:** Armazena **sempre em UTC**. Datas chegam com offset do dispositivo e são normalizadas internamente pelo PocketBase.

### 3. Hub Next.js (VPS `:3000`)

**Propósito:** Dashboard de visualização para o coordenador de campo.

**Funcionalidades:**
- Cards de ocupação em tempo real para todos os locais
- Painel de fervedouros: pipeline FILA → ÁGUA por grupo com tempo elapsed + urgência por cor
- Fluxo horário (gráfico de barras)
- Heatmap semanal (hora × dia)
- Gráfico de cidades de origem
- Tabela de visitas do dia com filtros por local/tipo
- Histórico por data
- Export CSV (todas as collections, intervalo configurável)

**Autenticação:** Proteção por senha via middleware Next.js.

**Timezone:** Toda exibição em BRT via `src/lib/tz.ts`. Ver `docs/TIMEZONE_POLICY.md`.

## Tipos de local e telas correspondentes

| Tipo | Tela Flutter | Fluxo |
|---|---|---|
| `fervedouro` | DashboardScreen | FILA DE ESPERA → NA ÁGUA → CONCLUÍDO |
| `cachoeira`, `atrativo_cultural`, `loja`, `fazenda`, `chacaras` | CounterScreen | CHEGADA → ativo → SAÍDA |
| `restaurante`, `pousada` | PlaceReservationScreen | RESERVA → NO LOCAL → SAÍDA |

## Coleta de dados por tipo

```
Fervedouro:
  arrival_time  = chegada na área de espera
  entry_time    = entrada efetiva na água
  exit_time     = saída da água
  → collection: visits (legado) e place_visits

Cachoeira/Atrativo:
  arrival_time  = chegada e entrada simultâneas
  exit_time     = saída
  → collection: place_visits

Restaurante/Pousada:
  scheduled_time = horário da reserva
  arrival_time   = check-in real
  exit_time      = check-out real
  → collection: reservations
```

## Decisões de design

### Offline-first
Tablets no Jalapão operam em área com cobertura instável. Todos os dados são gravados localmente em Hive antes de tentar sync. O Hub pode exibir dados defasados de até 30s — aceitável para o estudo.

### Multi-tablet
Cada tablet tem um `tablet_id` único. Registros são independentes. O Hub agrega todos. **Não usar 2 tablets operando simultaneamente no mesmo local** — risco de duplicata na janela de 30s entre syncs.

### UTC no backend, BRT na exibição
PocketBase armazena em UTC. O Hub converte para BRT na exibição via `Intl.DateTimeFormat`. Filtros de "hoje" usam `dateBRTRange()` que produz `03:00:00Z` a `02:59:59Z` (meia-noite BRT = 03:00 UTC). Ver `docs/TIMEZONE_POLICY.md`.

### Dois sistemas de coleta de fervedouro
`visits` (legado) = DashboardScreen, fluxo fila/água original.
`place_visits` = sistema v2 unificado, também usado pelo CounterScreen.
O Hub lê **ambos** e faz merge para exibição.
