import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/actions.dart';
import '../../app/back_navigation.dart';
import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../widgets/app_bar_actions.dart';
import '../../widgets/attention.dart';
import '../../widgets/day_timeline.dart';
import '../../widgets/explain_sheet.dart';
import '../../widgets/motion.dart';
import '../../widgets/quick_entry_sheet.dart';
import '../calendar/day_type_picker.dart';
import '../calendar/trip_booking_card.dart';
import '../projects/project_picker.dart';
import '../projects/project_time_dialog.dart';

/// The home screen. It answers "where do I stand right now?": one button
/// that follows the state, a ring of today's time against the target, the
/// balance, projects to switch with one tap, today's timeline and what
/// needs attention.
class TodayScreen extends ConsumerWidget {
  /// Creates the screen.
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final today = ref.watch(todayProvider);
    final ledger = ref.watch(ledgerProvider);
    final day = ledger.day(today);
    final clockedIn = ref.watch(trackerStateProvider).clockedIn;
    final type = day.type;
    final showProjects =
        type != DayType.businessTrip &&
        ((type?.allowsProjectTime ?? true) || clockedIn);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.navToday),
            Text(
              context.longDate(today),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l.quickEntry,
            icon: const Icon(Icons.bolt),
            onPressed: () => showQuickEntrySheet(context, today),
          ),
          ...commonActions(),
        ],
      ),
      body: _Body(
        children: [
          if (!ref.watch(isSetUpProvider)) const _SetupCard(),
          AttentionCards(
            from: today.addDays(-1),
            to: today,
            includeQuota: true,
            includeTrip: true,
            collapseAfter: 3,
          ),
          const _HeroCard(),
          if (type == DayType.businessTrip) TripBookingCard(date: today),
          if (showProjects) const _ProjectStrip(),
          _TimelineCard(date: today),
          const _QuotaCard(),
        ],
      ),
    );
  }
}

/// A centred column, at most 720 px wide on desktops.
class _Body extends StatelessWidget {
  const _Body({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ],
  );
}

class _SetupCard extends StatelessWidget {
  const _SetupCard();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.rocket_launch_outlined,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(l.setupHint)),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => context.push('/setup'),
              child: Text(l.setupStart),
            ),
          ],
        ),
      ),
    );
  }
}

/// Status, day type, the ring and the one button that matters now.
class _HeroCard extends ConsumerStatefulWidget {
  const _HeroCard();

