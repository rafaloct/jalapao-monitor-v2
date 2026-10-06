# ADR 0001 — Diagramas C4 (contêineres)

Referenciado por [`0001-authoritative-backend.md`](./0001-authoritative-backend.md).
Renderizável como Mermaid no GitHub. `PROPOSED` — descreve o alvo; o observado
espelha o checkout `main @ a6d9bfe`.

## Arquitetura observada (baseline)

```mermaid
C4Container
    title Contêineres — arquitetura observada (baseline a6d9bfe)

    Person(monitor, "Monitor/Operador", "Tablet Android no atrativo")
    Person(gestor, "Gerente", "Cadastro via app (PIN local)")
    Person(coord, "Coordenador territorial", "Dashboard Hub")

    Container(app, "App Flutter", "Flutter + Hive + Provider", "Offline-first: grava local, sync 30s")
    ContainerDb(hive, "Hive", "Store local durável", "places, place_visits, reservations, config")
    System_Boundary(vps, "VPS existente") {
        Container(pb, "PocketBase", "PocketBase :8090", "Collections abertas; auth _superusers; UTC")
        Container(hub, "Hub Next.js", "Next.js :3000", "Dashboard; merge visits + place_visits; BRT via tz.ts")
    }

    Rel(monitor, app, "Opera fila/contador/reservas")
    Rel(gestor, app, "Cadastra locais (PIN local + fallback)")
    Rel(app, hive, "Persiste antes de sincronizar")
    Rel(app, pb, "Sync up/down a cada 30s (HTTP)")
    Rel(hub, pb, "REST SDK")
    Rel(coord, hub, "Visualiza (senha via middleware)")
```

## Arquitetura alvo (proposta — Opção C referência)

```mermaid
C4Container
    title Contêineres — arquitetura alvo proposta

    Person(monitor, "Monitor/Operador", "Tablet no atrativo")
    Person(gestor, "Gerente do empreendimento")
    Person(coord, "Coordenador territorial")
    Person(pesq, "Pesquisador", "Dados de pesquisa, sem PII operacional")
    Person(tv, "Display/TV", "Visão pública do atrativo")
    Person(admin, "Administrador técnico")

    Container(app, "App Flutter", "Flutter, sem store local", "Cache transitório em memória; estados de conectividade explícitos")
    Container(hub, "Hub Next.js", "Next.js", "Dashboard do coordenador (BRT via tz.ts)")

    System_Boundary(backend, "Backend autoritativo (Opção C: FastAPI + Postgres)") {
        Container(api, "API de comandos", "FastAPI / REST+OpenAPI", "Idempotency key, dedup, confirmação server-side")
        Container(rt, "Realtime", "SSE (proposta)", "Estados operacionais p/ Hub e TV")
        ContainerDb(pg, "Postgres", "Store autoritativo", "UTC; RLS conforme matriz #19; auditoria")
    }

    Rel(monitor, app, "Comandos de operação")
    Rel(gestor, app, "Gestão (auth individual + dispositivo)")
    Rel(app, api, "POST comandos c/ idempotency_key; GET resultado", "HTTPS")
    Rel(api, pg, "Transações autoritativas")
    Rel(api, rt, "Publica eventos confirmados")
    Rel(hub, api, "Leitura REST")
    Rel(hub, rt, "Assina eventos")
    Rel(coord, hub, "Dashboard")
    Rel(tv, rt, "Visão pública (sem PII)")
    Rel(pesq, api, "Exportações de pesquisa")
    Rel(admin, api, "Operação/auditoria")
```

## Ciclo de vida do comando (confirmação server-side)

```mermaid
stateDiagram-v2
    [*] --> pendente: comando criado (idempotency_key)
    pendente --> pendente: F1/F2 offline ou degradado (retry c/ mesma key)
    pendente --> pendente: F3 timeout pós-envio (reenvio dedup)
    pendente --> confirmado: 200 + applied|duplicate
    pendente --> rejeitado: resposta de conflito/validação (F5)
    rejeitado --> pendente: operador corrige e reenvia (nova key)
    confirmado --> [*]
    rejeitado --> [*]
```

> `pendente` nunca é apresentado como "salvo". Restart descarta `pendente`
> (§4 da ADR); recuperação via consulta de resultado por chave natural.
