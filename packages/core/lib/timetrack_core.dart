/// Business logic of TimeTrack: time model, calculation rules and sync.
///
/// Pure Dart, no Flutter. The rules implement `docs/specs/calculations.md`,
/// the sync implements `docs/specs/sync-format.md`.
library;

export 'src/rules/holidays.dart';
export 'src/time/local_date.dart';
export 'src/time/span.dart';
