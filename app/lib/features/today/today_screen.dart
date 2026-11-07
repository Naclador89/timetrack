import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/notices.dart';
import '../projects/project_picker.dart';
import '../projects/project_time_dialog.dart';

/// The home screen: clock in/out, breaks, projects and today's numbers.
class TodayScreen extends ConsumerWidget {
  /// Creates the screen.
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final ledger = ref.watch(ledgerProvider);
    final settings = ref.watch(settingsProvider);
    final quotas = ref.watch(homeOfficeQuotasProvider);
    final notices = reviewItems(
      ledger,
      from: today.addDays(-1),
      to: today,
      openSessionLimitMinutes: settings.openSessionLimitMinutes,
      quotas: quotas,
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.longDate(today))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (!ref.watch(isSetUpProvider)) const _SetupCard(),
          const _AttendanceCard(),
          const _ProjectCard(),
          _SummaryCard(day: ledger.day(today), ledger: ledger, quotas: quotas),
          NoticesCard(items: notices, showDates: true),
          _TodayEntries(day: ledger.day(today)),
        ],
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard();

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: ListTile(
      leading: const Icon(Icons.tune),
      title: Text(context.l10n.setupHint),
      trailing: TextButton(
        onPressed: () => context.go('/settings'),
        child: Text(context.l10n.openSettings),
      ),
    ),
  );
}

/// Clock in/out, location, break and trip.
class _AttendanceCard extends ConsumerStatefulWidget {
  const _AttendanceCard();

