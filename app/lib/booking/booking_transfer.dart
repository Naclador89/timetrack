import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timetrack_core/timetrack_core.dart';
import 'package:webview_windows/webview_windows.dart';

import '../app/format.dart';
import '../app/providers.dart';
import 'booking_store.dart';

/// The week view's line for the booking system: transfer status and the
/// way to the preview (booking-transfer.md §1, §7). Shown only on Windows
/// with an address set.
class BookingWeekTile extends ConsumerWidget {
  /// Creates the tile for the week starting at [monday].
  const BookingWeekTile({super.key, required this.monday});

  /// The Monday of the week.
  final LocalDate monday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(bookingAvailableProvider)) return const SizedBox.shrink();
    final l = context.l10n;
    final week = ref.watch(weekBookingProvider(monday));
    final marker = ref.watch(bookingMarkerProvider(week.weekKey)).value;
    final zone = ref.watch(zoneProvider);
    final String status;
    if (marker == null) {
      status = l.bookingNotTransferred;
    } else {
      final date = context.date(zone.dateOf(marker.at));
      status = marker.fingerprint == week.fingerprint
          ? l.bookingTransferredOn(date)
          : l.bookingChangedSince(date);
    }
    final changed = marker != null && marker.fingerprint != week.fingerprint;
    return Card(
      child: ListTile(
        leading: Icon(
          marker == null
              ? Icons.upload_outlined
              : changed
              ? Icons.sync_problem_outlined
              : Icons.cloud_done_outlined,
        ),
        title: Text(l.bookingSystem),
        subtitle: Text(status),
        trailing: TextButton(
          onPressed: () => showBookingPreview(context, ref, monday),
          child: Text(l.bookingTransfer),
        ),
      ),
    );
  }
}

/// Hours with a decimal comma, `1,5` (booking-transfer.md §5).
String _hours(BuildContext context, int halfHours) =>
    halfHours == 0 ? '' : context.days(halfHours / 2);

/// Shows what would be filled in (booking-transfer.md §5); "open" goes on to
/// the booking page.
Future<void> showBookingPreview(
  BuildContext context,
  WidgetRef ref,
  LocalDate monday,
) async {
  final week = ref.read(weekBookingProvider(monday));
  final url = ref.read(bookingUrlProvider).value ?? '';
  final open = await showDialog<bool>(
    context: context,
    builder: (_) => BookingPreviewDialog(week: week),
  );
  if (open != true || url.isEmpty || !context.mounted) return;
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => BookingWebViewScreen(week: week, url: url),
    ),
  );
  ref.invalidate(bookingMarkerProvider(week.weekKey));
}

/// The preview: rows × Mo–So, sums and warnings (booking-transfer.md §3, §5).
class BookingPreviewDialog extends StatelessWidget {
  /// Creates the dialog.
  const BookingPreviewDialog({super.key, required this.week});

