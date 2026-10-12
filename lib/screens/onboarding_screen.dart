import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../providers/visit_provider.dart';
import '../theme/jalapao_theme.dart';

/// Tela de configuração inicial — identifica o tablet com um ID único.
/// NÃO cria places: essa é responsabilidade exclusiva do gestor via Hub.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _tabletIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<VisitProvider>();
    if (provider.tabletId.isNotEmpty) {
      _tabletIdController.text = provider.tabletId;
    }
  }

  @override
  void dispose() {
    _tabletIdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final tabletId = _tabletIdController.text.trim();
    if (tabletId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite o ID deste Tablet (ex: TAB-01)'),
          backgroundColor: JalapaoTheme.danger,
        ),
      );
      return;
    }

    // Apenas identifica o tablet — places são gerenciados pelo gestor via Hub
    await context.read<VisitProvider>().saveConfig(
      atrativo: '',
      tabletId: tabletId,
      poolCapacity: 6,
      bathTimeMinutes: 20,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  const Icon(
                    Icons.water,
                    size: 80,
                    color: JalapaoTheme.primaryDeep,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Jalapão Monitor',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: JalapaoTheme.textPrimary,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configuração do Tablet',
                    style: TextStyle(
                      fontSize: 18,
                      color: JalapaoTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // ── Tablet ID ──────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: JalapaoTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: JalapaoTheme.outline,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.tablet_android,
                              color: JalapaoTheme.primaryDeep,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ID DO TABLET',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: JalapaoTheme.textMuted,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _tabletIdController,
                          style: const TextStyle(
                            color: JalapaoTheme.textPrimary,
                            fontSize: 22,
                          ),
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            hintText: 'Ex: TAB-01',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Os locais de monitoramento são cadastrados\npelo gestor e aparecem automaticamente.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: JalapaoTheme.textMuted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // ── Save Button ────────────────────────────────────
                  SizedBox(
                    width: 320,
                    height: 64,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.check_circle, size: 28),
                      label: const Text(
                        'SALVAR E INICIAR',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
