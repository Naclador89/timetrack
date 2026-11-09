import '../model/planning.dart';
import '../time/local_date.dart';
import 'ledger.dart';
import 'review.dart';
import 'target.dart';

/// Zones of the overtime account (spec: calculations.md §20.1), from good to
/// bad.
enum BalanceZone {
  /// Inside every limit.
  green,

  /// Beyond the yellow limit.
  yellow,

  /// Beyond the red limit.
  red,

  /// Beyond the account's hard limit.
  overLimit,
}

/// The limits of the overtime account in minutes, each positive; `null` =
/// no such limit (calculations.md §20). None is built in.
final class BalanceLimits {
  /// Creates limits.
  const BalanceLimits({
    this.yellowPlus,
    this.yellowMinus,
    this.redPlus,
    this.redMinus,
    this.maxPlus,
    this.maxMinus,
  });

  /// Yellow above +this.
  final int? yellowPlus;

  /// Yellow below −this.
  final int? yellowMinus;

  /// Red above +this.
  final int? redPlus;

  /// Red below −this.
  final int? redMinus;

  /// Over the limit above +this.
  final int? maxPlus;

  /// Over the limit below −this.
  final int? maxMinus;

  /// Whether any limit is set.
  bool get isSet => [
    yellowPlus,
    yellowMinus,
    redPlus,
    redMinus,
    maxPlus,
    maxMinus,
  ].any((v) => v != null);
}

/// The zone of [balance] (§20.1); `null` without any limit.
BalanceZone? balanceZone(int balance, BalanceLimits limits) {
  if (!limits.isSet) return null;
  bool beyond(int? plus, int? minus) =>
      (plus != null && balance > plus) || (minus != null && balance < -minus);
  if (beyond(limits.maxPlus, limits.maxMinus)) return BalanceZone.overLimit;
  if (beyond(limits.redPlus, limits.redMinus)) return BalanceZone.red;
  if (beyond(limits.yellowPlus, limits.yellowMinus)) return BalanceZone.yellow;
  return BalanceZone.green;
}

/// The zone notices between [from] and [to] (§20.1): a finished day whose
/// closing balance is in a worse zone than the day before. [ReviewItem.minutes]
/// is the balance, [ReviewItem.refId] the zone's name.
List<ReviewItem> balanceZoneItems(
  Ledger ledger,
  BalanceLimits limits, {
  required LocalDate from,
  required LocalDate to,
}) {
  if (!limits.isSet) return const [];
  final start = ledger.settings.balanceStart;
  final first = from.isBefore(start) ? start : from;
  // Today's balance counts the full target against the time so far.
  final yesterday = ledger.today.addDays(-1);
  final last = to.isAfter(yesterday) ? yesterday : to;
  final items = <ReviewItem>[];
  var balance = ledger.balanceAtEndOf(first.addDays(-1));
  var zone = balanceZone(balance, limits)!;
  for (var d = first; !d.isAfter(last); d = d.addDays(1)) {
    balance += ledger.day(d).delta;
    final now = balanceZone(balance, limits)!;
    if (now.index > zone.index) {
      items.add(
        ReviewItem(
          date: d,
          kind: ReviewKind.balanceZone,
          minutes: balance,
          refId: now.name,
        ),
      );
    }
    zone = now;
  }
  return items;
}

/// The overtime carried over from the last year and what of it is still open
/// (calculations.md §20.2).
final class BalanceCarryOver {
  /// Creates the status.
  const BalanceCarryOver({
    required this.year,
    required this.carry,
    required this.open,
    required this.deadline,
    required this.expired,
  });

  /// The year the carry-over is to be settled in.
  final int year;

  /// The balance at the end of 31 December of the year before.
  final int carry;

  /// What is still to reduce (plus) or work off (minus), signed like [carry].
  final int open;

  /// The last day to settle it.
  final LocalDate deadline;

  /// Whether [deadline] has passed.
  final bool expired;
}

/// The carry-over of today's year with [months] to settle it (§20.2);
/// `null` if [months] is 0, the balance starts after 1 January or nothing is
/// open.
BalanceCarryOver? balanceCarryOver(Ledger ledger, {required int months}) {
  if (months <= 0) return null;
  final today = ledger.today;
  final year = today.year;
  if (ledger.settings.balanceStart.isAfter(LocalDate(year, 1, 1))) return null;
  final carry = ledger.balanceAtEndOf(LocalDate(year - 1, 12, 31));
  final current = ledger.balanceAtEndOf(today.addDays(-1));
  final open = carry > 0
      ? (current < 0 ? 0 : (current < carry ? current : carry))
      : (current > 0 ? 0 : (current > carry ? current : carry));
  if (open == 0) return null;
  final deadline = _endOfMonth(year, months);
  return BalanceCarryOver(
    year: year,
    carry: carry,
    open: open,
    deadline: deadline,
    expired: today.isAfter(deadline),
  );
}

/// Carried-over vacation not yet taken or planned before its deadline
/// (calculations.md §10.2); `null` if [months] is 0, today is past the
/// deadline or nothing is open.
({double open, LocalDate deadline})? vacationCarryLeft({
  required double carryOver,
  required int months,
  required TargetCalendar targets,
  required List<Absence> absences,
  required LocalDate today,
}) {
  if (months <= 0 || carryOver <= 0) return null;
  final deadline = _endOfMonth(today.year, months);
  if (today.isAfter(deadline)) return null;
  final start = LocalDate(today.year, 1, 1);
  var used = 0.0;
  for (final a in absences) {
    if (a.kind != AbsenceKind.vacation) continue;
    if (a.date.isBefore(start) || a.date.isAfter(deadline)) continue;
    if (targets.isWorkday(a.date)) used += a.fraction;
  }
  final open = carryOver - used;
  return open > 0 ? (open: open, deadline: deadline) : null;
}

LocalDate _endOfMonth(int year, int month) => month >= 12
    ? LocalDate(year, 12, 31)
    : LocalDate(year, month + 1, 1).addDays(-1);
