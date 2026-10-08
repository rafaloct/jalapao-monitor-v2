# Transição de credenciais — remoção do fallback de PIN local

- **Tarefa:** [Issue #24](https://github.com/rafaloct/jalapao-monitor-v2/issues/24)
- **Base aprovada:** matriz de acesso e modelo de provisionamento
  (`ACCESS_MATRIX.md` §5), aprovados na Issue #13 (ata de 06/10/2026).
- **Valores reais:** nenhum valor de credencial é reproduzido neste documento.

## 1. O que mudou

| Antes (baseline `a6d9bfe`) | Depois |
|---|---|
| PIN local embutido via `--dart-define=GESTOR_PIN` com literal de fallback no código | Removido: nenhuma credencial padrão válida existe no cliente |
| `login()` concedia fluxo de gestor offline antes de tentar o PocketBase | Login é exclusivamente conta PocketBase individual (`users`) |
| Modo PIN marcava aprovação como sucesso sem confirmação do servidor (falso positivo — risco R3) | `approvePlace`/`rejectPlace` retornam sucesso somente com resposta do servidor |
| PIN do gestor podia ser alterado localmente no app (`setPin`) | Não existe mais credencial local a alterar |
| Walkthrough/scripts usavam `--dart-define=GESTOR_PIN` com literal | Conta sintética via `TEST_GESTOR_EMAIL`/`TEST_GESTOR_PASSWORD`, sem default |

## 2. Comportamento ao atualizar (instalações existentes)

- No primeiro `init` após a atualização, o app **apaga a chave `gestor_pin`**
  do `flutter_secure_storage` — nenhum vestígio do PIN local permanece.
- Uma sessão PocketBase válida já persistida (token) continua válida e é
  restaurada normalmente — é credencial emitida pelo servidor, revogável.

## 3. Falha explícita (aceite da #24)

| Cenário | Comportamento |
|---|---|
| Sem configuração de servidor / rede indisponível | `login` retorna "Servidor indisponível…" — **nenhum privilégio local** |
| Credencial inválida (HTTP 400) | `login` retorna "Credenciais inválidas…" — **nenhum privilégio local** |
| Token expirado/revogado | `pb.authStore.isValid` = false → sessão não restaura; novo login exigido |
| Operação sem login | `approvePlace`, `rejectPlace`, `fetchPendingPlaces` retornam `false`/`[]` |

## 4. Orientação de transição e rotação (operacional)

O PIN anterior foi distribuído em material impresso e permanece no histórico
git — **trate-o como comprometido**:

1. **Rotacionar a senha** da conta de gestor no PocketBase Admin
   (`PB_URL/_/` → Collections → `users`) — o valor antigo não deve ser
   reutilizado como senha de nenhuma conta.
2. **Criar contas individuais** para cada gestor/coordenador (matriz §5.5) —
   sem conta compartilhada.
3. **Atualizar os tablets** para o build sem fallback; verificar login com a
   conta individual de cada gestor **antes** da operação de campo.
4. **Reimprimir o cartão A5** (`CARD_A5_MONITOR.html`) — a versão anterior
   continha PIN e senha do Hub em claro; a versão atual aponta para o
   coordenador.
5. **Revogar tokens antigos**: após a rotação, sessões persistidas com a
   senha antiga deixam de autenticar na próxima validação server-side.
6. Scripts operacionais (`capture_screens.ps1`, `run_baseline_only.ps1`)
   leem `PB_URL`, `PB_GESTOR_USER`, `PB_GESTOR_PASS`, `TEST_GESTOR_*` do
   ambiente — nunca literais versionados.

## 5. Fora de escopo (não realizado)

- Rotação efetiva de credenciais no servidor — procedimento operacional do
  responsável, executado com acesso ao backend.
- Alteração de usuários já existentes no backend.
- Pareamento de dispositivos operadores (`devices`, tokens de vida curta) —
  depende do desenho D-E da ADR, ainda pendente de aprovação.
- `network_security_config.xml` ainda lista cleartext para o VPS (risco R4,
  documentado — mitigação via TLS/rede privada é tarefa separada).
