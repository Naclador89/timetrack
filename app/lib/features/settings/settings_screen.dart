import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timetrack_core/timetrack_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/appearance.dart';
import '../../app/format.dart';
import '../../app/providers.dart';
import '../../reminders/reminders.dart';
import '../../sync/sync_controller.dart';
import '../../update/update_banner.dart';
import '../../update/update_controller.dart';
import '../../widgets/dialogs.dart';
import '../../work_pc/work_pc.dart';

/// Official names of the federal states (proper names, not translated).
const stateNames = {
  FederalState.bw: 'Baden-Württemberg',
  FederalState.by: 'Bayern',
  FederalState.be: 'Berlin',
  FederalState.bb: 'Brandenburg',
  FederalState.hb: 'Bremen',
  FederalState.hh: 'Hamburg',
  FederalState.he: 'Hessen',
  FederalState.mv: 'Mecklenburg-Vorpommern',
  FederalState.ni: 'Niedersachsen',
  FederalState.nw: 'Nordrhein-Westfalen',
  FederalState.rp: 'Rheinland-Pfalz',
  FederalState.sl: 'Saarland',
  FederalState.sn: 'Sachsen',
  FederalState.st: 'Sachsen-Anhalt',
  FederalState.sh: 'Schleswig-Holstein',
  FederalState.th: 'Thüringen',
};

/// The federal states as chips (settings and setup).
class FederalStateChips extends StatelessWidget {
  /// Creates the chips.
  const FederalStateChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  /// The current state.
  final FederalState? selected;

  /// Called with the tapped state.
  final ValueChanged<FederalState> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final e in stateNames.entries)
        ChoiceChip(
          label: Text(e.value),
          selected: selected == e.key,
          onSelected: (_) => onSelected(e.key),
        ),
    ],
  );
}

