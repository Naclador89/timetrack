import '../model/project.dart';

/// How often and how recently a project was used; ranks equally good
/// matches (spec: project-search.md §4).
final class ProjectUsage {
  /// Creates usage statistics.
  const ProjectUsage({this.count = 0, this.lastUsedMinute});

  /// Number of uses, e.g. project entries in the last 90 days.
  final int count;

  /// Last use, in minutes since the epoch, or `null` if never used.
  final int? lastUsedMinute;
}

/// The searchable fields of a [Project].
enum ProjectField {
  /// [Project.name]
  name,

  /// [Project.projectNumber]
  projectNumber,

  /// [Project.orderNumber]
  orderNumber,

  /// [Project.client]
  client,
}

/// One search result.
final class ProjectMatch {
  /// Creates a result. Use [searchProjects] instead of calling this directly.
  const ProjectMatch(this.project, this.tier, this.highlights);

  /// The matching project.
  final Project project;

  /// Match tier, 0 (exact number) to 3 (fuzzy) (spec: project-search.md §3).
  final int tier;

  /// Matched ranges `[start, end)` in the **original** field strings, sorted
  /// and merged, for highlighting.
  final Map<ProjectField, List<(int, int)>> highlights;
}

/// Searches [projects] for [query] (spec: project-search.md).
///
/// [usage] maps project ids to usage statistics for ranking. Archived
/// projects are only included if [includeArchived] is true.
List<ProjectMatch> searchProjects(
  String query,
  List<Project> projects, {
  Map<String, ProjectUsage> usage = const {},
  bool includeArchived = false,
}) {
  final tokens = query.trim().split(RegExp(r'\s+'))
    ..removeWhere((t) => t.isEmpty);
  final results = <ProjectMatch>[];
  for (final p in projects) {
    if (p.archived && !includeArchived) continue;
    final match = tokens.isEmpty
        ? ProjectMatch(p, 0, const {})
        : _match(p, tokens);
    if (match != null) results.add(match);
  }
  int byUsage(ProjectMatch a, ProjectMatch b) {
    final ua = usage[a.project.id], ub = usage[b.project.id];
    final count = (ub?.count ?? 0).compareTo(ua?.count ?? 0);
    if (count != 0) return count;
    final last = (ub?.lastUsedMinute ?? -1).compareTo(ua?.lastUsedMinute ?? -1);
    if (last != 0) return last;
    return a.project.name.toLowerCase().compareTo(b.project.name.toLowerCase());
  }

  results.sort((a, b) {
    if (tokens.isEmpty && a.project.favorite != b.project.favorite) {
      return a.project.favorite ? -1 : 1;
    }
    final tier = a.tier.compareTo(b.tier);
    return tier != 0 ? tier : byUsage(a, b);
  });
  return results;
}

ProjectMatch? _match(Project p, List<String> tokens) {
  final fields = {
    ProjectField.name: (p.name, false),
    ProjectField.client: (p.client, false),
    ProjectField.projectNumber: (p.projectNumber, true),
    ProjectField.orderNumber: (p.orderNumber, true),
  };
  final folded = {
    for (final MapEntry(key: f, value: (text, isNumber)) in fields.entries)
      f: _fold(text, number: isNumber),
  };
  var projectTier = 0;
  final highlights = <ProjectField, List<(int, int)>>{};
  for (final token in tokens) {
    var best = 99;
    final hits = <ProjectField, List<(int, int)>>{};
    for (final MapEntry(key: f, value: (_, isNumber)) in fields.entries) {
      final field = folded[f]!;
      if (field.text.isEmpty) continue;
      final t = _fold(token, number: isNumber).text;
      if (t.isEmpty) continue;
      final hit = isNumber ? _numberHit(field, t) : _textHit(field, t);
      if (hit == null) continue;
      final (tier, ranges) = hit;
      if (tier < best) {
        best = tier;
        hits.clear();
      }
      if (tier == best) hits[f] = ranges;
    }
    if (best == 99) return null;
    if (best > projectTier) projectTier = best;
    for (final MapEntry(key: f, value: r) in hits.entries) {
      (highlights[f] ??= []).addAll(r);
    }
  }
  return ProjectMatch(p, projectTier, {
    for (final MapEntry(key: f, value: r) in highlights.entries) f: _merge(r),
  });
}

