import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jalapao_monitor/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Sinaliza ao script PowerShell via stdout para tirar um screenshot ADB.
  Future<void> snap(WidgetTester tester, String name) async {
    await tester.pumpAndSettle(const Duration(seconds: 2));
    debugPrint('[SCREEN_CAPTURE]: $name');
    await Future.delayed(const Duration(seconds: 3));
  }

  testWidgets('Jalapão Monitor — Captura de Telas por Fluxo', (tester) async {
    app.main();
    await tester.pump(const Duration(seconds: 5));
    // Snapshot incondicional — diagnóstico: mostra exatamente qual tela abriu
    await snap(tester, '00_tela_inicial');

    // ── 1. Detectar tela inicial ─────────────────────────────────────────────
    // O HomeRouter pode mostrar OnboardingScreen, SessionSelectorScreen,
    // DashboardScreen, PlaceReservationScreen ou CounterScreen.

    // ── A. ONBOARDING ────────────────────────────────────────────────────────
    // Onboarding usa TextField (não TextFormField)
    final onboardingFields = find.byType(TextField);
    if (onboardingFields.evaluate().isNotEmpty) {
      debugPrint('[STATE] Onboarding detectado');

      // Campo nome (primeiro TextField)
      await tester.enterText(onboardingFields.at(0), 'Fervedouro do Ceiça');
      // Campo tablet ID (segundo TextField)
      await tester.enterText(onboardingFields.at(1), 'TAB-01');
      // Fechar teclado tocando fora dos campos
      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 500));
      // Screenshot com campos preenchidos e teclado fechado
      await snap(tester, '01_onboarding');

      // Botão "SALVAR E INICIAR" — scroll para tornar visível antes de tocar
      final saveBtn = find.text('SALVAR E INICIAR');
      if (saveBtn.evaluate().isNotEmpty) {
        await tester.ensureVisible(saveBtn.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(saveBtn.first);
        // Aguarda sync PocketBase + HomeRouter redirecionar (rede real, precisa de tempo)
        for (int i = 0; i < 12; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
      }
      await snap(tester, '02_pos_onboarding');
    }

    // ── B. SESSION SELECTOR ──────────────────────────────────────────────────
    final selectorHeader = find.text('SELECIONAR LOCAL DE MONITORAMENTO');
    if (selectorHeader.evaluate().isNotEmpty) {
      debugPrint('[STATE] SessionSelectorScreen detectado');
      await snap(tester, '03_session_selector');

      // ── B1. CounterScreen — seleciona Cachoeira ─────────────────────────
      final cachoeira = find.textContaining('Cachoeira');
      if (cachoeira.evaluate().isNotEmpty) {
        await tester.tap(cachoeira.first);
        await tester.pump(const Duration(seconds: 3));
        await snap(tester, '04_counter_cachoeira');
        // Voltar via botão swap_horiz → confirmar dialog
        final swapBtn = find.byIcon(Icons.swap_horiz);
        if (swapBtn.evaluate().isNotEmpty) {
          await tester.tap(swapBtn.first, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 500));
          final trocarBtn = find.text('Trocar');
          if (trocarBtn.evaluate().isNotEmpty) {
            await tester.tap(trocarBtn.first);
            await tester.pump(const Duration(seconds: 3));
          }
        }
      }

      // Aguarda SessionSelector reaparecer
      await tester.pump(const Duration(seconds: 2));

      // ── B2. PlaceReservationScreen — seleciona Pousada ──────────────────
      final pousada = find.textContaining('Pousada Jalapão');
      if (pousada.evaluate().isNotEmpty) {
        await tester.tap(pousada.first);
        await tester.pump(const Duration(seconds: 3));
        await snap(tester, '05_reservas_pousada');
        // Abrir dialog ENTRADA RÁPIDA
        final quickBtn = find.textContaining('ENTRADA RÁPIDA');
        if (quickBtn.evaluate().isNotEmpty) {
          await tester.tap(quickBtn.first);
          await tester.pump(const Duration(seconds: 1));
          await snap(tester, '06_reservas_dialog_entrada_rapida');
          final cancelBtn = find.text('CANCELAR');
          if (cancelBtn.evaluate().isNotEmpty) {
            await tester.tap(cancelBtn.first);
            await tester.pump();
          }
        }
        // Voltar via swap_horiz
        final swapBtn = find.byIcon(Icons.swap_horiz);
        if (swapBtn.evaluate().isNotEmpty) {
          await tester.tap(swapBtn.first);
          await tester.pump();
          // Confirmar dialog de troca
          final trocarBtn = find.text('Trocar');
          if (trocarBtn.evaluate().isNotEmpty) {
            await tester.tap(trocarBtn.first);
            await tester.pump(const Duration(seconds: 2));
          }
        }
      }

      // Aguarda SessionSelector reaparecer
      await tester.pump(const Duration(seconds: 2));

      // ── B3. DashboardScreen — seleciona Fervedouro ──────────────────────
      final fervedouro = find.textContaining('Fervedouro da Ceiça');
      if (fervedouro.evaluate().isNotEmpty) {
        await tester.tap(fervedouro.first);
        await tester.pump(const Duration(seconds: 3));
        await snap(tester, '07_dashboard_fervedouro');
      }
    }

    // ── C. DASHBOARD SCREEN (fervedouro) ─────────────────────────────────────
    // Identificado pelo botão principal "NOVO GRUPO" na coluna da fila
    final chegadaBtn = find.text('NOVO GRUPO');
    if (chegadaBtn.evaluate().isNotEmpty) {
      debugPrint('[STATE] DashboardScreen (fervedouro) detectado');
      await snap(tester, '05_dashboard_fervedouro');

      // Abrir dialog de chegada de grupo
      await tester.tap(chegadaBtn.first);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await snap(tester, '06_dashboard_dialog_chegada');

      // Fechar dialog
      final cancelBtn = find.text('CANCELAR');
      if (cancelBtn.evaluate().isNotEmpty) {
        await tester.tap(cancelBtn.first);
        await tester.pumpAndSettle();
      } else {
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      }
    }

    // ── D. PLACE RESERVATION SCREEN (pousada/restaurante/fazenda/chácaras) ───
    // Identificado pelo cabeçalho '🗓 RESERVAS'
    final reservasHeader = find.textContaining('RESERVAS');
    if (reservasHeader.evaluate().isNotEmpty) {
      debugPrint('[STATE] PlaceReservationScreen detectado');
      await snap(tester, '07_reservas_principal');

      // Abrir dialog de ENTRADA RÁPIDA
      final quickEntryBtn = find.textContaining('ENTRADA RÁPIDA');
      if (quickEntryBtn.evaluate().isNotEmpty) {
        await tester.tap(quickEntryBtn.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await snap(tester, '08_reservas_dialog_entrada_rapida');

        final cancelBtn = find.text('CANCELAR');
        if (cancelBtn.evaluate().isNotEmpty) {
          await tester.tap(cancelBtn.first);
          await tester.pumpAndSettle();
        } else {
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();
        }
      }

      // Abrir dialog de NOVA RESERVA COM HORÁRIO
      final novaReservaBtn = find.textContaining('NOVA RESERVA');
      if (novaReservaBtn.evaluate().isNotEmpty) {
        await tester.tap(novaReservaBtn.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await snap(tester, '09_reservas_dialog_nova_reserva');

        final cancelBtn = find.text('CANCELAR');
        if (cancelBtn.evaluate().isNotEmpty) {
          await tester.tap(cancelBtn.first);
          await tester.pumpAndSettle();
        } else {
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();
        }
      }
    }

    // ── E. COUNTER SCREEN (cachoeira/atrativo_cultural/camping/loja) ─────────
    // Identificado pelo painel 'REGISTRAR CHEGADA'
    final registrarHeader = find.text('REGISTRAR CHEGADA');
    if (registrarHeader.evaluate().isNotEmpty) {
      debugPrint('[STATE] CounterScreen detectado');
      await snap(tester, '10_counter_principal');
    }

    // ── F. GESTOR LOGIN (navegação manual) ────────────────────────────────────
    // Ícone de admin está presente em todas as telas principais
    final adminIcon = find.byIcon(Icons.admin_panel_settings);
    if (adminIcon.evaluate().isNotEmpty) {
      await tester.tap(adminIcon.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verifica se abriu a tela de login do gestor
      final emailField = find.byType(TextFormField);
      if (emailField.evaluate().isNotEmpty) {
        await snap(tester, '11_gestor_login');
        // Voltar sem logar
        final backBtn = find.byType(BackButton);
        if (backBtn.evaluate().isNotEmpty) {
          await tester.tap(backBtn.first);
        } else {
          await tester.pageBack();
        }
        await tester.pumpAndSettle();
      }
    }

    debugPrint('[SCREEN_CAPTURE]: 99_fim_captura');
    await Future.delayed(const Duration(seconds: 2));
    debugPrint('Fluxo de captura finalizado.');
  });
}
