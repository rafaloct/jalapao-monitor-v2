import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../theme/jalapao_theme.dart';

class PaxSelector extends StatefulWidget {
  final int maxPax;
  final int selectedCount;
  final ValueChanged<int> onChanged;
  final Color activeColor;
  final String label;

  const PaxSelector({
    super.key,
    this.maxPax = 30,
    required this.selectedCount,
    required this.onChanged,
    this.activeColor = JalapaoTheme.primary,
    this.label = 'Pessoas',
  });

  @override
  State<PaxSelector> createState() => _PaxSelectorState();
}

class _PaxSelectorState extends State<PaxSelector> {
  Timer? _holdTimer;

  void _startHold(int delta) {
    _holdTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      final next = (widget.selectedCount + delta).clamp(0, widget.maxPax);
      if (next != widget.selectedCount) widget.onChanged(next);
    });
  }

  void _stopHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Contador grande animado
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder:
              (child, anim) => ScaleTransition(scale: anim, child: child),
          child: Text(
            '${widget.selectedCount}',
            key: ValueKey(widget.selectedCount),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 56,
              color:
                  widget.selectedCount > 0
                      ? widget.activeColor
                      : JalapaoTheme.textSync.withOpacity(0.5),
            ),
          ),
        ),
        Text(
          widget.label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: JalapaoTheme.textSync.withOpacity(0.7),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        // Chips de atalho para valores comuns (1/2/4/10)
        _buildQuickChips(),
        const SizedBox(height: 16),
        // Botões −/+ com long-press para incremento rápido
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _HoldButton(
              icon: Icons.remove,
              color: widget.activeColor,
              onTap:
                  () => widget.onChanged(
                    (widget.selectedCount - 1).clamp(0, widget.maxPax),
                  ),
              onHoldStart: () => _startHold(-1),
              onHoldEnd: _stopHold,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '${widget.selectedCount} / ${widget.maxPax}',
                style: TextStyle(
                  fontSize: 13,
                  color: JalapaoTheme.textSync.withOpacity(0.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _HoldButton(
              icon: Icons.add,
              color: widget.activeColor,
              onTap:
                  () => widget.onChanged(
                    (widget.selectedCount + 1).clamp(0, widget.maxPax),
                  ),
              onHoldStart: () => _startHold(1),
              onHoldEnd: _stopHold,
            ),
          ],
        ),
      ],
    );
  }

  /// Chips de atalho para seleção rápida: 1, 2, 4, 10.
  /// Substitui a grade de N ícones que bloqueava o CTA em locais com alta capacidade.
  Widget _buildQuickChips() {
    final chips = [1, 2, 4, 10].where((v) => v <= widget.maxPax).toList();
    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: chips.map((v) {
        final bool selected = widget.selectedCount == v;
        return InkWell(
          onTap: () => widget.onChanged(v),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color:
                  selected
                      ? widget.activeColor.withOpacity(0.15)
                      : JalapaoTheme.textSync.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    selected
                        ? widget.activeColor
                        : JalapaoTheme.textSync.withOpacity(0.2),
                width: selected ? 2.0 : 1.0,
              ),
            ),
            child: Text(
              '$v',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color:
                    selected
                        ? widget.activeColor
                        : JalapaoTheme.textSync.withOpacity(0.7),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}


class _HoldButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  const _HoldButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPressStart: (_) => onHoldStart(),
      onLongPressEnd: (_) => onHoldEnd(),
      onLongPressCancel: onHoldEnd,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.35), width: 2),
        ),
        child: Icon(icon, color: color, size: 30),
      ),
    );
  }
}
