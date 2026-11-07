import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../widgets/dialogs.dart';

const _days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// Work schedules (contracts) with their validity (calculations.md §7).
class SchedulesScreen extends ConsumerWidget {
  /// Creates the screen.
  const SchedulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final schedules = [...ref.watch(ledgerDataProvider).schedules]
      ..sort((a, b) => b.validFrom.compareTo(a.validFrom));
    return Scaffold(
      appBar: AppBar(title: Text(l.schedules)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => _ScheduleDialog(
            template: schedules.isEmpty ? null : schedules.first,
            validFrom: ref.read(todayProvider),
          ),
        ),
        icon: const Icon(Icons.add),
        label: Text(l.newSchedule),
      ),
      body: ListView(
        children: [
          for (final s in schedules)
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text('${l.validFrom} ${context.date(s.validFrom)}'),
              subtitle: Text(
                l.perWeekSummary(
                  formatMinutes(s.weekdayMinutes.fold(0, (a, b) => a + b)),
                  context.days(s.annualVacationDays),
                ),
              ),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    _ScheduleDialog(existing: s, validFrom: s.validFrom),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScheduleDialog extends ConsumerStatefulWidget {
  const _ScheduleDialog({
    this.existing,
    this.template,
    required this.validFrom,
  });

  final WorkSchedule? existing;
  final WorkSchedule? template;
  final LocalDate validFrom;

  @override
  ConsumerState<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends ConsumerState<_ScheduleDialog> {
  late LocalDate _validFrom = widget.validFrom;
  late final List<TextEditingController> _minutes;
  late final _vacation = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final base = widget.existing ?? widget.template;
    _minutes = [
      for (var i = 0; i < 7; i++)
        TextEditingController(
          text: formatMinutes(base?.weekdayMinutes[i] ?? (i < 5 ? 480 : 0)),
        ),
    ];
    _vacation.text = (base?.annualVacationDays ?? 30).toString().replaceAll(
      RegExp(r'\.0$'),
      '',
    );
  }

  @override
  void dispose() {
    for (final c in [..._minutes, _vacation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final minutes = [for (final c in _minutes) parseHours(c.text)];
    final vacation = double.tryParse(_vacation.text.replaceAll(',', '.'));
    if (minutes.any((m) => m == null || m < 0 || m > 1440) ||
        vacation == null) {
      setState(() => _error = context.l10n.invalidValue);
      return;
    }
    final repo = ref.read(repositoryProvider);
    await repo.write('work_schedules', widget.existing?.id ?? repo.newId(), {
      'valid_from': '$_validFrom',
      for (var i = 0; i < 7; i++) 'minutes_${_days[i]}': minutes[i],
      'vacation_days': vacation,
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    // 2024-01-01 was a Monday.
    String weekday(int i) =>
        DateFormat.E(locale).format(DateTime(2024, 1, 1 + i));
    return AlertDialog(
      title: Text(widget.existing == null ? l.newSchedule : l.schedules),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DateTile(
                label: l.validFrom,
                value: _validFrom,
                onChanged: (d) => setState(() => _validFrom = d),
              ),
              Text(
                l.hoursPerWeekday,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < 7; i++)
                    SizedBox(
                      width: 72,
                      child: TextField(
                        controller: _minutes[i],
                        decoration: InputDecoration(labelText: weekday(i)),
                      ),
                    ),
                ],
              ),
              TextField(
                controller: _vacation,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: l.vacationDays),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () async {
              if (await confirmDelete(context)) {
                await ref
                    .read(repositoryProvider)
                    .delete('work_schedules', widget.existing!.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Text(l.delete),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}
