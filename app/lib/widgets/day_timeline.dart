import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../app/format.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../features/projects/project_time_dialog.dart';
import 'motion.dart';

/// What a timeline bar stands for.
typedef TimelineRef = ({String table, String id});

/// One day as two lanes on a time axis: attendance (sessions, breaks) and
/// projects (entries in project colours, unassigned gaps hatched).
///
/// With [editable], the edges of finished bars can be dragged (5-minute
/// steps) and a tap on a gap books it to a project. [onTap] opens a bar.
class DayTimeline extends ConsumerStatefulWidget {
  /// Creates the timeline of [date].
  const DayTimeline({
    super.key,
    required this.date,
    this.editable = false,
    this.onTap,
  });

  /// The day.
  final LocalDate date;

  /// Whether bars can be dragged and gaps assigned.
  final bool editable;

  /// Called with the bar that was tapped.
  final void Function(TimelineRef ref)? onTap;

  @override
  ConsumerState<DayTimeline> createState() => _DayTimelineState();
}

class _Bar {
  _Bar(this.ref, this.span, {this.color, this.icon, this.open = false});

  final TimelineRef ref;
  final Span span;
  final Color? color;
  final IconData? icon;
  final bool open;
}

class _DayTimelineState extends ConsumerState<DayTimeline> {
  /// Drag previews by row id: the span shown until the write lands.
  final Map<String, Span> _preview = {};

  static const _lane = 30.0;
  static const _gap = 6.0;
  static const _handle = 14.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final zone = ref.watch(zoneProvider);
    final ledger = ref.watch(ledgerProvider);
    final data = ref.watch(ledgerDataProvider);
    final now = ledger.nowMinute;
    final dayWindow = zone.daySpan(widget.date);
    final day = ledger.day(widget.date);

    Span clip(Span s) => Span(
      math.max(s.start, dayWindow.start),
      math.max(
        math.max(s.start, dayWindow.start),
        math.min(s.end, dayWindow.end),
      ),
    );
    bool onDay(Span s) => s.start < dayWindow.end && s.end > dayWindow.start;

    final sessions = [
      for (final s in data.sessions)
        if (onDay(s.spanAt(now)))
          _Bar(
            (table: 'work_sessions', id: s.id),
            clip(_preview[s.id] ?? s.spanAt(now)),
            icon: locationIcon(s.location),
            open: s.isOpen,
          ),
    ];
    final breaks = [
      for (final b in data.breaks)
        if (onDay(b.spanAt(now)))
          _Bar(
            (table: 'breaks', id: b.id),
            clip(_preview[b.id] ?? b.spanAt(now)),
            open: b.end == null,
          ),
    ];
    final entries = [
      for (final e in data.entries)
        if (onDay(e.spanAt(now)))
          _Bar(
            (table: 'project_entries', id: e.id),
            clip(_preview[e.id] ?? e.spanAt(now)),
            color: scheme.projectColor(e.projectId),
            open: e.end == null,
          ),
    ];
    final gaps = day.isTripDay
        ? const <Span>[]
        : day.work.unassignedSpans.spans.where((g) => g.length >= 5).toList();

    if (sessions.isEmpty && entries.isEmpty) return const SizedBox.shrink();

    // The visible hours: everything recorded, at least 7–19 on short days.
    final all = [...sessions, ...breaks, ...entries].map((b) => b.span);
    final first = all.map((s) => s.start).reduce(math.min);
    final last = all.map((s) => s.end).reduce(math.max);
    final midnight = dayWindow.start;
    var from = ((first - midnight) ~/ 60).clamp(0, 23);
    var to = ((last - midnight + 59) ~/ 60).clamp(from + 1, 24);
    if (to - from < 6) {
      from = math.max(0, math.min(from, 7));
      to = math.min(24, math.max(to, from + 12));
    }
    final windowStart = midnight + from * 60;
    final windowMinutes = (to - from) * 60;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final perMinute = width / windowMinutes;
        double x(int minute) => (minute - windowStart) * perMinute;