/// §3 tiers for number fields: exact 0, prefix 1, contains 2, fuzzy 3.
(int, List<(int, int)>)? _numberHit(_Folded field, String t) {
  final text = field.text;
  // Leading letters (`p` in `p2026014`) may be left out of the query.
  final lettersEnd = RegExp(r'^\p{L}*', unicode: true).firstMatch(text)!.end;
  for (final start in [0, lettersEnd]) {
    if (text.startsWith(t, start)) {
      final tier = start + t.length == text.length ? 0 : 1;
      return (tier, [field.originalRange(start, start + t.length)]);
    }
  }
  final i = text.indexOf(t);
  if (i >= 0) return (2, [field.originalRange(i, i + t.length)]);
  return _fuzzy(field, t);
}

/// §3 tiers for text fields: word start 1, contains 2, fuzzy 3.
(int, List<(int, int)>)? _textHit(_Folded field, String t) {
  final text = field.text;
  int? first;
  for (var i = text.indexOf(t); i >= 0; i = text.indexOf(t, i + 1)) {
    first ??= i;
    if (i == 0 || text[i - 1] == ' ') {
      return (1, [field.originalRange(i, i + t.length)]);
    }
  }
  if (first != null) return (2, [field.originalRange(first, first + t.length)]);
  return _fuzzy(field, t.replaceAll(' ', ''));
}

(int, List<(int, int)>)? _fuzzy(_Folded field, String t) {
  if (t.length < 3) return null;
  final ranges = <(int, int)>[];
  var j = 0;
  for (var i = 0; i < field.text.length && j < t.length; i++) {
    if (field.text[i] == t[j]) {
      ranges.add(field.originalRange(i, i + 1));
      j++;
    }
  }
  return j == t.length ? (3, ranges) : null;
}

List<(int, int)> _merge(List<(int, int)> ranges) {
  final sorted = [...ranges]..sort((a, b) => a.$1.compareTo(b.$1));
  final merged = <(int, int)>[];
  for (final r in sorted) {
    if (merged.isNotEmpty && r.$1 <= merged.last.$2) {
      final last = merged.removeLast();
      merged.add((last.$1, r.$2 > last.$2 ? r.$2 : last.$2));
    } else {
      merged.add(r);
    }
  }
  return merged;
}

/// Folded text plus, for every folded character, its index in the original.
final class _Folded {
  _Folded(this.text, this.origin);

  final String text;
  final List<int> origin;

  /// The original range covering folded characters `[start, end)`.
  (int, int) originalRange(int start, int end) =>
      (origin[start], origin[end - 1] + 1);
}

const _letterFolds = {
  'ä': 'a', 'ö': 'o', 'ü': 'u', 'ß': 'ss', //
  'á': 'a', 'à': 'a', 'â': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ó': 'o', 'ò': 'o', 'ô': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ç': 'c', 'ñ': 'n',
};

final _alphanumeric = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// spec: project-search.md §1.
_Folded _fold(String input, {required bool number}) {
  final chars = <String>[];
  final origin = <int>[];
  for (var i = 0; i < input.length; i++) {
    final c = input[i].toLowerCase();
    final folded = _letterFolds[c];
    if (folded != null) {
      for (final f in folded.split('')) {
        chars.add(f);
        origin.add(i);
      }
    } else if (_alphanumeric.hasMatch(c)) {
      chars.add(c);
      origin.add(i);
    } else if (!number && chars.isNotEmpty && chars.last != ' ') {
      chars.add(' ');
      origin.add(i);
    }
  }
  if (chars.isNotEmpty && chars.last == ' ') {
    chars.removeLast();
    origin.removeLast();
  }
  // ae/oe/ue → a/o/u, so "Mueller" and "Müller" fold alike.
  final outChars = <String>[], outOrigin = <int>[];
  for (var i = 0; i < chars.length; i++) {
    if (chars[i] == 'e' && i > 0 && 'aou'.contains(chars[i - 1])) continue;
    outChars.add(chars[i]);
    outOrigin.add(origin[i]);
  }
  return _Folded(outChars.join(), outOrigin);
}
