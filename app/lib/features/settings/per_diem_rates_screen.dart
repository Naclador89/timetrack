import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/undo.dart';

/// Per-diem and lodging rates per country and city (calculations.md §13.0).
/// Rows of one place are versions: a trip day uses the newest one valid on
/// that day. Built-in rows (Germany, the BMF table) can't be changed, only
/// superseded by a newer row. Without a search only Germany and the places
/// with own rows are listed.
class PerDiemRatesScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const PerDiemRatesScreen({super.key});

  @override
  ConsumerState<PerDiemRatesScreen> createState() => _PerDiemRatesState();
}

class _PerDiemRatesState extends ConsumerState<PerDiemRatesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final rates = ref.watch(perDiemRatesProvider);
    final today = ref.watch(todayProvider);
    final byPlace = <TripPlace, List<PerDiemRate>>{};
    for (final r in rates) {
      (byPlace[TripPlace(r.country, r.city)] ??= []).add(r);
    }
    final q = _query.trim().toLowerCase();
    bool shown(TripPlace p) => q.isEmpty
        ? p.country == 'DE' || byPlace[p]!.any((r) => !_isBuiltIn(r))
        : placeLabel(p).toLowerCase().contains(q) ||
              p.country.toLowerCase() == q;
    final places = byPlace.keys.where(shown).toList()
      ..sort(
        (a, b) => a.country == 'DE' && b.country != 'DE'
            ? -1
            : b.country == 'DE' && a.country != 'DE'
            ? 1
            : placeLabel(a).compareTo(placeLabel(b)),
      );
    return Scaffold(
      appBar: AppBar(title: Text(l.perDiemRates)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, validFrom: today),
        icon: const Icon(Icons.add),
        label: Text(l.newRate),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(l.perDiemRatesHint, style: theme.textTheme.bodySmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SearchBar(
              hintText: l.searchCountry,
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          for (final place in places) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                '${placeLabel(place)} (${place.country})',
                style: theme.textTheme.titleSmall,
              ),
            ),
            for (final r
                in byPlace[place]!.toList()
                  ..sort((a, b) => b.validFrom.compareTo(a.validFrom)))
              _RateTile(
                rate: r,
                inUse: identical(
                  perDiemRateOn(rates, place.country, today, city: place.city),
                  r,
                ),
                onTap: () => _isBuiltIn(r)
                    ? _edit(context, copyOf: r, validFrom: today)
                    : _edit(context, existing: r, validFrom: r.validFrom),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context, {
    PerDiemRate? existing,
    PerDiemRate? copyOf,
    required LocalDate validFrom,
  }) => showDialog<void>(
    context: context,
    builder: (_) => _RateDialog(
      existing: existing,
      template: existing ?? copyOf,
      validFrom: validFrom,
    ),
  );
}

bool _isBuiltIn(PerDiemRate r) =>
    r.id.startsWith('default-') || r.id.startsWith('bmf-');

String _euro(BuildContext context, int cents) => NumberFormat.currency(
  locale: Localizations.localeOf(context).toString(),
  symbol: '€',
).format(cents / 100);

class _RateTile extends StatelessWidget {
  const _RateTile({
    required this.rate,
    required this.inUse,
    required this.onTap,
  });

  final PerDiemRate rate;
  final bool inUse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final builtIn = _isBuiltIn(rate);
    return ListTile(
      leading: Icon(builtIn ? Icons.lock_outline : Icons.restaurant_outlined),
      title: Text(
        [
          l.rateAmounts(
            _euro(context, rate.partialCents),
            _euro(context, rate.fullCents),
          ),
          if (rate.lodgingCents case final c?)
            '${l.lodging} ${_euro(context, c)}',
        ].join(' · '),
      ),
      subtitle: Text(
        [
          '${l.validFrom} ${context.date(rate.validFrom)}',
          if (builtIn) l.builtInRate,
        ].join(' · '),
      ),
      trailing: inUse ? Chip(label: Text(l.rateInUse)) : null,
      onTap: onTap,
    );
  }
}

class _RateDialog extends ConsumerStatefulWidget {
  const _RateDialog({this.existing, this.template, required this.validFrom});

  /// The user row being edited; null creates a new row.
  final PerDiemRate? existing;

  /// Values to start from (the edited row, or a row to supersede).
  final PerDiemRate? template;
  final LocalDate validFrom;

  @override
  ConsumerState<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends ConsumerState<_RateDialog> {
  late LocalDate _validFrom = widget.validFrom;
  late final _country = TextEditingController(
    text: widget.template?.country ?? 'DE',
  );
  late final _partial = TextEditingController(
    text: _amount(widget.template?.partialCents),
  );
  late final _full = TextEditingController(
    text: _amount(widget.template?.fullCents),
  );
  late final _city = TextEditingController(text: widget.template?.city);
  late final _lodging = TextEditingController(
    text: _amount(widget.template?.lodgingCents),
  );
  String? _error;

  static String _amount(int? cents) => cents == null
      ? ''
      : '${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _country.dispose();
    _partial.dispose();
    _full.dispose();
    _city.dispose();
    _lodging.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final country = _country.text.trim().toUpperCase();
    final partial = parseCents(_partial.text);
    final full = parseCents(_full.text);
    final lodging = parseCents(_lodging.text);
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(country) ||
        partial == null ||
        full == null ||
        (_lodging.text.trim().isNotEmpty && lodging == null)) {
      setState(() => _error = context.l10n.invalidValue);
      return;
    }
    final repo = ref.read(repositoryProvider);
    await repo.write('per_diem_rates', widget.existing?.id ?? repo.newId(), {
      'country': country,
      'valid_from': '$_validFrom',
      'partial_cents': partial,
      'full_cents': full,
      'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
      'lodging_cents': lodging,
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final existing = widget.existing;
    return AlertDialog(
      title: Text(existing == null ? l.newRate : l.perDiemRates),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _country,
                textCapitalization: TextCapitalization.characters,
                maxLength: 2,
                decoration: InputDecoration(labelText: l.countryIso),
              ),
              TextField(
                controller: _city,
                decoration: InputDecoration(labelText: l.cityOptional),
              ),
              DateTile(
                label: l.validFrom,
                value: _validFrom,
                onChanged: (d) => setState(() => _validFrom = d),
              ),
              TextField(
                controller: _partial,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l.partialDayRate,
                  suffixText: '€',
                ),
              ),
              TextField(
                controller: _full,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l.fullDayRate,
                  suffixText: '€',
                ),
              ),
              TextField(
                controller: _lodging,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l.lodgingRate,
                  suffixText: '€',
                  errorText: _error,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (existing != null)
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await deleteWithUndo(context, ref, [
                ('per_diem_rates', existing.id),
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

/// "14", "14,5", "14.50" or "1.234,56" → cents; null if not an amount.
int? parseCents(String text) {
  var t = text.trim().replaceAll('€', '').replaceAll(' ', '');
  if (t.isEmpty) return null;
  // The last separator is the decimal one when 1–2 digits follow it.
  final m = RegExp(r'^(.*?)[.,](\d{1,2})$').firstMatch(t);
  final whole = (m?.group(1) ?? t).replaceAll(RegExp('[.,]'), '');
  final frac = m?.group(2) ?? '';
  final euros = int.tryParse(whole.isEmpty ? '0' : whole);
  if (euros == null || euros < 0) return null;
  return euros * 100 + (frac.isEmpty ? 0 : int.parse(frac.padRight(2, '0')));
}
