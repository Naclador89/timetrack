import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/back_navigation.dart';
import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../widgets/attention.dart';
import '../../widgets/day_timeline.dart';
import '../../widgets/explain_sheet.dart';
import '../../widgets/interval_dialog.dart';
import '../../widgets/motion.dart';
import '../../widgets/quick_entry_sheet.dart';
import '../../widgets/shortcuts.dart';
import '../../widgets/undo.dart';
import '../projects/project_time_dialog.dart';
import 'absences_screen.dart';
import 'day_type_picker.dart';
import 'trip_booking_card.dart';

/// Everything recorded on one day, editable: sessions, breaks, project
/// entries and absences.
class DayScreen extends ConsumerWidget {
  /// Creates the screen for [date].
  const DayScreen({super.key, required this.date});

  /// The day being edited.
  final LocalDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final zone = ref.watch(zoneProvider);
    final ledger = ref.watch(ledgerProvider);
    final data = ref.watch(ledgerDataProvider);
    final projects = ref.watch(projectByIdProvider);
    final holiday = ref.watch(holidaysProvider).holidayOn(date);
    final day = ledger.day(date);
    final window = zone.daySpan(date);
    final now = ledger.nowMinute;
    bool onDay(Span s) => s.start < window.end && s.end > window.start;
    List<T> sorted<T>(Iterable<T> items, DateTime Function(T) start) =>
        items.toList()..sort((a, b) => start(a).compareTo(start(b)));
    final sessions = sorted(
      data.sessions.where((s) => onDay(s.spanAt(now))),
      (s) => s.start,
    );
    final breaks = sorted(
      data.breaks.where((b) => onDay(b.spanAt(now))),
      (b) => b.start,
    );
    final entries = sorted(
      data.entries.where((e) => onDay(e.spanAt(now))),
      (e) => e.start,
    );
    final canWork = day.type == null || day.type!.isWork;
    final hasProjectTime =
        entries.isNotEmpty || data.durations.any((x) => x.date == date);

    String range(DateTime s, DateTime? e) =>
        '${context.time(s, zone)} – ${e == null ? l.running : context.time(e, zone)}';

    // Quick delete from the overview (user request 2026-11-08), undone from
    // the snackbar instead of asking first.
    Widget deleteButton(String table, String id) => IconButton(
      tooltip: l.delete,
      icon: const Icon(Icons.close),
      onPressed: () => deleteWithUndo(context, ref, [(table, id)]),
    );

    void openBar(TimelineRef bar) {
      switch (bar.table) {
        case 'project_entries':
          final e = entries.where((e) => e.id == bar.id).firstOrNull;
          if (e != null) showProjectTimeDialog(context, date: date, entry: e);
        case 'breaks':
          final b = breaks.where((b) => b.id == bar.id).firstOrNull;
          if (b == null) return;
          _editInterval(
            context,
            ref,
            'breaks',
            b.id,
            start: b.start,
            end: b.end,
          );
        default:
          final s = sessions.where((s) => s.id == bar.id).firstOrNull;
          if (s == null) return;
          _editInterval(
            context,
            ref,
            'work_sessions',
            s.id,
            start: s.start,
            end: s.end,
            location: s.location,
          );
      }
    }

