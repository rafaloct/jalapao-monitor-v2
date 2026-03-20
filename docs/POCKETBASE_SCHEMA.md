# Schema PocketBase — Jalapão Monitor

PocketBase v0.23+. URL: configurada via `.env`. Auth via `_superusers`.

## Collection: `places`

Cadastro de atrativos. Escrito pelo app (GestorScreen) e lido por todos.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | Auto PocketBase |
| `name` | string | Nome do local |
| `type` | string | `fervedouro \| cachoeira \| restaurante \| pousada \| fazenda \| chacaras \| loja \| atrativo_cultural` |
| `latitude` | number | Validação: < 10.0 (hemisfério sul) |
| `longitude` | number | Validação: < -40.0 |
| `capacity_total` | number | Capacidade máxima simultânea |
| `owner_name` | string | |
| `contact_phone` | string | Opcional |
| `status` | string | `pending \| active \| rejected \| archived` |
| `description` | string | Opcional |
| `operating_hours` | string | Ex: "08:00-18:00" |
| `created_at_v2` | datetime | |
| `approved_at` | datetime | Preenchido pelo gestor ao aprovar |

**Índice de locais de campo (2026):**

| Nome | Tipo | Capacidade |
|---|---|---|
| Fervedouro da Ceiça | fervedouro | — |
| Fervedouro do Encanto | fervedouro | — |
| Cachoeira da Formiga | cachoeira | 20 |
| Museu do Capim Dourado | atrativo_cultural | 30 |
| Loja Artesanato Jalapão | loja | 15 |
| Chácara Rio Sono | chacaras | 30 |
| Fazenda Bela Vista | fazenda | 40 |
| Pousada Jalapão Dreams | pousada | 20 |
| Pousada Serra do Espírito | pousada | 16 |
| Restaurante Mirela | restaurante | 25 |
| Restaurante Sabor do Sertão | restaurante | 30 |

---

## Collection: `visits` (legado — fervedouros)

Registros do DashboardScreen. Status segue fluxo próprio de fervedouro.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `group_id` | string | ID único do grupo (UUID gerado no tablet) |
| `atrativo` | string | Nome do fervedouro (ex: "Fervedouro da Ceiça") |
| `tablet_id` | string | ID do tablet (ex: "TAB-01") |
| `pax_qty` | number | Quantidade de pessoas |
| `status` | string | `fila \| agua \| concluido` |
| `arrival_time` | datetime | Chegada na área — **UTC** |
| `entry_time` | datetime \| null | Entrada na água — **UTC** |
| `exit_time` | datetime \| null | Saída da água — **UTC** |
| `capacity_limit` | number | Capacidade configurada no momento |
| `group_name` | string \| null | Nome do grupo (opcional) |

**Mapeamento de status para Hub:**
- `fila` → `queued`
- `agua` → `visiting`
- `concluido` → `exited`

---

## Collection: `place_visits`

Registros do CounterScreen e PlaceReservationScreen (sistema v2).

| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `place_id` | string | FK → `places.id` |
| `pax_qty` | number | |
| `arrival_time` | datetime | Chegada — **UTC** |
| `entry_time` | datetime \| null | Entrada efetiva (fervedouro) ou = arrival_time |
| `exit_time` | datetime \| null | Saída — **UTC** |
| `status` | string | `visiting \| exited \| queued` |
| `tablet_id` | string | |
| `notes` | string \| null | |
| `group_name` | string \| null | |
| `origin_city` | string \| null | Cidade de origem — dado primário da pesquisa |

---

## Collection: `reservations`

Reservas e check-ins de pousadas/restaurantes.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `place_id` | string | FK → `places.id` |
| `pax_qty` | number | |
| `guest_name` | string | Nome do responsável |
| `contact_phone` | string \| null | |
| `scheduled_time` | datetime | Horário agendado — **UTC** |
| `arrival_time` | datetime \| null | Check-in real — **UTC** |
| `exit_time` | datetime \| null | Check-out real — **UTC** |
| `status` | string | `reserva \| no_local \| concluida \| cancelada` |
| `notes` | string \| null | |
| `tablet_id` | string \| null | |
| `is_estimated` | boolean | true = horário aproximado |
| `origin_city` | string \| null | |

---

## Regras de autenticação

Todas as collections usam regras abertas (`""`) para simplificar operação de campo. Em produção/fase 2, adicionar regras de acesso por tablet_id.

## Notas de timezone

Todos os campos `datetime` são armazenados em UTC pelo PocketBase.
O PocketBase normaliza internamente qualquer offset recebido.
Filtros de "hoje" no Hub usam `dateBRTRange()` — ver `docs/TIMEZONE_POLICY.md`.
