import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../widgets/date_range_dialog.dart';
import '../../widgets/undo.dart';
import '../settings/settings_screen.dart' show stateNames;

/// Adds an absence for one day or a date range, picked in one calendar
/// ([pickDateRange]). A range marks every date in it, weekends and holidays
/// too; only workdays use vacation days (calculations §10). [end] prefills a
/// range, e.g. school holidays.
Future<void> showAbsenceDialog(
  BuildContext context,
  WidgetRef ref, {
  required LocalDate initial,
  LocalDate? end,
  bool singleDay = false,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _AbsenceDialog(initial: initial, end: end, singleDay: singleDay),
);

class _AbsenceDialog extends ConsumerStatefulWidget {
  const _AbsenceDialog({
    required this.initial,
    required this.end,
    required this.singleDay,
  });

  final LocalDate initial;
  final LocalDate? end;
  final bool singleDay;

  @override
  ConsumerState<_AbsenceDialog> createState() => _AbsenceDialogState();
}

class _AbsenceDialogState extends ConsumerState<_AbsenceDialog> {
  late LocalDate _from = widget.initial;
  late LocalDate _to = widget.singleDay
      ? widget.initial
      : widget.end ?? widget.initial;
  AbsenceKind _kind = AbsenceKind.vacation;
  bool _half = false;

  Iterable<LocalDate> get _dates sync* {
    for (var d = _from; !d.isAfter(_to); d = d.addDays(1)) {
      yield d;
    }
  }

  Future<void> _save() async {
    final repo = ref.read(repositoryProvider);
    for (final d in _dates) {
      await repo.write('absences', repo.newId(), {
        'date': '$d',
        'kind': _kind.wireName,
        'fraction': _half ? 0.5 : 1,
      });
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pick() async {
    final l = context.l10n;
    final picked = await pickDateRange(
      context,
      start: _from,
      end: _to,
      today: ref.read(todayProvider),
      title: widget.singleDay ? l.absence : l.pickAbsenceStart,
      secondTitle: l.pickAbsenceEnd,
      single: widget.singleDay,
    );
    if (picked == null) return;
    setState(() {
      _from = picked.$1;
      _to = picked.$2 ?? picked.$1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final today = ref.watch(todayProvider);
    String day(LocalDate d) =>
        d.year == today.year ? context.shortDate(d) : context.date(d);
    // What the vacation account will count (calculations §10, §6.1).
    final targets = ref.watch(ledgerProvider).targets;
    final used = _dates.fold(
      0.0,
      (sum, d) => sum + targets.usedDays(d, _half ? 0.5 : 1),
    );
    return AlertDialog(
      title: Text(l.addAbsence),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<AbsenceKind>(
              // Long names ("Extra day off …") must not overflow the dialog.
              isExpanded: true,
              initialValue: _kind,
              decoration: InputDecoration(labelText: l.absence),
              items: [
                for (final k in AbsenceKind.values)
                  DropdownMenuItem(
                    value: k,
                    child: Text(context.absenceName(k)),
                  ),
              ],
              onChanged: (v) => setState(() => _kind = v ?? _kind),
            ),
            const SizedBox(height: 16),
            PickerField(
              label: widget.singleDay ? l.colDate : l.absenceDates,
              value: _from == _to ? day(_from) : '${day(_from)} – ${day(_to)}',
              icon: Icons.date_range,
              onTap: _pick,
            ),
            if (_kind == AbsenceKind.vacation)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Text(
                  l.absenceDaysUsed(context.days(used)),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.halfDay),
              value: _half,
              onChanged: (v) => setState(() => _half = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}

/// The year's bridge days, best first, each bookable as vacation
/// (calculations §10.1).
class BridgeCard extends ConsumerWidget {
  /// Creates the card for [year].
  const BridgeCard({
    super.key,
    required this.year,
    required this.bridges,
    required this.onNextYear,
  });

  /// The year shown.
  final int year;

  /// Its suggestions, best first.
  final List<BridgeSuggestion> bridges;

  /// Late in the year there may be none left: look at the next one.
  final VoidCallback onNextYear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    String range(LocalDate a, LocalDate b) =>
        '${context.shortDate(a)} – ${context.shortDate(b)}';
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.tertiary),
                const SizedBox(width: 8),
                Text(l.bridgeDays, style: theme.textTheme.titleMedium),
              ],
            ),
          ),
          if (bridges.isEmpty)
            ListTile(
              title: Text(l.noBridges(year)),
              trailing: TextButton.icon(
                onPressed: onNextYear,
                icon: const Icon(Icons.chevron_right),
                label: Text('${year + 1}'),
              ),
            ),
          for (final b in bridges.take(8))
            ListTile(
              title: Text(l.bridgeTitle(b.vacationDays.length, b.freeDays)),
              subtitle: Text(
                '${b.vacationDays.map(context.shortDate).join(', ')} · '
                '${range(b.freeFrom, b.freeTo)}',
              ),
              trailing: TextButton(
                onPressed: () => _book(context, ref, b),
                child: Text(l.bridgeBook),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _book(
    BuildContext context,
    WidgetRef ref,
    BridgeSuggestion b,
  ) async {
    final repo = ref.read(repositoryProvider);
    final created = <(String, String)>[];
    for (final d in b.vacationDays) {
      final id = repo.newId();
      await repo.write('absences', id, {
        'date': '$d',
        'kind': AbsenceKind.vacation.wireName,
        'fraction': 1,
      });
      created.add(('absences', id));
    }
    if (!context.mounted) return;
    offerUndoCreate(context, ref, created, context.l10n.bridgeBooked);
  }
}

/// The school holidays of the configured state in [year] (calculations
/// §10.5), each with a button to enter it as vacation.
class SchoolHolidayCard extends ConsumerWidget {
  /// Creates the card for [year].
  const SchoolHolidayCard({super.key, required this.year});

  /// The year shown.
  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final state = ref.watch(holidaysProvider).state;
    final periods = ref.watch(schoolHolidaysProvider(year));
    String day(LocalDate d) =>
        d.year == year ? context.shortDate(d) : context.date(d);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Icon(Icons.school_outlined, color: theme.colorScheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.schoolHolidays,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  stateNames[state] ?? state.code,
                  style: theme.textTheme.labelMedium?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          if (periods.isEmpty)
            ListTile(title: Text(l.schoolHolidaysNone(year))),
          for (final h in periods)
            ListTile(
              dense: true,
              enabled: !h.end.isBefore(today),
              title: Text(h.name),
              subtitle: Text(
                h.start == h.end
                    ? day(h.start)
                    : '${day(h.start)} – ${day(h.end)}',
              ),
              trailing: h.end.isBefore(today)
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: l.planVacation,
                      // Only what is still ahead.
                      onPressed: () => showAbsenceDialog(
                        context,
                        ref,
                        initial: h.start.isBefore(today) ? today : h.start,
                        end: h.end,
                      ),
                    ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              l.schoolHolidaysSource,
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// One month as a small grid: weekends muted, holidays red, absences and
/// trip days in their day type's colour (half days lighter), bridge days
/// outlined, today ringed, school holidays as a band behind the days. A tap
/// calls [onTap] with the day.
class MiniMonth extends ConsumerWidget {
  /// Creates the month starting [first].
  const MiniMonth({
    super.key,
    required this.first,
    required this.bridges,
    required this.tripDays,
    required this.onTap,
    this.schoolHolidays = const [],
  });

  /// The first of the month.
  final LocalDate first;

  /// Days suggested as bridge days.
  final Set<LocalDate> bridges;

  /// Dates on a business trip.
  final Set<LocalDate> tripDays;

  /// School holidays of the state (calculations §10.5).
  final List<SchoolHoliday> schoolHolidays;

  /// Called with the tapped day.
  final ValueChanged<LocalDate> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ledger = ref.watch(ledgerProvider);
    final holidays = ref.watch(holidaysProvider);
    final today = ref.watch(todayProvider);
    final absences = <LocalDate, Absence>{
      for (final a in ref.watch(ledgerDataProvider).absences)
        if (a.date.year == first.year && a.date.month == first.month) a.date: a,
    };
    final locale = Localizations.localeOf(context).toString();
    final days = first.addDays(31).startOfMonth.addDays(-1).day;
    final lead = first.weekday - 1;
    final weekdays = [
      for (var i = 0; i < 7; i++)
        DateFormat.E(locale).format(DateTime(2024, 1, 1 + i)).substring(0, 2),
    ];
    final small = theme.textTheme.labelSmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat.MMMM(locale).format(DateTime(first.year, first.month)),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final w in weekdays)
              Center(
                child: Text(
                  w,
                  style: small?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            for (var i = 0; i < lead; i++) const SizedBox.shrink(),
            for (var d = 1; d <= days; d++)
              _cell(
                context,
                ref,
                LocalDate(first.year, first.month, d),
                absence: absences[LocalDate(first.year, first.month, d)],
                holiday: holidays.isHoliday(
                  LocalDate(first.year, first.month, d),
                ),
                free:
                    ledger.targets.targetMinutes(
                      LocalDate(first.year, first.month, d),
                    ) ==
                    0,
                isToday: LocalDate(first.year, first.month, d) == today,
              ),
          ],
        ),
      ],
    );
  }

  Widget _cell(
    BuildContext context,
    WidgetRef ref,
    LocalDate date, {
    required Absence? absence,
    required bool holiday,
    required bool free,
    required bool isToday,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    bool school(LocalDate d) => schoolHolidays.any((h) => h.contains(d));
    // Rounded where a period or a week row starts or ends.
    const cap = Radius.circular(99);
    final band = school(date)
        ? Positioned.fill(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: schoolHolidayColor(scheme),
                borderRadius: BorderRadius.horizontal(
                  left:
                      date.weekday == DateTime.monday ||
                          !school(date.addDays(-1))
                      ? cap
                      : Radius.zero,
                  right:
                      date.weekday == DateTime.sunday ||
                          !school(date.addDays(1))
                      ? cap
                      : Radius.zero,
                ),
              ),
            ),
          )
        : null;
    final type = absence == null ? null : DayType.ofAbsence(absence.kind);
    final Color? fill = absence != null
        ? (type == null ? scheme.error : scheme.dayTypeColor(type)).withValues(
            alpha: absence.fraction < 1 ? 0.3 : 0.6,
          )
        : tripDays.contains(date)
        ? scheme.dayTypeColor(DayType.businessTrip).withValues(alpha: 0.6)
        : null;
    final textColor = holiday
        ? scheme.error
        : free
        ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
        : scheme.onSurface;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => onTap(date),
      child: Stack(
        children: [
          ?band,
          Positioned.fill(
            child: _dayCircle(
              theme,
              date,
              fill,
              textColor,
              holiday: holiday,
              isToday: isToday,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayCircle(
    ThemeData theme,
    LocalDate date,
    Color? fill,
    Color textColor, {
    required bool holiday,
    required bool isToday,
  }) {
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: isToday
            ? Border.all(color: scheme.primary, width: 2)
            : bridges.contains(date)
            ? Border.all(color: scheme.tertiary, width: 1.5)
            : null,
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '${date.day}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: textColor,
            fontWeight: holiday || isToday ? FontWeight.w700 : null,
          ),
        ),
      ),
    );
  }
}

/// The band colour of school holidays in the planner (calculations §10.5).
Color schoolHolidayColor(ColorScheme scheme) =>
    scheme.secondaryContainer.withValues(alpha: 0.8);

/// What the colours and rings of the year mean.
class PlannerLegend extends StatelessWidget {
  /// Creates the legend.
  const PlannerLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    Widget item(Widget dot, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [dot, const SizedBox(width: 6), Text(label)],
    );
    Widget dot({Color? fill, Color? ring}) => Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: ring == null ? null : Border.all(color: ring, width: 1.5),
      ),
    );
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        item(dot(ring: scheme.error), l.holiday),
        item(
          dot(
            fill: scheme.dayTypeColor(DayType.vacation).withValues(alpha: 0.6),
          ),
          l.absenceVacation,
        ),
        item(
          dot(fill: scheme.dayTypeColor(DayType.sick).withValues(alpha: 0.6)),
          l.otherAbsence,
        ),
        item(
          dot(
            fill: scheme
                .dayTypeColor(DayType.businessTrip)
                .withValues(alpha: 0.6),
          ),
          dayTypeLabel(l, DayType.businessTrip),
        ),
        item(
          Container(
            width: 22,
            height: 12,
            decoration: BoxDecoration(
              color: schoolHolidayColor(scheme),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          l.schoolHolidays,
        ),
        item(dot(ring: scheme.tertiary), l.bridgeDay),
        item(dot(ring: scheme.primary), l.navToday),
      ],
    );
  }
}