  @override
  ConsumerState<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends ConsumerState<_HeroCard> {
  Future<void> _clockIn() => clockIn(context, ref);

  Future<void> _clockOut() => clockOut(context, ref);

  Future<void> _toggleBreak() => toggleBreak(context, ref);

  /// Runs a trip step (calculations §9.1): each records the exact minute
  /// for the travel report, at the time the user confirms (§19).
  Future<void> _tripStep(TripStep step) async {
    if (step == TripStep.endInbound) {
      await _clockOut(); // asks the time and offers to end the trip
      return;
    }
    tapFeedback(strong: true);
    final tracker = ref.read(trackerProvider);
    final clockedIn = ref.read(trackerStateProvider).clockedIn;
    final action = switch (step) {
      TripStep.arriveOnSite => StampAction.changeLocation,
      TripStep.startInbound when clockedIn => StampAction.changeLocation,
      TripStep.endOutbound || TripStep.endOnSite => StampAction.clockOut,
      _ => StampAction.clockIn,
    };
    final at = await askStampTime(context, ref, action, _stepLabel(step));
    if (at == null || !mounted) return;
    switch (step) {
      case TripStep.startOutbound:
        await tracker.clockIn(location: WorkLocation.travel, at: at);
      case TripStep.arriveOnSite:
        await tracker.changeLocation(WorkLocation.onSite, at: at);
      case TripStep.startOnSite:
        await tracker.clockIn(location: WorkLocation.onSite, at: at);
      case TripStep.startInbound:
        clockedIn
            ? await tracker.changeLocation(WorkLocation.travel, at: at)
            : await tracker.clockIn(location: WorkLocation.travel, at: at);
      case TripStep.endOutbound || TripStep.endOnSite:
        await withSummaryPrompt(context, ref, () => tracker.clockOut(at: at));
      case TripStep.endInbound:
        break;
    }
  }

  String _stepLabel(TripStep step) {
    final l = context.l10n;
    return switch (step) {
      TripStep.startOutbound => l.stepStartOutbound,
      TripStep.arriveOnSite => l.stepArriveOnSite,
      TripStep.endOutbound => l.stepEndOutbound,
      TripStep.startOnSite => l.stepStartOnSite,
      TripStep.endOnSite => l.stepEndOnSite,
      TripStep.startInbound => l.stepStartInbound,
      TripStep.endInbound => l.stepEndInbound,
    };
  }

  static IconData _stepIcon(TripStep step) => switch (step) {
    TripStep.startOutbound || TripStep.startInbound => Icons.directions_car,
    TripStep.arriveOnSite || TripStep.startOnSite => Icons.place,
    TripStep.endOutbound || TripStep.endOnSite => Icons.stop_rounded,
    TripStep.endInbound => Icons.home_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final zone = ref.watch(zoneProvider);
    final state = ref.watch(trackerStateProvider);
    final today = ref.watch(todayProvider);
    final ledger = ref.watch(ledgerProvider);
    final day = ledger.day(today);
    final type = day.type;
    final balance = ledger.balanceAtEndOf(today);
    String at(String field, StoredRow row) =>
        context.time(DateTime.parse(row.fields[field]! as String), zone);
    final status = state.onBreak
        ? l.onBreakSince(at('start_utc', state.breakRow!))
        : state.clockedIn
        ? l.clockedInSince(at('start_utc', state.session!))
        : l.notClockedIn;
    final ringColor = state.onBreak
        ? scheme.outline
        : state.clockedIn
        ? scheme.primary
        : scheme.primary.withValues(alpha: 0.6);

    Widget figure(String label, int minutes, {bool signed = false}) => InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showDayExplanation(context, ref, today),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            AnimatedMinutes(
              minutes,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              signed: signed ? scheme.deltaColor : null,
            ),
          ],
        ),
      ),
    );

    final big = theme.textTheme.titleMedium;
    final Widget actions;
    if (type == DayType.businessTrip) {
      // Trip days: the next step instead of clock in/out and location.
      final steps = tripSteps(
        running: state.clockedIn ? state.location : null,
        onSiteToday: tripLegs(
          ledger,
          today,
        ).any((leg) => leg.kind == TripLegKind.onSite),
      );
      actions = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 60)),
            onPressed: () => _tripStep(steps.first),
            icon: Icon(_stepIcon(steps.first), size: 26),
            label: Text(
              _stepLabel(steps.first),
              style: big?.copyWith(color: scheme.onPrimary),
            ),
          ),
          if (steps.length > 1 || state.clockedIn) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                for (final step in steps.skip(1))
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _tripStep(step),
                      icon: Icon(_stepIcon(step)),
                      label: Text(_stepLabel(step)),
                    ),
                  ),
                if (steps.length > 1 && state.clockedIn)
                  const SizedBox(width: 8),
                if (state.clockedIn)
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _toggleBreak,
                      icon: Icon(
                        state.onBreak
                            ? Icons.play_arrow_rounded
                            : Icons.coffee_outlined,
                      ),
                      label: Text(state.onBreak ? l.endBreak : l.startBreak),
                    ),
                  ),
              ],
            ),
          ],
        ],
      );
    } else if (!state.clockedIn) {
      actions = SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 60)),
          onPressed: _clockIn,
          icon: const Icon(Icons.play_arrow_rounded, size: 28),
          label: Text(l.clockIn, style: big?.copyWith(color: scheme.onPrimary)),
        ),
      );
    } else {
      actions = Row(
        children: [
          Expanded(
            child: (state.onBreak ? FilledButton.icon : FilledButton.tonalIcon)(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 60)),
              onPressed: _toggleBreak,
              icon: Icon(
                state.onBreak
                    ? Icons.play_arrow_rounded
                    : Icons.coffee_outlined,
              ),
              label: Text(state.onBreak ? l.endBreak : l.startBreak),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 60)),
              onPressed: _clockOut,
              icon: const Icon(Icons.stop_rounded),
              label: Text(l.clockOut),
            ),
          ),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: state.onBreak
                        ? scheme.tertiary
                        : state.clockedIn
                        ? scheme.deltaColor(1)
                        : scheme.outlineVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [...previous, ?current],
                    ),
                    child: Text(
                      status,
                      key: ValueKey(status),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ),
                DayTypeChip(date: today, startsNow: true),
              ],
            ),
            if (type != null && !type.isWork) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l.absenceWorkHint,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => showDayExplanation(context, ref, today),
              child: ProgressRing(
                value: day.breaks.effectiveWorked,
                total: day.target,
                color: ringColor,
                overColor: scheme.deltaColor(1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.worked, style: theme.textTheme.labelMedium),
                    AnimatedMinutes(
                      day.work.worked,
                      style: theme.textTheme.displayMedium,
                    ),
                    Text(
                      l.ofTarget(formatMinutes(day.target)),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                // Actual vs. credited differ on trips, weekends and holidays
                // (§9); tap explains why.
                if (day.credited != day.work.worked)
                  figure(l.credited, day.credited),
                figure(l.difference, day.delta, signed: true),
                figure(l.balance, balance, signed: true),
                if (day.sundayHours > 0) figure(l.sundayHours, day.sundayHours),
              ],
            ),
            if (state.clockedIn) _ForecastLine(day: day, state: state),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey((state.clockedIn, state.onBreak, state.location)),
                child: actions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Soll erreicht um 15:30 (inkl. 30 min Pause) · 10 Std. um 17:45" while
