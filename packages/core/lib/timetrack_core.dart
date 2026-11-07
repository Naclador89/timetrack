/// Business logic of TimeTrack: time model, calculation rules and sync.
///
/// Pure Dart, no Flutter. The rules implement `docs/specs/calculations.md`,
/// the sync implements `docs/specs/sync-format.md`.
library;

export 'src/model/attendance.dart';
export 'src/model/planning.dart';
export 'src/rules/arbzg.dart';
export 'src/rules/credit.dart';
export 'src/rules/day_work.dart';
export 'src/rules/holidays.dart';
export 'src/rules/ledger.dart';
export 'src/rules/target.dart';
export 'src/time/home_time_zone.dart';
export 'src/time/local_date.dart';
export 'src/time/span.dart';
