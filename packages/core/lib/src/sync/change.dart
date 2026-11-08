import 'hlc.dart';

/// The synced tables this app version knows (spec: sync-format.md §4,
/// data-model.md). Changes to other tables are stored too but not used, so
/// newer app versions can add tables.
const syncedTables = {
  'work_sessions',
  'breaks',
  'projects',
  'project_entries',
  'absences',
  'work_schedules',
  'settings',
  'home_office_rules',
  'trips',
  'trip_meals',
  'per_diem_rates',
  'days',
  'day_templates',
  'dismissed_notices',
};

/// One write: the fields of row [id] in [table] set by this change
/// (spec: sync-format.md §5).
final class Change {
  /// Creates a change. [set] must not be empty; values are JSON primitives.
  Change({
    required this.table,
    required this.id,
    required this.hlc,
    required Map<String, Object?> set,
  }) : set = Map.unmodifiable(set) {
    if (set.isEmpty) throw ArgumentError.value(set, 'set', 'Must not be empty');
  }

  /// Reads a change from its JSON form.
  factory Change.fromJson(Map<String, Object?> json) => Change(
    table: json['tbl']! as String,
    id: json['id']! as String,
    hlc: Hlc.parse(json['hlc']! as String),
    set: (json['set']! as Map).cast<String, Object?>(),
  );

  /// Table name.
  final String table;

  /// Row id.
  final String id;

  /// Timestamp of this write.
  final Hlc hlc;

  /// Fields written. A delete is `{"deleted": true}`.
  final Map<String, Object?> set;

  /// The JSON form used in batch files.
  Map<String, Object?> toJson() => {
    'tbl': table,
    'id': id,
    'hlc': hlc.toString(),
    'set': set,
  };
}

/// A synced row as stored locally: its fields plus the HLC of the last applied
/// write per field (`field_clock`, spec: sync-format.md §4).
final class StoredRow {
  /// Creates a row.
  StoredRow({
    required this.table,
    required this.id,
    Map<String, Object?> fields = const {},
    Map<String, String> fieldClock = const {},
  }) : fields = Map.unmodifiable(fields),
       fieldClock = Map.unmodifiable(fieldClock);

  /// Table name.
  final String table;

  /// Row id.
  final String id;

  /// Field values; fields never written are absent (read them as `null`).
  final Map<String, Object?> fields;

  /// HLC string of the last applied write per field.
  final Map<String, String> fieldClock;

  /// Whether the row is deleted (tombstone).
  bool get isDeleted => fields['deleted'] == true;

  @override
  String toString() => 'StoredRow($table/$id, $fields)';
}

/// Applies [change] to [row] (or to a new empty row) and returns the result
/// (spec: sync-format.md §6).
///
/// A field takes the change's value only if the change is newer than that
/// field's clock, so the result doesn't depend on order or repetition.
StoredRow applyChange(StoredRow? row, Change change) {
  final fields = {...?row?.fields};
  final clock = {...?row?.fieldClock};
  final hlc = change.hlc.toString();
  for (final MapEntry(:key, :value) in change.set.entries) {
    final current = clock[key];
    if (current == null || hlc.compareTo(current) > 0) {
      fields[key] = value;
      clock[key] = hlc;
    }
  }
  return StoredRow(
    table: change.table,
    id: change.id,
    fields: fields,
    fieldClock: clock,
  );
}
