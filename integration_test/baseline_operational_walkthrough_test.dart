import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jalapao_monitor/main.dart' as app;

/// Credencial de teste do gestor — conta SINTÉTICA no PocketBase de teste,
/// passada via --dart-define. Sem valor padrão: se ausente, a seção do gestor
/// é pulada explicitamente (o PIN local de fallback foi removido na #24 —
/// nenhuma credencial é embutida no app nem nos testes).
const _testGestorEmail = String.fromEnvironment('TEST_GESTOR_EMAIL');
const _testGestorPassword = String.fromEnvironment('TEST_GESTOR_PASSWORD');

/// Helpers de navegação
Future<void> _voltarAoSelector(WidgetTester tester) async {
  final swapBtn = find.byIcon(Icons.swap_horiz);
  if (swapBtn.evaluate().isNotEmpty) {
    await tester.tap(swapBtn.first, warnIfMissed: false);
    await tester.pumpAndSettle();
    final trocarBtn = find.text('Trocar');
    if (trocarBtn.evaluate().isNotEmpty) {
      await tester.tap(trocarBtn.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> snap(WidgetTester tester, String name) async {
    // Usa pump finito em vez de pumpAndSettle para evitar loop infinito
    // causado pelo timer de SyncDown do PlaceProvider (30s).
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    debugPrint('[SCREEN_CAPTURE]: $name');
    await Future.delayed(const Duration(seconds: 3));
  }

  testWidgets('Jalapão Monitor — Full Walkthrough v2.2', (tester) async {
    app.main();
    await tester.pump(const Duration(seconds: 5));
    await snap(tester, '00_tela_inicial');

    // ══════════════════════════════════════════════════════════════════════════
    // A. ONBOARDING — apenas tabletId (refactor 1.10)
    // ══════════════════════════════════════════════════════════════════════════
    final onboardingFields = find.byType(TextField);
    if (onboardingFields.evaluate().isNotEmpty) {
      debugPrint('[STATE] Onboarding detectado');
      await tester.enterText(onboardingFields.at(0), 'TAB-01');
      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 500));
      await snap(tester, '01_onboarding_tablet_id');

      final saveBtn = find.text('SALVAR E INICIAR');
      if (saveBtn.evaluate().isNotEmpty) {
        await tester.ensureVisible(saveBtn.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(saveBtn.first);
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
      }
      await snap(tester, '02_pos_onboarding');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // B. SESSION SELECTOR — badges de ocupação em tempo real (item 1.5)
    // ══════════════════════════════════════════════════════════════════════════
    final selectorHeader = find.text('SELECIONAR LOCAL DE MONITORAMENTO');
    if (selectorHeader.evaluate().isNotEmpty) {
      debugPrint('[STATE] SessionSelectorScreen detectado');
      await snap(tester, '03_session_selector_com_badges');

      // ── B1. CounterScreen — Cachoeira da Formiga ──────────────────────────
      final cachoeira = find.textContaining('Cachoeira');
      if (cachoeira.evaluate().isNotEmpty) {
        await tester.tap(cachoeira.first);
        await tester.pump(const Duration(seconds: 3));
        await snap(tester, '04_counter_cachoeira_principal');

        // B1a: Botão CHEGOU → dialog com nome + cidade (item 3.6)
        final chegouBtn = find.textContaining('CHEGOU');
        if (chegouBtn.evaluate().isNotEmpty) {
          await tester.tap(chegouBtn.first);
          await tester.pumpAndSettle(const Duration(seconds: 1));
          await snap(tester, '05_counter_dialog_registro');

          // Preencher nome do grupo e cidade de origem
          final dialogFields = find.byType(TextField);
          if (dialogFields.evaluate().length >= 2) {
            await tester.enterText(dialogFields.at(0), 'Grupo Teste');
            await tester.pump(const Duration(milliseconds: 200));
            await tester.enterText(dialogFields.at(1), 'Brasilia');
            await tester.pump(const Duration(milliseconds: 200));
          }
          await snap(tester, '06_counter_dialog_com_nome_cidade');

          // Confirmar chegada
          final confirmarCounter = find.text('REGISTRAR');
          if (confirmarCounter.evaluate().isNotEmpty) {
            await tester.tap(confirmarCounter.first, warnIfMissed: false);
            await tester.pumpAndSettle(const Duration(seconds: 2));
          } else {
            await tester.tapAt(const Offset(10, 10));
            await tester.pumpAndSettle();
          }
        }
        await snap(tester, '07_counter_apos_registro');

        // B1b: Voltar ao SessionSelector
        await _voltarAoSelector(tester);
      }
      await tester.pump(const Duration(seconds: 2));

      // ── B2. PlaceReservationScreen — Pousada Jalapão Dreams ───────────────
      final pousada = find.textContaining('Pousada');
      if (pousada.evaluate().isNotEmpty) {
        await tester.tap(pousada.first);
        await tester.pump(const Duration(seconds: 3));
        await snap(tester, '08_reservas_pousada_lista');

        // Dialog ENTRADA RÁPIDA com nome e cidade
        final quickBtn = find.textContaining('ENTRADA RÁPIDA');
        if (quickBtn.evaluate().isNotEmpty) {
          await tester.tap(quickBtn.first);
          await tester.pumpAndSettle(const Duration(seconds: 1));
          await snap(tester, '09_reservas_dialog_entrada_rapida');

          final qFields = find.byType(TextField);
          if (qFields.evaluate().length >= 2) {
            await tester.enterText(qFields.at(0), 'Visitante Rapido');
            await tester.pump(const Duration(milliseconds: 200));
            await tester.enterText(qFields.at(1), 'Goiania');
            await tester.pump(const Duration(milliseconds: 200));
          }
          await snap(tester, '10_reservas_entrada_rapida_preenchida');
          final cancelBtn = find.text('CANCELAR');
          if (cancelBtn.evaluate().isNotEmpty) {
            await tester.tap(cancelBtn.first);
            await tester.pumpAndSettle();
          }
        }

        // Dialog NOVA RESERVA COM HORÁRIO + cidade de origem
        final novaReservaBtn = find.textContaining('NOVA RESERVA');
        if (novaReservaBtn.evaluate().isNotEmpty) {
          await tester.tap(novaReservaBtn.first);
          await tester.pumpAndSettle(const Duration(seconds: 1));
          await snap(tester, '11_reservas_dialog_nova_reserva');

          final nrFields = find.byType(TextField);
          if (nrFields.evaluate().isNotEmpty) {
            // Preencher hóspede e cidade
            await tester.enterText(nrFields.at(0), 'Familia Teste');
            await tester.pump(const Duration(milliseconds: 200));
          }
          await snap(tester, '12_reservas_nova_reserva_preenchida');
          final cancelBtn = find.text('CANCELAR');
          if (cancelBtn.evaluate().isNotEmpty) {
            await tester.tap(cancelBtn.first);
            await tester.pumpAndSettle();
          }
        }

        // Voltar ao SessionSelector
        await _voltarAoSelector(tester);
      }
      await tester.pump(const Duration(seconds: 2));

      // ── B3. DashboardScreen — Fervedouro da Ceiça ────────────────────────
      final fervedouro = find.textContaining('Fervedouro');
      if (fervedouro.evaluate().isNotEmpty) {
        await tester.tap(fervedouro.first);
        await tester.pump(const Duration(seconds: 3));
        await snap(tester, '13_dashboard_fervedouro_inicial');
      }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // C. DASHBOARD — fluxo completo fila→água→saída + nome/cidade (items 1.3, 3.6)
    // ══════════════════════════════════════════════════════════════════════════
    final novoGrupoBtn = find.text('NOVO GRUPO');
    if (novoGrupoBtn.evaluate().isNotEmpty) {
      debugPrint('[STATE] DashboardScreen — fluxo de água');
      await snap(tester, '14_dashboard_visao_geral');

      // C1: Dialog NOVO GRUPO — com nome e cidade
      await tester.tap(novoGrupoBtn.first);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await snap(tester, '15_dashboard_dialog_chegada_vazio');

      // Preencher nome e cidade
      final chegadaFields = find.byType(TextField);
      if (chegadaFields.evaluate().length >= 2) {
        await tester.enterText(chegadaFields.at(0), 'Grupo Ipê Dourado');
        await tester.pump(const Duration(milliseconds: 200));
        await tester.enterText(chegadaFields.at(1), 'São Paulo');
        await tester.pump(const Duration(milliseconds: 200));
      }
      // Ajustar pax via +
      final addPaxBtn = find.byIcon(Icons.add);
      if (addPaxBtn.evaluate().isNotEmpty) {
        await tester.tap(addPaxBtn.first);
        await tester.pump(const Duration(milliseconds: 150));
        await tester.tap(addPaxBtn.first);
        await tester.pump(const Duration(milliseconds: 150));
      }
      await snap(tester, '16_dashboard_dialog_chegada_preenchido');

      final confirmarBtn = find.text('CONFIRMAR FILA');
      if (confirmarBtn.evaluate().isNotEmpty) {
        await tester.ensureVisible(confirmarBtn.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(confirmarBtn.first);
        await tester.pumpAndSettle();
      } else {
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      }
      await snap(tester, '17_dashboard_grupo_na_fila');

      // C2: Toca no card da fila → dialog ENTRAR NA ÁGUA
      final paxCard = find.textContaining('PAX');
      if (paxCard.evaluate().isNotEmpty) {
        await tester.tap(paxCard.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await snap(tester, '18_dashboard_dialog_entrar_agua');

        final addBtnWater = find.byIcon(Icons.add).last;
        if (addBtnWater.evaluate().isNotEmpty) {
          await tester.tap(addBtnWater);
          await tester.pump(const Duration(milliseconds: 200));
        }
        final entrarAguaBtn = find.text('ENTRAR NA ÁGUA');
        if (entrarAguaBtn.evaluate().isNotEmpty) {
          await tester.tap(entrarAguaBtn.first);
          await tester.pumpAndSettle();
        } else {
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();
        }
      }
      await snap(tester, '19_dashboard_grupo_na_agua_timer');

      // C3: Dialog SAÍDA DO BANHO
      final banhistaCard = find.textContaining('banhista');
      if (banhistaCard.evaluate().isNotEmpty) {
        await tester.tap(banhistaCard.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await snap(tester, '20_dashboard_dialog_saida_banho');
        final cancelSaida = find.text('CANCELAR');
        if (cancelSaida.evaluate().isNotEmpty) {
          await tester.tap(cancelSaida.first);
          await tester.pumpAndSettle();
        }
      }

      // C4: Indicador de capacidade (item 1.6) — long press → dialog ajuste
      final capacityCounter = find.textContaining(' / ');
      if (capacityCounter.evaluate().isNotEmpty) {
        await tester.longPress(capacityCounter.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await snap(tester, '21_dashboard_dialog_capacidade');
        final cancelCap = find.text('CANCELAR');
        if (cancelCap.evaluate().isNotEmpty) {
          await tester.tap(cancelCap.first);
          await tester.pumpAndSettle();
        }
      }

      // C5: PlaceVisitsScreen — histórico do local (ícone people_rounded)
      final placeVisitsIcon = find.byIcon(Icons.people_rounded);
      if (placeVisitsIcon.evaluate().isNotEmpty) {
        await tester.tap(placeVisitsIcon.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await snap(tester, '22_place_visits_screen');
        final backBtn = find.byIcon(Icons.arrow_back);
        if (backBtn.evaluate().isNotEmpty) {
          await tester.tap(backBtn.first);
        } else {
          await tester.tapAt(const Offset(10, 10));
        }
        await tester.pumpAndSettle();
      }

      // C6: HistoryScreen — histórico geral (ícone history)
      final historyIcon = find.byIcon(Icons.history);
      if (historyIcon.evaluate().isNotEmpty) {
        await tester.tap(historyIcon.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await snap(tester, '23_history_screen');
        final backBtn = find.byIcon(Icons.arrow_back);
        if (backBtn.evaluate().isNotEmpty) {
          await tester.tap(backBtn.first);
        } else {
          await tester.tapAt(const Offset(10, 10));
        }
        await tester.pumpAndSettle();
      }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // D. PLACE RESERVATION — fluxo completo com nome e cidade
    // ══════════════════════════════════════════════════════════════════════════
    final reservasHeader = find.textContaining('RESERVAS');
    if (reservasHeader.evaluate().isNotEmpty) {
      debugPrint('[STATE] PlaceReservationScreen');
      await snap(tester, '24_reservas_principal');

      // D1: ENTRADA RÁPIDA — preenche nome e cidade
      final quickEntryBtn = find.textContaining('ENTRADA RÁPIDA');
      if (quickEntryBtn.evaluate().isNotEmpty) {
        await tester.tap(quickEntryBtn.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await snap(tester, '25_reservas_dialog_entrada_rapida');

        final qFields = find.byType(TextField);
        if (qFields.evaluate().length >= 2) {
          await tester.enterText(qFields.at(0), 'Grupo Veredas');
          await tester.pump(const Duration(milliseconds: 200));
          await tester.enterText(qFields.at(1), 'Curitiba');
          await tester.pump(const Duration(milliseconds: 200));
        }
        await snap(tester, '26_reservas_entrada_rapida_com_dados');
        final cancelBtn = find.text('CANCELAR');
        if (cancelBtn.evaluate().isNotEmpty) {
          await tester.tap(cancelBtn.first);
          await tester.pumpAndSettle();
        }
      }

      // D2: NOVA RESERVA — preenche nome e cidade
      final novaReservaBtn = find.textContaining('NOVA RESERVA');
      if (novaReservaBtn.evaluate().isNotEmpty) {
        await tester.tap(novaReservaBtn.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await snap(tester, '27_reservas_dialog_nova_reserva');

        final nrFields = find.byType(TextField);
        if (nrFields.evaluate().isNotEmpty) {
          await tester.enterText(nrFields.at(0), 'Casal Teste');
          await tester.pump(const Duration(milliseconds: 200));
        }
        await snap(tester, '28_reservas_nova_reserva_preenchida');
        final cancelBtn = find.text('CANCELAR');
        if (cancelBtn.evaluate().isNotEmpty) {
          await tester.tap(cancelBtn.first);
          await tester.pumpAndSettle();
        }
      }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // E. COUNTER SCREEN — se chegar por aqui diretamente
    // ══════════════════════════════════════════════════════════════════════════
    final registrarHeader = find.text('REGISTRAR CHEGADA');
    if (registrarHeader.evaluate().isNotEmpty) {
      debugPrint('[STATE] CounterScreen detectado');
      await snap(tester, '29_counter_principal');

      final chegouBtnCounter = find.textContaining('CHEGOU');
      if (chegouBtnCounter.evaluate().isNotEmpty) {
        await tester.tap(chegouBtnCounter.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await snap(tester, '30_counter_dialog_registro');
        final cFields = find.byType(TextField);
        if (cFields.evaluate().length >= 2) {
          await tester.enterText(cFields.at(0), 'Grupo Mangaba');
          await tester.pump(const Duration(milliseconds: 200));
          await tester.enterText(cFields.at(1), 'Palmas');
          await tester.pump(const Duration(milliseconds: 200));
        }
        await snap(tester, '31_counter_dialog_preenchido');
        final cancelC = find.text('CANCELAR');
        if (cancelC.evaluate().isNotEmpty) {
          await tester.tap(cancelC.first);
          await tester.pumpAndSettle();
        }
      }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // F. GESTOR SCREEN — login, 3 abas, PlaceFormScreen, logout
    // ══════════════════════════════════════════════════════════════════════════
    // F0: resetar para o SessionSelector antes de buscar ícone admin
    await _voltarAoSelector(tester);

    final adminIcon = find.byIcon(Icons.admin_panel_settings);
    if (adminIcon.evaluate().isNotEmpty) {
      await tester.tap(adminIcon.first, warnIfMissed: false);
      // Poll até TextFormField aparecer — Navigator.push pode demorar em CI
      var loginFields = find.byType(TextFormField);
      for (int i = 0; i < 10 && loginFields.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        loginFields = find.byType(TextFormField);
      }
      // Diagnóstico: distingue credencial vazia de campo de login ausente
      debugPrint(
        '[GESTOR] loginFields=${loginFields.evaluate().length} '
        'email=${_testGestorEmail.isEmpty ? "<vazio>" : "ok"} '
        'password=${_testGestorPassword.isEmpty ? "<vazio>" : "ok"}',
      );
      if (loginFields.evaluate().isNotEmpty &&
          _testGestorEmail.isNotEmpty &&
          _testGestorPassword.isNotEmpty) {
        await snap(tester, '32_gestor_login');

        await tester.enterText(loginFields.at(0), _testGestorEmail);
        await tester.enterText(loginFields.at(1), _testGestorPassword);
        await tester.tapAt(const Offset(10, 10));
        await tester.pump(const Duration(milliseconds: 300));
        final entrarBtn = find.text('ENTRAR');
        await tester.ensureVisible(entrarBtn.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(entrarBtn.first, warnIfMissed: false);
        await tester.pumpAndSettle(const Duration(seconds: 4));

        final pendentesTab = find.text('PENDENTES');
        if (pendentesTab.evaluate().isNotEmpty) {
          await snap(tester, '33_gestor_tab_pendentes');

          // Aba ATIVOS — lista de visitas ativas
          await tester.tap(find.text('ATIVOS').first);
          await tester.pumpAndSettle(const Duration(seconds: 1));
          await snap(tester, '34_gestor_tab_ativos');

          // Aba MONITORAR — mapa / visão geral
          await tester.tap(find.text('MONITORAR').first);
          await tester.pump(const Duration(seconds: 2));
          await snap(tester, '35_gestor_tab_monitorar');

          // FAB "Novo Local" → PlaceFormScreen
          final fabNovoLocal = find.byIcon(Icons.add_location_alt);
          if (fabNovoLocal.evaluate().isNotEmpty) {
            await tester.tap(fabNovoLocal.first, warnIfMissed: false);
            await tester.pump(const Duration(seconds: 2));
            await snap(tester, '36_gestor_place_form');

            // Preencher campos do formulário de local
            final placeFields = find.byType(TextFormField);
            if (placeFields.evaluate().isNotEmpty) {
              await tester.enterText(placeFields.at(0), 'Novo Atrativo Teste');
              await tester.pump(const Duration(milliseconds: 200));
            }
            await snap(tester, '37_gestor_place_form_preenchido');

            final backBtnForm = find.byIcon(Icons.arrow_back);
            if (backBtnForm.evaluate().isNotEmpty) {
              await tester.tap(backBtnForm.first, warnIfMissed: false);
            }
            await tester.pump(const Duration(seconds: 1));
          }

          // Logout
          final logoutIcon = find.byIcon(Icons.logout);
          if (logoutIcon.evaluate().isNotEmpty) {
            await tester.tap(logoutIcon.first, warnIfMissed: false);
            await tester.pump(const Duration(seconds: 1));
            final confirmarSair = find.text('Sair');
            if (confirmarSair.evaluate().isNotEmpty) {
              await tester.tap(confirmarSair.first, warnIfMissed: false);
              await tester.pump(const Duration(seconds: 1));
            }
          }
          await snap(tester, '38_pos_logout_session_selector');
        } else {
          // Credencial sintética FOI fornecida — rejeição ou indisponibilidade
          // não é skip, é falha (#24: seção do gestor nunca confirma em verde).
          final backBtn = find.byType(BackButton);
          if (backBtn.evaluate().isNotEmpty) {
            await tester.tap(backBtn.first);
          }
          await tester.pump(const Duration(seconds: 1));
          fail(
            'Login do gestor falhou com credencial sintética fornecida — '
            'backend offline ou credencial recusada.',
          );
        }
      } else {
        // #24: sem credencial sintética o walkthrough NÃO pode fingir cobertura
        // do fluxo de autenticação — falha explicitamente em vez de reportar verde.
        fail(
          'Seção do gestor sem credencial de teste: defina '
          '--dart-define=TEST_GESTOR_EMAIL e --dart-define=TEST_GESTOR_PASSWORD '
          'apontando para conta sintética do PocketBase de teste.',
        );
      }
    }

    debugPrint('[SCREEN_CAPTURE]: 99_fim_walkthrough');
    await Future.delayed(const Duration(seconds: 2));
    debugPrint('Walkthrough v2.2 finalizado — ${DateTime.now()}');
  });
}
