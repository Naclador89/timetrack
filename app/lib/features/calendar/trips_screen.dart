import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../widgets/date_range_dialog.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/place_picker.dart';
import '../projects/project_picker.dart';
import '../reports/report_documents.dart' show projectLabel;
import '../settings/per_diem_rates_screen.dart' show parseCents;
import 'trip_expenses.dart';

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
                    : '${t.destination} (${placeLabel(TripPlace(t.country, t.city))})',
              ),
              subtitle: Text(
                [
                  '${when(t.depart)} – ${t.returnAt == null ? l.running : when(t.returnAt!)}',
                  if (projects[t.projectId] case final p?) projectLabel(p),
                  if (t.orderLabel.isNotEmpty) '${l.tripOrder} ${t.orderLabel}',
                  if (t.note.isNotEmpty) t.note.split('\n').first,
                  if (t.claimedOn case final c?) l.claimedOn(context.date(c)),
                ].join('\n'),
              ),
              trailing: t.returnAt == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.receipt_long_outlined),
                      tooltip: l.tripExpenses,
                      onPressed: () => openTripExpenses(context, ref, t),
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
  late TripOrderKind? _orderKind = widget.trip?.orderKind;
  late final _orderNumber = TextEditingController(
    text: widget.trip?.orderNumber,
  );
  late final _note = TextEditingController(text: widget.trip?.note);
  late TripPlace _place = TripPlace(
    widget.trip?.country ?? 'DE',
    widget.trip?.city,
  );

  /// Places from a date on (calculations §13.1), as stored and as edited.
  late final Map<LocalDate, TripPlace> _storedStops = {
    for (final s in ref.read(ledgerDataProvider).tripStops)
      if (s.tripId == _id) s.date: TripPlace(s.country, s.city),
  };
  late final Map<LocalDate, TripPlace> _stops = {..._storedStops};
  late LodgingMode _lodging = widget.trip?.lodging ?? LodgingMode.company;
  late final _lodgingAmount = TextEditingController(
    text: (widget.trip?.lodgingCents ?? 0) == 0
        ? ''
        : (widget.trip!.lodgingCents / 100).toStringAsFixed(2),
  );
  late LocalDate? _claimedOn = widget.trip?.claimedOn;
  late final _carKm = TextEditingController(
    text: (widget.trip?.carKm ?? 0) == 0 ? '' : '${widget.trip!.carKm}',
  );
  late bool _overnight = widget.trip?.overnight ?? true;
  late bool _service = widget.trip?.service ?? true;
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
    _orderNumber.dispose();
    _note.dispose();
    _lodgingAmount.dispose();
    _carKm.dispose();
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
      'country': _place.country,
      'city': _place.city,
      'overnight': _overnight,
      'service': _service,
      'project_id': _projectId,
      'lodging': _lodging.name,
      'lodging_cents': _lodging == LodgingMode.receipt
          ? parseCents(_lodgingAmount.text) ?? 0
          : 0,
      'car_km': int.tryParse(_carKm.text.trim()) ?? 0,
      'claimed_on': _claimedOn?.toString(),
      'order_kind': _orderKind?.wire,
      'order_number': _orderNumber.text.trim(),
      'note': _note.text.trim(),
    });
    // One row per trip and date, like the meals.
    for (final MapEntry(key: d, value: place) in _stops.entries) {
      if (_storedStops[d] == place) continue;
      await repo.write('trip_stops', '${_id}_$d', {
        'trip_id': _id,
        'date': '$d',
        'country': place.country,
        'city': place.city,
      });
    }
    for (final d in _storedStops.keys) {
      if (!_stops.containsKey(d)) await repo.delete('trip_stops', '${_id}_$d');
    }
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

  /// Asks for the first day at a new place, then the place (§13.1).
  Future<void> _addStop() async {
    final days = _tripDays.skip(1).toList();
    final day = await showDialog<LocalDate>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(c.l10n.changePlaceFrom),
        children: [
          for (final d in days)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, d),
              child: Text(c.shortDate(d)),
            ),
        ],
      ),
    );
    if (day == null || !mounted) return;
    final place = await showPlacePicker(context);
    if (place != null) setState(() => _stops[day] = place);
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

  /// Both dates in one calendar that closes on the second tap (only the
  /// departure while the trip is open), then the two times.
  Widget _datesFields(BuildContext context) {
    final l = context.l10n;
    final today = ref.watch(todayProvider);
    String day(LocalDate d) =>
        d.year == today.year ? context.shortDate(d) : context.date(d);
    String clock(int m) =>
        '${(m ~/ 60).toString().padLeft(2, '0')}:'
        '${(m % 60).toString().padLeft(2, '0')}';
    final back = _returnDate;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PickerField(
            label: l.tripDates,
            value: back == null
                ? l.tripDatesFrom(day(_departDate))
                : back == _departDate
                ? day(back)
                : '${day(_departDate)} – ${day(back)}',
            icon: Icons.date_range,
            onTap: () async {
              final picked = await pickDateRange(
                context,
                start: _departDate,
                end: back,
                today: today,
                title: l.pickTripStart,
                secondTitle: l.pickTripEnd,
                single: back == null,
              );
              if (picked == null) return;
              setState(() {
                _departDate = picked.$1;
                if (picked.$2 case final end?) _returnDate = end;
              });
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PickerField(
                  label: l.depart,
                  value: clock(_departTime),
                  icon: Icons.schedule,
                  onTap: () async {
                    final m = await pickTime(context, _departTime);
                    if (m != null) setState(() => _departTime = m);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PickerField(
                  label: l.returnTime,
                  value: back == null ? l.running : clock(_returnTime!),
                  icon: Icons.schedule,
                  onTap: () async {
                    final m = await pickTime(context, _returnTime ?? 19 * 60);
                    if (m == null) return;
                    setState(() {
                      _returnTime = m;
                      _returnDate ??= _departDate;
                    });
                  },
                  // Still travelling: no return yet.
                  onClear: back == null
                      ? null
                      : () => setState(() {
                          _returnDate = null;
                          _returnTime = null;
                        }),
                  clearTooltip: l.returnOpen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The order the trip is billed through: MO, GA or SA and its number.
  Widget _orderFields(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_outlined, size: 18),
              const SizedBox(width: 8),
              Text(l.tripOrder, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<TripOrderKind>(
            showSelectedIcon: false,
            emptySelectionAllowed: true,
            segments: [
              for (final (kind, name) in [
                (TripOrderKind.installation, l.tripOrderInstallation),
                (TripOrderKind.warranty, l.tripOrderWarranty),
                (TripOrderKind.service, l.tripOrderService),
              ])
                ButtonSegment(
                  value: kind,
                  label: Text(kind.code),
                  tooltip: name,
                ),
            ],
            selected: {?_orderKind},
            onSelectionChanged: (v) =>
                setState(() => _orderKind = v.isEmpty ? null : v.single),
          ),
          TextField(
            controller: _orderNumber,
            decoration: InputDecoration(
              labelText: l.orderNumber,
              helperText: l.tripOrderHint,
            ),
          ),
        ],
      ),
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
              // calculations §13.0: picks the per-diem and lodging rate.
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.public),
                title: Text(placeLabel(_place)),
                subtitle: Text(l.placeHint),
                onTap: () async {
                  final p = await showPlacePicker(context);
                  if (p != null) setState(() => _place = p);
                },
              ),
              _datesFields(context),
              _projectTile(context),
              _orderFields(context),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.overnight),
                value: _overnight,
                onChanged: (v) => setState(() => _overnight = v),
              ),
              // calculations.md §9: how the account credits the trip days.
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.serviceTrip),
                subtitle: Text(l.serviceTripHint),
                value: _service,
                onChanged: (v) => setState(() => _service = v),
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
              if (_tripDays.length > 1) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l.otherPlaces,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                for (final d in _stops.keys.toList()..sort())
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      '${l.placeFrom(context.shortDate(d))}: '
                      '${placeLabel(_stops[d]!)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: l.delete,
                      onPressed: () => setState(() => _stops.remove(d)),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: Text(l.changePlace),
                    onPressed: _addStop,
                  ),
                ),
              ],
              // calculations §13.2, §13.3
              const SizedBox(height: 12),
              if (_overnight) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l.lodging,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 4),
                SegmentedButton<LodgingMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: LodgingMode.company,
                      label: Text(l.lodgingCompany),
                    ),
                    ButtonSegment(
                      value: LodgingMode.flat,
                      label: Text(l.lodgingFlat),
                    ),
                    ButtonSegment(
                      value: LodgingMode.receipt,
                      label: Text(l.lodgingReceipt),
                    ),
                  ],
                  selected: {_lodging},
                  onSelectionChanged: (v) =>
                      setState(() => _lodging = v.single),
                ),
                if (_lodging == LodgingMode.receipt)
                  TextField(
                    controller: _lodgingAmount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l.lodgingReceiptTotal,
                      suffixText: '€',
                    ),
                  ),
              ],
              TextField(
                controller: _carKm,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l.carKm,
                  suffixText: 'km',
                ),
              ),
              // calculations §13.5
              if (_returnDate != null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.markClaimed),
                  subtitle: _claimedOn == null
                      ? null
                      : Text(l.claimedOn(context.date(_claimedOn!))),
                  value: _claimedOn != null,
                  onChanged: (v) => setState(
                    () => _claimedOn = v ?? false
                        ? ref.read(todayProvider)
                        : null,
                  ),
                ),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: l.tripNote,
                  hintText: l.tripNoteHint,
                  alignLabelWithHint: true,
                ),
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

/// Looks like a form field, opens a picker on tap.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
    this.clearTooltip,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  /// If given, a cross replaces [icon] and calls it.
  final VoidCallback? onClear;
  final String? clearTooltip;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        suffixIcon: onClear == null
            ? Icon(icon, size: 18)
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: clearTooltip,
                onPressed: onClear,
              ),
      ),
      child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}
