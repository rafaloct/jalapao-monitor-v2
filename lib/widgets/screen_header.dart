import 'package:material_ui/material_ui.dart';

import '../models/place.dart';
import '../theme/jalapao_theme.dart';
import '../theme/place_type_style.dart';

/// Cabeçalho compacto (56dp) compartilhado pelas telas operacionais.
///
/// Em tablet landscape o topo é espaço nobre: título + seletor inline,
/// badge de sync integrado e ações com alvo ≥ 48dp (issue #60, item 4).
class ScreenHeader extends StatelessWidget implements PreferredSizeWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.center,
  });

  static const double height = 56;

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? center;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: JalapaoTheme.background,
        border: Border(bottom: BorderSide(color: JalapaoTheme.outline)),
      ),
      child: Row(
        children: [
          if (leading != null) leading!,
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle(
                  style: const TextStyle(
                    color: JalapaoTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: title,
                ),
                if (subtitle != null)
                  DefaultTextStyle(
                    style: const TextStyle(
                      color: JalapaoTheme.textMuted,
                      fontSize: 11,
                      letterSpacing: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: subtitle!,
                  ),
              ],
            ),
          ),
          if (center != null) ...[const SizedBox(width: 8), center!],
          const SizedBox(width: 8),
          ...actions,
        ],
      ),
    );
  }
}

/// Seletor de local slim: um botão de 48dp que abre um menu — substitui o
/// `DropdownButton` largo com `keyboard_arrow_down` de 24px.
class PlaceSelectorButton extends StatelessWidget {
  const PlaceSelectorButton({
    super.key,
    required this.places,
    required this.selected,
    required this.onSelected,
  });

  final List<Place> places;
  final Place? selected;
  final ValueChanged<Place> onSelected;

  @override
  Widget build(BuildContext context) {
    final current = selected;
    return PopupMenuButton<Place>(
      tooltip: 'Selecionar local',
      onSelected: onSelected,
      itemBuilder: (_) => places
          .map(
            (p) => PopupMenuItem<Place>(
              value: p,
              height: JalapaoTheme.minTouch,
              child: Row(
                children: [
                  Icon(
                    PlaceTypeStyle.icon(p.type),
                    color: PlaceTypeStyle.color(p.type),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        constraints: const BoxConstraints(minHeight: JalapaoTheme.minTouch),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: JalapaoTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: JalapaoTheme.outline, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (current != null)
              Icon(
                PlaceTypeStyle.icon(current.type),
                color: PlaceTypeStyle.color(current.type),
                size: 22,
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                current?.name ?? 'Nenhum local ativo',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: JalapaoTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            const Icon(
              Icons.expand_more,
              color: JalapaoTheme.textMuted,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge de sincronização integrado ao header: ícone + contagem pendente.
class SyncBadge extends StatelessWidget {
  const SyncBadge({
    super.key,
    required this.pending,
    required this.hasError,
    required this.onTap,
    this.tooltip,
  });

  final int pending;
  final bool hasError;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final color = hasError ? JalapaoTheme.warn : JalapaoTheme.secondaryDeep;
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip ?? (hasError ? 'Erro de sync' : 'Sincronizar'),
      icon: Badge(
        isLabelVisible: pending > 0,
        backgroundColor: JalapaoTheme.danger,
        textColor: JalapaoTheme.onPrimary,
        label: Text('$pending'),
        child: Icon(
          hasError ? Icons.cloud_off : Icons.cloud_sync,
          color: color,
        ),
      ),
    );
  }
}

/// Ícone de pessoas com contador — substitui `List.generate(paxQty, 👤)`.
class PaxCount extends StatelessWidget {
  const PaxCount({
    super.key,
    required this.count,
    this.color = JalapaoTheme.textPrimary,
    this.size = 28,
  });

  final int count;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.person, color: color, size: size),
        const SizedBox(width: 4),
        Text(
          '×$count',
          style: TextStyle(
            color: color,
            fontSize: size * 0.8,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
