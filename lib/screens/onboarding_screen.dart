import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../providers/visit_provider.dart';

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
          backgroundColor: Colors.redAccent,
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
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  const Icon(Icons.water, size: 80, color: Color(0xFF58A6FF)),
                  const SizedBox(height: 12),
                  const Text(
                    'Jalapão Monitor',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configuração do Tablet',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 48),

                  // ── Tablet ID ──────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade800),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.tablet_android,
                              color: Color(0xFF58A6FF),
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ID DO TABLET',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade400,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _tabletIdController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: 'Ex: TAB-01',
                            hintStyle: TextStyle(color: Colors.grey.shade600),
                            filled: true,
                            fillColor: const Color(0xFF0D1117),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Os locais de monitoramento são cadastrados\npelo gestor e aparecem automaticamente.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
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
                        backgroundColor: const Color(0xFF238636),
                        foregroundColor: Colors.white,
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
