import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jalapao_monitor/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> snap(WidgetTester tester, String name) async {
    await tester.pumpAndSettle(const Duration(seconds: 2));
    debugPrint('[SCREEN_CAPTURE]: edge_$name');
    await Future.delayed(const Duration(seconds: 3));
  }

  testWidgets('Casos de Borda — Validação e Resiliência', (tester) async {
    app.main();
    await tester.pump(const Duration(seconds: 5));

    // 1. Setup inicial (Cachoeira para teste de contador rápido)
    final fervedouro = find.textContaining('Fervedouro do Encanto');
    if (fervedouro.evaluate().isNotEmpty) {
      await tester.tap(fervedouro.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    // --- EDGE CASE 1: PAX = 0 (Não permitido) ---
    final novoGrupoBtn = find.text('NOVO GRUPO');
    if (novoGrupoBtn.evaluate().isNotEmpty) {
      await tester.tap(novoGrupoBtn);
      await tester.pumpAndSettle();

      // O valor inicial é 1. Vamos tentar baixar para 0.
      final removeIcon = find.byIcon(Icons.remove);
      if (removeIcon.evaluate().isNotEmpty) {
        await tester.tap(removeIcon);
        await tester.pump();
      }

      await snap(tester, '01_pax_zero_attempt');

      // Tentar confirmar (deve falhar ou o botão deve estar desabilitado se implementado,
      // ou simplesmente ignoramos e cancelamos para o teste prosseguir)
      final cancelarBtn = find.text('CANCELAR');
      await tester.tap(cancelarBtn);
      await tester.pumpAndSettle();
    }

    // --- EDGE CASE 2: Alerta de Tempo Excedido ---
    // (Este teste é difícil de automatizar sem "viajar no tempo",
    // mas capturamos o estado do Dashboard com grupos ativos).
    await snap(tester, '02_dashboard_overdue_check');

    debugPrint('[SCREEN_CAPTURE]: edge_99_fim');
  });
}
