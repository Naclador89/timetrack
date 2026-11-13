import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../widgets/app_bar_actions.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/undo.dart';
import '../calendar/trip_expenses.dart';
import '../reports/report_documents.dart' show projectLabel;
import 'absences.dart';
import 'trip_dialog.dart';

/// What the planner's list shows (`/planner?show=trips|absences`).
enum PlannerFilter {
  /// Trips and absences.
  all,

  /// Only business trips.
  trips,

  /// Only absences.
  absences;

  /// The filter named [name], or [all].
  static PlannerFilter parse(String? name) =>
      values.firstWhere((f) => f.name == name, orElse: () => all);
}

/// Business trips and absences in their own tab (navigation.md "Planer"):
/// the vacation account and the year's trips at a glance, the year as mini
/// months, bridge days, and one list of everything, coming up first.
class PlannerScreen extends ConsumerStatefulWidget {
  /// Creates the screen showing [filter].
  const PlannerScreen({super.key, this.filter = PlannerFilter.all});

  /// What the list shows first.
  final PlannerFilter filter;

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

/// A trip or a block of absences in the list, with its first and last day
/// (an open trip lasts until today).
typedef _Entry = ({
  LocalDate start,
  LocalDate end,
  Trip? trip,
  AbsenceBlock? block,
});

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  late int _year = ref.read(todayProvider).year;
  late PlannerFilter _filter = widget.filter;
  bool _allPast = false;

  /// Past entries shown before "more".
  static const _pastShown = 5;

  @override
  void didUpdateWidget(PlannerScreen old) {
    super.didUpdateWidget(old);
    if (old.filter != widget.filter) _filter = widget.filter;
  }

  /// Asks for the days carried into [_year]; unset, it suggests what was
  /// left of the year before (calculations §10).
  Future<void> _editCarryOver() async {
    final l = context.l10n;
    final settings = ref.read(settingsProvider);
    final key = SettingKeys.vacationCarryOver(_year);
    var initial = settings.number(key);
    if (initial == null) {
      final last = ref.read(vacationAccountProvider(_year - 1));
      initial = last.remaining > 0 ? last.remaining : 0;
    }
    final text = await showTextPrompt(
      context,
      title: l.vacationCarryOverInto('$_year'),
      okLabel: l.save,
      cancelLabel: l.cancel,
      initial: context.days(initial),
      label: l.vacationCarryOver,
    );
    if (text == null) return;
    final days = double.tryParse(text.replaceAll(',', '.'));
    if (days == null || days < 0) return;
    await saveSetting(ref.read(repositoryProvider), key, days);
  }

