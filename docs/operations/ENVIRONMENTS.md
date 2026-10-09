# Ambientes — builds staging/produção sem retrabalho de credenciais

- **Tarefa:** [Issue #39](https://github.com/rafaloct/jalapao-monitor-v2/issues/39)
- **Invariante central:** desde a #24, **nenhuma credencial entra no build**.
  Trocar de ambiente = trocar o arquivo de configuração externo; nunca reeditar
  código, senha ou PIN.

## 1. Modelo

| Camada | Configuração | Credencial |
|---|---|---|
| App Flutter | `env/<ambiente>.local.json` → `--dart-define-from-file` | Nenhuma — auth do gestor é conta PocketBase individual |
| Hub Next.js | `hub/.env.local` / `.env.production` (gitignored) | Nenhuma em `NEXT_PUBLIC_*` |
| PocketBase | Config do servidor (fora do repo) | Contas/tokens vivem no backend — rotação não exige rebuild |

"Não há senha a trocar em staging vs produção" é uma propriedade **do modelo**:
o build carrega apenas URLs; credenciais são emitidas pelo servidor e revogáveis.

## 2. Arquivos de ambiente do app

```bash
cp env/staging.example.json    env/staging.local.json    # ajustar hostname
cp env/production.example.json env/production.local.json
```

Os `*.local.json` são gitignored (`env/*.local.json`) — os hostnames reais
ficam fora do repo. Conteúdo permitido: somente valores não secretos
(`PB_URL`, futuros flags de ambiente).

## 3. Builds

```bash
# Staging
flutter run     --dart-define-from-file=env/staging.local.json
flutter build apk --dart-define-from-file=env/staging.local.json

# Produção — mesmos inputs de código, só muda o arquivo de config
flutter build apk --release --dart-define-from-file=env/production.local.json
```

Critério de promoção: o build de produção difere do de staging **somente** no
arquivo `env/*.local.json`. Qualquer diferença além disso indica configuração
vazada para o código — tratar como bug.

## 4. Hub

```bash
cd hub
cp .env.example .env.local                    # desenvolvimento (127.0.0.1)
# staging/produção: definir NEXT_PUBLIC_PB_URL no ambiente de deploy
NEXT_PUBLIC_PB_URL=https://pb.SEU-DOMINIO npm run build
```

`NEXT_PUBLIC_PB_URL` carrega apenas a URL pública do backend — por definição
`NEXT_PUBLIC_*` vai para o bundle do cliente, logo **jamais** recebe senha ou
token.

## 5. Promoção staging → produção (checklist)

- [ ] Mesmo SHA de código nos dois builds (só `env/*.local.json` difere)
- [ ] `PB_URL` de produção é HTTPS via Cloudflare ([CLOUDFLARE_BACKEND.md](CLOUDFLARE_BACKEND.md))
- [ ] Contas PocketBase de produção criadas como **individuais** (matriz §5.5)
      — staging usa contas sintéticas separadas, nunca as mesmas
- [ ] Cleartext Android removido após cutover confirmado (CLOUDFLARE_BACKEND §5)
- [ ] Sem valor de segredo em `git grep` no diff de promoção

## 6. Rotação de credenciais — o que NÃO exige rebuild

| Evento | Ação | Rebuild? |
|---|---|---|
| Rotacionar senha de gestor | PocketBase Admin → usuário | Não |
| Revogar token de tablet | Deletar sessão/token no backend | Não |
| Trocar URL do backend | Novo build só com outro `env/*.local.json` | Sim — mas é só config |
| Vazamento de credencial de staging | Rotacionar no PB de staging | Não |

## 7. Não implementado aqui

- CI de build (workflow exige scope `workflow` no token GitHub — pendente
  junto ao widening de `flutter test`).
- Assinatura de release do APK — tarefa própria com autorização específica
  (DEVELOPMENT.md §Build).
