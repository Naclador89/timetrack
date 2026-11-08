import '../model/project.dart';
import '../time/local_date.dart';
import 'ledger.dart';
import 'review.dart';

/// A project's booked minutes on one day and what was done
/// (spec: calculations.md §3.1).
final class ProjectDay {
  /// Creates a day.
  const ProjectDay({
    required this.date,
    required this.minutes,
    this.notes = const [],
  });

  /// The local date.
  final LocalDate date;

  /// Booked minutes (§3, incl. the trip project's share).
  final int minutes;

  /// Notes of the day's entries and durations, in order, without repeats.
  final List<String> notes;
}

/// The days [projectId] has booked time on, oldest first
/// (spec: calculations.md §3.1).
List<ProjectDay> projectHistory(Ledger ledger, String projectId) {
  final zone = ledger.zone;
  final data = ledger.data;
  final today = zone.dateOf(
    DateTime.fromMillisecondsSinceEpoch(ledger.nowMinute * 60000, isUtc: true),
  );
  final dates = <LocalDate>{};
  final notes = <LocalDate, List<String>>{};
  void note(LocalDate d, String n) {
    if (n.trim().isEmpty) return;
    final list = notes.putIfAbsent(d, () => []);
    if (!list.contains(n.trim())) list.add(n.trim());
  }

  void range(DateTime start, DateTime? end) {
    final last = end == null ? today : zone.dateOf(end);
    for (var d = zone.dateOf(start); !d.isAfter(last); d = d.addDays(1)) {
      dates.add(d);
    }
  }

  for (final e in data.entries.where((e) => e.projectId == projectId)) {
    range(e.start, e.end);
    note(zone.dateOf(e.start), e.note);
  }
  for (final d in data.durations.where((d) => d.projectId == projectId)) {
    dates.add(d.date);
    note(d.date, d.note);
  }
  for (final t in data.trips.where((t) => t.projectId == projectId)) {
    range(t.depart, t.returnAt);
  }
  return [
    for (final d in dates.toList()..sort())
      if (ledger.day(d).bookedByProject[projectId] case final m? when m > 0)
        ProjectDay(date: d, minutes: m, notes: notes[d] ?? const []),
  ];
}

/// The budget notices of [projects] between [from] and [to]: the day the
/// running total reaches 80 % and the day it exceeds 100 % of the budget
/// (spec: calculations.md §3.1).
List<ReviewItem> budgetItems(
  Ledger ledger,
  Iterable<Project> projects, {
  required LocalDate from,
  required LocalDate to,
}) {
  final items = <ReviewItem>[];
  for (final p in projects) {
    final budget = p.budgetMinutes;
    if (budget == null || budget <= 0) continue;
    var total = 0;
    LocalDate? near, over;
    for (final day in projectHistory(ledger, p.id)) {
      total += day.minutes;
      if (near == null && total * 100 >= budget * 80) near = day.date;
      if (total > budget) {
        over = day.date;
        break;
      }
    }
    bool inRange(LocalDate d) => !d.isBefore(from) && !d.isAfter(to);
    if (near != null && near != over && inRange(near)) {
      items.add(
        ReviewItem(
          date: near,
          kind: ReviewKind.projectBudgetNear,
          minutes: budget,
          refId: p.id,
        ),
      );
    }
    if (over != null && inRange(over)) {
      items.add(
        ReviewItem(
          date: over,
          kind: ReviewKind.projectBudgetOver,
          minutes: budget,
          refId: p.id,
        ),
      );
    }
  }
  return items;
}