  /// Adds a trip or an absence from [date]; with both shown, asks which.
  Future<void> _add(LocalDate date) async {
    final l = context.l10n;
    final kind = _filter != PlannerFilter.all
        ? _filter
        : await showModalBottomSheet<PlannerFilter>(
            context: context,
            showDragHandle: true,
            builder: (c) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(dayTypeIcon(DayType.businessTrip)),
                    title: Text(l.newTrip),
                    onTap: () => Navigator.pop(c, PlannerFilter.trips),
                  ),
                  ListTile(
                    leading: Icon(dayTypeIcon(DayType.vacation)),
                    title: Text(l.addAbsence),
                    onTap: () => Navigator.pop(c, PlannerFilter.absences),
                  ),
                ],
              ),
            ),
          );
    if (!mounted) return;
    switch (kind) {
      case PlannerFilter.trips:
        await showTripDialog(context, date: date);
      case PlannerFilter.absences:
        await showAbsenceDialog(context, ref, initial: date);
      case PlannerFilter.all || null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final ledger = ref.watch(ledgerProvider);
    final zone = ref.watch(zoneProvider);
    final data = ref.watch(ledgerDataProvider);
    final bridges = bridgeDays(ledger, _year, today: today);
    bool inYear(_Entry e) => e.start.year <= _year && e.end.year >= _year;

    // An open trip runs until today (or starts in the future).
    List<LocalDate> datesOf(Trip t) {
      final closed = tripDates(t, zone);
      if (t.returnAt != null) return closed;
      final first = zone.dateOf(t.depart);
      return [
        for (var d = first; !d.isAfter(today); d = d.addDays(1)) d,
        if (first.isAfter(today)) first,
      ];
    }

    final tripEntries = <_Entry>[
      for (final t in data.trips)
        if (datesOf(t) case [final first, ...] && final dates)
          (start: first, end: dates.last, trip: t, block: null),
    ].where(inYear).toList();
    final blocks = [
      for (final b in absenceBlocks(data.absences, ledger.targets))
        (start: b.start, end: b.end, trip: null, block: b),
    ].where(inYear).toList();
    final tripByDate = {
      for (final e in tripEntries)
        for (final d in datesOf(e.trip!)) d: e.trip!,
    };
    final entries = [
      if (_filter != PlannerFilter.absences) ...tripEntries,
      if (_filter != PlannerFilter.trips) ...blocks,
    ];
    final upcoming = entries.where((e) => !e.end.isBefore(today)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final past = entries.where((e) => e.end.isBefore(today)).toList()
      ..sort((a, b) => b.start.compareTo(a.start));

    final Widget listCard = Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final (f, label, icon) in [
                  (PlannerFilter.all, l.plannerAll, null),
                  (
                    PlannerFilter.trips,
                    l.trips,
                    dayTypeIcon(DayType.businessTrip),
                  ),
                  (
                    PlannerFilter.absences,
                    l.absences,
                    dayTypeIcon(DayType.vacation),
                  ),
                ])
                  ChoiceChip(
                    avatar: icon == null ? null : Icon(icon),
                    label: Text(label),
                    selected: _filter == f,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
              ],
            ),
          ),
          if (entries.isEmpty) ListTile(title: Text(l.plannerEmpty(_year))),
          for (final (title, list) in [
            (l.plannerUpcoming, upcoming),
            (l.plannerPast, past),
          ])
            if (list.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              // The past only as far back as asked for.
              for (final e in list.take(
                list == past && !_allPast ? _pastShown : list.length,
              ))
                e.trip != null
                    ? _TripTile(entry: e, today: today)
                    : _AbsenceTile(entry: e, today: today),
              if (list == past && !_allPast && past.length > _pastShown)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _allPast = true),
                    icon: const Icon(Icons.expand_more),
                    label: Text(l.plannerMore(past.length - _pastShown)),
                  ),
                ),
            ],
          const SizedBox(height: 8),
        ],
      ),
    );
    final Widget yearCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, box) {
                final columns = box.maxWidth >= 900
                    ? 4
                    : box.maxWidth >= 560
                    ? 3
                    : 2;
                final width = (box.maxWidth - 16 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (var m = 1; m <= 12; m++)
                      SizedBox(
                        width: width,
                        child: MiniMonth(
                          first: LocalDate(_year, m, 1),
                          bridges: {for (final b in bridges) ...b.vacationDays},
                          tripDays: tripByDate.keys.toSet(),
                          // A trip day opens its trip.
                          onTap: (d) {
                            if (tripByDate[d] case final t?) {
                              showTripDialog(context, trip: t);
                            } else {
                              _add(d);
                            }
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            const PlannerLegend(),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.plannerTitle), actions: commonActions()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(today),
        icon: const Icon(Icons.add),
        label: Text(switch (_filter) {
          PlannerFilter.all => l.plannerNew,
          PlannerFilter.trips => l.newTrip,
          PlannerFilter.absences => l.addAbsence,
        }),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1300),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '${_year - 1}',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() => _year--),
                  ),
                  Expanded(
                    child: Text(
                      '$_year',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '${_year + 1}',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() => _year++),
                  ),
                ],
              ),
              _Summary(
                year: _year,
                trips: tripEntries,
                tripDays: {
                  for (final d in tripByDate.keys)
                    if (d.year == _year) d,
                }.length,
                blocks: [for (final b in blocks) b.block],
                onCarryOver: _editCarryOver,
              ),
              // Side by side on wide windows, else one below the other.
              LayoutBuilder(
                builder: (context, box) {
                  final year = [
                    yearCard,
                    if (_year >= today.year)
                      BridgeCard(
                        year: _year,
                        bridges: bridges,
                        onNextYear: () => setState(() => _year++),
                      ),
                  ];
                  if (box.maxWidth < 900) {
                    return Column(children: [listCard, ...year]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: listCard),
                      Expanded(flex: 2, child: Column(children: year)),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The year in numbers: vacation account, trips, other absences.
class _Summary extends ConsumerWidget {
  const _Summary({
    required this.year,
    required this.trips,
    required this.tripDays,
    required this.blocks,
    required this.onCarryOver,
  });

  final int year;
  final List<_Entry> trips;
  final int tripDays;
  final List<AbsenceBlock> blocks;
  final VoidCallback onCarryOver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final account = ref.watch(vacationAccountProvider(year));
    final total = account.entitlement + account.carryOver;
    final today = ref.watch(todayProvider);
    final unclaimed = trips
        .where(
          (e) =>
              e.trip!.returnAt != null &&
              e.trip!.claimedOn == null &&
              !e.end.isAfter(today),
        )
        .length;
    // Days per kind of the other absences, in the order of the kinds.
    final others = <AbsenceKind, double>{};
    for (final b in blocks) {
      if (b.kind == AbsenceKind.vacation) continue;
      others[b.kind] = (others[b.kind] ?? 0) + b.days;
    }
    final otherKinds = AbsenceKind.values.where(others.containsKey).toList();
    final otherTotal = others.values.fold(0.0, (a, b) => a + b);
    final cards = [
      _StatCard(
        icon: dayTypeIcon(DayType.vacation),
        color: scheme.dayTypeColor(DayType.vacation),
        title: l.absenceVacation,
        value: context.days(account.remaining),
        unit: l.dashDaysOf(context.days(total)),
        detail: l.vacationTakenPlanned(
          context.days(account.taken),
          context.days(account.planned),
        ),
        taken: total <= 0 ? 0 : account.taken / total,
        planned: total <= 0 ? 0 : account.planned / total,
        action: IconButton(
          tooltip: l.vacationCarryOver,
          icon: const Icon(Icons.edit_calendar_outlined),
          onPressed: onCarryOver,
        ),
      ),
      _StatCard(
        icon: dayTypeIcon(DayType.businessTrip),
        color: scheme.dayTypeColor(DayType.businessTrip),
        title: l.trips,
        value: '${trips.length}',
        unit: l.tripsInYear(trips.length, tripDays),
        detail: trips.isEmpty
            ? null
            : unclaimed > 0
            ? l.claimsOpen(unclaimed)
            : l.claimsAllDone,
        detailColor: unclaimed > 0 ? scheme.error : null,
      ),
      if (otherKinds.isNotEmpty)
        _StatCard(
          icon: dayTypeIcon(DayType.sick),
          color: scheme.dayTypeColor(DayType.sick),
          title: l.otherAbsence,
          value: context.days(otherTotal),
          unit: l.daysUnit(otherTotal),
          detail: [
            for (final k in otherKinds)
              '${context.absenceName(k)} ${context.days(others[k]!)}',
          ].join(' · '),
        ),
    ];
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth < 640
          ? Column(children: cards)
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final c in cards) Expanded(child: c)],
              ),
            ),
    );
  }
}

