# Backlog — Melhorias Pós-Teste de Campo

Este arquivo documenta melhorias identificadas antes e durante o desenvolvimento.
Após o teste de campo (25/03/2026), novas observações devem ser adicionadas aqui.

## Prioridade Alta (identificadas antes do campo)

### APP

- [ ] **Proteção de duplicata multi-tablet:** Implementar lock otimista no PocketBase ou reduzir intervalo de sync para ~5s quando 2 tablets operam no mesmo local. Atualmente há janela cega de 30s.
- [ ] **Remoção de grupo por engano:** Não há como desfazer um registro sem acesso gestor. Adicionar opção "Desfazer" com janela de 30s.
- [ ] **Indicador de sync mais claro:** O banner laranja de "sem internet" some quando o sync funciona, mas o usuário não sabe se o dado foi confirmado pelo PocketBase. Adicionar timestamp "último sync bem-sucedido".
- [ ] **Foto na sessão:** PlaceFormScreen aceita até 5 fotos mas o upload para PocketBase não está implementado (paths locais). Implementar upload de arquivo.

### HUB

- [ ] **Autenticação por usuário:** Atualmente a senha é compartilhada. Implementar auth por email/senha via PocketBase Users para auditoria de acesso.
- [ ] **Alertas em tempo real:** Notificar coordenador quando capacidade de um fervedouro atingir 80% ou 100%.
- [ ] **Dashboard mobile:** Hub é otimizado para desktop. Criar visualização responsiva para smartphone do coordenador.
- [ ] **Relatório PDF:** Além do CSV, gerar relatório formatado por dia com estatísticas resumidas.

## Prioridade Média

- [ ] **Histórico de capacidade:** Registrar quando a capacidade de um local foi alterada pelo gestor, para análise histórica correta.
- [ ] **Modo offline do Hub:** Cache de dados no browser para visualização mesmo sem internet no VPS.
- [ ] **Configuração de ciclo de banho por fervedouro:** Atualmente hardcoded em 20min. Tornar configurável por local via GestorScreen.
- [ ] **Internacionalização:** Sistema em PT-BR. Se houver turistas internacionais operando tablets, adicionar EN.

## Prioridade Baixa / Fase 3

- [ ] **API pública para pesquisadores:** Endpoint REST autenticado para exportar dados agregados anonimizados.
- [ ] **Dashboard comparativo entre temporadas:** Comparar dados de 2026 vs 2027+.
- [ ] **Integração com sistema de ingressos:** Se houver bilheteria, correlacionar com dados de fluxo.
- [ ] **Análise preditiva de filas:** Com dados históricos suficientes, prever pico de demanda por horário.

---

## Observações do Teste de Campo (preencher após 25/03/2026)

> **TODO:** Após o teste de campo, registrar aqui:
> - Problemas encontrados pelos monitores em campo
> - Funcionalidades que faltaram
> - Fluxos que precisam ser simplificados
> - Dados coletados que não estavam previstos no schema
> - Feedback dos coordenadores sobre o Hub

---

## Bugs conhecidos (resolvidos antes do campo)

| Bug | Solução | Arquivo |
|---|---|---|
| `_buildEmptyState` 17px overflow | `FittedBox(fit: BoxFit.scaleDown)` | `place_reservation_screen.dart` |
| CANCELAR off-screen em dialogs landscape | `ConstrainedBox(82%) + SingleChildScrollView` | `place_reservation_screen.dart` |
| `pumpAndSettle` loop infinito nos testes | `4×pump(500ms)` em `snap()` | `integration_test/baseline_operational_walkthrough.dart` |
| CounterScreen 5.1px overflow | `SingleChildScrollView` no AlertDialog | `counter_screen.dart` |
| GPS dialog sobrepondo tela ao abrir | Removido `_getGPS()` do `initState` | `place_form_screen.dart` |
| Hub exibindo horários em UTC | Criado `src/lib/tz.ts`, todos os helpers migrados para BRT | Hub |
| `convertLegacyVisits` mapeando `fila` → `exited` | Corrigido para `queued` | `places-service.ts` |
