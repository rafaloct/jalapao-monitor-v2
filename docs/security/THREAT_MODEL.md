# Threat model — superfícies do Jalapão Monitor

- **Status:** `PROPOSED` — companheiro da
  [`ACCESS_MATRIX.md`](./ACCESS_MATRIX.md); aguarda aprovação na
  [Issue #13](https://github.com/rafaloct/jalapao-monitor-v2/issues/13).
- **Tarefa:** [Issue #19](https://github.com/rafaloct/jalapao-monitor-v2/issues/19)
- **Base:** `main @ a6d9bfe1507f9d75e6d4a872c17501c435204634`; reconciliar com a
  ADR 0001 (`docs/adr/0001-authoritative-backend.md`, [PR #28](https://github.com/rafaloct/jalapao-monitor-v2/pull/28)) antes da aprovação.

## 1. Escopo e ativos

Cobre as superfícies nomeadas na #13: **QR/tokens públicos, API, displays,
impressora, mídia**, além do cliente tablet, transporte e backend. QR, impressora
e mídia são futuros (#5, #6, #10) — modelados por papel previsto, não por código
existente; nada aqui presume implementação.

| Ativo | Impacto se comprometido |
|---|---|
| Integridade do fluxo (fila/contagens/reservas) | Decisão de manejo e operação do atrativo corrompidas |
| PII de hóspedes/proprietários | Exposição LGPD, dano a titulares |
| Disponibilidade do backend | Parada da operação de campo |
| Tokens/credenciais de dispositivo | Escrita falsa em nome do atrativo |
| Confiança pública (TV/QR) | Informação falsa a turistas |

## 2. Limites de confiança

```
turista/QR ─┐
display TV ─┤
agência ────┤
operador ───┼─► [FRONTEIRA 1: transporte público] ─► API/backend ─► [FRONTEIRA 2: store autoritativo]
gerente ────┤                                              │
coordenador─┘                                              ▼
                                                    exports/Hub/TV/pesquisa
                                                   [FRONTEIRA 3: consumidores]
admin (FRONTEIRA 4: plano de controle — regras, backups, usuários)
```

## 3. Ameaças por superfície (STRIDE resumido)

### 3.1 QR / tokens públicos (turista, agência)

| Ameaça | Cenário | Mitigação proposta |
|---|---|---|
| Spoofing/enumerável | Token sequencial lê reserva de outro | Token opaco, alto-entropia, escopo `self`, expiração curta (D7) |
| Tampering | Alterar voucher → check-in falso | Assinatura/validação server-side; estado só muda por comando confirmado |
| Repúdio | Turista nega check-in | Trilha: evento com `idempotency_key`, ator, timestamp do servidor |
| DoS | Enfileirar falsos no balcão do QR | Rate limit por token/IP; captcha na criação se necessário |
| Elevação | Token público chama endpoints internos | Escopo de leitura mínimo; deny-by-default (N7/N9) |

### 3.2 API e transporte

| Ameaça | Cenário | Mitigação |
|---|---|---|
| Sniffing | HTTP cleartext expõe dados/PII em Wi-Fi de campo | HTTPS obrigatório no alvo (risco R4 do baseline) |
| Replay | Reenvio de comando capturado | `idempotency_key` + dedup; timestamp do servidor |
| Escrita falsa | Qualquer cliente escreve (regras abertas hoje) | Auth de dispositivo pareado; RLS/regras por papel (N10) |
| Dedup insuficiente | Timeout pós-envio duplica coleta | Modelo F3 da ADR: dedup server-side |
| DoS | Flood de comandos | Rate limit por dispositivo/ator; limites de payload |

### 3.3 Displays / TV

| Ameaça | Cenário | Mitigação |
|---|---|---|
| Info disclosure | Feed com registro individual/PII | Feed só `publico`+agregado (N6); revisão de payload |
| Spoofing de fonte | Atacante publica feed falso na TV | Canal autenticado por dispositivo de exibição |
| Vandalismo de endpoint | Token da TV usado para ler além | Escopo read-only do atrativo (T6) |

### 3.4 Impressora térmica (futuro #6)

| Ameaça | Cenário | Mitigação |
|---|---|---|
| Forjar recibo/voucher | Recibo impresso como prova falsa | Código de verificação no recibo; emissão só por comando confirmado |
| PII impressa | Nome/telefone em papel exposto | Payload mínimo por papel; descarte definido (D2) |
| Pareamento Bluetooth | Emissor não autorizado emparelha | Impressão sempre mediada pelo tablet autorizado |

### 3.5 Mídia / snapshots (futuro #10)

| Ameaça | Cenário | Mitigação |
|---|---|---|
| Privacidade | Pessoa identificável em imagem ao vivo | Consentimento/aviso, minimização, retenção — decisões D2/D3 |
| Info disclosure | Snapshot vaza para visão pública | Classe `pesquisa`/`pii`; nunca `publico` |
| Escopo de acesso | Pesquisador baixa bruto com pessoas | Visão minimizada como padrão (D2) |

### 3.6 Cliente tablet

| Ameaça | Cenário | Mitigação |
|---|---|---|
| Credencial privilegiada embarcada | PIN/fallback atual dá fluxo gestor (R1) | Provisionamento por pareamento (ACCESS_MATRIX §5); remoção na #24 |
| Roubo/perda do tablet | Escrita falsa continuada | Token curto revogável; T9 |
| Estado falso local | Item "salvo" sem servidor | Confirmação server-side (ADR §4–§6) |

### 3.7 Backend / admin (fronteira 4)

| Ameaça | Cenário | Mitigação |
|---|---|---|
| Privesc | Regra aberta permite alterar schema/usuários | Regras fechadas, `_superusers` restrito, MFA avaliável (D6) |
| Auditoria ausente | Não se sabe quem aprovou/alterou | Trilha de auditoria por ator (requisito #13) |
| Perda de dados | VPS único sem restore testado | Backup versionado + restore drill (roadmap) |
| Vazamento de secret | Credencial em código/docs | Secrets fora do código; baseline já registra divergência (R1) |

## 4. Ameaças herdadas do baseline (resumo de verificação)

Estas existem **hoje** e são riscos a verificar, não modelo aprovado — cruzam com
a lista R1–R7 da matriz: regras abertas, PIN fallback, HTTP cleartext, senha
única do Hub, sync sem autenticação, duplicata multi-tablet, PII sem separação.

## 5. Pendências

- Aprovação da matriz (versão/commit) na #13 e reconciliação com a ADR.
- Decisões D1–D7 de `ACCESS_MATRIX.md` (retenção, finalidade, base legal, MFA, QR).
- Remoção do fallback de credencial → #24 (após modelo §5 aprovado).
- Cenários T1–T10 viram casos de teste na implementação das APIs (#23/#24+).