        Widget bar(
          _Bar b, {
          required double top,
          required Color fill,
          required Color ink,
          bool striped = false,
        }) {
          final left = x(b.span.start);
          final w = math.max(3.0, x(b.span.end) - left);
          final body = GestureDetector(
            onTap: widget.onTap == null ? null : () => widget.onTap!(b.ref),
            child: Container(
              decoration: BoxDecoration(
                color: striped ? null : fill,
                borderRadius: BorderRadius.circular(8),
                border: striped ? Border.all(color: fill, width: 2) : null,
              ),
              alignment: Alignment.center,
              child: b.icon != null && w > 28
                  ? Icon(b.icon, size: 16, color: ink)
                  : null,
            ),
          );
          return Positioned(
            left: left,
            top: top,
            width: w,
            height: _lane,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: body),
                if (widget.editable && !b.open && w > 2 * _handle) ...[
                  _edge(b, perMinute, start: true, color: ink),
                  _edge(b, perMinute, start: false, color: ink),
                ],
              ],
            ),
          );
        }

        final nowX = x(now);
        return SizedBox(
          height: 2 * _lane + _gap + 20,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Hour grid.
              for (var h = from; h <= to; h++)
                Positioned(
                  left: x(midnight + h * 60) - 0.5,
                  top: 0,
                  bottom: 18,
                  child: Container(width: 1, color: scheme.outlineVariant),
                ),
              for (var h = from; h <= to; h += (to - from) > 12 ? 3 : 2)
                Positioned(
                  left: math.min(
                    width - 18,
                    math.max(0, x(midnight + h * 60) - 9),
                  ),
                  bottom: 0,
                  child: Text(
                    '$h',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              for (final s in sessions)
                bar(
                  s,
                  top: 0,
                  fill: scheme.primaryContainer,
                  ink: scheme.onPrimaryContainer,
                ),
              for (final b in breaks)
                bar(
                  b,
                  top: 0,
                  fill: scheme.surfaceContainerHighest,
                  ink: scheme.onSurfaceVariant,
                ),
              for (final g in gaps)
                Positioned(
                  left: x(g.start),
                  top: _lane + _gap,
                  width: math.max(3, x(g.end) - x(g.start)),
                  height: _lane,
                  child: GestureDetector(
                    onTap: widget.editable ? () => _assignGap(g) : null,
                    child: CustomPaint(
                      painter: _Hatch(scheme.outline),
                      child: x(g.end) - x(g.start) > 24 && widget.editable
                          ? Icon(Icons.add, size: 16, color: scheme.outline)
                          : null,
                    ),
                  ),
                ),
              for (final e in entries)
                bar(
                  e,
                  top: _lane + _gap,
                  fill: e.color!,
                  ink: scheme.inkOn(e.color!),
                ),
              if (widget.date == ledger.today && nowX >= 0 && nowX <= width)
                Positioned(
                  left: nowX - 1,
                  top: -4,
                  height: 2 * _lane + _gap + 8,
                  child: Container(width: 2, color: scheme.error),
                ),
            ],
          ),
        );
      },
    );
  }

  /// A drag handle on one edge of [b]; dragging moves that edge.
  Widget _edge(
    _Bar b,
    double perMinute, {
    required bool start,
    required Color color,
  }) {
    var dx = 0.0;
    Span moved() {
      final delta = (dx / perMinute / 5).round() * 5;
      return start
          ? Span(math.min(b.span.start + delta, b.span.end - 5), b.span.end)
          : Span(b.span.start, math.max(b.span.end + delta, b.span.start + 5));
    }

    return Positioned(
      left: start ? 0 : null,
      right: start ? null : 0,
      top: 0,
      bottom: 0,
      width: _handle,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => tapFeedback(),
          onHorizontalDragUpdate: (d) {
            dx += d.delta.dx;
            setState(() => _preview[b.ref.id] = moved());
          },
          onHorizontalDragEnd: (_) async {
            final span = moved();
            await ref.read(repositoryProvider).write(b.ref.table, b.ref.id, {
              'start_utc': isoMinute(instantOfEpochMinute(span.start)),
              'end_utc': isoMinute(instantOfEpochMinute(span.end)),
            });
            if (mounted) setState(() => _preview.remove(b.ref.id));
          },
          child: Center(
            child: Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Opens the booking sheet with the gap's start and length.
  Future<void> _assignGap(Span gap) => showProjectTimeDialog(
    context,
    date: widget.date,
    startMinutes: localMinuteOf(
      instantOfEpochMinute(gap.start),
      widget.date,
      ref.read(zoneProvider),
    ),
    durationMinutes: gap.length,
  );
}

class _Hatch extends CustomPainter {
  _Hatch(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    final line = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1.5;
    canvas
      ..save()
      ..clipRRect(rrect);
    for (var x = -size.height; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
    }
    canvas
      ..restore()
      ..drawRRect(
        rrect,
        Paint()
          ..color = color.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke,
      );
  }

  @override
  bool shouldRepaint(_Hatch old) => old.color != color;
}