/// All settings (stored as synced `settings` rows, data-model.md §7),
/// grouped in cards, with a search over all of them.
class SettingsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final repo = ref.watch(repositoryProvider);
    final schedules = ref.watch(ledgerDataProvider).schedules;
    final rules = ref.watch(homeOfficeRulesProvider);
    Future<void> save(String key, Object? value) =>
        saveSetting(repo, key, value);
    Widget header(String text, {String? description}) =>
        _Header(text, description: description);
    final tiles = <Widget>[
      header(l.sync),
      ListTile(
        leading: Icon(switch (ref.watch(syncControllerProvider).phase) {
          SyncPhase.notConfigured => Icons.cloud_off_outlined,
          SyncPhase.error => Icons.sync_problem,
          _ => Icons.cloud_done_outlined,
        }),
        title: Text(l.sync),
        subtitle: Text(switch (ref.watch(syncControllerProvider)) {
          SyncStatus(phase: SyncPhase.notConfigured) => l.syncNotConnected,
          SyncStatus(phase: SyncPhase.error) => l.syncError,
          final st => st.root?.host ?? '',
        }),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/settings/sync'),
      ),
      header(l.general),
      ListTile(
        leading: const Icon(Icons.map_outlined),
        title: Text(l.federalState),
        subtitle: Text(stateNames[s.federalState] ?? l.notSet),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final v = await showModalBottomSheet<FederalState>(
            context: context,
            isScrollControlled: true,
            builder: (c) => SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FederalStateChips(
                  selected: s.federalState,
                  onSelected: (v) => Navigator.pop(c, v),
                ),
              ),
            ),
          );
          if (v != null) await save(SettingKeys.federalState, v.code);
        },
      ),
      if (s.federalState == FederalState.by)
        SwitchListTile(
          secondary: const SizedBox(width: 24),
          title: const Text('Mariä Himmelfahrt (15.08.)'),
          value: s.bavariaAssumptionDay,
          onChanged: (v) => save(SettingKeys.bavariaAssumptionDay, v),
        ),
      SwitchListTile(
        secondary: const Icon(Icons.login),
        title: Text(l.autoClockIn),
        value: s.autoClockIn,
        onChanged: (v) => save(SettingKeys.autoClockIn, v),
      ),
      SwitchListTile(
        secondary: const Icon(Icons.play_arrow_outlined),
        title: Text(l.resumeAfterBreak),
        value: s.resumeAfterBreak,
        onChanged: (v) => save(SettingKeys.resumeAfterBreak, v),
      ),
      // spec: calculations.md §4.1 (only prefills, never deducts)
      ListTile(
        leading: const Icon(Icons.coffee_outlined),
        title: Text(l.defaultBreakStart),
        subtitle: Text(l.defaultBreakHint),
        trailing: Text(
          TimeOfDay(
            hour: s.defaultBreakStart ~/ 60,
            minute: s.defaultBreakStart % 60,
          ).format(context),
        ),
        onTap: () async {
          final v = await pickTime(context, s.defaultBreakStart);
          if (v != null) await save(SettingKeys.defaultBreakStart, v);
        },
      ),
      ListTile(
        leading: const SizedBox(width: 24),
        title: Text(l.defaultBreakLength),
        trailing: Text(formatMinutes(s.defaultBreakMinutes)),
        onTap: () async {
          final v = await _askHours(
            context,
            formatMinutes(s.defaultBreakMinutes),
          );
          if (v != null && v >= 5 && v <= 240) {
            await save(SettingKeys.defaultBreakMinutes, v);
          }
        },
      ),
      // spec: reminders.md §2 (Android notifications, Windows tray)
      if (ref.watch(remindersAvailableProvider)) ...[
        SwitchListTile(
          secondary: const Icon(Icons.notifications_active_outlined),
          title: Text('${l.reminders}: ${l.remindBreak}'),
          subtitle: Text(l.remindBreakHint),
          value: s.remindBreak,
          onChanged: (v) => save(SettingKeys.remindBreak, v),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_active_outlined),
          title: Text('${l.reminders}: ${l.remindLongDay}'),
          subtitle: Text(l.remindLongDayHint),
          value: s.remindLongDay,
          onChanged: (v) => save(SettingKeys.remindLongDay, v),
        ),
      ],
      ListTile(
        leading: Icon(locationIcon(WorkLocation.home)),
        title: Text(l.homeOfficeRules),
        subtitle: rules.isEmpty ? Text(l.notSet) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/settings/home-office'),
      ),
      // The overtime account (calculations §7–§9): what is credited.
      header(l.accountSection, description: l.accountSectionHint),
      ListTile(
        leading: const Icon(Icons.schedule),
        title: Text(l.schedules),
        subtitle: Text(
          schedules.isEmpty ? l.notSet : _scheduleSummary(context, schedules),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/settings/schedules'),
      ),
      ListTile(
        leading: const Icon(Icons.functions),
        title: Text(l.startingBalance),
        trailing: Text(formatMinutes(s.startingBalance)),
        onTap: () async {
          final v = await _askHours(context, formatMinutes(s.startingBalance));
          if (v != null) await save(SettingKeys.startingBalance, v);
        },
      ),
      DateTile(
        leading: const Icon(Icons.event_outlined),
        label: l.balanceStart,
        value: ref.watch(ledgerProvider).settings.balanceStart,
        onChanged: (d) => save(SettingKeys.balanceStartDate, '$d'),
      ),
      ListTile(
        leading: const Icon(Icons.coffee_outlined),
        title: Text(l.breakRule),
        subtitle: SegmentedButton<BreakRuleMode>(
          segments: [
            ButtonSegment(value: BreakRuleMode.warn, label: Text(l.breakWarn)),
            ButtonSegment(
              value: BreakRuleMode.deduct,
              label: Text(l.breakDeduct),
            ),
          ],
          selected: {s.breakMode},
          onSelectionChanged: (v) => save(SettingKeys.breakRuleMode, v.single),
        ),
      ),
      // Only the account: the travel record always has the real times.
      header(l.travelRules, description: l.travelRulesHint),
      // calculations.md §9; each rule is a setting, defaults as agreed.
      // Weekdays on a trip:
      ListTile(
        leading: const Icon(Icons.work_history_outlined),
        title: Text(l.travelWorkday),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.travelWorkdayHint),
            const SizedBox(height: 8),
            SegmentedButton<TripWorkdayCredit>(
              segments: [
                ButtonSegment(
                  value: TripWorkdayCredit.target,
                  label: Text(l.travelWorkdayTarget),
                ),
                ButtonSegment(
                  value: TripWorkdayCredit.actual,
                  label: Text(l.travelWorkdayActual),
                ),
              ],
              selected: {s.travel.workday},
              onSelectionChanged: (v) =>
                  save(SettingKeys.travelWorkday, v.single),
            ),
          ],
        ),
      ),
      header(l.weekendRules, description: l.weekendRulesHint),
      // On every Saturday, Sunday and holiday, trip or not (§9).
      ListTile(
        leading: const Icon(Icons.weekend_outlined),
        title: Text(l.saturdayCap),
        subtitle: Text(l.travelSaturdayHint),
        trailing: Text(formatMinutes(s.travel.saturdayCapMinutes)),
        onTap: () async {
          final v = await _askHours(
            context,
            formatMinutes(s.travel.saturdayCapMinutes),
          );
          if (v != null && v >= 0) {
            await save(SettingKeys.travelSaturdayCap, v);
          }
        },
      ),
      ListTile(
        leading: const SizedBox(width: 24),
        title: Text(l.saturdayCapScope),
        subtitle: SegmentedButton<SaturdayCapScope>(
          segments: [
            ButtonSegment(
              value: SaturdayCapScope.total,
              label: Text(l.capTotal),
            ),
            ButtonSegment(
              value: SaturdayCapScope.travelOnly,
              label: Text(l.capTravelOnly),
            ),
          ],
          selected: {s.travel.saturdayCapScope},
          onSelectionChanged: (v) =>
              save(SettingKeys.travelSaturdayCapScope, v.single),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.wb_sunny_outlined),
        title: Text(l.travelSunday),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.travel.sunday == TripSundayCredit.sundayHours
                  ? l.travelSundayHoursHint
                  : l.travelSundayWorkOnlyHint,
            ),
            const SizedBox(height: 8),
            SegmentedButton<TripSundayCredit>(
              segments: [
                ButtonSegment(
                  value: TripSundayCredit.sundayHours,
                  label: Text(l.sundayHours),
                ),
                ButtonSegment(
                  value: TripSundayCredit.workOnly,
                  label: Text(l.sundayWorkOnly),
                ),
              ],
              selected: {s.travel.sunday},
              onSelectionChanged: (v) =>
                  save(SettingKeys.travelSunday, v.single),
            ),
          ],
        ),
      ),
      if (s.travel.sunday == TripSundayCredit.sundayHours)
        ListTile(
          leading: const SizedBox(width: 24),
          title: Text(l.sundayCap),
          trailing: Text(formatMinutes(s.travel.sundayCapMinutes)),
          onTap: () async {
            final v = await _askHours(
              context,
              formatMinutes(s.travel.sundayCapMinutes),
            );
            if (v != null && v >= 0) {
              await save(SettingKeys.travelSundayCap, v);
            }
          },
        ),
      ListTile(
        leading: const Icon(Icons.celebration_outlined),
        title: Text(l.travelHoliday),
        subtitle: SegmentedButton<TripDayRule>(
          segments: [
            ButtonSegment(
              value: TripDayRule.likeSunday,
              label: Text(l.likeSunday),
            ),
            ButtonSegment(
              value: TripDayRule.likeSaturday,
              label: Text(l.likeSaturday),
            ),
          ],
          selected: {s.travel.holiday},
          onSelectionChanged: (v) => save(SettingKeys.travelHoliday, v.single),
        ),
      ),
      // What is recorded as it happened, independent of the account.
      header(l.recordsSection, description: l.recordsSectionHint),
      ListTile(
        leading: const Icon(Icons.flight),
        title: Text(l.travelRecord),
        subtitle: Text(l.travelRecordHint),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/reports'),
      ),
      ListTile(
        leading: const Icon(Icons.restaurant_outlined),
        title: Text(l.perDiemRates),
        subtitle: Text(
          l.perDiemRatesSummary(
            '${ref.watch(perDiemRatesProvider).map((r) => r.country).toSet().length}',
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/settings/per-diem'),
      ),
      ListTile(
        leading: const Icon(Icons.work_outline),
        title: Text(l.projectTimesRecord),
        subtitle: Text(l.projectTimesRecordHint),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/reports'),
      ),
      // Which notices appear as cards (calculations §12); a dismissed card
      // stays away and only leaves the marker in the calendar.
      header(l.notices),
      ListTile(
        leading: const Icon(Icons.work_off_outlined),
        title: Text(l.noticeUnassignedFrom),
        subtitle: Text(l.noticeUnassignedHint),
        trailing: Text(formatMinutes(s.noticeUnassignedMinMinutes)),
        enabled: s.showsNotice(NoticeCategory.unassigned.wireName),
        onTap: () async {
          final v = await _askHours(
            context,
            formatMinutes(s.noticeUnassignedMinMinutes),
          );
          if (v != null && v >= 0) {
            await save(SettingKeys.noticeUnassignedMin, v);
          }
        },
      ),
      for (final c in NoticeCategory.values)
        SwitchListTile(
          secondary: Icon(noticeCategoryIcon(c)),
          title: Text(noticeCategoryLabel(l, c)),
          value: s.showsNotice(c.wireName),
          onChanged: (v) => save(SettingKeys.noticeShow(c.wireName), v),
        ),
      ListTile(
        leading: const Icon(Icons.notifications_active_outlined),
        title: Text(l.restoreNotices),
        subtitle: Text(
          l.dismissedCount('${ref.watch(dismissedNoticesProvider).length}'),
        ),
        enabled: ref.watch(dismissedNoticesProvider).isNotEmpty,
        onTap: () async {
          for (final key in ref.read(dismissedNoticesProvider)) {
            await repo.delete('dismissed_notices', key);
          }
        },
      ),
      // spec: updates.md §3
      header(l.appSection),
      ListTile(
        leading: const Icon(Icons.palette_outlined),
        title: Text(l.appearance),
        subtitle: SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(value: ThemeMode.system, label: Text(l.themeSystem)),
            ButtonSegment(value: ThemeMode.light, label: Text(l.themeLight)),
            ButtonSegment(value: ThemeMode.dark, label: Text(l.themeDark)),
          ],
          selected: {ref.watch(appearanceProvider).mode},
          onSelectionChanged: (v) =>
              ref.read(appearanceProvider.notifier).setMode(v.single),
        ),
      ),
      if (ref.watch(wallpaperColorsAvailableProvider).value ?? false)
        SwitchListTile(
          secondary: const Icon(Icons.wallpaper_outlined),
          title: Text(l.wallpaperColors),
          subtitle: Text(l.wallpaperColorsHint),
          value: ref.watch(appearanceProvider).wallpaperColors,
          onChanged: (v) =>
              ref.read(appearanceProvider.notifier).setWallpaperColors(v),
        ),
      ListTile(
        leading: const Icon(Icons.system_update_outlined),
        title: Text(l.checkForUpdates),
        subtitle: Text(_versionLine(context)),
        onTap: () => checkForUpdatesByHand(context, ref),
      ),
      SwitchListTile(
        secondary: const Icon(Icons.update),
        title: Text(l.autoUpdateCheck),
        subtitle: Text(l.autoUpdateCheckHint),
        value: ref.watch(updateStateProvider).value?.auto ?? true,
        onChanged: (v) =>
            ref.read(updateControllerProvider.notifier).setAuto(v),
      ),
      // spec: work-pc.md §1 (Windows only)
      if (ref.watch(workPcPlatformProvider) case final workPc?) ...[
        SwitchListTile(
          secondary: const Icon(Icons.power_settings_new),
          title: Text(l.autostart),
          subtitle: Text(l.autostartHint),
          value: ref.watch(workPcEnabledProvider).value ?? false,
          onChanged: (v) async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await workPc.setEnabled(v);
            } on Object {
              messenger.showSnackBar(SnackBar(content: Text(l.workPcFailed)));
            }
            ref.invalidate(workPcEnabledProvider);
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.work_outline),
          title: Text(l.workPc),
          subtitle: Text(l.workPcHint),
          value:
              (ref.watch(workPcEnabledProvider).value ?? false) &&
              (ref.watch(startPromptProvider).value ?? true),
          onChanged: (v) async {
            final messenger = ScaffoldMessenger.of(context);
            await ref
                .read(storeProvider)
                .transaction((tx) => tx.setLocalValue(startPromptKey, '$v'));
            ref.invalidate(startPromptProvider);
            // Asking at sign-in needs the start at sign-in.
            if (v && !(ref.read(workPcEnabledProvider).value ?? false)) {
              try {
                await workPc.setEnabled(true);
              } on Object {
                messenger.showSnackBar(SnackBar(content: Text(l.workPcFailed)));
              }
              ref.invalidate(workPcEnabledProvider);
            }
          },
        ),
      ],
      // spec: work-pc.md §3 (Windows only)
      if (ref.watch(workPcPlatformProvider) != null)
        SwitchListTile(
          secondary: const Icon(Icons.minimize),
          title: Text(l.closeToTray),
          subtitle: Text(l.closeToTrayHint),
          value: ref.watch(closeToTrayProvider).value ?? true,
          onChanged: (v) async {
            await ref
                .read(storeProvider)
                .transaction((tx) => tx.setLocalValue(closeToTrayKey, '$v'));
            ref.invalidate(closeToTrayProvider);
          },
        ),
      ListTile(
        leading: const Icon(Icons.open_in_new),
        title: Text(l.releasePage),
        onTap: () =>
            launchUrl(releasesPage, mode: LaunchMode.externalApplication),
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.navSettings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SearchBar(
              hintText: l.searchSettings,
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.rocket_launch_outlined),
            title: Text(l.setupTitle),
            subtitle: Text(l.setupAgainHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/setup'),
          ),
          ..._grouped(context, tiles),
        ],
      ),
    );
  }

  /// "Installiert: 0.4.0 · zuletzt geprüft 08.11.2026 10:00".
  String _versionLine(BuildContext context) {
    final l = context.l10n;
    final version = ref.watch(installedVersionProvider).value;
    final checked = ref.watch(updateStateProvider).value?.checked;
    final locale = Localizations.localeOf(context).toString();
    return [
      l.installedVersion(version == null ? '–' : '$version'),
      if (checked != null)
        l.lastChecked(
          DateFormat.yMd(locale).add_Hm().format(checked.toLocal()),
        ),
    ].join(' · ');
  }

  /// Puts the tiles after each [_Header] into one card; while searching,
  /// only the tiles whose texts match, under their group.
  List<Widget> _grouped(BuildContext context, List<Widget> tiles) {
    final q = _query.toLowerCase();
    final out = <Widget>[];
    String? title;
    String? description;
    var group = <Widget>[];
    var titleMatches = false;
    void flush() {
      if (group.isEmpty || title == null) return;
      out
        ..add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
                if (description != null && q.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        )
        ..add(Card(child: Column(children: group)));
      group = [];
    }

    for (final t in tiles) {
      if (t is _Header) {
        flush();
        title = t.text;
        description = t.description;
        titleMatches = q.isNotEmpty && t.text.toLowerCase().contains(q);
        continue;
      }
      if (q.isEmpty || titleMatches || _searchText(t).contains(q)) {
        group.add(t);
      }
    }
    flush();
    return out;
  }

  /// The visible texts of a settings tile, lower-cased, for the search.
  static String _searchText(Widget w) {
    String text(Widget? t) => switch (t) {
      Text(:final data?) => data,
      Column(:final children) => children.map(text).join(' '),
      _ => '',
    };
    return switch (w) {
      ListTile(:final title, :final subtitle) =>
        '${text(title)} ${text(subtitle)}',
      SwitchListTile(:final title, :final subtitle) =>
        '${text(title)} ${text(subtitle)}',
      DateTile(:final label) => label,
      _ => '',
    }.toLowerCase();
  }

  static String _scheduleSummary(
    BuildContext context,
    List<WorkSchedule> schedules,
  ) {
    final current = schedules.reduce(
      (a, b) => a.validFrom.isAfter(b.validFrom) ? a : b,
    );
    return context.l10n.perWeekSummary(
      formatMinutes(current.weekdayMinutes.fold(0, (a, b) => a + b)),
      context.days(current.annualVacationDays),
    );
  }

  /// Asks for a duration in h:mm (or decimal hours); `null` if cancelled.
  static Future<int?> _askHours(BuildContext context, String initial) {
    final controller = TextEditingController(
      text: initial.replaceAll('−', '-'),
    );
    return showDialog<int>(
      context: context,
      builder: (c) {
        String? error;
        return StatefulBuilder(
          builder: (c, setState) => AlertDialog(
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              decoration: InputDecoration(hintText: 'h:mm', errorText: error),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(c.l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final v = parseHours(controller.text);
                  if (v == null) {
                    setState(() => error = c.l10n.invalidValue);
                  } else {
                    Navigator.pop(c, v);
                  }
                },
                child: Text(c.l10n.save),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Starts a group of settings (see `_grouped`).
class _Header extends StatelessWidget {
  const _Header(this.text, {this.description});

  final String text;

  /// What the group is about, shown under the title.
  final String? description;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
