import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../app/providers.dart';

/// `local_values` key: address of the company booking page
/// (booking-transfer.md §1). Device local, never in the repo.
const bookingUrlKey = 'booking_url';

/// `local_values` key of the transfer marker of [weekKey], e.g.
/// `booking_transfer/2026-W46` (booking-transfer.md §7).
String bookingMarkerKey(String weekKey) => 'booking_transfer/$weekKey';

/// Whether this platform can fill the booking page (Windows, WebView2).
final bookingSupportedProvider = Provider<bool>((ref) => Platform.isWindows);

/// The address of the booking page, empty if not set.
final bookingUrlProvider = FutureProvider<String>((ref) async {
  final raw = await ref
      .watch(storeProvider)
      .transaction((tx) => tx.localValue(bookingUrlKey));
  return raw?.trim() ?? '';
});

/// Whether the week view offers the transfer (booking-transfer.md §1).
final bookingAvailableProvider = Provider<bool>(
  (ref) =>
      ref.watch(bookingSupportedProvider) &&
      (ref.watch(bookingUrlProvider).value ?? '').isNotEmpty,
);

/// Saves the address of the booking page (empty removes it).
Future<void> saveBookingUrl(SyncStore store, String url) => store.transaction(
  (tx) => tx.setLocalValue(bookingUrlKey, url.trim().isEmpty ? null : url),
);

/// A week transferred to the booking system (booking-transfer.md §7).
final class BookingMarker {
  /// Creates the marker.
  const BookingMarker({required this.at, required this.fingerprint});

  /// Reads a stored marker; `null` if it is missing or broken.
  static BookingMarker? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return BookingMarker(
        at: DateTime.parse(json['at'] as String),
        fingerprint: json['fingerprint'] as String,
      );
    } on Object {
      return null;
    }
  }

  /// When the booking was started (UTC).
  final DateTime at;

  /// [WeekBooking.fingerprint] at that time.
  final String fingerprint;

  /// The stored form.
  String encode() => jsonEncode({
    'at': at.toUtc().toIso8601String(),
    'fingerprint': fingerprint,
  });
}

/// The transfer marker of a week key (`2026-W46`).
final bookingMarkerProvider = FutureProvider.family<BookingMarker?, String>((
  ref,
  weekKey,
) async {
  final raw = await ref
      .watch(storeProvider)
      .transaction((tx) => tx.localValue(bookingMarkerKey(weekKey)));
  return BookingMarker.tryParse(raw);
});

/// Stores the transfer marker of [week].
Future<void> saveBookingMarker(
  SyncStore store,
  WeekBooking week,
  DateTime at,
) => store.transaction(
  (tx) => tx.setLocalValue(
    bookingMarkerKey(week.weekKey),
    BookingMarker(at: at, fingerprint: week.fingerprint).encode(),
  ),
);

/// The week starting at a Monday, ready for the booking form.
final weekBookingProvider = Provider.family<WeekBooking, LocalDate>(
  (ref, monday) => buildWeekBooking(
    ref.watch(ledgerProvider),
    ref.watch(projectByIdProvider),
    monday: monday,
  ),
);
