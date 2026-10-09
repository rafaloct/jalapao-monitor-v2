# Runbook — Backend atrás do Cloudflare

- **Tarefa:** [Issue #39](https://github.com/rafaloct/jalapao-monitor-v2/issues/39)
- **Objetivo:** servir PocketBase e Hub via Cloudflare Tunnel com TLS na borda,
  sem expor IP/porta do VPS e sem cleartext HTTP (mitiga o risco R4 da
  [matriz de acesso](../security/ACCESS_MATRIX.md)).
- **Escopo deste documento:** procedimento operacional. **Nenhuma etapa foi
  executada** — o acesso ao VPS e à conta Cloudflare é operação humana.

## 1. Arquitetura alvo

```text
Tablet Flutter ──HTTPS──▶ Cloudflare Edge ──tunnel──▶ cloudflared no VPS
                                                       ├─▶ PocketBase :8090 (localhost)
                                                       └─▶ Hub Next.js :3000 (localhost)
```

- O VPS não precisa de porta pública aberta — o tunnel é saída (outbound only).
- TLS é terminado na borda do Cloudflare; o tráfego tunnel↔origem fica na
  loopback do VPS.
- SSE/realtime do PocketBase funciona sobre o tunnel (HTTP/1.1 com
  `noHappyEyeballs`).

## 2. Pré-requisitos

- Domínio próprio delegado ao Cloudflare (nameservers do CF no registrador).
- Acesso SSH ao VPS com permissão de instalar `cloudflared` como serviço.
- URLs definitivas de cada ambiente — exemplo: `pb.*` (PocketBase),
  `hub.*` (Hub), variantes `-staging`.

## 3. Provisionar o tunnel

```bash
# No VPS, uma vez:
cloudflared tunnel login            # gera cert.pem — autenticação humana
cloudflared tunnel create jalapao   # retorna TUNNEL-UUID + credentials file

# Configurar a partir do template versionado:
cp ops/cloudflared/config.example.yml /etc/cloudflared/config.yml
# editar TUNNEL-UUID, hostnames e credentials-file

# Rotas DNS (uma por hostname):
cloudflared tunnel route dns jalapao pb.SEU-DOMINIO
cloudflared tunnel route dns jalapao hub.SEU-DOMINIO
# staging — SOMENTE se a entrada de ingress pb-staging existir no config.yml;
# sem ingress correspondente a rota responde 404:
cloudflared tunnel route dns jalapao pb-staging.SEU-DOMINIO

# Serviço:
cloudflared service install
systemctl enable --now cloudflared
```

O `credentials-file` e o `cert.pem` são segredos operacionais do VPS —
**nunca** versionar nem copiar para esta máquina/repo.

## 4. Endurecimento recomendado (Zero Trust)

| Controle | Onde | Efeito |
|---|---|---|
| Cloudflare Access | Painel CF → Zero Trust | `hub.*`, `pb.*/_/*` **e** `pb.*/api/collections/_superusers/auth-with-password` atrás de login Cloudflare — proteger só `/_/` deixa a API de superuser exposta |
| Rate limiting | CF → Security | Limite em `/api/collections/*/auth-with-password` contra brute force |
| WAF/managed rules | CF → Security | Proteção OWASP básica na API |
| Cache | Desligado para `pb.*` | API e realtime nunca devem ser cacheados |
| Bind loopback | VPS | `next start -H 127.0.0.1` (ou firewall) — `next start` padrão escuta 0.0.0.0 e bypassa o tunnel; idem PocketBase (`--http=127.0.0.1:8090`) |

## 5. Fechando o cleartext (R4)

Quando o tablet usar `PB_URL` HTTPS, o fallback por IP deixa de ser necessário:

1. Build/dart-define apontando para `https://pb.SEU-DOMINIO` (ver
   [ENVIRONMENTS.md](ENVIRONMENTS.md)).
2. Validar sync, realtime e aprovação de places via tunnel.
3. Remover `92.112.179.111` de
   `android/app/src/main/res/xml/network_security_config.xml` — ou remover o
   arquivo se nenhum domínio cleartext restar — e remover a referência no
   `AndroidManifest.xml`. **Isso encerra o risco R4** (mitigação definitiva
   só vale depois da cutover confirmada em campo).

## 6. Verificação pós-deploy (checklist humano)

- [ ] `curl -sI https://pb.SEU-DOMINIO/api/health` → 200
- [ ] `https://pb.SEU-DOMINIO/_/` abre o admin (protegido por Access, se configurado)
- [ ] `https://hub.SEU-DOMINIO` renderiza o dashboard
- [ ] Tablet em staging sincroniza `place_visits`/`visits` via HTTPS
- [ ] Realtime/SSE do Hub atualiza sem refresh
- [ ] IP do VPS não responde mais em `:8090` publicamente (fechar firewall)

## 7. Observações de segurança

- O hostname de produção não é segredo criptográfico, mas mantê-lo fora do
  repo reduz a superfície de enumeração — por isso `env/*.local.json` é
  gitignored.
- TLS resolve transporte (R4); as regras de collection abertas (R2) são
  tarefa separada — Cloudflare não substitui autenticação do PocketBase.
