# PR #61 — evidência visual sintética

Capturas dos widgets reais em `3177ba70b5fe78b118df202dbbd2d9bc43f90dee`,
em 2026-10-13. Renderizadas com Flutter 3.47.7 e `flutter_test` a 1280 × 800
pixels, escala 1, usando providers e registros sintéticos. Nenhum backend,
tablet ou dado operacional foi acessado. Os quatro testes temporários de
captura passaram (4/4); o código dos harnesses não integra o PR.

| Tela | Captura |
| --- | --- |
| Seleção de local, com selo **Loja** | [Abrir PNG](01_session_selector_3177ba7_widget.png) |
| Dashboard do fervedouro | [Abrir PNG](dashboard_field_1280x800.png) |
| Chegada de grupo | [Abrir PNG](dashboard_new_group_dialog_1280x800.png) |
| Contador da loja | [Abrir PNG](counter_loja_field_1280x800.png) |
| Confirmação de chegada no contador | [Abrir PNG](counter_arrival_dialog_1280x800.png) |
| Reservas e aviso de check-in antigo | [Abrir PNG](04_reservas_lista_3177ba7_widget.png) |
| Entrada rápida | [Abrir PNG](05_reservas_entrada_rapida_3177ba7_widget.png) |
| Entrada rápida com 4 hóspedes | [Abrir PNG](06_reservas_pax_selecionado_3177ba7_widget.png) |
| Login do gestor | [Abrir PNG](02_gestor_login_3177ba7_widget.png) |
| Informação técnica do login | [Abrir PNG](03_gestor_login_hint_3177ba7_widget.png) |

Estas imagens mostram a renderização Flutter em teste de widget, não uma
captura do app executado no Android. `flutter_test` substitui a fonte sem família
explícita por Ahem; por isso o título e subtítulo do `ScreenHeader` aparecem
como blocos nas imagens de seleção de local e contador. Os demais textos usam
Outfit/Roboto e os ícones Material reais. Não avaliar esses dois cabeçalhos
pelas imagens de widget.

O E2E sintético no emulador do CI passou em
[run 38440992839](https://github.com/rafaloct/jalapao-monitor-v2/actions/runs/38440992839),
mas esse workflow só escreve marcadores `[SCREEN_CAPTURE]` no log; ele não
salva PNGs. A conferência de contraste em tablet e luz de campo continua no
aceite humano da issue #60.