    final theme = Theme.of(context);
    Widget figure(String label, int minutes, {Color? color}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        Text(
          formatMinutes(minutes),
          style: theme.textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    Widget section(String title, VoidCallback onAdd, List<Widget> tiles) =>
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                trailing: IconButton(
                  tooltip: l.add,
                  icon: const Icon(Icons.add),
                  onPressed: onAdd,
                ),
              ),
              ...tiles,
            ],
          ),
        );

    void open(LocalDate d) => context.go(dayLocation(context, d));
    return PageKeys(
      onPrevious: () => open(date.addDays(-1)),
      onNext: () => open(date.addDays(1)),
      onToday: () => open(ref.read(todayProvider)),
      child: CollapsingFab(
        onPressed: () => showQuickEntrySheet(context, date),
        icon: const Icon(Icons.bolt),
        label: Text(l.quickEntry),
        builder: (context, fab, onScroll) => Scaffold(
          appBar: AppBar(
            title: Text(context.longDate(date)),
            actions: [
              IconButton(
                tooltip: l.goToToday,
                icon: const Icon(Icons.today),
                onPressed: date == ref.watch(todayProvider)
                    ? null
                    : () => context.go(
                        dayLocation(context, ref.read(todayProvider)),
                      ),
              ),
              IconButton(
                tooltip: l.addAbsence,
                icon: const Icon(Icons.beach_access_outlined),
                onPressed: () => showAbsenceDialog(
                  context,
                  ref,
                  initial: date,
                  singleDay: true,
                ),
              ),
            ],
          ),
          floatingActionButton: fab,
          body: NotificationListener<UserScrollNotification>(
            onNotification: onScroll,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
              children: [
                Card(
                  child: InkWell(
                    onTap: () => showDayExplanation(context, ref, date),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              DayTypeChip(date: date),
                              const Spacer(),
                              Icon(
                                Icons.help_outline,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                                semanticLabel: l.explainHow,
                              ),
                            ],
                          ),
                          if (!canWork) ...[
                            const SizedBox(height: 8),
                            Text(
                              l.absenceWorkHint,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                l.accountSection,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 24,
                            runSpacing: 8,
                            children: [
                              // On trip days the real time is in the travel
                              // record below; the account shows what counts.
                              if (day.type != DayType.businessTrip)
                                figure(l.worked, day.work.worked),
                              figure(l.credited, day.credited),
                              figure(l.target, day.target),
                              figure(
                                l.difference,
                                day.delta,
                                color: theme.colorScheme.deltaColor(day.delta),
                              ),
                              if (day.sundayHours > 0)
                                figure(l.sundayHours, day.sundayHours),
                              if (day.specialHolidayHours > 0)
                                figure(
                                  l.specialHolidayHours,
                                  day.specialHolidayHours,
                                ),
                              if (day.nightHours > 0)
                                figure(l.nightHours, day.nightHours),
                              if (day.unassigned > 0 && !day.isTripDay)
                                figure(l.unassigned, day.unassigned),
                            ],
                          ),
                          if (holiday != null ||
                              day.isTripDay ||
                              day.breaks.deduction > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              [
                                if (holiday != null) holiday.name,
                                if (day.isTripDay) l.tripDay,
                                if (day.breaks.deduction > 0)
                                  l.breakDeducted(
                                    formatMinutes(day.breaks.deduction),
                                  ),
                              ].join(' · '),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (day.type == DayType.businessTrip)
                  TripBookingCard(date: date),
                AttentionCards(
                  from: date,
                  to: date,
                  showDates: false,
                  showHidden: true,
                ),
                if (sessions.isNotEmpty || entries.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.timeline, style: theme.textTheme.titleSmall),
                          const SizedBox(height: 4),
                          Text(
                            l.timelineHint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DayTimeline(
                            date: date,
                            editable: true,
                            onTap: openBar,
                          ),
                        ],
                      ),
                    ),
                  ),
                // Working time can be recorded on every day type; on absence days it
                // counts as overtime (calculations §8, §15, user request 2026-11-08).
                section(
                  l.sessions,
                  () => _editInterval(context, ref, 'work_sessions', null),
                  [
                    for (final s in sessions)
                      ListTile(
                        leading: Icon(
                          locationIcon(s.location),
                          color: theme.colorScheme.primary,
                        ),
                        trailing: deleteButton('work_sessions', s.id),
                        title: Text(range(s.start, s.end)),
                        subtitle: Text(context.locationName(s.location)),
                        onTap: () => _editInterval(
                          context,
                          ref,
                          'work_sessions',
                          s.id,
                          start: s.start,
                          end: s.end,
                          location: s.location,
                        ),
                      ),
                  ],
                ),
                section(
                  l.breaks,
                  () => _editInterval(context, ref, 'breaks', null),
                  [
                    for (final b in breaks)
                      ListTile(
                        leading: const Icon(Icons.coffee_outlined),
                        trailing: deleteButton('breaks', b.id),
                        title: Text(range(b.start, b.end)),
                        onTap: () => _editInterval(
                          context,
                          ref,
                          'breaks',
                          b.id,
                          start: b.start,
                          end: b.end,
                        ),
                      ),
                  ],
                ),
                // Trip days have no project time, only travel and on-site time;
                // absence days nothing (user decisions 2026-11-08). Old entries stay
                // visible so they can still be edited or deleted.
                if (day.type == DayType.businessTrip && !hasProjectTime)
                  const SizedBox.shrink() // the travel record is at the top
                else if (day.type == null ||
                    day.type!.allowsProjectTime ||
                    hasProjectTime ||
                    (!canWork && sessions.isNotEmpty))
                  section(
                    l.projectEntries,
                    () => showProjectTimeDialog(context, date: date),
                    [
                      for (final p in data.durations.where(
                        (x) => x.date == date,
                      ))
                        ListTile(
                          leading: Icon(
                            Icons.timelapse,
                            color: theme.colorScheme.projectColor(p.projectId),
                          ),
                          trailing: deleteButton('project_entries', p.id),
                          title: Text(
                            '${formatMinutes(p.minutes)} · ${projects[p.projectId]?.name ?? '?'}',
                          ),
                          subtitle: p.note.isEmpty ? null : Text(p.note),
                          onTap: () => showProjectTimeDialog(
                            context,
                            date: date,
                            duration: p,
                          ),
                        ),
                      for (final e in entries)
                        ListTile(
                          leading: Icon(
                            Icons.circle,
                            size: 14,
                            color: theme.colorScheme.projectColor(e.projectId),
                          ),
                          trailing: e.end == null
                              ? null // a running timer is stopped on Today
                              : deleteButton('project_entries', e.id),
                          title: Text(
                            '${range(e.start, e.end)} · ${projects[e.projectId]?.name ?? '?'}',
                          ),
                          subtitle: e.note.isEmpty ? null : Text(e.note),
                          onTap: () => showProjectTimeDialog(
                            context,
                            date: date,
                            entry: e,
                          ),
                        ),
                    ],
                  ),
                if (day.absences.isNotEmpty)
                  Card(
                    child: Column(
                      children: [
                        for (final a in day.absences)
                          ListTile(
                            leading: const Icon(Icons.beach_access_outlined),
                            title: Text(context.absenceName(a.kind)),
                            subtitle: a.fraction < 1 ? Text(l.halfDay) : null,
                            trailing: deleteButton('absences', a.id),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editInterval(
    BuildContext context,
    WidgetRef ref,
    String table,
    String? id, {
    DateTime? start,
    DateTime? end,
    WorkLocation? location,
  }) => showIntervalDialog(
    context,
    date: date,
    table: table,
    id: id,
    start: start,
    end: end,
    location: location,
  );
}
