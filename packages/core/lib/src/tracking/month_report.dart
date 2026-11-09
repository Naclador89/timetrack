import '../time/local_date.dart';

/// The month whose overtime balance is still to be reported, as its first
/// day, or `null` (spec: work-pc.md §4).
///
/// That is the month before [today]'s, unless [done] (`YYYY-MM`, the last
/// month reported) is that month or a later one, or it ends before
/// [balanceStart].
LocalDate? monthReportDue({
  required LocalDate today,
  required LocalDate balanceStart,
  String? done,
}) {
  final month = today.startOfMonth.addDays(-1).startOfMonth;
  final end = today.startOfMonth.addDays(-1);
  if (end.isBefore(balanceStart)) return null;
  if (done != null && done.compareTo(monthKey(month)) >= 0) return null;
  return month;
}

/// `YYYY-MM` of [date]'s month, as stored for the month report.
String monthKey(LocalDate date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';
