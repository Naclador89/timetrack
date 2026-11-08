import '../model/attendance.dart';
import '../model/day_type.dart';
import '../model/planning.dart';
import '../sync/repository.dart';
import '../time/home_time_zone.dart';
import '../time/local_date.dart';

/// Records [type] for [date] (calculations.md §15, data-model §12):
///
/// - office / home office: a `days` row (id = the date, so two devices
///   merge), and the sessions starting that day move to that location;
/// - an absence type: one full-day absence of that kind;
/// - business trip: only clears the other types. The trip itself is
///   created by the caller (it needs destination and times).
///
/// Other absences on [date] are removed (except `extra_holiday`, which is
/// not a day type). Work sessions are kept.
Future<void> setDayType(
  SyncedRepository repository,
  LocalDate date,
  DayType type, {
  required HomeTimeZone zone,
}) async {
  final (absences, sessions, choice) = await repository.store.transaction(
    (tx) async => (
      await tx.rows('absences'),
      await tx.rows('work_sessions'),
      await tx.row('days', '$date'),
    ),
  );
  final kind = type.absenceKind;
  var hasKind = false;
  for (final a in absences) {
    if (a.isDeleted || a.fields['date'] != '$date') continue;
    final wire = a.fields['kind'];
    if (wire == AbsenceKind.extraHoliday.wireName) continue;
    if (kind != null && wire == kind.wireName && !hasKind) {
      hasKind = true;
      if (a.fields['fraction'] != 1) {
        await repository.write('absences', a.id, {'fraction': 1});
      }
    } else {
      await repository.delete('absences', a.id);
    }
  }
  if (kind != null && !hasKind) {
    await repository.write('absences', repository.newId(), {
      'date': '$date',
      'kind': kind.wireName,
      'fraction': 1,
    });
  }

  final location = switch (type) {
    DayType.office => WorkLocation.office,
    DayType.home => WorkLocation.home,
    _ => null,
  };
  if (location != null) {
    await repository.write('days', '$date', {
      'date': '$date',
      'type': type.wireName,
      'deleted': false,
    });
    for (final s in sessions) {
      final start = s.fields['start_utc'];
      if (s.isDeleted || start is! String) continue;
      if (zone.dateOf(DateTime.parse(start)) != date) continue;
      if (s.fields['location'] != location.wireName) {
        await repository.write('work_sessions', s.id, {
          'location': location.wireName,
        });
      }
    }
  } else if (choice != null && !choice.isDeleted) {
    await repository.delete('days', '$date');
  }
}

/// Removes the day type chosen for [date] (calculations.md §15): the `days`
/// row and the day's absences (except `extra_holiday`, which is not a day
/// type). Work sessions and trips are kept; a trip day stays a business trip
/// until the trip changes. Returns the deleted rows as `(table, id)`, for
/// undo.
Future<List<(String, String)>> clearDayType(
  SyncedRepository repository,
  LocalDate date,
) async {
  final (absences, choice) = await repository.store.transaction(
    (tx) async => (await tx.rows('absences'), await tx.row('days', '$date')),
  );
  final deleted = <(String, String)>[
    for (final a in absences)
      if (!a.isDeleted &&
          a.fields['date'] == '$date' &&
          a.fields['kind'] != AbsenceKind.extraHoliday.wireName)
        ('absences', a.id),
    if (choice != null && !choice.isDeleted) ('days', '$date'),
  ];
  for (final (table, id) in deleted) {
    await repository.delete(table, id);
  }
  return deleted;
}
