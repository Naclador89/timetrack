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

/// The vacation planner (calculations §10, §10.1): a year at a glance with
/// holidays and absences, the vacation account, bridge days to book with
/// one tap, and the year's absences.
class AbsencesScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const AbsencesScreen({super.key});

  @override
  ConsumerState<AbsencesScreen> createState() => _AbsencesScreenState();
}

class _AbsencesScreenState extends ConsumerState<AbsencesScreen> {
  late int _year = ref.read(todayProvider).year;

  /// Asks for the days carried into [_year]; unset, it suggests what was
  /// left of the year before.
  Future<void> _editCarryOver(VacationAccount account) async {
    final l = context.l10n;
    final settings = ref.read(settingsProvider);
    final key = SettingKeys.vacationCarryOver(_year);
    var initial = settings.number(key);
    if (initial == null) {
      final data = ref.read(ledgerDataProvider);
      final last = vacationAccount(
        year: _year - 1,
        targets: ref.read(ledgerProvider).targets,
        schedules: data.schedules,
        absences: data.absences,
        today: ref.read(todayProvider),
        entitlementOverride: settings.number(
          SettingKeys.vacationEntitlement(_year - 1),
        ),
        carryOver:
            settings.number(SettingKeys.vacationCarryOver(_year - 1)) ?? 0,
      );
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final ledger = ref.watch(ledgerProvider);
    final data = ref.watch(ledgerDataProvider);
    final settings = ref.watch(settingsProvider);
    final account = vacationAccount(
      year: _year,
      targets: ledger.targets,
      schedules: data.schedules,
      absences: data.absences,
      today: today,
      entitlementOverride: settings.number(
        SettingKeys.vacationEntitlement(_year),
      ),
      carryOver: settings.number(SettingKeys.vacationCarryOver(_year)) ?? 0,
    );
    final bridges = bridgeDays(ledger, _year, today: today);
    final bridgeSet = {for (final b in bridges) ...b.vacationDays};
    final absences = data.absences.where((a) => a.date.year == _year).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return Scaffold(
      appBar: AppBar(title: Text(l.vacationPlanner)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAbsenceDialog(context, ref, initial: today),
        icon: const Icon(Icons.add),
        label: Text(l.addAbsence),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
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
              Card(
                child: ListTile(
                  leading: const Icon(Icons.beach_access),
                  title: Text(
                    l.vacationLeft(
                      '$_year',
                      context.days(account.remaining),
                      context.days(account.entitlement + account.carryOver),
                    ),
                  ),
                  subtitle: Text(
                    l.vacationTakenPlanned(
                      context.days(account.taken),
                      context.days(account.planned),
                    ),
                  ),
                  // calculations §10: the carry-over is a setting per year.
                  trailing: IconButton(
                    tooltip: l.vacationCarryOver,
                    icon: const Icon(Icons.edit_calendar_outlined),
                    onPressed: () => _editCarryOver(account),
                  ),
                ),
              ),
              if (_year >= today.year)
                _BridgeCard(
                  year: _year,
                  bridges: bridges,
                  onNextYear: () => setState(() => _year++),
                ),
              Card(
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
                          final width =
                              (box.maxWidth - 16 * (columns - 1)) / columns;
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              for (var m = 1; m <= 12; m++)
                                SizedBox(
                                  width: width,
                                  child: _MiniMonth(
                                    first: LocalDate(_year, m, 1),
                                    bridges: bridgeSet,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      const _Legend(),
                    ],
                  ),
                ),
              ),
              if (absences.isNotEmpty)
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          l.absencesOfYear(_year),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      for (final a in absences)
                        ListTile(
                          title: Text(context.longDate(a.date)),
                          subtitle: Text(
                            a.fraction < 1
                                ? '${context.absenceName(a.kind)} · ${l.halfDay}'
                                : context.absenceName(a.kind),
                          ),
                          trailing: IconButton(
                            tooltip: l.delete,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => deleteWithUndo(context, ref, [
                              ('absences', a.id),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The year's bridge days, best first, each bookable as vacation.
class _BridgeCard extends ConsumerWidget {
  const _BridgeCard({
    required this.year,
    required this.bridges,
    required this.onNextYear,
  });

  final int year;
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

/// One month as a small grid: weekends muted, holidays red, absences in
/// their day type's colour (half days lighter), bridge days outlined, today
/// ringed. A tap adds an absence from that day.
class _MiniMonth extends ConsumerWidget {
  const _MiniMonth({required this.first, required this.bridges});

  final LocalDate first;
  final Set<LocalDate> bridges;

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
    final Color? fill = absence == null
        ? null
        : (type == null ? scheme.error : scheme.dayTypeColor(type)).withValues(
            alpha: absence.fraction < 1 ? 0.3 : 0.6,
          );
    final textColor = holiday
        ? scheme.error
        : free
        ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
        : scheme.onSurface;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => showAbsenceDialog(context, ref, initial: date),
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
class _Legend extends StatelessWidget {
  const _Legend();

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
        item(dot(ring: scheme.tertiary), l.bridgeDay),
        item(dot(ring: scheme.primary), l.navToday),
      ],
    );
  }
}
