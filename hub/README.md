# Jalapão Monitor: Hub

Painel de visualização do monitoramento turístico. Next.js 14 + TypeScript +
PocketBase, exibição em BRT.

## Setup

```bash
cd hub
cp .env.example .env.local   # NEXT_PUBLIC_PB_URL sintético para dev
npm ci                        # instala pelo lockfile
npm run lint && npm run build
npm run dev                   # http://localhost:3000
```

O `package-lock.json` é **reconstruído** (2026-10-08) — o lockfile original da
cópia de origem cobria dependências não adotadas. Proveniência completa:
[`docs/evidence/HUB_SCAFFOLD_PROVENANCE.md`](../docs/evidence/HUB_SCAFFOLD_PROVENANCE.md)
(scaffold recuperado na Issue #22 a partir da cópia de 2026-03-16 encontrada em
`DESKTOP-8T5DRBS`).

## Regras deste diretório

- **Timezone:** sempre `src/lib/tz.ts` — nunca `new Date().getHours()` nem
  filtros em 00:00 UTC para dias BRT (ver `docs/TIMEZONE_POLICY.md`).
- **`pb.autoCancellation(false)`** em `src/lib/pb.ts` — obrigatório: queries
  paralelas do `Promise.all` se cancelam sem ele.
- Nunca colocar senha/credencial em variável `NEXT_PUBLIC_*` — são públicas
  no bundle do cliente.
- O link `/docs` na página principal aponta para rota inexistente neste
  checkout (página da versão antiga não foi adotada no scaffold — decisão
  registrada na evidência de proveniência).
- `middleware.ts`/login da cópia antiga **não** foram adotados — reintrodução
  de auth no Hub é decisão funcional (#13/#19), fora do escopo de scaffold.

## Fontes presentes

| Path | Função |
| --- | --- |
| `src/app/page.tsx` | Dashboard e exportação |
| `src/app/layout.tsx` | Shell raiz (Inter, pt-BR) |
| `src/app/globals.css` | Tema/paleta Jalapão |
| `src/components/PlacesTab.tsx` | Visões por local |
| `src/lib/pb.ts` | Cliente PocketBase |
| `src/lib/tz.ts` | Datas e horários em America/Sao_Paulo |
| `src/lib/types.ts` | Tipos das collections |
| `src/lib/places-service.ts` | Consultas e agregações |

## Para continuar

Ler [AGENTS.md](../AGENTS.md), a issue, o [baseline](../docs/operations/REPOSITORY_BASELINE.md) e o [guia de desenvolvimento](../docs/DEVELOPMENT.md). Um agente trabalha em uma tarefa por draft PR; não altera VPS ou faz deploy a partir deste README.
