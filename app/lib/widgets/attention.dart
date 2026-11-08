import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../app/format.dart';
import '../app/providers.dart';
import '../features/projects/project_time_dialog.dart';
import 'interval_dialog.dart';
import 'notices.dart';

/// Review items (calculations.md §12) as cards with a one-tap fix: add the
/// missing break, set the end of a forgotten session, assign unassigned
/// time, end an open trip, or open the day.
///
/// Which categories appear is a setting; a card closed with × is dismissed
/// for good (synced, data-model §14) and only leaves the marker in the
/// calendar. With [showHidden] (day view) the hidden ones are listed small
/// below, and dismissed ones can be brought back.
class AttentionCards extends ConsumerWidget {
  /// Creates the cards for the days [from]–[to].
  const AttentionCards({
    super.key,
    required this.from,
    required this.to,
    this.showDates = true,
    this.includeQuota = false,
    this.includeTrip = false,
    this.collapseAfter,
    this.showHidden = false,
  });

  /// List hidden notices of these days small, below the cards.
  final bool showHidden;

  /// Shows at most this many cards and a "show all" toggle for the rest.
  final int? collapseAfter;

  /// First day.
  final LocalDate from;

  /// Last day.
  final LocalDate to;

  /// Prefix each card with its date.
  final bool showDates;

  /// Also warn about home-office quotas.
  final bool includeQuota;

  /// Also offer to end an open trip while clocked out (Today).
  final bool includeTrip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    final dismissed = ref.watch(dismissedNoticesProvider);
    final state = ref.watch(trackerStateProvider);
    final quotas = includeQuota
        ? ref.watch(homeOfficeQuotasProvider)
        : const <HomeOfficeQuota>[];
    final items = [
      ...ref.watch(noticesProvider((from, to))),
      ...reviewItems(
        ref.watch(ledgerProvider),
        from: from,
        to: to,
        quotas: quotas,
      ).where((i) => i.kind == ReviewKind.homeOfficeQuota),
    ];
    final (:shown, :hidden) = splitNotices(
      items,
      shows: (c) => settings.showsNotice(c.wireName),
      dismissed: dismissed,
    );
    final cards = <Widget>[];
    for (final item in shown) {
      final key = noticeKey(item);
      final (icon, label, fix) = _fix(context, ref, item);
      cards.add(
        _AttentionCard(
          key: ValueKey(key),
          icon: icon,
          text: showDates
              ? '${context.shortDate(item.date)} · ${noticeText(context, item)}'
              : noticeText(context, item),
          actionLabel: label,
          onAction: fix,
          onDismiss: () => _dismiss(context, ref, item),
        ),
      );
    }
    if (includeTrip &&
        settings.showsNotice(NoticeCategory.openTrip.wireName) &&
        state.trip != null &&
        !state.clockedIn) {
      final dest = state.trip!.fields['destination'] as String? ?? '';
      cards.add(
        _AttentionCard(
          key: const ValueKey('trip'),
          icon: Icons.luggage_outlined,
          text: dest.isEmpty ? l.tripStillOpen : l.tripStillOpenTo(dest),
          actionLabel: l.endTrip,
          onAction: () => ref.read(trackerProvider).endTrip(),
        ),
      );
    }
    final limit = collapseAfter;
    final Widget body = limit != null && cards.length > limit + 1
        ? _Collapsible(cards: cards, visible: limit)
        : AnimatedSize(
            duration: const Duration(milliseconds: 250),
            alignment: Alignment.topCenter,
            child: Column(children: cards),
          );
    if (!showHidden || hidden.isEmpty) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        body,
        _HiddenNotices(items: hidden, dismissed: dismissed),
      ],
    );
  }

  /// Hides [item] for good (synced) and offers to undo it.
  Future<void> _dismiss(
    BuildContext context,
    WidgetRef ref,
    ReviewItem item,
  ) async {
    final repo = ref.read(repositoryProvider);
    final key = noticeKey(item);
    await repo.write('dismissed_notices', key, {
      'date': '${item.date}',
      'deleted': false,
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.noticeDismissed),
          action: SnackBarAction(
            label: context.l10n.undo,
            onPressed: () => repo.delete('dismissed_notices', key),
          ),
        ),
      );
  }

  (IconData, String, VoidCallback) _fix(
    BuildContext context,
    WidgetRef ref,
    ReviewItem item,
  ) {
    final l = context.l10n;
    final zone = ref.read(zoneProvider);
    void openDay() => context.go('/calendar/day/${item.date}');
    int local(int epochMinute) {
      final t = zone.toLocal(instantOfEpochMinute(epochMinute));
      return t.hour * 60 + t.minute;
    }

    switch (item) {
      case ReviewItem(
        kind: ReviewKind.arbzg,
        arbzg: ArbzgWarningKind.breakMissing ||
            ArbzgWarningKind.workOver6hWithoutBreak,
      ):
        return (
          Icons.coffee_outlined,
          l.fixAddBreak,
          () {
            final day = ref.read(ledgerProvider).day(item.date);
            final minutes = item.minutes > 0 ? item.minutes : 30;
            final span = suggestBreak(day, minutes);
            showIntervalDialog(
              context,
              date: item.date,
              table: 'breaks',
              initialStart: span == null ? null : local(span.start),
              initialEnd: span == null ? null : local(span.end),
            );
          },
        );
      case ReviewItem(kind: ReviewKind.openSessionTooLong, :final refId?):
        return (
          Icons.timer_off_outlined,
          l.fixSetEnd,
          () {
            final session = ref
                .read(ledgerDataProvider)
                .sessions
                .where((s) => s.id == refId)
                .firstOrNull;
            if (session == null) return;
            showIntervalDialog(
              context,
              date: item.date,
              table: 'work_sessions',
              id: session.id,
              start: session.start,
              location: session.location,
            );
          },
        );
      case ReviewItem(kind: ReviewKind.unassigned):
        return (
          Icons.work_outline,
          l.fixAssign,
          () => assignUnassigned(context, ref, item.date),
        );
      case ReviewItem(kind: ReviewKind.homeOfficeQuota):
        return (Icons.home_outlined, l.openDay, openDay);
      default:
        return (Icons.info_outline, l.openDay, openDay);
    }
  }
}

