import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../widgets/dialogs.dart';

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

/// Vacation account of the current year and all absences.
class AbsencesScreen extends ConsumerWidget {
  /// Creates the screen.
  const AbsencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final today = ref.watch(todayProvider);
    final data = ref.watch(ledgerDataProvider);
    final settings = ref.watch(settingsProvider);
    final account = vacationAccount(
      year: today.year,
      targets: ref.watch(ledgerProvider).targets,
      schedules: data.schedules,
      absences: data.absences,
      today: today,
      entitlementOverride: settings.number(
        SettingKeys.vacationEntitlement(today.year),
      ),
      carryOver:
          settings.number(SettingKeys.vacationCarryOver(today.year)) ?? 0,
    );
    final absences = [...data.absences]
      ..sort((a, b) => b.date.compareTo(a.date));
    return Scaffold(
      appBar: AppBar(title: Text(l.absences)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAbsenceDialog(context, ref, initial: today),
        icon: const Icon(Icons.add),
        label: Text(l.addAbsence),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.beach_access),
              title: Text(
                l.vacationLeft(
                  '${today.year}',
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
            ),
          ),
          for (final a in absences)
            ListTile(
              title: Text('${context.shortDate(a.date)} ${a.date.year}'),
              subtitle: Text(
                a.fraction < 1
                    ? '${context.absenceName(a.kind)} · ${l.halfDay}'
                    : context.absenceName(a.kind),
              ),
              trailing: IconButton(
                tooltip: l.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await confirmDelete(context)) {
                    await ref.read(repositoryProvider).delete('absences', a.id);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
