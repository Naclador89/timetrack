import '../time/local_date.dart';
import 'holidays.dart';
import 'school_holidays_data.dart';

/// A school holiday period of one state, e.g. the Osterferien
/// (spec: calculations.md §10.5).
final class SchoolHoliday {
  /// Creates a period from [start] to [end], both inclusive.
  const SchoolHoliday(this.start, this.end, this.name);

  /// The first day without school.
  final LocalDate start;

  /// The last day without school.
  final LocalDate end;

  /// The German name, e.g. `Osterferien`.
  final String name;

  /// Whether [date] lies in the period.
  bool contains(LocalDate date) => !date.isBefore(start) && !date.isAfter(end);

  @override
  bool operator ==(Object other) =>
      other is SchoolHoliday &&
      other.start == start &&
      other.end == end &&
      other.name == name;

  @override
  int get hashCode => Object.hash(start, end, name);

  @override
  String toString() => '$start–$end $name';
}

final Map<FederalState, List<SchoolHoliday>> _parsed = {};

/// The school holidays of [state] that touch [year], by start date
/// (spec: calculations.md §10.5). Empty for a year the built-in data doesn't
/// cover yet.
List<SchoolHoliday> schoolHolidays(FederalState state, int year) {
  final all = _parsed.putIfAbsent(state, () {
    return [
      for (final line in schoolHolidayData[state] ?? const <String>[])
        if (line.split(' ') case [final start, final end, ...final name])
          SchoolHoliday(
            LocalDate.parse(start),
            LocalDate.parse(end),
            name.join(' '),
          ),
    ]..sort((a, b) => a.start.compareTo(b.start));
  });
  return [
    for (final h in all)
      if (h.start.year <= year && h.end.year >= year) h,
  ];
}