  /// The week to transfer.
  final WeekBooking week;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dayNames = [
      for (var i = 0; i < 7; i++)
        DateFormat.E(locale).format(
          DateTime(week.monday.year, week.monday.month, week.monday.day + i),
        ),
    ];
    final theme = Theme.of(context);
    final warnings = [
      if (week.runningTimer) l.bookingRunningTimer,
      for (final s in week.skipped)
        l.bookingSkipped(s.name, formatMinutes(s.minutes)),
      for (final MapEntry(key: day, value: m) in week.unassignedByDay.entries)
        l.bookingUnassigned(context.shortDate(day), formatMinutes(m)),
      if (week.roundingDifferences.isNotEmpty)
        l.bookingRounding(
          formatMinutes(week.roundedMinutes),
          formatMinutes(week.exactMinutes),
        ),
    ];
    return AlertDialog(
      title: Text(l.bookingPreviewTitle('${week.isoWeek}')),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (week.rows.isEmpty)
                Text(l.bookingNoRows)
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 14,
                    headingRowHeight: 36,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 52,
                    columns: [
                      DataColumn(label: Text(l.projectNumber)),
                      DataColumn(label: Text(l.orderNumber)),
                      for (final n in dayNames)
                        DataColumn(label: Text(n), numeric: true),
                      DataColumn(label: Text(l.bookingSum), numeric: true),
                    ],
                    rows: [
                      for (final r in week.rows)
                        DataRow(
                          cells: [
                            DataCell(
                              Tooltip(
                                message: r.projectNames.join(', '),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.projectNumber),
                                    Text(
                                      r.projectNames.join(', '),
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(Text(r.orderNumber)),
                            for (final h in r.halfHours)
                              DataCell(Text(_hours(context, h))),
                            DataCell(
                              Text(
                                _hours(context, r.totalHalfHours),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      DataRow(
                        cells: [
                          DataCell(Text(l.bookingSum)),
                          const DataCell(Text('')),
                          for (var i = 0; i < 7; i++)
                            DataCell(
                              Text(
                                _hours(
                                  context,
                                  week.rows.fold(
                                    0,
                                    (a, r) => a + r.halfHours[i],
                                  ),
                                ),
                              ),
                            ),
                          DataCell(
                            Text(
                              _hours(context, week.roundedMinutes ~/ 30),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (warnings.isNotEmpty) const SizedBox(height: 12),
              for (final w in warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: theme.colorScheme.tertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(w)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.cancel),
        ),
        FilledButton.icon(
          onPressed: week.rows.isEmpty
              ? null
              : () => Navigator.pop(context, true),
          icon: const Icon(Icons.open_in_browser),
          label: Text(l.bookingOpen),
        ),
      ],
    );
  }
}

/// The data handed to the fill script (booking-transfer.md §6.5).
Map<String, Object> bookingFillData(WeekBooking week) => {
  'year': week.isoYear,
  'week': week.isoWeek,
  'rows': [
    for (final r in week.rows)
      {
        'project': r.projectNumber,
        'order': r.orderNumber,
        'seconds': [for (final h in r.halfHours) h * 1800],
      },
  ],
};

/// The booking page in an embedded WebView2, filled with [week]
/// (booking-transfer.md §6). The user books there himself.
class BookingWebViewScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const BookingWebViewScreen({
    super.key,
    required this.week,
    required this.url,
  });

  /// The week to fill in.
  final WeekBooking week;

  /// Address of the booking page.
  final String url;

  @override
  ConsumerState<BookingWebViewScreen> createState() =>
      _BookingWebViewScreenState();
}

class _BookingWebViewScreenState extends ConsumerState<BookingWebViewScreen> {
  // WebView2 takes its environment options once per process.
  static bool _environmentReady = false;

  final _controller = WebviewController();
  final _subscriptions = <StreamSubscription<Object?>>[];
  String? _script;
  bool _ready = false;
  bool _fillStarted = false;
  bool _filled = false;
  bool _booked = false;
  bool _busy = true;
  final _status = <(String, bool)>[]; // text, is error

  @override
  void initState() {
    super.initState();
    // _init reads inherited widgets (l10n), which initState must not do.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_init()));
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _say(String text, {bool error = false, bool replace = true}) {
    if (!mounted) return;
    setState(() {
      if (replace) _status.clear();
      _status.add((text, error));
      if (error) _busy = false;
    });
  }

  Future<void> _init() async {
    final l = context.l10n;
    _say(l.bookingLoading);
    try {
      if (await WebviewController.getWebViewVersion() == null) {
        _say(l.bookingNoRuntime, error: true);
        return;
      }
      if (!_environmentReady) {
        final host = Uri.tryParse(widget.url)?.host ?? '';
        try {
          await WebviewController.initializeEnvironment(
            additionalArguments: host.isEmpty
                ? null
                : '--auth-server-allowlist=$host',
          );
        } on PlatformException {
          // Already set up by an earlier window.
        }
        _environmentReady = true;
      }
      _script = await rootBundle.loadString('assets/booking/applus_fill.js');
      await _controller.initialize();
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.allow);
      _subscriptions
        ..add(_controller.webMessage.listen(_onMessage))
        ..add(
          _controller.loadingState.listen((s) {
            if (s == LoadingState.navigationCompleted) unawaited(_attach());
          }),
        )
        ..add(
          _controller.onLoadError.listen(
            (e) => _say(l.bookingErrorLoad(e.name), error: true),
          ),
        );
      if (!mounted) return;
      setState(() => _ready = true);
      await _controller.loadUrl(widget.url);
    } on Object catch (e) {
      _say(l.bookingErrorLoad('$e'), error: true);
    }
  }

  /// Runs on every loaded page: waits for the form and hooks the booking.
  Future<void> _attach() async {
    await _controller.executeScript(
      '${_script!}\nwindow.TimeTrackBooking.attach();',
    );
  }

  Future<void> _fill({required bool clear}) async {
    _fillStarted = true;
    _say(context.l10n.bookingFilling);
    final data = jsonEncode(bookingFillData(widget.week));
    await _controller.executeScript(
      'window.TimeTrackBooking.fill($data, $clear);',
    );
  }

  Future<void> _onMessage(dynamic message) async {
    if (message is! Map || !mounted) return;
    final l = context.l10n;
    switch (message['type']) {
      case 'ready':
        // After booking the page may reload: fill only once.
        if (_fillStarted) return;
        if (message['hasData'] == true) {
          final replace = await _askReplace();
          if (!replace) {
            _fillStarted = true;
            _say(l.bookingKept);
            setState(() => _busy = false);
            return;
          }
          await _fill(clear: true);
        } else {
          await _fill(clear: false);
        }
      case 'filled':
        _filled = true;
        final unknown = (message['unknown'] as List?)?.cast<String>() ?? [];
        final locked = (message['locked'] as List?)?.cast<num>() ?? [];
        _say(l.bookingFilled((message['rows'] as num?)?.toInt() ?? 0));
        if (unknown.isNotEmpty) {
          _say(
            l.bookingUnknownProjects(unknown.join(', ')),
            error: true,
            replace: false,
          );
        }
        if (locked.isNotEmpty) {
          final days = [
            for (final d in locked)
              context.shortDate(widget.week.monday.addDays(d.toInt())),
          ];
          _say(
            l.bookingLockedDays(days.join(', ')),
            error: true,
            replace: false,
          );
        }
        setState(() => _busy = false);
      case 'booked':
        if (_booked) return;
        _booked = true;
        await saveBookingMarker(
          ref.read(storeProvider),
          widget.week,
          ref.read(clockProvider)().toUtc(),
        );
        _say(l.bookingBooked);
      case 'error':
        final detail = '${message['detail'] ?? ''}';
        _say(switch (message['code']) {
          'timeout' => l.bookingErrorTimeout,
          'unexpectedPage' => l.bookingErrorPage(detail),
          _ => l.bookingErrorFill(detail),
        }, error: true);
    }
  }

  Future<bool> _askReplace() async {
    final l = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.bookingReplaceTitle),
            content: Text(l.bookingReplaceBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.bookingReplace),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Closing after filling without a seen booking asks (§7).
  Future<void> _close() async {
    final navigator = Navigator.of(context);
    if (_filled && !_booked) {
      final l = context.l10n;
      final booked = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.bookingAskBooked),
          content: Text(l.bookingAskBookedBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.bookingNotBooked),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.bookingWasBooked),
            ),
          ],
        ),
      );
      if (booked == null) return;
      if (booked) {
        _booked = true;
        await saveBookingMarker(
          ref.read(storeProvider),
          widget.week,
          ref.read(clockProvider)().toUtc(),
        );
      }
    }
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: l.bookingClose,
            icon: const Icon(Icons.close),
            onPressed: _close,
          ),
          title: Text(l.bookingPreviewTitle('${widget.week.isoWeek}')),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: _status.any((s) => s.$2)
                  ? scheme.errorContainer
                  : scheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [for (final (t, _) in _status) Text(t)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _ready ? Webview(_controller) : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
