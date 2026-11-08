import '../model/attendance.dart';
import '../rules/ledger.dart';
import '../time/local_date.dart';
import '../time/span.dart';

/// A part of a trip day in the travel report (calculations.md §9.1).
enum TripLegKind {
  /// Travel to the customer: travel time before the day's last on-site
  /// time (also between two sites), or on a day without on-site time
  /// that is not the trip's last day.
  outbound,

  /// Working at the customer.
  onSite,

  /// Travel back: travel time after the day's last on-site time, or on the
  /// trip's last day without on-site time.
  inbound,
}

/// One leg with its exact local times: a travel or on-site session,
/// clipped to the day.
final class TripLeg {
  /// Creates a leg.
  const TripLeg(this.kind, this.span, {required this.sessionId});

  /// Outbound, on site or inbound.
  final TripLegKind kind;

  /// Start and end in epoch minutes (the end of a running session is now).
  final Span span;

  /// The work session it comes from (to edit it).
  final String sessionId;
}

/// The legs of trip day [date] (calculations.md §9.1), in time order.
/// They are what the travel report shows, independent of what the overtime
/// account credits for the day.
List<TripLeg> tripLegs(Ledger ledger, LocalDate date) {
  final trips = ledger.tripsOn(date);
  if (trips.isEmpty) return const [];
  final window = ledger.zone.daySpan(date);
  final parts = <(WorkSession, Span)>[
    for (final s in ledger.data.sessions)
      if (s.location == WorkLocation.travel ||
          s.location == WorkLocation.onSite)
        if (s.spanAt(ledger.nowMinute) case final span
            when span.start < window.end && span.end > window.start)
          (
            s,
            Span(
              span.start < window.start ? window.start : span.start,
              span.end > window.end ? window.end : span.end,
            ),
          ),
  ]..sort((a, b) => a.$2.start.compareTo(b.$2.start));
  final lastOnSite = parts
      .where((p) => p.$1.location == WorkLocation.onSite)
      .map((p) => p.$2.start)
      .fold<int?>(null, (a, b) => a == null || b > a ? b : a);
  // Without on-site time, the trip's last day is the way back (unless the
  // trip also starts that day).
  final zone = ledger.zone;
  final homeward =
      trips.any(
        (t) => t.returnAt != null && zone.dateOf(t.returnAt!) == date,
      ) &&
      trips.every((t) => zone.dateOf(t.depart) != date);
  return [
    for (final (s, span) in parts)
      TripLeg(
        s.location == WorkLocation.onSite
            ? TripLegKind.onSite
            : lastOnSite == null
            ? (homeward ? TripLegKind.inbound : TripLegKind.outbound)
            : span.start < lastOnSite
            ? TripLegKind.outbound
            : TripLegKind.inbound,
        span,
        sessionId: s.id,
      ),
  ];
}

/// A one-tap step on Today during a trip (calculations.md §9.1). Each
/// records the exact time the user taps it.
enum TripStep {
  /// Clock in travelling.
  startOutbound,

  /// Travelling → on site, at the same minute.
  arriveOnSite,

  /// Clock out while travelling to the customer (e.g. a pause before the
  /// appointment).
  endOutbound,

  /// Clock in on site.
  startOnSite,

  /// Clock out on site (e.g. to the hotel on foot).
  endOnSite,

  /// On site → travelling, or clock in travelling after on-site work.
  startInbound,

  /// Clock out after travelling back.
  endInbound,
}

/// The steps that fit now, the most likely one first: [running] is the
/// open session's location (`null` = clocked out), [onSiteToday] whether
/// the day already has on-site time.
List<TripStep> tripSteps({
  required WorkLocation? running,
  required bool onSiteToday,
}) => switch (running) {
  null when onSiteToday => const [TripStep.startInbound, TripStep.startOnSite],
  null => const [TripStep.startOutbound, TripStep.startOnSite],
  WorkLocation.travel when onSiteToday => const [TripStep.endInbound],
  WorkLocation.travel => const [TripStep.arriveOnSite, TripStep.endOutbound],
  WorkLocation.onSite => const [TripStep.startInbound, TripStep.endOnSite],
  _ => const [TripStep.arriveOnSite],
};
