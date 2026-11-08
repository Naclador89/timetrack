import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../app/format.dart';
import '../app/providers.dart';
import '../features/projects/project_picker.dart';
import 'interval_dialog.dart';
import 'notices.dart';
import 'undo.dart';

/// Notices the user hid in this app session (by key).
final dismissedAttentionProvider = NotifierProvider<_Dismissed, Set<String>>(
  _Dismissed.new,
);

class _Dismissed extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void add(String key) => state = {...state, key};
}

/// Review items (calculations.md §12) as cards with a one-tap fix: add the
/// missing break, set the end of a forgotten session, assign unassigned
/// time, end an open trip, or open the day.
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
  });

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
    final ledger = ref.watch(ledgerProvider);
    final settings = ref.watch(settingsProvider);
    final dismissed = ref.watch(dismissedAttentionProvider);
    final state = ref.watch(trackerStateProvider);
    final items = reviewItems(
      ledger,
      from: from,
      to: to,
      openSessionLimitMinutes: settings.openSessionLimitMinutes,
      quotas: includeQuota ? ref.watch(homeOfficeQuotasProvider) : const [],
      includeUnassigned: true,
    );
    // One break card per day: "more than 6 h without a break" is the same
    // fix as the missing minutes.
    final missingBreak = {
      for (final i in items)
        if (i.arbzg == ArbzgWarningKind.breakMissing) i.date,
    };
    items.removeWhere(
      (i) =>
          i.arbzg == ArbzgWarningKind.workOver6hWithoutBreak &&
          missingBreak.contains(i.date),
    );
    final cards = <Widget>[];
    String keyOf(ReviewItem i) =>
        '${i.date}/${i.kind.name}/${i.arbzg?.name}/${i.refId}';
    for (final item in items) {
      final key = keyOf(item);
      if (dismissed.contains(key)) continue;
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
          onDismiss: () =>
              ref.read(dismissedAttentionProvider.notifier).add(key),
        ),
      );
    }
    if (includeTrip && state.trip != null && !state.clockedIn) {
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
    if (limit != null && cards.length > limit + 1) {
      return _Collapsible(cards: cards, visible: limit);
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      alignment: Alignment.topCenter,
      child: Column(children: cards),
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

/// Books the unassigned working time of [date] to a project the user picks:
/// timed entries over the gaps, or one duration when the gaps can't be
/// placed (the day already has durations).
Future<void> assignUnassigned(
  BuildContext context,
  WidgetRef ref,
  LocalDate date,
) async {
  final projectId = await showProjectPicker(context);
  if (projectId == null || !context.mounted) return;
  final day = ref.read(ledgerProvider).day(date);
  final repo = ref.read(repositoryProvider);
  final created = <(String, String)>[];
  final hasDurations = ref
      .read(ledgerDataProvider)
      .durations
      .any((d) => d.date == date);
  if (hasDurations) {
    final id = repo.newId();
    await repo.write('project_entries', id, {
      'project_id': projectId,
      'date': '$date',
      'duration_min': day.unassigned,
      'source': 'manual',
    });
    created.add(('project_entries', id));
  } else {
    for (final gap in day.work.unassignedSpans.spans) {
      final id = repo.newId();
      await repo.write('project_entries', id, {
        'project_id': projectId,
        'start_utc': isoMinute(instantOfEpochMinute(gap.start)),
        'end_utc': isoMinute(instantOfEpochMinute(gap.end)),
        'source': 'manual',
      });
      created.add(('project_entries', id));
    }
  }
  if (!context.mounted) return;
  final name = ref.read(projectByIdProvider)[projectId]?.name ?? '';
  offerUndoCreate(
    context,
    ref,
    created,
    context.l10n.assignedTo(formatMinutes(day.unassigned), name),
  );
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
