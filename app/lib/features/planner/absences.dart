import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/undo.dart';

/// Adds an absence for one day or a date range. Range entries are only
/// written for workdays (vacation on a weekend wouldn't count anyway, §10).
Future<void> showAbsenceDialog(
  BuildContext context,
  WidgetRef ref, {
  required LocalDate initial,
  bool singleDay = false,
}) => showDialog<void>(
  context: context,
  builder: (_) => _AbsenceDialog(initial: initial, singleDay: singleDay),
);

class _AbsenceDialog extends ConsumerStatefulWidget {
  const _AbsenceDialog({required this.initial, required this.singleDay});

  final LocalDate initial;
  final bool singleDay;

  @override
  ConsumerState<_AbsenceDialog> createState() => _AbsenceDialogState();
}

class _AbsenceDialogState extends ConsumerState<_AbsenceDialog> {
  late LocalDate _from = widget.initial;
  late LocalDate _to = widget.initial;
  AbsenceKind _kind = AbsenceKind.vacation;
  bool _half = false;

  Future<void> _save() async {
    final repo = ref.read(repositoryProvider);
    final targets = ref.read(ledgerProvider).targets;
    for (var d = _from; !d.isAfter(_to); d = d.addDays(1)) {
      final single = _from == _to;
      if (!single &&
          _kind != AbsenceKind.extraHoliday &&
          !targets.isWorkday(d)) {
        continue;
      }
      await repo.write('absences', repo.newId(), {
        'date': '$d',
        'kind': _kind.wireName,
        'fraction': _half ? 0.5 : 1,
      });
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.addAbsence),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            DateTile(
              label: widget.singleDay ? l.absence : l.from,
              value: _from,
              onChanged: (d) => setState(() {
                _from = d;
                if (_to.isBefore(d) || widget.singleDay) _to = d;
              }),
            ),
            if (!widget.singleDay)
              DateTile(
                label: l.to,
                value: _to,
                onChanged: (d) =>
                    setState(() => _to = d.isBefore(_from) ? _from : d),
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

/// One month as a small grid: weekends muted, holidays red, absences and
/// trip days in their day type's colour (half days lighter), bridge days
/// outlined, today ringed. A tap calls [onTap] with the day.
class MiniMonth extends ConsumerWidget {
  /// Creates the month starting [first].
  const MiniMonth({
    super.key,
    required this.first,
    required this.bridges,
    required this.tripDays,
    required this.onTap,
  });

  /// The first of the month.
  final LocalDate first;

  /// Days suggested as bridge days.
  final Set<LocalDate> bridges;

  /// Dates on a business trip.
  final Set<LocalDate> tripDays;

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
      child: Container(
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
      ),
    );
  }
}

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
        item(dot(ring: scheme.tertiary), l.bridgeDay),
        item(dot(ring: scheme.primary), l.navToday),
      ],
    );
  }
}
