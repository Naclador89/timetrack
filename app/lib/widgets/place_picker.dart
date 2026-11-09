import 'package:flutter/material.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../app/format.dart';

/// Picks a country, then one of its BMF cities or the rest of the country
/// (calculations §13.0). Returns `null` if cancelled.
Future<TripPlace?> showPlacePicker(BuildContext context) =>
    showDialog<TripPlace>(context: context, builder: (_) => const _Picker());

/// The cities with their own BMF rate, by country.
final _cities = () {
  final out = <String, List<String>>{};
  for (final (country, city, _, _, _) in bmfRates2026) {
    if (city != null) (out[country] ??= []).add(city);
  }
  return out;
}();

class _Picker extends StatefulWidget {
  const _Picker();

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  String _query = '';
  String? _country;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final country = _country;
    final q = _query.trim().toLowerCase();
    final countries =
        bmfCountryNames.entries
            .where(
              (e) =>
                  q.isEmpty ||
                  e.value.toLowerCase().contains(q) ||
                  e.key.toLowerCase() == q ||
                  (_cities[e.key] ?? const []).any(
                    (c) => c.toLowerCase().contains(q),
                  ),
            )
            .toList()
          // Germany first, then by name.
          ..sort(
            (a, b) => a.key == 'DE'
                ? -1
                : b.key == 'DE'
                ? 1
                : a.value.compareTo(b.value),
          );
    return AlertDialog(
      title: Text(country == null ? l.country : countryName(country)),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: SizedBox(
        width: 400,
        height: 420,
        child: country == null
            ? Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: l.searchCountry,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final e in countries)
                          ListTile(
                            title: Text(e.value),
                            trailing: Text(e.key),
                            onTap: () => _cities.containsKey(e.key)
                                ? setState(() => _country = e.key)
                                : Navigator.pop(context, TripPlace(e.key)),
                          ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView(
                children: [
                  ListTile(
                    title: Text(l.restOfCountry),
                    onTap: () => Navigator.pop(context, TripPlace(country)),
                  ),
                  for (final city in _cities[country]!)
                    ListTile(
                      title: Text(city),
                      onTap: () =>
                          Navigator.pop(context, TripPlace(country, city)),
                    ),
                ],
              ),
      ),
      actions: [
        if (country != null)
          TextButton(
            onPressed: () => setState(() => _country = null),
            child: Text(l.back),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
      ],
    );
  }
}
