import '../model/attendance.dart';
import '../rules/ledger.dart';
import '../sync/change.dart';
import '../sync/repository.dart';
import '../time/home_time_zone.dart';
import '../time/local_date.dart';
import '../time/span.dart';
import 'time_tracker.dart';

/// What a template item creates (data-model §13).
enum TemplateItemKind {
  /// A work session.
  session,

  /// A break.
  breakTime,

  /// A timed project entry.
  entry,

  /// A project duration without times.
  duration;

  /// The stored name.
  String get wireName => this == breakTime ? 'break' : name;

  /// Parses a [wireName]; `null` for anything else.
  static TemplateItemKind? parse(Object? wire) {
    for (final k in values) {
      if (k.wireName == wire) return k;
    }
    return null;
  }
}

/// One row of a [DayTemplate], in local wall-clock minutes of the day.
final class TemplateItem {
  /// Creates an item. [end] at or before [start] means the next day.
  const TemplateItem(
    this.kind, {
    this.start = 0,
    this.end = 0,
    this.minutes = 0,
    this.location,
    this.projectId,
    this.note = '',
  });

  /// What it creates.
  final TemplateItemKind kind;

  /// Start, minutes since local midnight (not for durations).
  final int start;

  /// End, minutes since local midnight (not for durations).
  final int end;

  /// Length of a [TemplateItemKind.duration].
  final int minutes;

  /// Location of a session.
  final WorkLocation? location;

  /// Project of an entry or duration.
  final String? projectId;

  /// Note of an entry or duration.
  final String note;

  /// The stored form.
  Map<String, Object?> toJson() => {
    'kind': kind.wireName,
    if (kind == TemplateItemKind.duration)
      'minutes': minutes
    else ...{
      'start': start,
      'end': end,
    },
    if (location != null) 'location': location!.wireName,
    if (projectId != null) 'project_id': projectId,
    if (note.isNotEmpty) 'note': note,
  };

  /// Reads a stored item; `null` if it is incomplete.
  static TemplateItem? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = TemplateItemKind.parse(json['kind']);
    if (kind == null) return null;
    int number(String key) => (json[key] as num?)?.toInt() ?? 0;
    final loc = json['location'];
    WorkLocation? location;
    try {
      location = loc is String ? WorkLocation.parse(loc) : null;
    } on ArgumentError {
      location = null;
    }
    final project = json['project_id'];
    if ((kind == TemplateItemKind.entry || kind == TemplateItemKind.duration) &&
        project is! String) {
      return null;
    }
    return TemplateItem(
      kind,
      start: number('start'),
      end: number('end'),
      minutes: number('minutes'),
      location: location,
      projectId: project is String ? project : null,
      note: json['note'] is String ? json['note'] as String : '',
    );
  }
}

/// A typical day to apply with one tap ("copy yesterday", saved templates;
/// data-model §13).
final class DayTemplate {
  /// Creates a template.
  const DayTemplate({
    required this.id,
    required this.name,
    required this.items,
  });

  /// Row id.
  final String id;

  /// Shown name, e.g. "Büro 8–16:30".
  final String name;

  /// What it creates.
  final List<TemplateItem> items;

  /// Whether applying it would create nothing.
  bool get isEmpty => items.isEmpty;
}

/// data-model §13; `null` for tombstones and incomplete rows.
DayTemplate? dayTemplateFromRow(StoredRow r) {
  if (r.isDeleted) return null;
  final name = r.fields['name'];
  final items = r.fields['items'];
  if (name is! String || items is! List) return null;
  return DayTemplate(
    id: r.id,
    name: name,
    items: [for (final i in items) ?TemplateItem.fromJson(i)],
  );
}

/// The day [date] of [data] as a template: finished sessions, breaks and
/// project entries starting that day, and its durations. Running rows are
/// left out.
DayTemplate captureDay(
  LedgerData data,
  LocalDate date,
  HomeTimeZone zone, {
  String id = '',
  String name = '',
}) {
  int local(DateTime t) {
    final l = zone.toLocal(t);
    return l.hour * 60 + l.minute;
  }

  bool onDay(DateTime start, DateTime? end) =>
      end != null && zone.dateOf(start) == date;
  List<T> sorted<T>(Iterable<T> rows, DateTime Function(T) start) =>
      rows.toList()..sort((a, b) => start(a).compareTo(start(b)));
  return DayTemplate(
    id: id,
    name: name,
    items: [
      for (final s in sorted(data.sessions, (s) => s.start))
        if (onDay(s.start, s.end))
          TemplateItem(
            TemplateItemKind.session,
            start: local(s.start),
            end: local(s.end!),
            location: s.location,
          ),
      for (final b in sorted(data.breaks, (b) => b.start))
        if (onDay(b.start, b.end))
          TemplateItem(
            TemplateItemKind.breakTime,
            start: local(b.start),
            end: local(b.end!),
          ),
      for (final e in sorted(data.entries, (e) => e.start))
        if (onDay(e.start, e.end))
          TemplateItem(
            TemplateItemKind.entry,
            start: local(e.start),
            end: local(e.end!),
            projectId: e.projectId,
            note: e.note,
          ),
      for (final d in data.durations)
        if (d.date == date)
          TemplateItem(
            TemplateItemKind.duration,
            minutes: d.minutes,
            projectId: d.projectId,
            note: d.note,
          ),
    ],
  );
}

/// Saves [template] as a `day_templates` row.
Future<void> saveDayTemplate(
  SyncedRepository repository,
  DayTemplate template,
) => repository.write('day_templates', template.id, {
  'name': template.name,
  'items': [for (final i in template.items) i.toJson()],
  'deleted': false,
});

/// Creates the rows of [template] on [date] and returns them as
/// `(table, id)` pairs, so the UI can undo it.
Future<List<(String, String)>> applyDayTemplate(
  SyncedRepository repository,
  DayTemplate template,
  LocalDate date, {
  required HomeTimeZone zone,
}) async {
  final created = <(String, String)>[];
  String at(int minutes) {
    final day = date.addDays(minutes ~/ 1440);
    final m = minutes % 1440;
    return isoMinute(zone.instantAt(day, m ~/ 60, m % 60));
  }

  for (final item in template.items) {
    final end = item.end <= item.start ? item.end + 1440 : item.end;
    final (table, fields) = switch (item.kind) {
      TemplateItemKind.session => (
        'work_sessions',
        <String, Object?>{
          'start_utc': at(item.start),
          'end_utc': at(end),
          'location': (item.location ?? WorkLocation.office).wireName,
          'source': 'manual',
        },
      ),
      TemplateItemKind.breakTime => (
        'breaks',
        {'start_utc': at(item.start), 'end_utc': at(end)},
      ),
      TemplateItemKind.entry => (
        'project_entries',
        {
          'project_id': item.projectId,
          'start_utc': at(item.start),
          'end_utc': at(end),
          'note': item.note,
          'source': 'manual',
        },
      ),
      TemplateItemKind.duration => (
        'project_entries',
        {
          'project_id': item.projectId,
          'date': '$date',
          'duration_min': item.minutes,
          'note': item.note,
          'source': 'manual',
        },
      ),
    };
    final id = repository.newId();
    await repository.write(table, id, fields);
    created.add((table, id));
  }
  return created;
}

/// Minutes from local midnight of [date] to [instant] (helper for tests
/// and the timeline).
int localMinuteOf(DateTime instant, LocalDate date, HomeTimeZone zone) =>
    epochMinute(instant) - epochMinute(zone.instantAt(date, 0, 0));
