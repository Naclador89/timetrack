import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../widgets/dialogs.dart';
import '../projects/project_picker.dart';
import '../reports/report_documents.dart' show projectLabel;

/// All business trips; tap to edit, + to add one afterwards.
class TripsScreen extends ConsumerWidget {
  /// Creates the screen.
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final zone = ref.watch(zoneProvider);
    final projects = ref.watch(projectByIdProvider);
    final trips = [...ref.watch(ledgerDataProvider).trips]
      ..sort((a, b) => b.depart.compareTo(a.depart));
    String when(DateTime t) =>
        '${context.date(zone.dateOf(t))} ${context.time(t, zone)}';
    return Scaffold(
      appBar: AppBar(title: Text(l.trips)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTripDialog(context),
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
                [
                  '${when(t.depart)} – ${t.returnAt == null ? l.running : when(t.returnAt!)}',
                  if (projects[t.projectId] case final p?) projectLabel(p),
                ].join('\n'),
              ),
              onTap: () => showTripDialog(context, trip: t),
            ),
        ],
      ),
    );
  }
}

/// Opens the trip dialog for [trip], or for a new trip. A new trip departs
/// on [date] (default today) at [departMinutes] and returns the same day at
/// [returnMinutes] (minutes after midnight), or has no return yet if
/// [openEnded] (a trip starting now). Returns whether it was saved.
Future<bool> showTripDialog(
  BuildContext context, {
  Trip? trip,
  LocalDate? date,
  int? departMinutes,
  int? returnMinutes,
  bool openEnded = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _TripDialog(
        trip: trip,
        date: date,
        departMinutes: departMinutes,
        returnMinutes: returnMinutes,
        openEnded: openEnded,
      ),
    ) ??
    false;

class _TripDialog extends ConsumerStatefulWidget {
  const _TripDialog({
    this.trip,
    this.date,
    this.departMinutes,
    this.returnMinutes,
    this.openEnded = false,
  });

  final Trip? trip;
  final LocalDate? date;
  final int? departMinutes;
  final int? returnMinutes;
  final bool openEnded;

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
  late String? _projectId = widget.trip?.projectId;
  late LocalDate _departDate;
  late int _departTime;
  LocalDate? _returnDate;
  int? _returnTime;
  String? _error;
  late final String _id =
      widget.trip?.id ?? ref.read(repositoryProvider).newId();

  /// Provided meals per trip day: (breakfast, lunch, dinner), §13.
  late final Map<LocalDate, (bool, bool, bool)> _meals = {
    for (final m in ref.read(tripMealsProvider))
      if (m.tripId == _id) m.date: (m.breakfast, m.lunch, m.dinner),
  };
  late final Map<LocalDate, (bool, bool, bool)> _storedMeals = {..._meals};

  /// Trip days for the meal checkboxes (only for closed trips up to 31 days).
  List<LocalDate> get _tripDays {
    final back = _returnDate;
    if (back == null || back.isBefore(_departDate)) return const [];
    if (_departDate.daysUntil(back) > 30) return const [];
    return [for (var d = _departDate; !d.isAfter(back); d = d.addDays(1)) d];
  }

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
    final day = widget.date ?? today;
    final (departDate, departTime) = t == null
        ? (day, widget.departMinutes ?? 7 * 60)
        : split(t.depart);
    _departDate = departDate;
    _departTime = departTime;
    if (t == null && !widget.openEnded) {
      _returnDate = day;
      _returnTime = widget.returnMinutes ?? 19 * 60;
    } else if (t?.returnAt case final back?) {
      final (d, m) = split(back);
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
    await repo.write('trips', _id, {
      'depart_utc': isoMinute(depart),
      'return_utc': back == null ? null : isoMinute(back),
      'destination': _destination.text.trim(),
      'country': _country.text.trim().toUpperCase().isEmpty
          ? 'DE'
          : _country.text.trim().toUpperCase(),
      'overnight': _overnight,
      'project_id': _projectId,
    });
    for (final d in _tripDays) {
      final meals = _meals[d] ?? (false, false, false);
      if (meals == (_storedMeals[d] ?? (false, false, false))) continue;
      // One row per trip and day, so edits on two devices merge (sync-format §6).
      await repo.write('trip_meals', '${_id}_$d', {
        'trip_id': _id,
        'date': '$d',
        'breakfast': meals.$1,
        'lunch': meals.$2,
        'dinner': meals.$3,
      });
    }
    if (mounted) Navigator.pop(context, true);
  }

  Widget _projectTile(BuildContext context) {
    final l = context.l10n;
    final project = ref.watch(projectByIdProvider)[_projectId];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.work_outline),
      title: Text(project?.name ?? l.tripProjectNone),
      subtitle: project == null ? null : Text(projectLabel(project)),
      trailing: project == null
          ? const Icon(Icons.search)
          : IconButton(
              icon: const Icon(Icons.clear),
              tooltip: l.delete,
              onPressed: () => setState(() => _projectId = null),
            ),
      onTap: () async {
        final id = await showProjectPicker(context);
        if (id != null) setState(() => _projectId = id);
      },
    );
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
              _projectTile(context),
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
              if (_tripDays.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l.mealsProvided,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                for (final d in _tripDays)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(width: 92, child: Text(context.shortDate(d))),
                        for (final (index, label) in [
                          (0, l.breakfast),
                          (1, l.lunch),
                          (2, l.dinner),
                        ])
                          FilterChip(
                            label: Text(label),
                            selected: switch (_meals[d] ??
                                (false, false, false)) {
                              (final b, final lu, final di) => [
                                b,
                                lu,
                                di,
                              ][index],
                            },
                            onSelected: (on) => setState(() {
                              final (b, lu, di) =
                                  _meals[d] ?? (false, false, false);
                              _meals[d] = (
                                index == 0 ? on : b,
                                index == 1 ? on : lu,
                                index == 2 ? on : di,
                              );
                            }),
                          ),
                      ],
                    ),
                  ),
              ],
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
