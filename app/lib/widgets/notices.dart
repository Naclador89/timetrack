import 'package:flutter/material.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../app/format.dart';

/// The user-facing text of a Review list item (spec: calculations.md §12).
String noticeText(BuildContext context, ReviewItem item) {
  final l = context.l10n;
  final m = formatMinutes(item.minutes);
  return switch (item.kind) {
    ReviewKind.openSessionTooLong => l.warnOpenSession,
    ReviewKind.overlappingSessions => l.warnOverlapSessions,
    ReviewKind.overlappingProjectEntries => l.warnOverlapProjects,
    ReviewKind.projectOutsideSession => l.warnProjectOutside(m),
    ReviewKind.projectOverWork => l.warnProjectOverWork(m),
    ReviewKind.homeOfficeQuota => l.warnQuota,
    ReviewKind.unassigned => l.warnUnassigned(m),
    ReviewKind.arbzg => switch (item.arbzg!) {
      ArbzgWarningKind.breakMissing => l.warnBreakMissing(m),
      ArbzgWarningKind.workOver6hWithoutBreak => l.warnOver6h,
      ArbzgWarningKind.over10h => l.warnOver10h,
      ArbzgWarningKind.restUnder11h => l.warnRest(m),
      ArbzgWarningKind.sundayOrHolidayWork => l.warnSunday,
    },
  };
}

/// A card listing notices; renders nothing if [items] is empty.
class NoticesCard extends StatelessWidget {
  /// Creates the card.
  const NoticesCard({super.key, required this.items, this.showDates = false});

  /// The notices.
  final List<ReviewItem> items;

  /// Prefix each notice with its date.
  final bool showDates;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.info_outline,
                  color: scheme.onTertiaryContainer,
                ),
                title: Text(
                  showDates
                      ? '${context.shortDate(item.date)}: ${noticeText(context, item)}'
                      : noticeText(context, item),
                  style: TextStyle(color: scheme.onTertiaryContainer),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
