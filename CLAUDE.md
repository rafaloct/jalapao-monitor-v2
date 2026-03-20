# CLAUDE.md — Contexto completo para agentes AI

Este arquivo é o ponto de entrada para qualquer agente AI que for continuar o desenvolvimento
do Jalapão Monitor. Leia inteiramente antes de propor qualquer mudança.

## O que é este projeto

Sistema de monitoramento de fluxo turístico no **Território do Jalapão** (Tocantins, Brasil).
Pesquisa de extensão vinculada à **UFT / FAPT / SEPLAN**, coordenada por Rafael.

**Missão:** coletar dados de entrada/saída de turistas em ~10 atrativos,
para embasar o Plano de Manejo do território.

**Teste de campo inicial:** 25/03/2026 — 2 tablets, 2 monitores, ~10 locais.

---

## Arquitetura (leia `docs/ARCHITECTURE.md` para detalhe)

```
Tablet (Flutter + Hive) → sync 30s → PocketBase :8090 → Hub Next.js :3000
```

- **Tablet:** coleta de campo, offline-first
- **PocketBase:** backend central, armazena em UTC
- **Hub:** visualização em tempo real para o coordenador (lê do PocketBase via JS SDK)

---

## Estrutura de arquivos críticos

### Flutter (`lib/`)

| Arquivo | Função |
|---|---|
| `main.dart` | HomeRouter — roteamento por tipo de local |
| `screens/dashboard_screen.dart` | Fervedouro: fila → água → concluído |
| `screens/counter_screen.dart` | Cachoeira/atrativos: contador entrada/saída |
| `screens/place_reservation_screen.dart` | Pousada/restaurante: reservas |
| `screens/session_selector_screen.dart` | Seleção de local de trabalho |
| `screens/gestor_screen.dart` | Gestão (PIN: ver memory do projeto) |
| `services/sync_service.dart` | Upload/download PocketBase a cada 30s |
| `providers/place_provider.dart` | Estado + timer de sync |

### Hub (`hub/src/`)

| Arquivo | Função |
|---|---|
| `lib/tz.ts` | **CRÍTICO** — todos os helpers de timezone BRT |
| `lib/types.ts` | Tipos TypeScript de todas as collections |
| `lib/places-service.ts` | Queries ao PocketBase + agregações |
| `lib/pb.ts` | Cliente PocketBase singleton |
| `components/PlacesTab.tsx` | Aba principal do dashboard |
| `app/page.tsx` | Dashboard principal + modal CSV |

### Documentação (`docs/`)

| Arquivo | Conteúdo |
|---|---|
| `ARCHITECTURE.md` | Visão geral do sistema e decisões de design |
| `POCKETBASE_SCHEMA.md` | Schema completo de todas as collections |
| `DEVELOPMENT.md` | Como rodar, buildar e deployar |
| `TIMEZONE_POLICY.md` | Política BRT/UTC (leia antes de tocar em datas) |
| `BACKLOG.md` | Melhorias identificadas + observações pós-campo |

---

## Regras invioláveis

### 1. Timezone — nunca quebre BRT

O VPS roda em UTC. O Brasil é BRT = UTC-3, sem horário de verão (desde 2019).

**No Hub, SEMPRE use `src/lib/tz.ts`:**
```ts
// ❌ ERRADO
new Date().getHours()
new Date().toLocaleDateString()
new Date().toISOString().split('T')[0]
filter: `arrival_time >= "${today} 00:00:00.000Z"`

// ✅ CORRETO
hourBRT(d)           // hora local BRT
dateBRTStr(d)        // "2026-03-25"
todayBRT()           // "2026-03-25"
const [s, e] = dateBRTRange(todayBRT())  // filtro correto
```

**Por quê:** meia-noite BRT = 03:00 UTC. Filtrar por 00:00 UTC inclui 3h do dia anterior em BRT.

### 2. Sync timer nos testes de integração

O `PlaceProvider` tem um timer de 30s que impede `pumpAndSettle()` de terminar.

```dart
// ❌ NUNCA em testes de integração
await tester.pumpAndSettle();

// ✅ SEMPRE
for (int i = 0; i < 4; i++) {
  await tester.pump(const Duration(milliseconds: 500));
}
```

### 3. PocketBase autoCancellation

```ts
pb.autoCancellation(false); // Não remova — queries paralelas no Promise.all se cancelam
```

### 4. Multi-tablet no mesmo local

Não recomendado. Janela de 30s entre syncs cria risco de duplicata. 1 tablet por local.

### 5. Credenciais

**Nunca commitar** em código: IPs do VPS, senhas admin do PocketBase, PIN do gestor,
tokens de auth. Use `.env.local` (ignorado pelo git) ou `flutter_secure_storage`.

---

## Collections PocketBase (resumo)

| Collection | Quem usa | Status legado |
|---|---|---|
| `places` | App (gestor) + Hub | Novo v2 |
| `visits` | DashboardScreen fervedouro | **Legado** — manter compatibilidade |
| `place_visits` | CounterScreen + reservas (como PlaceVisit) | Novo v2 |
| `reservations` | PlaceReservationScreen | Novo v2 |

**Importante:** `visits` é o sistema legado de fervedouro com status `fila/agua/concluido`.
`place_visits` é o sistema novo com status `visiting/exited/queued`.
O Hub lê ambos e faz merge. Não migrar dados entre eles sem ajustar os dois lados.

---

## Tipos de local e roteamento

```
fervedouro              → DashboardScreen  (fila/água/concluído)
cachoeira               → CounterScreen    (contador chegada/saída)
atrativo_cultural       → CounterScreen
loja                    → CounterScreen
fazenda                 → CounterScreen
chacaras                → CounterScreen
restaurante             → PlaceReservationScreen  (reservas + check-in/out)
pousada                 → PlaceReservationScreen
```

---

## Fluxo de desenvolvimento recomendado

1. **Leia este arquivo e `docs/ARCHITECTURE.md`** antes de qualquer mudança
2. **Verifique `docs/BACKLOG.md`** para o contexto da melhoria solicitada
3. **Para mudanças em datas/horas:** leia `docs/TIMEZONE_POLICY.md` primeiro
4. **Para mudanças no schema:** atualize `docs/POCKETBASE_SCHEMA.md`
5. **Após implementar:** rode os testes de integração com tablet físico
6. **Registre observações** de campo em `docs/BACKLOG.md`

---

## Testes

```bash
# Testes de integração (tablet físico necessário)
flutter test integration_test/baseline_operational_walkthrough.dart \
  -d <device-id> --dart-define=PB_URL=http://<PB_IP>:8090

# Resultado esperado: 38 screenshots em screenshots/YYYY-MM-DD/baseline/
# Duração típica: ~3m 15s no SM T835
```

---

## Histórico de versões relevante

| Versão | Data | O que mudou |
|---|---|---|
| v2.0 | 2026-03-18 | CounterScreen, SessionSelector, PlaceReservation, Gestor |
| v2.1 | 2026-03-18 | Bugfixes overflow, GPS, pumpAndSettle, convertLegacyVisits |
| v2.2 | 2026-03-19 | Hub BRT timezone fix, redesign painel fervedouro, card A5 |
| Campo | 2026-03-25 | Primeiro teste real — ver `docs/BACKLOG.md` pós-campo |

---

## Contato e contexto institucional

- **Pesquisador:** Rafael (UFT / FAPT / SEPLAN)
- **Território:** Jalapão, Tocantins, Brasil
- **Objetivo:** Plano de Manejo — dados de fluxo turístico
- **Horizonte:** Sistema em uso contínuo após o teste de campo
