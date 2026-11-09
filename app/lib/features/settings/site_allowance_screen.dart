import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/undo.dart';
import 'per_diem_rates_screen.dart' show parseCents;

/// The employer's site allowance per day and country (calculations.md
/// §13.4); none is built in. Country `*` covers every other country.
class SiteAllowanceScreen extends ConsumerWidget {
  /// Creates the screen.
  const SiteAllowanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final rates = [...ref.watch(ledgerDataProvider).siteAllowances]
      ..sort((a, b) {
        final byName = _name(
          context,
          a.country,
        ).compareTo(_name(context, b.country));
        return byName != 0 ? byName : b.validFrom.compareTo(a.validFrom);
      });
    return Scaffold(
      appBar: AppBar(title: Text(l.siteAllowance)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null, today),
        icon: const Icon(Icons.add),
        label: Text(l.newRate),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              l.siteAllowanceRatesHint,
              style: theme.textTheme.bodySmall,
            ),
          ),
          for (final r in rates)
            ListTile(
              leading: const Icon(Icons.construction_outlined),
              title: Text(
                '${_name(context, r.country)}: ${context.euro(r.cents)}',
              ),
              subtitle: Text('${l.validFrom} ${context.date(r.validFrom)}'),
              trailing:
                  identical(siteAllowanceOn(rates, r.country, today), r) &&
                      r.country != '*'
                  ? Chip(label: Text(l.rateInUse))
                  : null,
              onTap: () => _edit(context, r, r.validFrom),
            ),
        ],
      ),
    );
  }

  static String _name(BuildContext context, String code) =>
      code == '*' ? context.l10n.allOtherCountries : countryName(code);

  Future<void> _edit(
    BuildContext context,
    SiteAllowanceRate? existing,
    LocalDate validFrom,
  ) => showDialog<void>(
    context: context,
    builder: (_) => _Dialog(existing: existing, validFrom: validFrom),
  );
}

class _Dialog extends ConsumerStatefulWidget {
  const _Dialog({this.existing, required this.validFrom});

  final SiteAllowanceRate? existing;
  final LocalDate validFrom;

  @override
  ConsumerState<_Dialog> createState() => _DialogState();
}

class _DialogState extends ConsumerState<_Dialog> {
  late LocalDate _validFrom = widget.validFrom;
  late final _country = TextEditingController(
    text: widget.existing?.country ?? '*',
  );
  late final _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        : (widget.existing!.cents / 100).toStringAsFixed(2),
  );
  String? _error;

  @override
  void dispose() {
    _country.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final country = _country.text.trim().toUpperCase();
    final cents = parseCents(_amount.text);
    if (!RegExp(r'^([A-Z]{2}|\*)$').hasMatch(country) || cents == null) {
      setState(() => _error = context.l10n.invalidValue);
      return;
    }
    final repo = ref.read(repositoryProvider);
    await repo.write('site_allowances', widget.existing?.id ?? repo.newId(), {
      'country': country,
      'valid_from': '$_validFrom',
      'cents': cents,
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final existing = widget.existing;
    return AlertDialog(
      title: Text(l.siteAllowance),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _country,
              textCapitalization: TextCapitalization.characters,
              maxLength: 2,
              decoration: InputDecoration(
                labelText: l.countryIso,
                helperText: l.siteAllowanceCountryHint,
              ),
            ),
            DateTile(
              label: l.validFrom,
              value: _validFrom,
              onChanged: (d) => setState(() => _validFrom = d),
            ),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l.perSiteDay,
                suffixText: '€',
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (existing != null)
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await deleteWithUndo(context, ref, [
                ('site_allowances', existing.id),
              ]);
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
