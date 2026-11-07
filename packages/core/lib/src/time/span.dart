/// A half-open time interval `[start, end)` in whole minutes since the Unix epoch (UTC).
///
/// Every calculation works in whole minutes (spec: calculations.md §1), so
/// plain `int`s avoid any rounding and stay fast.
final class Span {
  /// Creates the span `[start, end)`. Throws an [ArgumentError] if `end < start`.
  Span(this.start, this.end) {
    if (end < start) {
      throw ArgumentError('Span end ($end) is before start ($start)');
    }
  }

  /// Creates a span from two UTC instants, truncated to the full minute.
  factory Span.fromInstants(DateTime start, DateTime end) =>
      Span(epochMinute(start), epochMinute(end));

  /// Start, in minutes since the epoch (inclusive).
  final int start;

  /// End, in minutes since the epoch (exclusive).
  final int end;

  /// Length in minutes.
  int get length => end - start;

  /// Whether the span has zero length.
  bool get isEmpty => end == start;

  /// The overlap with [other], or `null` if they don't overlap.
  Span? intersect(Span other) {
    final s = start > other.start ? start : other.start;
    final e = end < other.end ? end : other.end;
    return s < e ? Span(s, e) : null;
  }

  @override
  bool operator ==(Object other) =>
      other is Span && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'Span($start, $end)';
}

/// Minutes since the Unix epoch for [instant], truncated to the full minute.
int epochMinute(DateTime instant) =>
    instant.toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute;

/// The UTC instant for [minute] minutes since the Unix epoch.
DateTime instantOfEpochMinute(int minute) =>
    DateTime.fromMillisecondsSinceEpoch(
      minute * Duration.millisecondsPerMinute,
      isUtc: true,
    );

/// A set of time spans with **union** semantics: sorted, non-overlapping,
/// non-adjacent and without empty spans.
///
/// Totals are always computed on unions, so overlapping or duplicated entries,
/// for example after a sync conflict, never count twice (spec: calculations.md §2).
final class SpanSet {
  /// Creates the union of [spans]. Empty spans are dropped; overlapping and
  /// touching spans are merged.
  factory SpanSet(Iterable<Span> spans) {
    final sorted = spans.where((s) => !s.isEmpty).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final merged = <Span>[];
    for (final s in sorted) {
      if (merged.isNotEmpty && s.start <= merged.last.end) {
        final last = merged.removeLast();
        merged.add(Span(last.start, s.end > last.end ? s.end : last.end));
      } else {
        merged.add(s);
      }
    }
    return SpanSet._(List.unmodifiable(merged));
  }

  const SpanSet._(this.spans);

  /// The empty set.
  static const SpanSet empty = SpanSet._([]);

  /// The disjoint spans, in ascending order.
  final List<Span> spans;

  /// Total length in minutes.
  int get length => spans.fold(0, (sum, s) => sum + s.length);

  /// Whether the set covers no time at all.
  bool get isEmpty => spans.isEmpty;

  /// The union of this set and [other].
  SpanSet union(SpanSet other) => SpanSet([...spans, ...other.spans]);

  /// The time covered by both this set and [other].
  SpanSet intersect(SpanSet other) {
    final result = <Span>[];
    var i = 0, j = 0;
    while (i < spans.length && j < other.spans.length) {
      final overlap = spans[i].intersect(other.spans[j]);
      if (overlap != null) result.add(overlap);
      if (spans[i].end < other.spans[j].end) {
        i++;
      } else {
        j++;
      }
    }
    return SpanSet._(List.unmodifiable(result));
  }

  /// The time covered by this set but not by [other].
  SpanSet subtract(SpanSet other) {
    final result = <Span>[];
    var j = 0;
    for (final s in spans) {
      var cursor = s.start;
      while (j < other.spans.length && other.spans[j].end <= cursor) {
        j++;
      }
      var k = j;
      while (k < other.spans.length && other.spans[k].start < s.end) {
        final cut = other.spans[k];
        if (cut.start > cursor) result.add(Span(cursor, cut.start));
        if (cut.end > cursor) cursor = cut.end;
        k++;
      }
      if (cursor < s.end) result.add(Span(cursor, s.end));
    }
    return SpanSet._(List.unmodifiable(result));
  }

  /// This set clipped to [window], e.g. one calendar day.
  SpanSet clip(Span window) => intersect(SpanSet([window]));

  /// The gaps between consecutive spans (not before the first or after the last).
  List<Span> get gaps => [
    for (var i = 1; i < spans.length; i++)
      Span(spans[i - 1].end, spans[i].start),
  ];

  @override
  String toString() => 'SpanSet($spans)';
}

/// Formats [minutes] as `H:MM`, negative values as `−H:MM` with a real minus
/// sign (spec: calculations.md §14).
String formatMinutes(int minutes) {
  final sign = minutes < 0 ? '\u2212' : '';
  final m = minutes.abs();
  return '$sign${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}';
}