  @override
  ConsumerState<_AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends ConsumerState<_AttendanceCard> {
  WorkLocation? _chosen;

  /// The location for the next clock-in: the chosen one, else the last used.
  WorkLocation _nextLocation() {
    if (_chosen != null) return _chosen!;
    final sessions = ref.read(ledgerDataProvider).sessions;
    if (sessions.isEmpty) return WorkLocation.office;
    return sessions.reduce((a, b) => a.start.isAfter(b.start) ? a : b).location;
  }

  Future<void> _selectLocation(WorkLocation location) async {
    final tracker = ref.read(trackerProvider);
    final state = ref.read(trackerStateProvider);
    setState(() => _chosen = location);
    if (state.clockedIn) await tracker.changeLocation(location);
    if (location == WorkLocation.travel && state.trip == null && mounted) {
      await _askStartTrip();
    }
  }

  Future<void> _askStartTrip() async {
    final l = context.l10n;
    final destination = await showTextPrompt(
      context,
      title: l.startTripQuestion,
      label: l.destination,
      okLabel: l.startTrip,
      cancelLabel: l.notNow,
    );
    if (destination != null) {
      await ref.read(trackerProvider).startTrip(destination: destination);
    }
  }

  Future<void> _clockOut() async {
    final state = ref.read(trackerStateProvider);
    await withSummaryPrompt(context, ref, ref.read(trackerProvider).clockOut);
    if (!mounted) return;
    if (state.trip != null &&
        state.location == WorkLocation.travel &&
        mounted) {
      final end = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(c.l10n.endTripQuestion),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(c.l10n.notNow),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(c.l10n.endTrip),
            ),
          ],
        ),
      );
      if (end == true) await ref.read(trackerProvider).endTrip();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final zone = ref.watch(zoneProvider);
    final state = ref.watch(trackerStateProvider);
    final tracker = ref.watch(trackerProvider);
    final location = state.location ?? _nextLocation();
    final since = state.onBreak
        ? l.onBreakSince(
            context.time(
              DateTime.parse(state.breakRow!.fields['start_utc']! as String),
              zone,
            ),
          )
        : state.clockedIn
        ? l.clockedInSince(
            context.time(
              DateTime.parse(state.session!.fields['start_utc']! as String),
              zone,
            ),
          )
        : l.notClockedIn;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(since, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in WorkLocation.values)
                  ChoiceChip(
                    showCheckmark: false,
                    avatar: Icon(locationIcon(l), size: 18),
                    label: Text(context.locationName(l)),
                    selected: location == l,
                    onSelected: (_) => _selectLocation(l),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (state.clockedIn)
                  FilledButton.tonalIcon(
                    onPressed: _clockOut,
                    icon: const Icon(Icons.logout),
                    label: Text(l.clockOut),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => tracker.clockIn(location: _nextLocation()),
                    icon: const Icon(Icons.login),
                    label: Text(l.clockIn),
                  ),
                OutlinedButton.icon(
                  onPressed: !state.clockedIn
                      ? null
                      : state.onBreak
                      ? tracker.endBreak
                      : () =>
                            withSummaryPrompt(context, ref, tracker.startBreak),
                  icon: Icon(
                    state.onBreak ? Icons.play_arrow : Icons.coffee_outlined,
                  ),
                  label: Text(state.onBreak ? l.endBreak : l.startBreak),
                ),
              ],
            ),
            if (state.trip != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.luggage_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (state.trip!.fields['destination'] as String? ?? '')
                              .isEmpty
                          ? l.onTrip
                          : l.onTripTo(
                              state.trip!.fields['destination']! as String,
                            ),
                    ),
                  ),
                  TextButton(
                    onPressed: tracker.endTrip,
                    child: Text(l.endTrip),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Running project, favorites and the project picker.
class _ProjectCard extends ConsumerWidget {
  const _ProjectCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final zone = ref.watch(zoneProvider);
    final state = ref.watch(trackerStateProvider);
    final tracker = ref.watch(trackerProvider);
    final projects = ref.watch(projectByIdProvider);
    final running = state.projectId == null ? null : projects[state.projectId];
    final favorites = ref
        .watch(projectsProvider)
        .where((p) => p.favorite && !p.archived);
    Future<void> start(String id) => withSummaryPrompt(
      context,
      ref,
      () => tracker.startProject(id, location: state.location),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                running == null ? Icons.work_off_outlined : Icons.work,
              ),
              title: Text(running?.name ?? l.noProjectRunning),
              subtitle: running == null
                  ? null
                  : Text(
                      [
                        if (running.projectNumber.isNotEmpty)
                          running.projectNumber,
                        if (running.orderNumber.isNotEmpty) running.orderNumber,
                        context.time(
                          DateTime.parse(
                            state.entry!.fields['start_utc']! as String,
                          ),
                          zone,
                        ),
                      ].join(' · '),
                    ),
              trailing: running == null
                  ? null
                  : IconButton(
                      tooltip: l.stopProject,
                      icon: const Icon(Icons.stop_circle_outlined),
                      onPressed: () =>
                          withSummaryPrompt(context, ref, tracker.stopProject),
                    ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in favorites)
                  ActionChip(
                    avatar: Icon(
                      p.id == state.projectId
                          ? Icons.play_arrow
                          : Icons.star_outline,
                      size: 18,
                    ),
                    label: Text(p.name),
                    onPressed: () => start(p.id),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.search, size: 18),
                  label: Text(l.chooseProject),
                  onPressed: () async {
                    final id = await showProjectPicker(context);
                    if (id != null) await start(id);
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.more_time, size: 18),
                  label: Text(l.addProjectTime),
                  onPressed: () => showProjectTimeDialog(
                    context,
                    date: ref.read(todayProvider),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Worked vs target, balance and home-office quotas.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.day,
    required this.ledger,
    required this.quotas,
  });

  final DayResult day;
  final Ledger ledger;
  final List<HomeOfficeQuota> quotas;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    Widget figure(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.labelMedium),
        Text(value, style: text.headlineSmall),
      ],
    );
    final before = ledger.balanceAtEndOf(day.date.addDays(-1));
    final after = ledger.balanceAtEndOf(day.date);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 32,
              runSpacing: 12,
              children: [
                figure(l.worked, formatMinutes(day.work.worked)),
                figure(l.target, formatMinutes(day.target)),
                if (day.credited != day.breaks.effectiveWorked)
                  figure(l.credited, formatMinutes(day.credited)),
                figure(l.unassigned, formatMinutes(day.work.unassigned)),
                figure(
                  l.balance,
                  '${formatMinutes(before)}  (${l.balanceToday} ${formatMinutes(after)})',
                ),
              ],
            ),
            for (final q in quotas.where(
              (q) => q.rule.unit == QuotaUnit.days,
            )) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(locationIcon(WorkLocation.home), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (q.rule.period == QuotaPeriod.week
                          ? l.homeOfficeWeek
                          : l.homeOfficeMonth)(
                        context.days(q.used),
                        '${q.allowedTotal}',
                        context.days(q.left),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Today's sessions and project entries; tap to edit the day.
class _TodayEntries extends ConsumerWidget {
  const _TodayEntries({required this.day});

  final DayResult day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zone = ref.watch(zoneProvider);
    final window = zone.daySpan(day.date);
    final data = ref.watch(ledgerDataProvider);
    final projects = ref.watch(projectByIdProvider);
    final now = ref.watch(ledgerProvider).nowMinute;
    bool today(Span s) => s.start < window.end && s.end > window.start;
    final sessions = data.sessions.where((s) => today(s.spanAt(now))).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final entries = data.entries.where((e) => today(e.spanAt(now))).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final durations = data.durations.where((d) => d.date == day.date).toList();
    if (sessions.isEmpty && entries.isEmpty && durations.isEmpty) {
      return const SizedBox.shrink();
    }
    String range(DateTime s, DateTime? e) =>
        '${context.time(s, zone)} – ${e == null ? context.l10n.running : context.time(e, zone)}';
    return Card(
      child: InkWell(
        onTap: () => context.go('/calendar/day/${day.date}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              for (final s in sessions)
                ListTile(
                  dense: true,
                  leading: Icon(locationIcon(s.location)),
                  title: Text(range(s.start, s.end)),
                  subtitle: Text(context.locationName(s.location)),
                ),
              for (final e in entries)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.work_outline),
                  title: Text(
                    '${range(e.start, e.end)} · ${projects[e.projectId]?.name ?? '?'}',
                  ),
                  subtitle: e.note.isEmpty ? null : Text(e.note),
                ),
              for (final d in durations)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.timelapse),
                  title: Text(
                    '${formatMinutes(d.minutes)} · ${projects[d.projectId]?.name ?? '?'}',
                  ),
                  subtitle: d.note.isEmpty ? null : Text(d.note),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