/// Opens the booking sheet for the unassigned time of [date]: one gap is
/// prefilled with its times, several as a duration (the rest of the day).
Future<void> assignUnassigned(
  BuildContext context,
  WidgetRef ref,
  LocalDate date,
) {
  final day = ref.read(ledgerProvider).day(date);
  final gaps = day.work.unassignedSpans.spans;
  final hasDurations = ref
      .read(ledgerDataProvider)
      .durations
      .any((d) => d.date == date);
  if (gaps.length == 1 && !hasDurations) {
    return showProjectTimeDialog(
      context,
      date: date,
      startMinutes: localMinuteOf(
        instantOfEpochMinute(gaps.single.start),
        date,
        ref.read(zoneProvider),
      ),
      durationMinutes: gaps.single.length,
    );
  }
  return showProjectTimeDialog(
    context,
    date: date,
    durationMinutes: snapToQuarter(day.unassigned),
  );
}

/// Hidden notices of a day, small and folded: dismissed ones can be shown
/// again; switched-off categories say where to turn them on.
class _HiddenNotices extends ConsumerStatefulWidget {
  const _HiddenNotices({required this.items, required this.dismissed});

  final List<ReviewItem> items;
  final Set<String> dismissed;

  @override
  ConsumerState<_HiddenNotices> createState() => _HiddenNoticesState();
}

class _HiddenNoticesState extends ConsumerState<_HiddenNotices> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _open = !_open),
            icon: Icon(
              _open ? Icons.expand_less : Icons.notifications_off_outlined,
              size: 18,
            ),
            label: Text(l.hiddenNotices('${widget.items.length}')),
          ),
        ),
        if (_open)
          for (final item in widget.items)
            ListTile(
              dense: true,
              leading: const Icon(Icons.info_outline, size: 18),
              title: Text(noticeText(context, item)),
              subtitle: widget.dismissed.contains(noticeKey(item))
                  ? null
                  : Text(l.noticeCategoryOff, style: theme.textTheme.bodySmall),
              trailing: widget.dismissed.contains(noticeKey(item))
                  ? TextButton(
                      onPressed: () => ref
                          .read(repositoryProvider)
                          .delete('dismissed_notices', noticeKey(item)),
                      child: Text(l.showAgain),
                    )
                  : null,
            ),
      ],
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    super.key,
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onAction,
    this.onDismiss,
  });

  final IconData icon;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, color: scheme.onTertiaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(color: scheme.onTertiaryContainer),
                  ),
                  const SizedBox(height: 4),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      backgroundColor: scheme.surface.withValues(alpha: 0.6),
                    ),
                    onPressed: onAction,
                    child: Text(actionLabel),
                  ),
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: Icon(Icons.close, color: scheme.onTertiaryContainer),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}

/// The first [visible] cards and a button for the rest.
class _Collapsible extends StatefulWidget {
  const _Collapsible({required this.cards, required this.visible});

  final List<Widget> cards;
  final int visible;

  @override
  State<_Collapsible> createState() => _CollapsibleState();
}

class _CollapsibleState extends State<_Collapsible> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hidden = widget.cards.length - widget.visible;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...(_open ? widget.cards : widget.cards.take(widget.visible)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _open = !_open),
              icon: Icon(_open ? Icons.expand_less : Icons.expand_more),
              label: Text(_open ? l.showLess : l.moreNotices('$hidden')),
            ),
          ),
        ],
      ),
    );
  }
}
