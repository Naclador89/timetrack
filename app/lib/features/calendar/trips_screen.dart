import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../widgets/dialogs.dart';

/// All business trips; tap to edit, + to add one afterwards.
class TripsScreen extends ConsumerWidget {
  /// Creates the screen.
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final zone = ref.watch(zoneProvider);
    final trips = [...ref.watch(ledgerDataProvider).trips]
      ..sort((a, b) => b.depart.compareTo(a.depart));
    String when(DateTime t) =>
        '${context.date(zone.dateOf(t))} ${context.time(t, zone)}';
    return Scaffold(
      appBar: AppBar(title: Text(l.trips)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _TripDialog(),
        ),
        icon: const Icon(Icons.add),
        label: Text(l.newTrip),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          for (final t in trips)
            ListTile(
              leading: const Icon(Icons.luggage_outlined),
              title: Text(
                t.destination.isEmpty
                    ? l.tripDay
                    : '${t.destination} (${t.country})',
              ),
              subtitle: Text(
                '${when(t.depart)} – ${t.returnAt == null ? l.running : when(t.returnAt!)}',
              ),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => _TripDialog(trip: t),
              ),
            ),
        ],
      ),
    );
  }
}

class _TripDialog extends ConsumerStatefulWidget {
  const _TripDialog({this.trip});

  final Trip? trip;

  @override
  ConsumerState<_TripDialog> createState() => _TripDialogState();
}

class _TripDialogState extends ConsumerState<_TripDialog> {
  late final _destination = TextEditingController(
    text: widget.trip?.destination,
  );
  late final _country = TextEditingController(
    text: widget.trip?.country ?? 'DE',
  );
  late bool _overnight = widget.trip?.overnight ?? true;
  late LocalDate _departDate;
  late int _departTime;
  LocalDate? _returnDate;
  int? _returnTime;
  String? _error;

  @override
  void initState() {
    super.initState();
    final zone = ref.read(zoneProvider);
    final today = ref.read(todayProvider);
    (LocalDate, int) split(DateTime t) {
      final local = zone.toLocal(t);
      return (zone.dateOf(t), local.hour * 60 + local.minute);
    }

    final t = widget.trip;
    final (departDate, departTime) = t == null
        ? (today, 7 * 60)
        : split(t.depart);
    _departDate = departDate;
    _departTime = departTime;
    if (t == null) {
      _returnDate = today;
      _returnTime = 19 * 60;
    } else if (t.returnAt != null) {
      final (d, m) = split(t.returnAt!);
      _returnDate = d;
      _returnTime = m;
    }
  }

  @override
  void dispose() {
    _destination.dispose();
    _country.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final zone = ref.read(zoneProvider);
    final depart = zone.instantAt(
      _departDate,
      _departTime ~/ 60,
      _departTime % 60,
    );
    final back = _returnDate == null
        ? null
        : zone.instantAt(_returnDate!, _returnTime! ~/ 60, _returnTime! % 60);
    if (back != null && !back.isAfter(depart)) {
      setState(() => _error = context.l10n.endBeforeStart);
      return;
    }
    final repo = ref.read(repositoryProvider);
    await repo.write('trips', widget.trip?.id ?? repo.newId(), {
      'depart_utc': isoMinute(depart),
      'return_utc': back == null ? null : isoMinute(back),
      'destination': _destination.text.trim(),
      'country': _country.text.trim().toUpperCase().isEmpty
          ? 'DE'
          : _country.text.trim().toUpperCase(),
      'overnight': _overnight,
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.trip == null ? l.newTrip : l.tripDay),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _destination,
                decoration: InputDecoration(labelText: l.destination),
              ),
              TextField(
                controller: _country,
                decoration: InputDecoration(labelText: l.country),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.overnight),
                value: _overnight,
                onChanged: (v) => setState(() => _overnight = v),
              ),
              DateTile(
                label: l.depart,
                value: _departDate,
                onChanged: (d) => setState(() => _departDate = d),
              ),
              TimeTile(
                label: l.depart,
                minutes: _departTime,
                onChanged: (m) => setState(() => _departTime = m),
              ),
              DateTile(
                label: l.returnTime,
                value: _returnDate ?? _departDate,
                onChanged: (d) => setState(() {
                  _returnDate = d;
                  _returnTime ??= 19 * 60;
                }),
              ),
              TimeTile(
                label: l.returnTime,
                minutes: _returnDate == null ? null : _returnTime,
                onChanged: (m) => setState(() {
                  _returnTime = m;
                  _returnDate ??= _departDate;
                }),
                onClear: () => setState(() {
                  _returnDate = null;
                  _returnTime = null;
                }),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.trip != null)
          TextButton(
            onPressed: () async {
              if (await confirmDelete(context)) {
                await ref
                    .read(repositoryProvider)
                    .delete('trips', widget.trip!.id);
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
