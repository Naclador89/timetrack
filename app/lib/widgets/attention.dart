import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:go_router/go_router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../app/back_navigation.dart';
import '../app/format.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../features/projects/project_time_dialog.dart';
import 'interval_dialog.dart';
import 'notices.dart';

/// One notice with its fix, as shown in the cards and the review flow.
typedef AttentionItem = ({
  ReviewItem item,
  String key,
  IconData icon,
  String text,
  String actionLabel,
  Future<void> Function() onAction,
  bool opensDay,
});

/// The notices of [from]–[to] with their fixes: the [shown] ones (category
/// on, not dismissed; calculations §12) and the [hidden] ones. [watch]
/// rebuilds the caller on changes; the review flow reads instead.
({List<AttentionItem> shown, List<ReviewItem> hidden}) attentionItems(
  BuildContext context,
  WidgetRef ref, {
  required LocalDate from,
  required LocalDate to,
  bool includeQuota = false,
  bool watch = true,
}) {
  T get<T>(ProviderListenable<T> p) => watch ? ref.watch(p) : ref.read(p);
  final settings = get(settingsProvider);
  final quotas = includeQuota
      ? get(homeOfficeQuotasProvider)
      : const <HomeOfficeQuota>[];
  final items = [
    ...get(noticesProvider((from, to))),
    ...reviewItems(
      get(ledgerProvider),
      from: from,
      to: to,
      quotas: quotas,
    ).where((i) => i.kind == ReviewKind.homeOfficeQuota),
  ];
  final (:shown, :hidden) = splitNotices(
    items,
    shows: (c) => settings.showsNotice(c.wireName),
    dismissed: get(dismissedNoticesProvider),
  );
  return (
    shown: [
      for (final item in shown)
        if (_fix(context, ref, item) case (
          final icon,
          final label,
          final fix,
          final opensDay,
        ))
          (
            item: item,
            key: noticeKey(item),
            icon: icon,
            text: noticeText(context, item),
            actionLabel: label,
            onAction: fix,
            opensDay: opensDay,
          ),
    ],
    hidden: hidden,
  );
}

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
    this.grouped = false,
  });

  /// One summary card with a line per day and "Woche prüfen" instead of a
  /// card per notice (the week view).
  final bool grouped;

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
    final (:shown, :hidden) = attentionItems(
      context,
      ref,
      from: from,
      to: to,
      includeQuota: includeQuota,
    );
    if (grouped) {
      return _WeekSummary(items: shown, from: from, to: to);
    }
    final cards = <Widget>[
      for (final a in shown)
        _AttentionCard(
          key: ValueKey(a.key),
          icon: a.icon,
          text: showDates
              ? '${context.shortDate(a.item.date)} · ${a.text}'
              : a.text,
          actionLabel: a.actionLabel,
          onAction: () => unawaited(a.onAction()),
          onDismiss: () => dismissNotice(context, ref, a.item),
        ),
    ];
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
}

/// Hides [item] for good (synced) and offers to undo it.
Future<void> dismissNotice(
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
        // With an action Flutter would keep it until tapped.
        persist: false,
        action: SnackBarAction(
          label: context.l10n.undo,
          onPressed: () => repo.delete('dismissed_notices', key),
        ),
      ),
    );
}

