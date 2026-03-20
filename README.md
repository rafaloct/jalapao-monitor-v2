# 🌵 Jalapão Monitor

Sistema de monitoramento de fluxo turístico para o **Território do Jalapão** (Tocantins, Brasil).
Pesquisa de extensão — UFT / FAPT / SEPLAN.

---

## O que é

Aplicativo para tablets Android que permite monitorar em tempo real a entrada e saída de
grupos de turistas em atrativos do Jalapão (fervedouros, cachoeiras, pousadas, restaurantes etc.).
Os dados são sincronizados com um backend central (PocketBase) e visualizados em um painel web (Hub).

## Arquitetura

```
Tablet (Flutter)  ──sync 30s──▶  PocketBase (VPS)  ──REST──▶  Hub Next.js
offline-first                    :8090 · UTC                   :3000 · BRT
```

## Funcionalidades

### App (tablet de campo)
- **Fervedouro:** fila de espera → na água (com timer) → concluído
- **Cachoeiras e atrativos:** contador de entrada/saída com dados de grupo
- **Pousadas e restaurantes:** reservas com agendamento e check-in/check-out
- **Offline-first:** funciona sem internet, sincroniza quando o sinal retornar
- **Gestor:** cadastro de novos locais com GPS, aprovação/rejeição

### Hub (coordenador)
- Ocupação em tempo real de todos os locais
- Painel de fervedouros com pipeline FILA→ÁGUA por grupo e urgência por cor
- Fluxo horário e heatmap semanal
- Gráfico de cidades de origem dos visitantes
- Histórico por data com filtros
- Export CSV (todas as collections, intervalo configurável)

## Estrutura do repositório

```
/
├── lib/                    # App Flutter (Dart)
│   ├── screens/            # Telas por tipo de local
│   ├── models/             # Modelos de dados (Hive)
│   ├── providers/          # Estado + sync
│   └── services/           # SyncService (PocketBase)
├── hub/                    # Hub Next.js
│   └── src/
│       ├── lib/            # tz.ts · types.ts · places-service.ts · pb.ts
│       ├── components/     # PlacesTab.tsx
│       └── app/            # page.tsx (dashboard)
├── integration_test/       # Testes de integração (38 screenshots)
├── docs/
│   ├── ARCHITECTURE.md     # Visão geral e decisões de design
│   ├── POCKETBASE_SCHEMA.md
│   ├── DEVELOPMENT.md      # Como rodar, buildar, deployar
│   ├── TIMEZONE_POLICY.md  # Política BRT/UTC
│   └── BACKLOG.md          # Melhorias + notas de campo
└── CLAUDE.md               # Contexto completo para agentes AI
```

## Setup rápido

```bash
# App Flutter
flutter run --dart-define=PB_URL=http://<PB_HOST>:8090

# Hub
cd hub && npm install && npm run dev
```

Ver [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) para instruções completas.

## Para agentes AI

Leia [`CLAUDE.md`](CLAUDE.md) — contém arquitetura, regras invioláveis, schema completo
e fluxo de desenvolvimento. É o ponto de entrada para qualquer continuação do projeto.

## Tecnologias

| Camada | Tech |
|---|---|
| App mobile | Flutter · Dart · Hive · Provider |
| Backend | PocketBase v0.23+ |
| Hub web | Next.js 14 · TypeScript · Tailwind · Recharts |
| Infra | VPS Linux · PM2 |

## Licença

Uso acadêmico / pesquisa de extensão — UFT / FAPT / SEPLAN · 2026
