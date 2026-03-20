import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jalapao_monitor/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Sinaliza ao script PowerShell via stdout para tirar um screenshot ADB.
  Future<void> snap(WidgetTester tester, String name) async {
    await tester.pumpAndSettle(const Duration(seconds: 2));
    debugPrint('[SCREEN_CAPTURE]: peak_$name');
    await Future.delayed(const Duration(seconds: 3));
  }

  /// Helper para adicionar grupo no Dashboard
  Future<void> addGroup(WidgetTester tester, int pax) async {
    final novoGrupoBtn = find.text('NOVO GRUPO');
    expect(novoGrupoBtn, findsOneWidget);
    await tester.tap(novoGrupoBtn);
    await tester.pumpAndSettle();

    // No PaxSelectorDialog, incrementar até o valor desejado
    // O valor inicial agora é 1 (Item 1.3 do plano)
    // Usa .last para pegar o botão + do PaxSelector (não o do NOVO GRUPO, que está atrás do dialog)
    for (int i = 1; i < pax; i++) {
      final addIcon = find.byIcon(Icons.add).last;
      await tester.tap(addIcon);
      await tester.pump(const Duration(milliseconds: 100));
    }

    final confirmarBtn = find.text('CONFIRMAR FILA');
    await tester.ensureVisible(confirmarBtn.first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(confirmarBtn.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  testWidgets('Cenário de Pico — Simulação de Lotação Progressiva', (tester) async {
    app.main();
    await tester.pump(const Duration(seconds: 5));

    // 1. Setup inicial (Onboarding se necessário)
    // Após refactor 1.10: apenas 1 TextField (tabletId)
    final onboardingFields = find.byType(TextField);
    if (onboardingFields.evaluate().isNotEmpty) {
      await tester.enterText(onboardingFields.at(0), 'TEST-PEAK');
      await tester.tapAt(const Offset(10, 10)); // fechar teclado
      await tester.pumpAndSettle();
      await tester.tap(find.text('SALVAR E INICIAR'));
      // Aguarda redirecionamento
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    // 2. Seleção de Sessão
    final fervedouro = find.textContaining('Fervedouro do Encanto');
    if (fervedouro.evaluate().isNotEmpty) {
      await tester.ensureVisible(fervedouro.first);
      await tester.tap(fervedouro.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    // --- ESTADO 0: Vazio ---
    await snap(tester, '00_vazio');

    // --- ESTADO 1: 50% (3 pessoas de 6) ---
    await addGroup(tester, 3);
    await snap(tester, '01_50pct');

    // --- ESTADO 2: 83% (Alerta Amarelo - 5/6 pessoas) ---
    await addGroup(tester, 2);
    await snap(tester, '02_83pct_alerta_amarelo');

    // --- ESTADO 3: 100% (Alerta Vermelho - 6/6 pessoas) ---
    await addGroup(tester, 1);
    await snap(tester, '03_100pct_lotado');

    // --- ESTADO 4: 133% (Capacidade Excedida - 8/6 pessoas) ---
    await addGroup(tester, 2);
    await snap(tester, '04_133pct_excedido');

    debugPrint('[SCREEN_CAPTURE]: peak_99_fim');
    await Future.delayed(const Duration(seconds: 2));
  });
}