/// The icon, the fix's label and the fix of [item], and whether the fix
/// only opens the day.
(IconData, String, Future<void> Function(), bool) _fix(
  BuildContext context,
  WidgetRef ref,
  ReviewItem item,
) {
  final l = context.l10n;
  final zone = ref.read(zoneProvider);
  Future<void> openDay() async => context.go(dayLocation(context, item.date));
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
          final settings = ref.read(settingsProvider);
          final minutes = item.minutes > 0
              ? item.minutes
              : settings.defaultBreakMinutes;
          final usual = epochMinute(
            zone.instantAt(
              item.date,
              settings.defaultBreakStart ~/ 60,
              settings.defaultBreakStart % 60,
            ),
          );
          final span = suggestBreak(
            day,
            minutes,
            preferred: Span(usual, usual + minutes),
          );
          return showIntervalDialog(
            context,
            date: item.date,
            table: 'breaks',
            initialStart: span == null ? null : local(span.start),
            initialEnd: span == null ? null : local(span.end),
          );
        },
        false,
      );
    case ReviewItem(kind: ReviewKind.openSessionTooLong, :final refId?):
      return (
        Icons.timer_off_outlined,
        l.fixSetEnd,
        () async {
          final session = ref
              .read(ledgerDataProvider)
              .sessions
              .where((s) => s.id == refId)
              .firstOrNull;
          if (session == null) return;
          await showIntervalDialog(
            context,
            date: item.date,
            table: 'work_sessions',
            id: session.id,
            start: session.start,
            location: session.location,
          );
        },
        false,
      );
    case ReviewItem(kind: ReviewKind.unassigned):
      return (
        Icons.work_outline,
        l.fixAssign,
        () => assignUnassigned(context, ref, item.date),
        false,
      );
    case ReviewItem(kind: ReviewKind.homeOfficeQuota):
      return (Icons.home_outlined, l.openDay, openDay, true);
    case ReviewItem(
      kind: ReviewKind.projectBudgetNear || ReviewKind.projectBudgetOver,
      :final refId?,
    ):
      return (
        Icons.savings_outlined,
        l.openProject,
        () async => context.go('/projects/$refId'),
        true,
      );
    default:
      return (Icons.info_outline, l.openDay, openDay, true);
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

/// The week's notices in one card: how many on how many days, a line per
/// day and "Woche prüfen"; with none left, "Woche vollständig".
class _WeekSummary extends ConsumerWidget {
  const _WeekSummary({
    required this.items,
    required this.from,
    required this.to,
  });

