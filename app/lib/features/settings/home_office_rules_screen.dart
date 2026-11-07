import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../widgets/dialogs.dart';

/// Home-office quota rules (calculations.md §11.2). Rules with the same
/// period are versions; the one valid at the start of a period applies.
class HomeOfficeRulesScreen extends ConsumerWidget {
  /// Creates the screen.
  const HomeOfficeRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final rules = ref.watch(homeOfficeRulesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.homeOfficeRules)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) =>
              _RuleDialog(validFrom: ref.read(todayProvider).startOfMonth),
        ),
        icon: const Icon(Icons.add),
        label: Text(l.newRule),
      ),
      body: ListView(
        children: [
          for (final r in rules)
            ListTile(
              leading: Icon(locationIcon(WorkLocation.home)),
              title: Text(ruleSummary(context, r)),
              subtitle: Text('${l.validFrom} ${context.date(r.validFrom)}'),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    _RuleDialog(existing: r, validFrom: r.validFrom),
              ),
            ),
        ],
      ),
    );
  }
}

/// E.g. "40 % per month of days worked".
String ruleSummary(BuildContext context, HomeOfficeRule r) {
  final l = context.l10n;
  return l.ruleSummary(
    '${r.maxPercent}',
    r.period == QuotaPeriod.week ? l.perWeek : l.perMonth,
    r.basis == QuotaBasis.worked ? l.basisWorked : l.basisScheduled,
  );
}

class _RuleDialog extends ConsumerStatefulWidget {
  const _RuleDialog({this.existing, required this.validFrom});

  final HomeOfficeRule? existing;
  final LocalDate validFrom;

  @override
  ConsumerState<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends ConsumerState<_RuleDialog> {
  late LocalDate _validFrom = widget.validFrom;
  late QuotaPeriod _period = widget.existing?.period ?? QuotaPeriod.month;
  late QuotaBasis _basis = widget.existing?.basis ?? QuotaBasis.worked;
  late final _percent = TextEditingController(
    text: '${widget.existing?.maxPercent ?? 40}',
  );
  String? _error;

  @override
  void dispose() {
    _percent.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final percent = int.tryParse(_percent.text.trim());
    if (percent == null || percent < 0 || percent > 100) {
      setState(() => _error = context.l10n.invalidValue);
      return;
    }
    final repo = ref.read(repositoryProvider);
    await repo.write('home_office_rules', widget.existing?.id ?? repo.newId(), {
      'valid_from': '$_validFrom',
      'period': _period.name,
      'unit': QuotaUnit.days.name,
      'max_percent': percent,
      'basis': _basis.name,
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.existing == null ? l.newRule : l.homeOfficeRules),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DateTile(
              label: l.validFrom,
              value: _validFrom,
              onChanged: (d) => setState(() => _validFrom = d),
            ),
            SegmentedButton<QuotaPeriod>(
              segments: [
                ButtonSegment(value: QuotaPeriod.week, label: Text(l.perWeek)),
                ButtonSegment(
                  value: QuotaPeriod.month,
                  label: Text(l.perMonth),
                ),
              ],
              selected: {_period},
              onSelectionChanged: (v) => setState(() => _period = v.single),
            ),
            TextField(
              controller: _percent,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l.maxPercent,
                errorText: _error,
              ),
            ),
            DropdownButtonFormField<QuotaBasis>(
              initialValue: _basis,
              items: [
                DropdownMenuItem(
                  value: QuotaBasis.worked,
                  child: Text(l.basisWorked),
                ),
                DropdownMenuItem(
                  value: QuotaBasis.scheduled,
                  child: Text(l.basisScheduled),
                ),
              ],
              onChanged: (v) => setState(() => _basis = v ?? _basis),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () async {
              if (await confirmDelete(context)) {
                await ref
                    .read(repositoryProvider)
                    .delete('home_office_rules', widget.existing!.id);
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
