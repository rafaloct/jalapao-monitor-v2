# Atualizações do aplicativo em tablets de campo — decisão proposta

Estado: proposta documental para a issue #53. Consulta das fontes: 15/10/2026. Nenhum serviço OTA, canal de distribuição ou APK foi configurado ou testado nesta tarefa.

## Necessidade e contexto observado

O app Flutter usa PocketBase e mantém dados pendentes em Hive durante períodos sem conexão ([arquitetura](../ARCHITECTURE.md)). O Android já tem flavors `staging` e `production`, com URLs de backend fornecidas no build por `--dart-define-from-file` ([ambientes](../operations/ENVIRONMENTS.md)). O pedido é corrigir o app em tablets instalados sem reinstalar APK a cada correção. Ainda não há evidência nesta tarefa de como os tablets recebem o APK (Play Store, distribuição privada ou sideload), de conectividade em campo ou de uma release Shorebird existente.

## Alternativas

| Opção | O que atualiza | Rede e primeiro uso | Custo e operação |
| --- | --- | --- | --- |
| **Shorebird Code Push** | Código Dart já compatível com a release instalada, incluindo lógica e UI. Alterações nativas, configuração Android, assets e versão do Flutter exigem nova release binária; dependência que muda código nativo também exige release. [Escopo de patches][shorebird-faq] | Exige rede para descobrir e baixar um patch novo. Na configuração padrão, baixa em segundo plano ao abrir o app e aplica no **próximo início do processo**; a primeira abertura de uma instalação nova usa a release base. Offline, roda a última versão já instalada/cacheada. [Estratégias][shorebird-updates] | Serviço externo e pipeline próprios. A [tabela pública de preços][shorebird-pricing] consultada mostra Free US$0/mês com 5.000 instalações de patch/mês, Pro US$20/mês com 50.000 e Business US$400/mês com 1.000.000; excedente anunciado para Pro/Business: US$1 por 2.500 instalações. Preço, limites e termos devem ser reconfirmados na contratação. |
| **Configuração remota no PocketBase** | Somente valores e regras que o código existente tenha sido projetado para buscar e interpretar (por exemplo, texto ou flag). Não corrige lógica Dart arbitrária, UI estrutural, plugin, asset ou código nativo. | Precisa de rede para receber valores novos; cache e valor padrão precisam de contrato explícito para o primeiro boot sem rede. Não há contrato de configuração remota implementado identificado nesta análise. | Pode aproveitar o backend existente, mas requer schema, autorização, versionamento, cache, auditoria e testes. Não implica custo de licença OTA; há custo de desenvolvimento e operação do backend. [API de registros][pb-records] |
| **Nova release/APK manual** | Dart, assets, Flutter, plugins e partes nativas, respeitando compatibilidade da plataforma. | O app funciona com o binário instalado quando offline; distribuir e instalar um novo APK exige um canal de entrega e conectividade ou transporte físico. | Sem serviço de Code Push, mas exige build, assinatura, distribuição, controle de versão nos tablets e suporte de campo. O canal atual ainda precisa ser confirmado. [Distribuição Android][android-distribution] |

**Conclusão funcional:** configuração remota é complementar para parâmetros operacionais versionados; não substitui correções de código. Shorebird cobre a maioria das correções Dart sem reinstalação, mas não elimina a necessidade de releases binárias. APK/release continua sendo o caminho para mudanças nativas, assets, SDK e recuperação quando o patch não puder ser recebido.

## Flavors e política release → patch

Shorebird atribui um `app_id` distinto a cada flavor; `shorebird release android --flavor staging` e o patch com o mesmo flavor ficam associados à release correspondente. A documentação também oferece *tracks* de distribuição para testar patches antes de promovê-los. [Flavors Android][shorebird-flavors] [Tracks][shorebird-tracks] Isso combina conceitualmente com `staging`/`production` do projeto, mas **a compatibilidade com os arquivos `env/*.local.json`, Flutter 3.47.7, assinatura e pipeline reais não foi testada**.

Proposta de política para uma tarefa futura: (1) criar e validar uma release base por flavor; (2) gerar patch somente a partir do código e da configuração daquela release; (3) verificar o diff para mudanças não patcháveis; (4) testar um patch sintético em `staging` e em tablet descartável; (5) registrar release, patch, flavor, SHA e resultado; (6) submeter a promoção de `production` ao gate humano. A FAQ do Shorebird confirma que valores de `dart-define`, inclusive `--dart-define-from-file`, **podem** mudar por patch. Uma troca do endpoint de backend exige, portanto, teste de roteamento, isolamento entre flavors e segurança antes da promoção; escolher nova release para essa troca é uma decisão operacional, não limitação da ferramenta. [FAQ de Dart defines][shorebird-faq] [Ambientes do projeto](../operations/ENVIRONMENTS.md)

