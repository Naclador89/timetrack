import '../rules/ledger.dart';

/// Booking step for project time (user request 2026-11-08): 15 minutes.
const bookingStepMinutes = 15;

/// [minutes] on the 15-minute grid, nearest step, at least one step
/// (calculations.md §3).
int snapToQuarter(int minutes) {
  final snapped =
      ((minutes + bookingStepMinutes ~/ 2) ~/ bookingStepMinutes) *
      bookingStepMinutes;
  return snapped < bookingStepMinutes ? bookingStepMinutes : snapped;
}

/// The last [limit] different notes written for [projectId], newest first:
/// suggestions for the comment field.
List<String> recentNotes(LedgerData data, String projectId, {int limit = 3}) {
  final dated = <(DateTime, String)>[
    for (final e in data.entries)
      if (e.projectId == projectId && e.note.trim().isNotEmpty)
        (e.start, e.note.trim()),
    for (final d in data.durations)
      if (d.projectId == projectId && d.note.trim().isNotEmpty)
        (DateTime.utc(d.date.year, d.date.month, d.date.day), d.note.trim()),
  ]..sort((a, b) => b.$1.compareTo(a.$1));
  final notes = <String>[];
  for (final (_, note) in dated) {
    if (!notes.contains(note)) notes.add(note);
    if (notes.length == limit) break;
  }
  return notes;
}