  final List<AttentionItem> items;
  final LocalDate from;
  final LocalDate to;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (items.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Chip(
            avatar: Icon(Icons.check_circle, color: scheme.deltaColor(1)),
            label: Text(l.weekComplete),
          ),
        ),
      );
    }
    final byDay = <LocalDate, List<AttentionItem>>{};
    for (final a in items) {
      (byDay[a.item.date] ??= []).add(a);
    }
    final days = byDay.keys.toList()..sort();
    final on = TextStyle(color: scheme.onTertiaryContainer);
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.checklist, color: scheme.onTertiaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${l.noticeCount(items.length)} ${l.noticeDays(days.length)}',
                    style: theme.textTheme.titleSmall?.merge(on),
                  ),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.surface.withValues(alpha: 0.6),
                  ),
                  onPressed: () => runReviewFlow(
                    context,
                    ref,
                    from: from,
                    to: to,
                    title: l.weekCheck,
                  ),
                  child: Text(l.weekCheck),
                ),
              ],
            ),
            for (final d in days)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => runReviewFlow(
                  context,
                  ref,
                  from: from,
                  to: to,
                  startAt: d,
                  title: l.weekCheck,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 84,
                        child: Text(
                          context.shortDate(d),
                          style: on.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          byDay[d]!.map((a) => a.text).join(' · '),
                          style: on,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _Step { fix, hide, skip }

/// Steps through the open notices of [from]–[to] one at a time, each with
/// its fix, "hide for good" and "skip" (calculations §12, checking a week or
/// month). [startAt] begins with that day. A fix that only opens the day
/// ends the flow there.
Future<void> runReviewFlow(
  BuildContext context,
  WidgetRef ref, {
  required LocalDate from,
  required LocalDate to,
  required String title,
  LocalDate? startAt,
}) async {
  final skipped = <String>{};
  var handled = 0;
  List<AttentionItem> open() =>
      attentionItems(context, ref, from: from, to: to, watch: false).shown;
  while (true) {
    if (!context.mounted) return;
    final all = open().where((a) => !skipped.contains(a.key)).toList();
    final start = startAt;
    final queue = start == null
        ? all
        : [
            ...all.where((a) => !a.item.date.isBefore(start)),
            ...all.where((a) => a.item.date.isBefore(start)),
          ];
    if (queue.isEmpty) {
      if (handled + skipped.length > 0) {
        await _showDone(context, skipped.length);
      }
      return;
    }
    final current = queue.first;
    final step = await showDialog<_Step>(
      context: context,
      builder: (_) => _FlowStep(
        title: title,
        item: current,
        index: handled + skipped.length + 1,
        total: handled + skipped.length + queue.length,
      ),
    );
    if (step == null || !context.mounted) return;
    final before = {for (final a in open()) a.key};
    switch (step) {
      case _Step.fix when current.opensDay:
        await current.onAction();
        return;
      case _Step.fix:
        await current.onAction();
      case _Step.hide:
        await dismissNotice(context, ref, current.item);
      case _Step.skip:
        skipped.add(current.key);
        continue;
    }
    await _untilChanged(ref, (from, to), before);
    if (!open().any((a) => a.key == current.key)) handled++;
  }
}

/// Waits until the open notices differ from [before] (the write went
/// through), at most a moment: a cancelled fix changes nothing.
Future<void> _untilChanged(
  WidgetRef ref,
  (LocalDate, LocalDate) range,
  Set<String> before,
) async {
  bool changed() {
    final now = {
      for (final i in ref.read(openNoticesProvider(range))) noticeKey(i),
    };
    return now.length != before.length || !now.containsAll(before);
  }

  for (var i = 0; i < 10 && !changed(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> _showDone(BuildContext context, int skipped) => showDialog<void>(
  context: context,
  builder: (context) {
    final l = context.l10n;
    return AlertDialog(
      icon: Icon(
        Icons.check_circle,
        color: Theme.of(context).colorScheme.deltaColor(1),
      ),
      title: Text(l.allDone),
      content: skipped > 0 ? Text(l.skippedCount(skipped)) : null,
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  },
);

/// One notice of the review flow: its day, text and the three choices.
class _FlowStep extends StatelessWidget {
  const _FlowStep({
    required this.title,
    required this.item,
    required this.index,
    required this.total,
  });

  final String title;
  final AttentionItem item;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(title)),
          Text(l.reviewStep(index, total), style: theme.textTheme.labelLarge),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.longDate(item.item.date),
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon),
              const SizedBox(width: 12),
              Expanded(child: Text(item.text)),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _Step.hide),
          child: Text(l.hideNotice),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _Step.skip),
          child: Text(l.skip),
        ),
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.pop(context, _Step.fix),
          child: Text(item.actionLabel),
        ),
      ],
    );
  }
}

/// "Monat vollständig", or how many notices are open with a button that
/// checks them one by one (reports, before handing in the timesheet).
class ReviewStatus extends ConsumerWidget {
  /// Creates the status of [from]–[to].
  const ReviewStatus({
    super.key,
    required this.from,
    required this.to,
    required this.completeLabel,
    required this.checkLabel,
  });

  /// First day.
  final LocalDate from;

  /// Last day.
  final LocalDate to;

  /// Shown when nothing is open.
  final String completeLabel;

  /// The button and the flow's title.
  final String checkLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final open = ref.watch(openNoticesProvider((from, to)));
    if (open.isEmpty) {
      return Chip(
        avatar: Icon(Icons.check_circle, color: scheme.deltaColor(1)),
        label: Text(completeLabel),
      );
    }
    final days = {for (final i in open) i.date}.length;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Icon(Icons.checklist, color: scheme.tertiary),
        Text('${l.noticeCount(open.length)} ${l.noticeDays(days)}'),
        TextButton(
          onPressed: () => runReviewFlow(
            context,
            ref,
            from: from,
            to: to,
            title: checkLabel,
          ),
          child: Text(checkLabel),
        ),
      ],
    );
  }
}
