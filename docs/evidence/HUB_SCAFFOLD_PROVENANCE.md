# Evidência — proveniência do scaffold do Hub (Issue #22)

## Origem

Cópia anterior do Hub localizada pelo mantenedor em
`DESKTOP-8T5DRBS` (nó Tailscale `desktop-8t5drbs.tail2faed0.ts.net`),
`C:\Users\Usuario\Downloads\jalapao_context\jalapao_monitor_hub`,
datada de **2026-03-16** (timestamps internos do arquivo), recebida em
`avellaria` via SCP sobre Tailscale SSH em 2026-10-08 como
`jalapao_monitor_hub-20261008T221659Z-1-001.zip` (27 arquivos).

## Manifesto de integridade (SHA-256)

Todos os 27 arquivos da cópia de origem, hasheados antes de qualquer uso —
manifesto completo em [`hub-scaffold-origin.sha256`](./hub-scaffold-origin.sha256)
(commit junto nesta entrega). Exemplo dos arquivos-chave:

| Arquivo | SHA-256 (prefixo) |
|---|---|
| `package.json` | `ecd66999…` |
| `package-lock.json` (original) | `3a74a40f…` |
| `tailwind.config.ts` | ver manifesto |
| `src/app/layout.tsx` | ver manifesto |

## Verificação de versão

| Item | Origem (2026-03-16) | Repo atual |
|---|---|---|
| `src/lib/places-service.ts` | **ausente** (havia `data-service.ts`, 3.5 KB) | 373 linhas — versão mais nova |
| `src/lib/pb.ts` | URL hardcoded | `NEXT_PUBLIC_PB_URL` configurável |
| `middleware.ts` + login | Presente | Ausente no checkout |
| `src/app/docs/page.tsx` | Presente | Ausente (link `/docs` na page atual → 404 conhecido) |

A cópia é **anterior** ao código versionado — serve como fonte legítima do
**scaffold**, não do código de aplicação.

## Adotado × descartado

| Adotado (scaffold) | Descartado (fora de escopo) |
|---|---|
| `package.json` (dependências reduzidas ao usado por `src/` atual) | `package-lock.json` original — não compatível com manifesto reduzido; lockfile regenerado e marcado como reconstruído |
| `next.config.mjs`, `tsconfig.json`, `postcss.config.mjs`, `.eslintrc.json`, `.gitignore` | `middleware.ts`, `src/app/login/`, `src/app/api/login/` — auth por cookie existia na versão antiga; reintrodução é decisão funcional (#13/#19), não de scaffold |
| `tailwind.config.ts` (paleta `jalapao` usada por `PlacesTab`/`page.tsx`) | `src/app/docs/page.tsx` (exige `react-markdown`/`remark-gfm`, página fora do src atual; link `/docs` fica 404 registrado) |
| `src/app/layout.tsx` (ajustado: título/lang pt-BR), `globals.css`, `favicon.ico` | `src/lib/data-service.ts`, `src/lib/types.ts`, `src/lib/pb.ts`, `components/dashboard/*` — versões antigas substituídas pelas atuais |
| `public/` next/vercel svg | — |

## Limitações

- Lockfile é **reconstruído** (`npm install` sobre manifesto reduzido), não o
  original — registrado porque o original cobria dependências não adotadas.
- Dependências descartadas são usadas apenas por arquivos não adotados
  (`date-fns`, `clsx`, `tailwind-merge`, `react-markdown`, `remark-gfm`).
- `NEXT_PUBLIC_PB_URL` em `.env.example` aponta para `127.0.0.1` sintético;
  o fallback em `src/lib/pb.ts` (herdado do baseline) permanece **não tocado**
  — remoção é escopo de tarefa de credenciais (#24 e correlata Hub-side).
