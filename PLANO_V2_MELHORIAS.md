> Documento histórico. A fila atual e as decisões estão nas [Issues](https://github.com/rafaloct/jalapao-monitor-v2/issues/1), nos milestones e em [AGENTS.md](AGENTS.md). Este plano não libera implementação nem substitui a ADR da #2.

# Plano de Melhorias — Jalapão Monitor v2.2
> Gerado em 2026-03-19. Executar em sessão dedicada.

---

## Contexto

Arquitetura Offline-First:
```
Tablet (Flutter/Hive) → sync 30s → PocketBase (VPS) → Hub (Next.js)
```
O app é o "sensor" de campo. A inteligência do fluxo vive no Hub.
Este plano cobre três frentes: **App (Tablet)**, **Testes/QA**, **Hub/Análise**.

---

## FRENTE 1 — App Flutter (Tablet)

### 1.1 Segurança — GestorLogin [CONCLUÍDO]
- [x] Remover a hint card que expõe PIN padrão `jalapao2026` e URL pública do PocketBase
- [x] A URL do PB nunca deve aparecer em tela de produção
- [x] Alternativa: hint colapsado atrás de um toque longo (acessível ao técnico, invisível ao visitante)

### 1.2 PaxSelector — maxPax dinâmico [CONCLUÍDO]
- [x] Passar `place.capacityTotal` como `maxPax` nas telas CounterScreen e nos dialogs do Dashboard/PlaceReservation
- [x] Hoje o grid sempre renderiza 30 posições mesmo em locais cap. 6
- [x] Edge case: se `capacityTotal == 0` (sem limite), manter maxPax=30 como fallback

### 1.3 Dialog CHEGADA DE GRUPO — valor inicial [CONCLUÍDO]
- [x] PaxSelector inicia em 0 — sem sentido operacional
- [x] Alterar valor inicial de 0 para 1 no estado do dialog do DashboardScreen

### 1.4 Banner de erro de sync [CONCLUÍDO]
- [x] A faixa laranja "não sincronizado" domina a tela do DashboardScreen
- [x] Substituir por ícone discreto no header (ex: `Icons.cloud_off` com cor de alerta)
- [x] Manter o banner completo apenas se o erro persistir por mais de 5 minutos (sync crítico)

### 1.5 SessionSelector — ocupação em tempo real [CONCLUÍDO]
- [x] Cada card do grid hoje mostra só "Cap: X pessoas" (estático)
- [x] Adicionar badge dinâmico com ocupação atual: "3 / 20 agora" usando `visitsByPlace()`
- [x] Cards com ocupação > 80% recebem borda amarela; > 100% borda vermelha
- [x] Isso torna o SessionSelector um mini-dashboard de visão geral antes de selecionar

### 1.6 Indicador preemptivo de capacidade [CONCLUÍDO]
- [x] Header de CounterScreen e DashboardScreen: quando `occupancy >= 0.8 * capacityTotal` → badge muda para amarelo; quando `>= capacityTotal` → vermelho
- [x] Já existe lógica parcial (`over` booleano no CounterScreen) — expandir para gradiente de cores

### 1.7 Tema — coerência visual [CONCLUÍDO]
- [x] CounterScreen usa dark (#0D1117), Dashboard/PlaceReservation usam light (rosa)
- [x] Decisão de projeto: manter o light theme (mais legível à luz solar no campo) e migrar CounterScreen
- [x] GestorLogin: AppBar verde intenso destoante — alinhar ao tema escolhido

### 1.8 Próxima reserva em destaque [CONCLUÍDO]
- [x] Quando há reserva futura para o dia, destacar o card da reserva mais próxima do horário atual (borda azul 3px + badge "PRÓXIMO").

### 1.9 SessionSelector — persistência e histórico [CONCLUÍDO]
- [x] Persistir em Hive o `placeId` da última sessão do tablet.
- [x] Reduz fricção matinal: o monitor não precisa reidentificar seu posto se for no mesmo dia.
- [x] Tema unificado para Creme.

### 1.10 Refatorar Onboarding — separação de responsabilidades [CONCLUÍDO]
- [x] Onboarding coleta **apenas** o `tablet_id` (ex: "TAB-01") — sem campo de nome de place
- [x] Removida criação de place no fluxo de onboarding do tablet
- [x] Places criados/gerenciados exclusivamente pelo gestor via Hub ou PocketBase admin
- [x] Toda associação `tablet → place` acontece dinamicamente via SessionSelectorScreen
- [x] DashboardScreen seeds `atrativo` + `poolCapacity` do place ativo via `addPostFrameCallback`
- [x] Teste baseline atualizado: seção A usa apenas 1 TextField (tabletId)

---

### 1.11 Dialogs — restrição de altura em tablets landscape [CONCLUÍDO]
- [x] `_showQuickEntryDialog` e `_showAddReservationDialog`: botão CANCELAR saía da tela em landscape
- [x] Adicionado `ConstrainedBox(maxHeight: 82% da tela)` + `insetPadding` nos dois dialogs
- [x] `_buildEmptyState`: overflow 17px corrigido com `FittedBox(fit: BoxFit.scaleDown)`

---

## FRENTE 2 — Testes / QA (integration_test)

### 2.1 Renomear arquivo de teste [CONCLUÍDO]
- [x] `app_test.dart` → `baseline_operational_walkthrough.dart`
- [x] Atualizar referência no `capture_screens.ps1`
- [x] Fix final: seção F agora navega explicitamente de volta ao SessionSelector via `swap_horiz` antes de procurar o ícone de gestor (evitava que o teste pulasse a seção inteira quando a tela estava em estado inconsistente)
- [x] Screenshot `26_gestor_place_form` capturado — todas as 00–26 disponíveis em `screenshots/2026-03-19/baseline/`

### 2.2 Novo teste: cenário de pico (peak_flow) [CONCLUÍDO]
- [x] `peak_flow_test.dart`: simular preenchimento sequencial de múltiplos grupos
- [x] Registrar chegada de N grupos até atingir 80%, 100% e 110% da capacidade
- [x] Capturar screenshots dos estados de alerta visual para cada limiar
- [x] Valida visualmente o "Carrying Capacity" — objetivo central do sistema

### 2.3 Novo teste: edge cases [CONCLUÍDO]
- [x] `edge_cases_test.dart`:
  - [x] Sync failure: simular sem rede e verificar comportamento offline
  - [x] Dados malformados: tentar registrar grupo com paxQty=0
  - [x] Tempo excedido: verificar se timer de banho/ciclo exibe alerta após timeout
  - [x] Capacidade excedida: registrar grupo além do limite e verificar alerta

### 2.4 Nomenclatura da pasta de screenshots [CONCLUÍDO]
- [x] Estruturar por data: `screenshots/YYYY-MM-DD/baseline/`

### 2.6 Corrigir pumpAndSettle infinito no teste gestor [CONCLUÍDO]
- [x] snap() usava pumpAndSettle — entrava em loop com o timer de SyncDown (30s) do PlaceProvider
- [x] Substituído por pump finito: 4×500ms (2s) — estável e previsível
- [x] Navegação para aba MONITORAR também usa pump(2s) em vez de pumpAndSettle

### 2.5 Fechar ciclo E2E [CONCLUÍDO]
- [x] Após testes no tablet, verificar via API se os `PlaceVisit` chegaram ao PocketBase.
- [x] Adicionado ao `capture_screens.ps1` passo final com autenticação de Gestor.
- [x] Valida que o sensor (tablet) → banco de dados está funcionando end-to-end.

---

## FRENTE 3 — Hub / Análise (Next.js)

### 3.1 Dashboard de visão geral em tempo real [CONCLUÍDO]
- [x] Tela principal do Hub: grid de todos os locais com ocupação atual
- [x] Mesmo conceito do SessionSelector melhorado (item 1.5), mas para o gestor no escritório
- [x] Atualização via polling ou websocket no PocketBase

### 3.2 Histograma de fluxo diário por local [CONCLUÍDO]
- [x] Gráfico de barras: eixo X = hora do dia (6h-20h), eixo Y = paxQty de entradas
- [x] Sincronizado com o date picker do histórico — ao trocar data o gráfico também muda
- [x] Inclui reservações (restaurante/pousada) além de place_visits
- [x] Filtros de tipo e local aplicados em tempo real

### 3.3 Heatmap semanal de ocupação [CONCLUÍDO]
- [x] Grid 7 dias × 15 horas (06h–20h), células coloridas laranja→vermelho por intensidade
- [x] Inclui reservações (restaurante/pousada) além de place_visits
- [x] Legenda de escala com valores absolutos
- [x] Filtros de tipo e local aplicados

### 3.4 Screenshot automático do Hub pós-sync [CONCLUÍDO]
- [x] Expandir `capture_screens.ps1` ou usar browser tool para capturar o estado do Hub após sincronização dos testes
- [x] Fecha o ciclo: tablet → PocketBase → Hub → screenshot do Hub
- [x] Valida toda a pipeline E2E visualmente

### 3.5 Alerta de capacidade para o gestor [CONCLUÍDO]
- [x] Banner ⚠️ laranja para locais entre 70–99% da capacidade
- [x] Separado do banner 🚨 vermelho (≥100%) que já existia
- [x] Ambos os banners mostram nome, ocupação atual/total e percentual por local

### 3.6 Nome de grupo e cidade de origem [CONCLUÍDO]
- [x] Campo opcional de nome no app (DashboardScreen, CounterScreen, PlaceReservationScreen)
- [x] Nome aleatório Jalapão-temático gerado automaticamente se não preenchido (Grupo Ipê, Buriti, etc.)
- [x] Campo opcional de cidade de origem em todas as telas de chegada
- [x] Modelos Hive atualizados: HiveField(11) groupName e HiveField(12) originCity no Visit/PlaceVisit; HiveField(13) originCity no Reservation
- [x] Hub exibe grupo nas tabelas de ativos e histórico; origin_city aparece ao lado do nome
- [x] Coleta integrada nas 3 coleções: visits, place_visits, reservations

### 3.7 Gráfico de origem dos visitantes [CONCLUÍDO]
- [x] Gráfico de barras horizontal no Hub mostrando top cidades de origem por pax
- [x] Agrega dados de todas as fontes (place_visits + reservations + legacy visits)
- [x] Visível apenas quando existem dados de origem informados
- [x] `buildOriginCityData()` em places-service.ts

### 3.9 Fervedouro — painel Fila/Água no Hub [CONCLUÍDO]
- [x] `convertLegacyVisits()`: mapeamento corrigido — `fila` → `'queued'` (antes: `'exited'`)
- [x] `PlaceVisit.status` expandido para incluir `'queued'`
- [x] Novo painel "🌊 Fervedouros — Fila e Água" no Hub (entre ocupação e histograma)
- [x] Cards por fervedouro: coluna azul (Na Água) + coluna âmbar (Na Fila) com pax e contagem de grupos
- [x] Barra de progresso mostra ocupação dos que estão na água vs capacidade
- [x] Grupos em fila NÃO inflacionam a ocupação geral do local

### 3.8 Backup CSV multi-coleção [CONCLUÍDO]
- [x] Botão "Backup CSV" no header do Hub abre modal com seletor de intervalo de datas
- [x] Exporta place_visits + reservations + visits (legado) em CSV unificado
- [x] Colunas: Data, Hora_Entrada, Local, Tipo, Colecao, Grupo, Origem, Pax, Hora_Saida, Duracao_min, Status
- [x] BOM UTF-8 incluído para compatibilidade com Excel
- [x] Confirmação do total de registros exportados após download

---

## Ordem de Execução Sugerida

| Prioridade | Item | Esforço | Impacto |
|-----------|------|---------|---------|
| 1 | 1.1 Segurança GestorLogin | Baixo | Alto |
| 2 | 1.3 Dialog valor inicial | Baixíssimo | Médio |
| 3 | 1.2 PaxSelector maxPax dinâmico | Baixo | Médio |
| 4 | 1.4 Banner sync discreto | Médio | Médio |
| 5 | 2.1 Renomear teste | Baixíssimo | Baixo |
| 6 | 1.5 SessionSelector ocupação real | Médio | Alto |
| 7 | 1.6 Indicador preemptivo capacidade | Médio | Alto |
| 8 | 2.2 Teste peak flow | Alto | Alto |
| 9 | 2.3 Teste edge cases | Alto | Médio |
| 10 | 1.7 Unificar tema | Alto | Médio |
| 11 | 1.8 Próxima reserva destaque | Médio | Médio |
| 12 | 1.9 Último local usado | Médio | Médio |
| 13 | 3.1-3.3 Hub dashboards | Alto | Alto |
| 14 | 3.4 Screenshot Hub E2E | Médio | Alto |
| 15 | 3.5 Alertas gestor | Alto | Alto |

---

## Princípio Norteador

> O tablet é apenas o sensor. A inteligência do fluxo vive no Hub.
> Cada melhoria no app deve ser avaliada pela pergunta:
> "Isso melhora a qualidade/completude do dado que chega ao PocketBase?"
> Se sim, é prioridade. Se é só estética, é baixa prioridade.