## Operação offline, primeiro boot e rollback

- Um tablet recém-instalado e sem rede executará o binário base, não o último patch. Mesmo com rede, o padrão aplica o patch no próximo início do **processo**; reabrir apenas a Activity pode não bastar se o processo continuar vivo. [Atualização][shorebird-updates] [FAQ][shorebird-faq]
- A atualização do código não confirma nem sincroniza dados de negócio. Os fluxos de Hive/PocketBase devem continuar distinguindo pendente, falha e confirmação; um patch não deve redefinir formato local ou contrato de eventos sem migração compatível e teste de retomada. Esta é uma exigência do projeto, não uma garantia do fornecedor. [Arquitetura](../ARCHITECTURE.md)
- O rollback remoto impede novos downloads do patch e orienta o retorno para a versão anterior/base, mas depende do ciclo de atualização do dispositivo; para tablet offline ou processo permanente, é necessário um procedimento local de recuperação. [Rollback][shorebird-rollback] [Estratégias][shorebird-updates]

## Distribuição, conformidade e segurança

A documentação de Shorebird afirma compatibilidade com políticas das lojas e descreve restrições para código executável e mudanças enganosas. Isso **não comprova** aprovação para o canal de distribuição deste app nem dispensa avaliação das políticas atuais e dos termos do fornecedor antes da adoção. Se houver sideload, o processo de assinatura, origem do APK, atualização e suporte aos tablets precisa ser documentado separadamente; Shorebird não substitui esse canal da release base. [FAQ de conformidade][shorebird-faq]

Shorebird oferece assinatura opcional dos patches com chave própria inserida na release; sem a chave privada correspondente não é possível criar novos patches assinados para essa release. A chave requer custódia e recuperação planejadas, e credenciais de publicação devem ficar fora do repositório e dos tablets. [Assinatura de patch][shorebird-signing] Antes de escolher o serviço, avaliar ainda disponibilidade do CDN na rede de campo, proteção do canal, permissão de saída e procedimento de rollback em caso de falha. Nenhuma dessas capacidades foi verificada em dispositivo aqui.

## Recomendação e gate de adoção

**Recomendação:** manter o APK/release assinada como base obrigatória e avaliar Shorebird em um experimento isolado de `staging` para correções Dart. Usar configuração remota apenas para parâmetros que ganhem contrato, defaults seguros e autorização própria. Não integrar Shorebird nem publicar patch de produção nesta issue.

Antes de implementar, o mantenedor deve abrir/aprovar uma tarefa própria com: canal real de distribuição e quantidade de tablets; orçamento e termos atuais; matriz do que é patchável na versão Flutter do projeto; estratégia de assinatura e custódia; procedimento de release, patch, teste, rollback e recuperação offline; teste sintético nos dois flavors e em tablet não operacional; verificação de políticas da loja ou de sideload aplicáveis; critérios de go/no-go e responsável pela promoção. A arquitetura autoritativa e a integridade do sync permanecem gates separados.

## Fontes

Fontes externas oficiais consultadas em 15/10/2026; valores comerciais e políticas podem mudar. Os documentos internos descrevem o checkout, não provam comportamento em hardware ou serviço externo.

- [Shorebird — FAQ de Code Push][shorebird-faq]: tipos de mudança, release/patch e conformidade declarada pelo fornecedor.
- [Shorebird — Update Strategies][shorebird-updates], [Android Flavors][shorebird-flavors], [Tracks][shorebird-tracks], [Rollback][shorebird-rollback] e [Patch Signing][shorebird-signing]: operação de atualização, isolamento e segurança.
- [Shorebird — Pricing][shorebird-pricing]: planos e preço público no dia da consulta.
- [PocketBase — Records API][pb-records]: capacidade de leitura de registros; não comprova um contrato de configuração remota deste projeto.
- [Android Developers — distribuição com App Bundle][android-distribution]: mecanismo de distribuição Android, não evidência do canal usado pelo projeto.

[shorebird-faq]: https://docs.shorebird.dev/code-push/faq/
[shorebird-updates]: https://docs.shorebird.dev/code-push/update-strategies/
[shorebird-flavors]: https://docs.shorebird.dev/code-push/guides/flavors/android/
[shorebird-tracks]: https://docs.shorebird.dev/code-push/tracks/
[shorebird-rollback]: https://docs.shorebird.dev/code-push/rollback/
[shorebird-signing]: https://docs.shorebird.dev/code-push/guides/patch-signing/
[shorebird-pricing]: https://shorebird.dev/pricing/
[pb-records]: https://pocketbase.io/docs/api-records/
[android-distribution]: https://developer.android.com/guide/app-bundle
