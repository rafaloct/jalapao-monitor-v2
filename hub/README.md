# Jalapão Monitor: Hub

Painel de visualização do monitoramento turístico. O checkout auditado contém fontes Next.js/TypeScript em `src/`, com consultas PocketBase e exibição em BRT.

## Estado do setup

Faltam `package.json`, lockfile, `tsconfig.json`, layout e configuração suficiente para instalação/build reproduzíveis. A [Issue #22](https://github.com/rafaloct/jalapao-monitor-v2/issues/22) delimita sua recuperação. Não inferir que comandos npm funcionam neste checkout.

Versões mencionadas no histórico não são um ambiente validado. Recuperar scaffold com proveniência e lock, então registrar os comandos reais. Não colocar senha ou credencial em variável `NEXT_PUBLIC_*`.

## Fontes presentes

| Path | Função |
| --- | --- |
| `src/app/page.tsx` | Dashboard e exportação |
| `src/components/PlacesTab.tsx` | Visões por local |
| `src/lib/pb.ts` | Cliente PocketBase |
| `src/lib/tz.ts` | Datas e horários em America/Sao_Paulo |
| `src/lib/types.ts` | Tipos das collections |
| `src/lib/places-service.ts` | Consultas e agregações |

Preservar `pb.autoCancellation(false)`, os helpers de timezone e a compatibilidade dos dados do legado. A referência histórica a `src/app/docs/page.tsx` não corresponde a arquivo no baseline.

## Para continuar

Ler [AGENTS.md](../AGENTS.md), a issue, o [baseline](../docs/operations/REPOSITORY_BASELINE.md) e o [guia de desenvolvimento](../docs/DEVELOPMENT.md). Um agente trabalha em uma tarefa por draft PR; não altera VPS ou faz deploy a partir deste README.
