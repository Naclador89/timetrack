import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'local_date.dart';
import 'span.dart';

/// The user's home time zone, in which calendar days are evaluated
/// (spec: calculations.md §1).
///
/// A day runs from local midnight to the next local midnight, so it is 23 or
/// 25 hours long on DST changes.
final class HomeTimeZone {
  /// Loads the IANA time zone [name], e.g. `Europe/Berlin`.
  ///
  /// Throws `tz.LocationNotFoundException` for unknown names.
  HomeTimeZone([String name = defaultName]) : _location = _load(name);

  /// The default home time zone (setting `home_time_zone`).
  static const String defaultName = 'Europe/Berlin';

  static bool _databaseLoaded = false;

  final tz.Location _location;

  /// The IANA name of this zone.
  String get name => _location.name;

  /// The span of [date], from local midnight to the next local midnight.
  Span daySpan(LocalDate date) {
    final start = tz.TZDateTime(_location, date.year, date.month, date.day);
    final next = date.addDays(1);
    final end = tz.TZDateTime(_location, next.year, next.month, next.day);
    return Span(epochMinute(start), epochMinute(end));
  }

  /// The local calendar date of [instant].
  LocalDate dateOf(DateTime instant) {
    final local = tz.TZDateTime.from(instant, _location);
    return LocalDate(local.year, local.month, local.day);
  }

  /// The local calendar date of the instant [minute] (minutes since the epoch).
  LocalDate dateOfMinute(int minute) => dateOf(instantOfEpochMinute(minute));

  static tz.Location _load(String name) {
    if (!_databaseLoaded) {
      tzdata.initializeTimeZones();
      _databaseLoaded = true;
    }
    return tz.getLocation(name);
  }
}
