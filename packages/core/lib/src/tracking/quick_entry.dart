import '../model/attendance.dart';
import 'day_templates.dart';

/// A line typed into quick entry, e.g. `8-16:30 p30 bosch 014: Zeichnungen`
/// (calculations.md §17):
///
/// - `8-16:30`, `08:15–12`: a working time from–to (local, same day; an end
///   at or before the start is the next day);
/// - `1:30`, `1,5h`, `90m`: a project duration instead;
/// - `p30`, `p0:45`, `pause 30`, `p`: a break (`p` alone: the usual length),
///   at the usual start if it fits, otherwise in the middle (§4.1);
/// - `@home`, `@ho`, `@büro`, `@office`: the location;
/// - the other words: the project search (project-search.md);
/// - after `: `: the note.
final class QuickEntry {
  /// Creates a parsed entry.
  const QuickEntry({
    this.start,
    this.end,
    this.duration,
    this.breakMinutes = 0,
    this.location,
    this.projectQuery = '',
    this.note = '',
  });

  /// Start, minutes since local midnight.
  final int? start;

  /// End, minutes since local midnight.
  final int? end;

  /// A project duration (only without [start]).
  final int? duration;

  /// Break length.
  final int breakMinutes;

  /// The location, if given.
  final WorkLocation? location;

  /// Words to search the project with.
  final String projectQuery;

  /// Note for the project entry.
  final String note;

  /// Whether it records a working time.
  bool get hasRange => start != null && end != null;

  /// Worked minutes of the range minus the break.
  int get rangeMinutes {
    if (!hasRange) return 0;
    final e = end! <= start! ? end! + 1440 : end!;
    return e - start! - breakMinutes;
  }

  /// The rows it creates as a template: a session with the break centred in
  /// it, and the project over the whole range (the break is cut out of
  /// project time, §3), or a project duration. [projectId] is the project
  /// the UI resolved from [projectQuery]. [breakStart] is the usual break
  /// start (§4.1), used when the break fits there.
  DayTemplate toTemplate({String? projectId, int? breakStart}) {
    final e = hasRange && end! <= start! ? end! + 1440 : end;
    final usual =
        hasRange &&
            breakStart != null &&
            breakStart >= start! &&
            breakStart + breakMinutes <= e!
        ? breakStart
        : null;
    final breakAt =
        usual ?? (hasRange ? ((start! + e! - breakMinutes) ~/ 2) ~/ 5 * 5 : 0);
    return DayTemplate(
      id: '',
      name: '',
      items: [
        if (hasRange) ...[
          TemplateItem(
            TemplateItemKind.session,
            start: start!,
            end: end!,
            location: location ?? WorkLocation.office,
          ),
          if (breakMinutes > 0)
            TemplateItem(
              TemplateItemKind.breakTime,
              start: breakAt,
              end: breakAt + breakMinutes,
            ),
          if (projectId != null)
            TemplateItem(
              TemplateItemKind.entry,
              start: start!,
              end: end!,
              projectId: projectId,
              note: note,
            ),
        ] else if (duration != null && projectId != null)
          TemplateItem(
            TemplateItemKind.duration,
            minutes: duration!,
            projectId: projectId,
            note: note,
          ),
      ],
    );
  }
}

final _time = r'(\d{1,2})(?:[:.](\d{2}))?';
final _range = RegExp('^$_time\\s*[-–]\\s*$_time\$');
final _hm = RegExp(r'^(\d{1,2}):([0-5]\d)$');
final _hours = RegExp(r'^(\d{1,2}(?:[.,]\d{1,2})?)h$', caseSensitive: false);
final _mins = RegExp(r'^(\d{1,3})m(?:in)?$', caseSensitive: false);
final _break = RegExp(r'^p(?:ause)?(\S+)$', caseSensitive: false);

const _locations = {
  'home': WorkLocation.home,
  'ho': WorkLocation.home,
  'homeoffice': WorkLocation.home,
  'office': WorkLocation.office,
  'büro': WorkLocation.office,
  'buero': WorkLocation.office,
  'buro': WorkLocation.office,
};

/// Parses [text] (see [QuickEntry]); `null` if it records nothing. A bare
/// `p` is a break of [defaultBreakMinutes] (§4.1).
QuickEntry? parseQuickEntry(String text, {int defaultBreakMinutes = 30}) {
  var body = text.trim();
  var note = '';
  final colon = body.indexOf(': ');
  if (colon >= 0) {
    note = body.substring(colon + 2).trim();
    body = body.substring(0, colon);
  }
  // Allow "8 - 16" with spaces around the dash.
  body = body.replaceAllMapped(
    RegExp(r'(\d)\s+([-–])\s+(\d)'),
    (m) => '${m[1]}${m[2]}${m[3]}',
  );
  int? start, end, duration;
  var breakMinutes = 0;
  WorkLocation? location;
  final words = <String>[];
  final tokens = body.split(RegExp(r'\s+'))..removeWhere((t) => t.isEmpty);
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    final lower = t.toLowerCase();
    final range = _range.firstMatch(t);
    if (range != null && start == null) {
      start = _clock(range[1]!, range[2]);
      end = _clock(range[3]!, range[4]);
      if (start == null || end == null) return null;
      continue;
    }
    if (lower == 'p' || lower == 'pause') {
      final m = i + 1 < tokens.length
          ? _length(tokens[i + 1], plainMinutes: true)
          : null;
      if (m != null) {
        breakMinutes = m;
        i++;
        continue;
      }
      breakMinutes = defaultBreakMinutes;
      continue;
    }
    final br = _break.firstMatch(t);
    final brMinutes = br == null ? null : _length(br[1]!, plainMinutes: true);
    if (brMinutes != null) {
      breakMinutes = brMinutes;
      continue;
    }
    if (lower.startsWith('@') && _locations[lower.substring(1)] != null) {
      location = _locations[lower.substring(1)];
      continue;
    }
    final length = duration == null && start == null ? _length(t) : null;
    if (length != null) {
      duration = length;
      continue;
    }
    words.add(t);
  }
  if (start == null && duration == null) return null;
  return QuickEntry(
    start: start,
    end: end,
    duration: start == null ? duration : null,
    breakMinutes: breakMinutes,
    location: location,
    projectQuery: words.join(' '),
    note: note,
  );
}

int? _clock(String hours, String? minutes) {
  final h = int.parse(hours), m = minutes == null ? 0 : int.parse(minutes);
  if (h > 24 || m > 59 || (h == 24 && m > 0)) return null;
  return h * 60 + m;
}

/// `1:30`, `1,5h`, `90m`; with [plainMinutes] also `30` (break tokens).
int? _length(String t, {bool plainMinutes = false}) {
  final hm = _hm.firstMatch(t);
  if (hm != null) return int.parse(hm[1]!) * 60 + int.parse(hm[2]!);
  final h = _hours.firstMatch(t);
  if (h != null) {
    return (double.parse(h[1]!.replaceAll(',', '.')) * 60).round();
  }
  final m = _mins.firstMatch(t);
  if (m != null) return int.parse(m[1]!);
  if (plainMinutes && RegExp(r'^\d{1,3}$').hasMatch(t)) return int.parse(t);
  return null;
}
