import 'package:flutter/material.dart';
import 'package:timetrack_core/timetrack_core.dart';

/// Picks a start and an end date in one calendar: the first tap sets one end,
/// the second tap the other, and the dialog closes right away, without an OK
/// (tap the same day twice for a single day; the order of the taps doesn't
/// matter). With [single] it closes after the first tap and returns no end.
///
/// [title] is shown before the first tap, [secondTitle] after it; [today]
/// gets a ring.
Future<(LocalDate, LocalDate?)?> pickDateRange(
  BuildContext context, {
  required LocalDate start,
  LocalDate? end,
  required LocalDate today,
  required String title,
  required String secondTitle,
  bool single = false,
}) => showDialog<(LocalDate, LocalDate?)>(
  context: context,
  builder: (_) => _RangeDialog(
    start: start,
    end: end,
    today: today,
    title: title,
    secondTitle: secondTitle,
    single: single,
  ),
);

class _RangeDialog extends StatefulWidget {
  const _RangeDialog({
    required this.start,
    required this.end,
    required this.today,
    required this.title,
    required this.secondTitle,
    required this.single,
  });

  final LocalDate start;
  final LocalDate? end;
  final LocalDate today;
  final String title;
  final String secondTitle;
  final bool single;

  @override
  State<_RangeDialog> createState() => _RangeDialogState();
}

class _RangeDialogState extends State<_RangeDialog> {
  // Pages count months from January of year 0, so any date has a page.
  static int _page(LocalDate d) => d.year * 12 + d.month - 1;

  late final _pages = PageController(initialPage: _page(widget.start));
  late int _shown = _page(widget.start);

  /// The first tap, while waiting for the second.
  LocalDate? _first;

  /// What is highlighted: the dates passed in, then the taps.
  late LocalDate _from = widget.start;
  late LocalDate? _to = widget.end;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _tap(LocalDate d) {
    final first = _first;
    if (widget.single) {
      setState(() {
        _from = d;
        _to = null;
      });
      Navigator.pop(context, (d, null));
    } else if (first == null) {
      setState(() {
        _first = _from = d;
        _to = null;
      });
    } else {
      final (a, b) = d.isBefore(first) ? (d, first) : (first, d);
      // The closing fade shows the picked range.
      setState(() {
        _from = a;
        _to = b;
      });
      Navigator.pop(context, (a, b));
    }
  }

  void _go(int by) => _pages.animateToPage(
    _shown + by,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    final shown = DateTime(_shown ~/ 12, _shown % 12 + 1);
    return AlertDialog(
      title: Text(_first == null ? widget.title : widget.secondTitle),
      content: SizedBox(
        width: 336,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    material.formatMonthYear(shown),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: material.previousMonthTooltip,
                  onPressed: () => _go(-1),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: material.nextMonthTooltip,
                  onPressed: () => _go(1),
                ),
              ],
            ),
            _Weekdays(material),
            SizedBox(
              height: _MonthGrid.height,
              child: PageView.builder(
                controller: _pages,
                onPageChanged: (p) => setState(() => _shown = p),
                itemBuilder: (_, p) => _MonthGrid(
                  month: LocalDate(p ~/ 12, p % 12 + 1, 1),
                  firstWeekday: material.firstDayOfWeekIndex,
                  from: _from,
                  to: _to,
                  today: widget.today,
                  onTap: _tap,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(material.cancelButtonLabel),
        ),
      ],
    );
  }
}

class _Weekdays extends StatelessWidget {
  const _Weekdays(this.material);

  final MaterialLocalizations material;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final first = material.firstDayOfWeekIndex;
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: Text(
                // narrowWeekdays starts on Sunday.
                material.narrowWeekdays[(first + i) % 7],
                style: style,
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.firstWeekday,
    required this.from,
    required this.to,
    required this.today,
    required this.onTap,
  });

  static const _cell = 44.0;
  static const height = _cell * 6;

  final LocalDate month;

  /// 0 = Sunday, as [MaterialLocalizations.firstDayOfWeekIndex].
  final int firstWeekday;
  final LocalDate from;
  final LocalDate? to;
  final LocalDate today;
  final ValueChanged<LocalDate> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.bodyMedium!;
    // LocalDate.weekday is 1 (Monday) to 7 (Sunday).
    final lead = (month.weekday % 7 - firstWeekday) % 7;
    final gridStart = month.addDays(-lead);
    final end = to ?? from;
    return Column(
      children: [
        for (var week = 0; week < 6; week++)
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: _day(
                    gridStart.addDays(week * 7 + i),
                    scheme,
                    text,
                    end,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _day(LocalDate d, ColorScheme scheme, TextStyle text, LocalDate end) {
    if (d.month != month.month) return const SizedBox(height: _cell);
    final isEnd = d == from || d == end;
    final inside = !d.isBefore(from) && !d.isAfter(end);
    // The band between the ends, cut in half at each end.
    final band = inside && from != end
        ? Align(
            alignment: d == from
                ? Alignment.centerRight
                : d == end
                ? Alignment.centerLeft
                : Alignment.center,
            child: FractionallySizedBox(
              widthFactor: d == from || d == end ? 0.5 : 1,
              child: Container(height: 36, color: scheme.secondaryContainer),
            ),
          )
        : null;
    return SizedBox(
      height: _cell,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ?band,
          InkResponse(
            onTap: () => onTap(d),
            radius: 20,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isEnd ? scheme.primary : null,
                border: d == today && !isEnd
                    ? Border.all(color: scheme.primary)
                    : null,
              ),
              child: Text(
                '${d.day}',
                style: text.copyWith(
                  color: isEnd
                      ? scheme.onPrimary
                      : inside
                      ? scheme.onSecondaryContainer
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
