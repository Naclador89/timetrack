import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

/// An overview tile on Today: a figure with a line of context; tapping it
/// grows the tile into [openBuilder]'s screen (container transform). With
/// a mouse it lifts a little on hover.
class DashboardTile extends StatefulWidget {
  /// Creates a tile.
  const DashboardTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.openBuilder,
    this.valueColor,
    this.badge,
    this.subtitle,
    this.footer,
  });

  /// The tile's symbol.
  final IconData icon;

  /// What the figure is.
  final String title;

  /// The figure.
  final String value;

  /// The figure's colour (plus/minus); `onSurface` without.
  final Color? valueColor;

  /// Shown after the figure, e.g. the time account zone.
  final Widget? badge;

  /// One line of context below the figure.
  final String? subtitle;

  /// A bar or chart at the bottom.
  final Widget? footer;

  /// The detail screen.
  final WidgetBuilder openBuilder;

  @override
  State<DashboardTile> createState() => _DashboardTileState();
}

class _DashboardTileState extends State<DashboardTile> {
  bool _hovered = false;

  static const _radius = BorderRadius.all(Radius.circular(20));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final still = MediaQuery.disableAnimationsOf(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(vertical: 6),
      transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
      decoration: BoxDecoration(
        color: _hovered
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLow,
        borderRadius: _radius,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: _hovered ? 0.12 : 0),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: OpenContainer(
        // The decoration above paints the tile; the transform grows from
        // its shape into the detail screen.
        closedColor: Colors.transparent,
        closedElevation: 0,
        openColor: scheme.surface,
        middleColor: scheme.surface,
        closedShape: const RoundedRectangleBorder(borderRadius: _radius),
        transitionType: ContainerTransitionType.fade,
        transitionDuration: still
            ? Duration.zero
            : const Duration(milliseconds: 400),
        openBuilder: (context, _) => widget.openBuilder(context),
        closedBuilder: (context, open) => Semantics(
          button: true,
          child: InkWell(
            onTap: open,
            onHover: (h) => setState(() => _hovered = h),
            borderRadius: _radius,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(widget.icon, size: 18, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.value,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: widget.valueColor,
                          ),
                        ),
                      ),
                      if (widget.badge != null) ...[
                        const SizedBox(width: 8),
                        widget.badge!,
                      ],
                    ],
                  ),
                  if (widget.subtitle != null)
                    Text(
                      widget.subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  if (widget.footer != null) ...[
                    const Spacer(),
                    const SizedBox(height: 12),
                    widget.footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A slim progress bar for a tile's footer.
class TileProgress extends StatelessWidget {
  /// Shows [value] (0–1) in [color].
  const TileProgress({super.key, required this.value, this.color});

  /// How full the bar is.
  final double value;

  /// The bar's colour; `primary` without.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => LinearProgressIndicator(
          minHeight: 6,
          value: v,
          color: color ?? scheme.primary,
          backgroundColor: scheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}
