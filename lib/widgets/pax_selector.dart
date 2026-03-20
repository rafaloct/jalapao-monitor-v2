import 'dart:async';
import 'package:flutter/material.dart';
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
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Text(
            '${widget.selectedCount}',
            key: ValueKey(widget.selectedCount),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 48,
              color: widget.selectedCount > 0
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
        _buildPersonGrid(),
        const SizedBox(height: 16),
        // +/- com long-press para incremento rápido (grupos grandes)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _HoldButton(
              icon: Icons.remove,
              color: widget.activeColor,
              onTap: () => widget.onChanged(
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
              onTap: () => widget.onChanged(
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

  Widget _buildPersonGrid() {
    const int cols = 5;
    final int rows = (widget.maxPax / cols).ceil();

    return LayoutBuilder(
      builder: (context, constraints) {
        // cada item tem margin: horizontal(4) = 8px total por item
        final double itemSize =
            ((constraints.maxWidth - cols * 8) / cols).clamp(28.0, 44.0);

        return Column(
          children: List.generate(rows, (row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(cols, (col) {
                  final int index = row * cols + col + 1;
                  if (index > widget.maxPax) return SizedBox(width: itemSize);

                  final bool isSelected = index <= widget.selectedCount;

                  return GestureDetector(
                    onTap: () => widget.onChanged(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: itemSize,
                      height: itemSize,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? widget.activeColor.withOpacity(0.2)
                            : Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? widget.activeColor
                              : JalapaoTheme.textSync.withOpacity(0.2),
                          width: isSelected ? 3.0 : 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Center(
                        child: Text(
                          '👤',
                          style: TextStyle(fontSize: itemSize * 0.55),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        );
      },
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
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.35), width: 2),
        ),
        child: Icon(icon, color: color, size: 26),
      ),
    );
  }
}
