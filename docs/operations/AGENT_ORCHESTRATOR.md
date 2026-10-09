# Orquestrador de agentes — merge-train e autorização de sessão

- **Tarefa:** [Issue #41](https://github.com/rafaloct/jalapao-monitor-v2/issues/41)
- **Complementa:** [AGENT_COORDINATION.md](AGENT_COORDINATION.md) (contrato de
  execução) e [AGENT_A2A.md](AGENT_A2A.md) (interoperabilidade agente↔agente).

## 1. Papel

O **orquestrador** é um agente (ou operador humano assistido por tooling)
responsável por duas funções:

1. **Trem de merges (git train):** ordenar e integrar PRs de agentes
   respeitando dependências entre issues, gates de CI e revisão.
2. **Autorização de sessão:** garantir que todo trabalho executado por um
   agente corresponde a uma issue claimada por ele, sem gate humano pendente
   e dentro do escopo declarado.

O orquestrador **não cria autoridade nova**: ele executa o contrato já
aprovado. Aprovações humanas (decisões D-*, human-gate) continuam
insubstituíveis — o orquestrador apenas verifica que elas existem.

## 2. Sessão autorizada — definição executável

Uma sessão de trabalho é autorizada quando **todos** os itens valem:

| # | Condição | Como verificar |
|---|---|---|
| S0 | PR tem base `main` | `baseRefName` |
| S1 | Issue existe e está `agent:working` **ou `agent:review`** | label na issue |
| S2 | Executor autorizado (`agent:executor:*`) **e claimant do CLAIM bate com ele** (`agent:executor:any` aceita qualquer um) | label + campo `executor:` do CLAIM |
| S3 | CLAIM postado na issue com branch e paths | comentário iniciando em `CLAIM` |
| S4 | Sem `agent:blocked` e sem `human-gate` pendente | labels da issue |
| S5 | Branch segue `agent/issue-<N>-*` e aponta para a issue claimada — **sem fallback** por `Closes #N` | nome do head ref |
| S6 | Arquivos do diff ⊆ paths declarados no CLAIM — fora do escopo **reprova** | `claim_check.sh` |
| S7 | CI verde **e pipeline do repo completa**: os 5 checks `ci/*` presentes (CheckRun `COMPLETED+SUCCESS/NEUTRAL/SKIPPED` ou StatusContext `SUCCESS`) | `statusCheckRollup` |
| S8 | Threads de revisão resolvidas — **resultado ilegível reprova** | GraphQL `reviewThreads.isResolved` |
| S9 | Gate humano exigido pela issue registrado em ata (issue/comment) | verificação humana; o script reporta, não decide |

`tooling/agents/claim_check.sh <pr>` executa S0–S8 e reporta S9 como aviso.
Ele **falha fechado**: resultado incerto, ausente ou fora do padrão reprova
o merge até verificação humana.

## 3. Autorização de executor por escopo

| Executor | Pode executar | Restrições |
|---|---|---|
| `devin` (local) | Issues `agent:executor:devin` ou `agent:executor:any` | Nunca acessa credenciais reais; nunca deploy |
| `codex` (nuvem GitHub) | Issues `agent:executor:codex` ou `agent:executor:any` | Só artefatos GitHub; entrega via relay (AGENT_A2A §4) |
| `humano` | Tudo, inclusive decisões D-* e human-gate | — |

Regras:
- Issue com `agent:executor:<x>` **só** pode ser claimada pelo executor `<x>`.
- `agent:executor:any` aceita qualquer executor — mas quem claimar primeiro ganha
  exclusividade até handoff/abandono explícito.
- Dois agentes nunca editam a mesma branch; um CLAIM vigente bloqueia outros.

## 4. Merge-train — algoritmo

```text
para cada PR aberto de agente com base main, na ordem topológica:
  1. claim_check → reprovado? para e reporta (o trem não passa por cima)
  2. head CONFLICTING ou BEHIND/DIRTY da main? → para; rebase + CI nova
     exigidos (CI rodada na base antiga não vale como evidência)
  3. Integra (merge commit) → CI pós-merge deve ficar verde
  4. Fecha a issue com referência ao merge commit + etiqueta agent:done
     (essa evidência é o que libera dependências futuras)
```

Ordem por número de PR é o default; dependências explícitas na descrição da
issue (`Depends on: #N` ou `Depende de #N`) têm precedência — `train.sh`
ordena topologicamente. Dependência fechada **só conta se tiver evidência de
integração** (PR que a fechou mergeado, ou label `agent:done`) — fechamento
administrativo não prova gate.

**Política de conflito:** se dois PRs tocam o mesmo arquivo, o segundo na fila
precisa de rebase após o merge do primeiro — o orquestrador pausa o trem ali
e sinaliza, em vez de resolver conflito adivinhando intenção.

## 5. Uso

```bash
# Validar um PR específico antes de mergear
tooling/agents/claim_check.sh 38

# Listar o trem sem executar (dry-run)
tooling/agents/train.sh --dry-run

# Integrar PRs elegíveis em ordem (requer MERGE_ALLOWED=YES no ambiente)
tooling/agents/train.sh --merge
```

## 6. Limites honestos

- Enforcement é **operacional** (scripts + disciplina): os gates definitivos
  continuam sendo rulesets, CODEOWNERS e revisão no GitHub.
- S6 compara caminhos declarados no CLAIM contra o diff — cobre deslize de
  escopo acidental, não agente malicioso (defesa em profundidade = review).
- O orquestrador não aprova decisões humanas nem forja atas: só lê o que está
  registrado nas issues.