/// One number of the year with its unit, a detail line and, for the
/// vacation, a bar of taken and planned days.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.unit,
    this.detail,
    this.detailColor,
    this.taken,
    this.planned,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String unit;
  final String? detail;
  final Color? detailColor;

  /// Shares of the total for the bar; none without.
  final double? taken, planned;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
                ?action,
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: '  $unit',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            if (taken != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Stack(
                      children: [
                        Container(color: scheme.surfaceContainerHighest),
                        FractionallySizedBox(
                          widthFactor: (taken! + planned!).clamp(0.0, 1.0),
                          child: Container(color: color.withValues(alpha: 0.4)),
                        ),
                        FractionallySizedBox(
                          widthFactor: taken!.clamp(0.0, 1.0),
                          child: Container(color: color),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: detailColor ?? scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The dates of [e]: one day, or first to last.
String _range(BuildContext context, _Entry e) => e.start == e.end
    ? context.shortDate(e.start)
    : '${context.shortDate(e.start)} – ${context.shortDate(e.end)}';

/// How soon [e] starts while it is ahead, or that it is running.
String? _relative(BuildContext context, _Entry e, LocalDate today) {
  final l = context.l10n;
  if (e.start.isAfter(today)) return l.startsIn(today.daysUntil(e.start));
  if (!e.end.isBefore(today)) return l.running;
  return null;
}

/// The entry's name with how soon it starts beside it, highlighted.
Widget _title(BuildContext context, String name, String? relative) {
  final theme = Theme.of(context);
  return Row(
    children: [
      Expanded(child: Text(name)),
      if (relative != null)
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            relative,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
    ],
  );
}

Widget _avatar(IconData icon, Color color) => CircleAvatar(
  backgroundColor: color.withValues(alpha: 0.2),
  foregroundColor: color,
  child: Icon(icon, size: 20),
);

/// A business trip: destination, dates, order and project, the first line
/// of its notes, claim status;
/// the receipt opens the expense report (calculations §13.5).
class _TripTile extends ConsumerWidget {
  const _TripTile({required this.entry, required this.today});

  final _Entry entry;
  final LocalDate today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final t = entry.trip!;
    final ledger = ref.watch(ledgerProvider);
    final project = ref.watch(projectByIdProvider)[t.projectId];
    final finished = t.returnAt != null && !entry.end.isAfter(today);
    final deadline = claimsDue(
      [t],
      ledger: ledger,
      rules: ledger.settings.expenses,
    ).firstOrNull?.deadline;
    final away = t.returnAt == null && !entry.start.isAfter(today);
    return ListTile(
      leading: _avatar(
        dayTypeIcon(DayType.businessTrip),
        scheme.dayTypeColor(DayType.businessTrip),
      ),
      title: _title(
        context,
        t.destination.isEmpty ? l.tripDay : t.destination,
        _relative(context, entry, today),
      ),
      subtitle: Text(
        [
          if (away)
            l.awaySince(context.shortDate(entry.start))
          else
            _range(context, entry),
          if ([
                if (t.orderLabel.isNotEmpty) t.orderLabel,
                if (project != null) projectLabel(project),
              ]
              case final refs when refs.isNotEmpty)
            refs.join(' · '),
          if (t.note.isNotEmpty) t.note.split('\n').first,
          if (finished)
            t.claimedOn != null
                ? l.claimedOn(context.date(t.claimedOn!))
                : deadline != null
                ? '${l.claimDeadline} ${context.date(deadline)}'
                : l.notClaimed,
        ].join('\n'),
      ),
      trailing: t.returnAt == null
          ? null
          : IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: l.tripExpenses,
              onPressed: () => openTripExpenses(context, ref, t),
            ),
      onTap: () => showTripDialog(context, trip: t),
    );
  }
}

/// A block of absences: kind, dates and days; tap opens its first day,
/// the bin deletes the whole block (with undo).
class _AbsenceTile extends ConsumerWidget {
  const _AbsenceTile({required this.entry, required this.today});

  final _Entry entry;
  final LocalDate today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final b = entry.block!;
    final type = DayType.ofAbsence(b.kind);
    final days = b.half && b.absences.length == 1
        ? l.halfDay
        : '${context.days(b.days)} ${l.daysUnit(b.days)}';
    return ListTile(
      leading: _avatar(
        type == null ? Icons.event_busy_outlined : dayTypeIcon(type),
        type == null ? scheme.tertiary : scheme.dayTypeColor(type),
      ),
      title: _title(
        context,
        context.absenceName(b.kind),
        _relative(context, entry, today),
      ),
      subtitle: Text('${_range(context, entry)}\n$days'),
      trailing: IconButton(
        tooltip: l.delete,
        icon: const Icon(Icons.delete_outline),
        onPressed: () => deleteWithUndo(context, ref, [
          for (final a in b.absences) ('absences', a.id),
        ]),
      ),
      onTap: () => context.go('/calendar/day/${b.start}'),
    );
  }
}
