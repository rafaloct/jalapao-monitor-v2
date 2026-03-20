# Jalapão Monitor — Hub Next.js

Painel web de monitoramento em tempo real de todos os atrativos do Jalapão.

## Stack

- Next.js 14 (App Router)
- PocketBase JS SDK
- Tailwind CSS
- Recharts (gráficos)
- Lucide React (ícones)

## Estrutura relevante

```
src/
  app/
    page.tsx          # Dashboard principal + modal de backup CSV
    docs/page.tsx     # Documentação inline
  components/
    PlacesTab.tsx     # Aba principal: cards, heatmap, fluxo horário, fervedouros
  lib/
    pb.ts             # Cliente PocketBase singleton
    tz.ts             # Utilitários de timezone BRT (LEIA ANTES DE ALTERAR DATAS)
    types.ts          # Tipos TypeScript de todas as collections
    places-service.ts # Queries ao PocketBase + funções de agregação
```

## Setup local

```bash
npm install
# Crie .env.local com:
# NEXT_PUBLIC_PB_URL=http://SEU_POCKETBASE:8090
# NEXT_PUBLIC_HUB_PASSWORD=sua_senha
npm run dev
```

## Deploy (VPS)

```bash
npm run build
pm2 restart hub
```

## Timezone

**Nunca** use `new Date().getHours()`, `toLocaleDateString()` sem `timeZone`, ou
`toISOString().split('T')[0]` para obter "hoje". Use sempre os helpers em `src/lib/tz.ts`.
Ver `docs/TIMEZONE_POLICY.md` para a política completa.
