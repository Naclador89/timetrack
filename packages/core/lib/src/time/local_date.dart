/// A calendar date without time of day or time zone, e.g. `2026-11-07`.
///
/// Calendar days are evaluated in the user's home time zone
/// (spec: calculations.md §1). This type carries only the date, so date
/// arithmetic never shifts across DST changes: internally it always computes
/// in UTC, where every day has 24 hours.
final class LocalDate implements Comparable<LocalDate> {
  /// Creates the date [year]-[month]-[day].
  ///
  /// Throws an [ArgumentError] for dates that don't exist, such as `2026-02-30`.
  factory LocalDate(int year, int month, int day) {
    final normalized = DateTime.utc(year, month, day);
    if (normalized.year != year ||
        normalized.month != month ||
        normalized.day != day) {
      throw ArgumentError('Invalid date: $year-$month-$day');
    }
    return LocalDate._(year, month, day);
  }

  const LocalDate._(this.year, this.month, this.day);

  /// Parses an ISO 8601 date (`YYYY-MM-DD`), the format used in sync changes
  /// (spec: sync-format.md §4).
  factory LocalDate.parse(String iso) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
    if (match == null) {
      throw FormatException('Expected YYYY-MM-DD', iso);
    }
    return LocalDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  /// The year, e.g. 2026.
  final int year;

  /// The month, 1 (January) to 12 (December).
  final int month;

  /// The day of the month, starting at 1.
  final int day;

  DateTime get _utc => DateTime.utc(year, month, day);

  /// ISO weekday: [DateTime.monday] (1) to [DateTime.sunday] (7).
  int get weekday => _utc.weekday;

  /// Whether this is a Saturday or Sunday.
  bool get isWeekend => weekday >= DateTime.saturday;

  /// The date [days] days later (or earlier, if negative).
  LocalDate addDays(int days) {
    final d = DateTime.utc(year, month, day + days);
    return LocalDate._(d.year, d.month, d.day);
  }

  /// Number of days from this date to [other] (negative if [other] is earlier).
  int daysUntil(LocalDate other) => other._utc.difference(_utc).inDays;

  /// The Monday of this date's ISO week (a week runs Monday–Sunday).
  LocalDate get startOfWeek => addDays(1 - weekday);

  /// The first day of this date's month.
  LocalDate get startOfMonth => LocalDate._(year, month, 1);

  /// Whether this date is before [other].
  bool isBefore(LocalDate other) => compareTo(other) < 0;

  /// Whether this date is after [other].
  bool isAfter(LocalDate other) => compareTo(other) > 0;

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  /// ISO 8601 form `YYYY-MM-DD`.
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}