/// clocked in (calculations §18).
class _ForecastLine extends ConsumerWidget {
  const _ForecastLine({required this.day, required this.state});

  final DayResult day;
  final TrackerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final zone = ref.watch(zoneProvider);
    final minute = ref.watch(ledgerProvider).nowMinute;
    final now = DateTime.fromMillisecondsSinceEpoch(
      minute * 60000,
      isUtc: true,
    );
    final breakStart = state.breakRow?.fields['start_utc'] as String?;
    final f = dayForecast(
      day,
      now: now,
      runningBreak: breakStart == null
          ? 0
          : now.difference(DateTime.parse(breakStart)).inMinutes,
    );
    final parts = [
      if (f.targetAt case final at?)
        f.breakIncluded > 0
            ? '${l.forecastTarget(context.time(at, zone))} '
                  '(${l.forecastBreak(f.breakIncluded)})'
            : l.forecastTarget(context.time(at, zone)),
      if (f.limitAt case final at?) l.forecastLimit(context.time(at, zone)),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flag_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              parts.join(' · '),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The running project and favourites as a row of cards to switch with one
/// tap, plus search and adding time afterwards.
class _ProjectStrip extends ConsumerWidget {
  const _ProjectStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(trackerStateProvider);
    final tracker = ref.watch(trackerProvider);
    final projects = ref.watch(projectByIdProvider);
    final ledger = ref.watch(ledgerProvider);
    final running = state.projectId == null ? null : projects[state.projectId];
    final favorites = ref
        .watch(projectsProvider)
        .where((p) => p.favorite && !p.archived && p.id != running?.id);
    final byProject = ledger.day(ref.watch(todayProvider)).work.byProject;
    Future<void> start(String id) {
      tapFeedback();
      return withSummaryPrompt(
        context,
        ref,
        () => tracker.startProject(id, location: state.location),
      );
    }

    final runningMinutes = running == null
        ? 0
        : ledger.nowMinute -
              epochMinute(
                DateTime.parse(state.entry!.fields['start_utc']! as String),
              );

    Widget tile({
      required Widget child,
      required VoidCallback onTap,
      Color? color,
      bool filled = false,
    }) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: filled ? color : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: color == null || filled
                  ? null
                  : Border(left: BorderSide(color: color, width: 4)),
            ),
            child: child,
          ),
        ),
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.navProjects, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (running != null)
                    Builder(
                      builder: (context) {
                        final color = scheme.projectColor(running.id);
                        final ink =
                            ThemeData.estimateBrightnessForColor(color) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black;
                        return tile(
                          filled: true,
                          color: color,
                          onTap: () => withSummaryPrompt(
                            context,
                            ref,
                            tracker.stopProject,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      running.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: ink,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.stop_circle_outlined,
                                    color: ink,
                                    semanticLabel: l.stopProject,
                                  ),
                                ],
                              ),
                              AnimatedMinutes(
                                runningMinutes,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: ink,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  for (final p in favorites)
                    tile(
                      color: scheme.projectColor(p.id),
                      onTap: () => start(p.id),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              p.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            byProject[p.id] == null
                                ? (p.projectNumber.isEmpty
                                      ? '▶'
                                      : p.projectNumber)
                                : formatMinutes(byProject[p.id]!),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  tile(
                    onTap: () async {
                      final id = await showProjectPicker(context);
                      if (id != null) await start(id);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.search),
                        Flexible(
                          child: Text(
                            l.chooseProject,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  tile(
                    onTap: () => showProjectTimeDialog(
                      context,
                      date: ref.read(todayProvider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.more_time),
                        Flexible(
                          child: Text(
                            l.addProjectTime,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (running == null) ...[
              const SizedBox(height: 8),
              Text(
                l.noProjectRunning,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Today's timeline; drag edges to adjust, tap a gap to assign it.
class _TimelineCard extends ConsumerWidget {
  const _TimelineCard({required this.date});

  final LocalDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final work = ref.watch(ledgerProvider).day(date).work;
    if (work.worked == 0 && work.projectTime == 0) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.timeline,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.go(dayLocation(context, date)),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(l.editDay),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: DayTimeline(
                date: date,
                editable: true,
                onTap: (_) => context.go(dayLocation(context, date)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Home-office quotas as bars: used of allowed, with what is left.
class _QuotaCard extends ConsumerWidget {
  const _QuotaCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final quotas = ref
        .watch(homeOfficeQuotasProvider)
        .where((q) => q.rule.unit == QuotaUnit.days)
        .toList();
    if (quotas.isEmpty) return const SizedBox.shrink();
    final color = theme.colorScheme.dayTypeColor(DayType.home);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final q in quotas) ...[
              Row(
                children: [
                  Icon(dayTypeIcon(DayType.home), size: 18, color: color),
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
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: q.allowedTotal <= 0
                      ? 0
                      : (q.used / q.allowedTotal).clamp(0, 1).toDouble(),
                  color: q.left <= 0 ? theme.colorScheme.error : color,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              if (q != quotas.last) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
