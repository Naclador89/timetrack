import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timetrack_core/timetrack_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/appearance.dart';
import '../../app/format.dart';
import '../../app/providers.dart';
import '../../booking/booking_store.dart';
import '../../l10n/app_localizations.dart';
import '../../reminders/reminders.dart';
import '../../update/update_banner.dart';
import '../../update/update_controller.dart';
import '../../widgets/dialogs.dart';
import '../../work_pc/month_report.dart';
import '../../work_pc/work_pc.dart';
import 'per_diem_rates_screen.dart' show parseCents;
import 'settings_screen.dart';

/// The pages of the settings (navigation.md, "Settings structure"), each
/// opened from the overview at `/settings/<path>`.
enum SettingsSection {
  /// Target hours, federal state, overtime account, vacation deadline.
  account('account', Icons.schedule),

  /// Clocking behaviour, breaks, reminders.
  clocking('clocking', Icons.login),

  /// Crediting on trips, weekends and holidays, per-diem rates.
  travel('travel', Icons.flight_outlined),

  /// Which notices show as cards.
  notices('notices', Icons.notifications_outlined),

  /// Theme and updates.
  app('app', Icons.palette_outlined),

  /// Windows only: autostart, tray, monthly reminder, booking.
  workPc('work-pc', Icons.computer_outlined);

  const SettingsSection(this.path, this.icon);

  /// The route below `/settings`.
  final String path;

  /// The icon on the overview.
  final IconData icon;

  /// The page title.
  String title(AppLocalizations l) => switch (this) {
    account => l.sectionAccount,
    clocking => l.sectionClocking,
    travel => l.sectionTravel,
    notices => l.notices,
    app => l.sectionApp,
    workPc => l.workPc,
  };

  /// Whether the page exists on this device.
  bool available(WidgetRef ref) =>
      this != workPc || ref.watch(workPcPlatformProvider) != null;

  /// The line under the title on the overview.
  String summary(BuildContext context, WidgetRef ref) =>
      _Tiles(context, ref).summary(this);

  /// The tiles of the page, with [SettingsHeader]s between the groups.
  List<Widget> tiles(BuildContext context, WidgetRef ref) {
    final t = _Tiles(context, ref);
    return switch (this) {
      account => t.account(),
      clocking => t.clocking(),
      travel => t.travel(),
      notices => t.notices(),
      app => t.app(),
      workPc => t.workPc(),
    };
  }
}

/// One settings page (see [SettingsSection]).
class SettingsPage extends ConsumerWidget {
  /// Creates the page.
  const SettingsPage(this.section, {super.key});

  /// What the page shows.
  final SettingsSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) => UpdateBannerHost(
    child: Scaffold(
      appBar: AppBar(title: Text(section.title(context.l10n))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: groupedSettings(context, section.tiles(context, ref)),
      ),
    ),
  );
}

/// Builds the tiles of the pages; one per build, nothing is kept.
class _Tiles {
  _Tiles(this.context, this.ref)
    : l = context.l10n,
      s = ref.watch(settingsProvider);

  final BuildContext context;
  final WidgetRef ref;
  final AppLocalizations l;
  final AppSettings s;

  Future<void> save(String key, Object? value) =>
      saveSetting(ref.read(repositoryProvider), key, value);

  String summary(SettingsSection section) {
    final schedules = ref.watch(ledgerDataProvider).schedules;
    return switch (section) {
      SettingsSection.account => [
        if (schedules.isNotEmpty) _scheduleSummary(context, schedules),
        stateNames[s.federalState] ?? l.notSet,
      ].join(' · '),
      SettingsSection.clocking =>
        '${l.breakRule}: ${s.breakMode == BreakRuleMode.warn ? l.breakWarn : l.breakDeduct}',
      SettingsSection.travel =>
        '${l.travelSunday}: ${s.travel.sunday == TripSundayCredit.sundayHours ? l.sundayHours : l.sundayWorkOnly}',
      SettingsSection.notices => [
        l.noticesActive(
          '${NoticeCategory.values.where((c) => s.showsNotice(c.wireName)).length}',
          '${NoticeCategory.values.length}',
        ),
        if (ref.watch(dismissedNoticesProvider) case final d when d.isNotEmpty)
          l.dismissedCount('${d.length}'),
      ].join(' · '),
      SettingsSection.app => [
        '${l.appearance}: ${switch (ref.watch(appearanceProvider).mode) {
          ThemeMode.system => l.themeSystem,
          ThemeMode.light => l.themeLight,
          ThemeMode.dark => l.themeDark,
        }}',
        if (ref.watch(installedVersionProvider).value case final v?)
          l.installedVersion('$v'),
      ].join(' · '),
      SettingsSection.workPc => l.workPcSummary,
    };
  }

  /// Target hours (calculations §7), the overtime account (§8, §20) and
  /// the vacation carry-over deadline (§10.2).
  List<Widget> account() {
    final schedules = ref.watch(ledgerDataProvider).schedules;
    return [
      SettingsHeader(l.groupTarget),
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
      SettingsHeader(l.accountSection),
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
      // calculations §20: the employer's limits, none built in.
      ListTile(
        leading: const Icon(Icons.traffic_outlined),
        title: Text(l.balanceZones),
        subtitle: Text(
          s.balanceLimits.isSet
              ? _limitsSummary(context, s.balanceLimits)
              : l.balanceZonesHint,
        ),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _BalanceLimitsDialog(s.balanceLimits, save),
        ),
      ),
      SettingsHeader(l.groupVacation),
      _deadlineTile(
        icon: Icons.beach_access_outlined,
        title: l.vacationCarryDeadline,
        hint: l.vacationCarryDeadlineHint,
        months: s.vacationCarryDeadlineMonths,
        onChanged: (v) => save(SettingKeys.vacationCarryDeadline, v),
      ),
    ];
  }

  /// How clocking behaves, breaks (calculations §4, §4.1) and reminders
  /// (reminders.md §2).
  List<Widget> clocking() => [
    SettingsHeader(l.groupClocking),
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
    // spec: calculations.md §19
    SwitchListTile(
      secondary: const Icon(Icons.schedule),
      title: Text(l.askStampTime),
      subtitle: Text(l.askStampTimeHint),
      value: s.askStampTime,
      onChanged: (v) => save(SettingKeys.askStampTime, v),
    ),
    SettingsHeader(l.groupBreaks),
    ListTile(
      leading: const Icon(Icons.rule),
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
      SettingsHeader(l.reminders),
      SwitchListTile(
        secondary: const Icon(Icons.notifications_active_outlined),
        title: Text(l.remindBreak),
        subtitle: Text(l.remindBreakHint),
        value: s.remindBreak,
        onChanged: (v) => save(SettingKeys.remindBreak, v),
      ),
      SwitchListTile(
        secondary: const Icon(Icons.notifications_active_outlined),
        title: Text(l.remindLongDay),
        subtitle: Text(l.remindLongDayHint),
        value: s.remindLongDay,
        onChanged: (v) => save(SettingKeys.remindLongDay, v),
      ),
    ],
  ];

  /// What trips, weekends and holidays credit (calculations §9; only the
  /// account, the travel record keeps the real times) and the per-diem.
  List<Widget> travel() => [
    SettingsHeader(l.travelRules, description: l.travelRulesHint),
    ListTile(
      leading: const Icon(Icons.construction_outlined),
      title: Text(l.serviceSaturdayCap),
      subtitle: Text(l.serviceSaturdayCapHint),
      trailing: Text(formatMinutes(s.travel.serviceSaturdayCapMinutes)),
      onTap: () async {
        final v = await _askHours(
          context,
          formatMinutes(s.travel.serviceSaturdayCapMinutes),
        );
        if (v != null && v >= 0) {
          await save(SettingKeys.travelServiceSaturdayCap, v);
        }
      },
    ),
    // On every Saturday, Sunday and holiday, trip or not (§9).
    SettingsHeader(l.weekendRules, description: l.weekendRulesHint),
    ListTile(
      leading: const Icon(Icons.weekend_outlined),
      title: Text(l.dayCap),
      subtitle: Text(l.dayCapHint),
      trailing: Text(formatMinutes(s.travel.dayCapMinutes)),
      onTap: () async {
        final v = await _askHours(
          context,
          formatMinutes(s.travel.dayCapMinutes),
        );
        if (v != null && v >= 0) await save(SettingKeys.travelDayCap, v);
      },
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
            onSelectionChanged: (v) => save(SettingKeys.travelSunday, v.single),
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
          if (v != null && v >= 0) await save(SettingKeys.travelSundayCap, v);
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
    // calculations §21.1: the employer's list, none built in.
    ListTile(
      leading: const Icon(Icons.star_outline),
      title: Text(l.specialDays),
      subtitle: Text(
        s.travel.specialDays.isEmpty
            ? '${l.specialDaysNone} · ${l.specialDaysHint}'
            : [
                for (final d in SpecialDay.values)
                  if (s.travel.specialDays.contains(d)) _specialDayName(l, d),
              ].join(', '),
      ),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => _SpecialDaysDialog(s.travel.specialDays, save),
      ),
    ),
    // calculations §21.2
    SettingsHeader(l.groupNightWork),
    ListTile(
      leading: const Icon(Icons.bedtime_outlined),
      title: Text(l.nightWorkCredit),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.travel.night == NightWorkCredit.exclude
                ? l.nightExcludeHint
                : l.nightCountHint,
          ),
          const SizedBox(height: 8),
          SegmentedButton<NightWorkCredit>(
            segments: [
              ButtonSegment(
                value: NightWorkCredit.count,
                label: Text(l.nightCount),
              ),
              ButtonSegment(
                value: NightWorkCredit.exclude,
                label: Text(l.nightExclude),
              ),
            ],
            selected: {s.travel.night},
            onSelectionChanged: (v) =>
                save(SettingKeys.nightWorkCredit, v.single),
          ),
        ],
      ),
    ),
    SettingsHeader(l.groupExpenses),
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
    // calculations §13.2–§13.5: the employer's rules.
    ListTile(
      leading: const Icon(Icons.construction_outlined),
      title: Text(l.siteAllowance),
      subtitle: Text(
        ref.watch(ledgerDataProvider).siteAllowances.isEmpty
            ? '${l.notSet} · ${l.siteAllowanceRatesHint}'
            : l.siteAllowanceSummary('${s.expenses.siteAllowanceMinDays}'),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/settings/site-allowance'),
    ),
    _choiceTile(
      icon: Icons.linear_scale,
      title: l.siteAllowanceMinDays,
      value: s.expenses.siteAllowanceMinDays,
      options: {for (var n = 1; n <= 5; n++) n: '$n'},
      onChanged: (v) => save(SettingKeys.siteAllowanceMinDays, v),
    ),
    ListTile(
      leading: const Icon(Icons.directions_car_outlined),
      title: Text(l.mileageRate),
      trailing: Text('${context.euro(s.expenses.mileageCentsPerKm)}/km'),
      onTap: () async {
        final v = await showTextPrompt(
          context,
          title: l.mileageRate,
          okLabel: l.save,
          cancelLabel: l.cancel,
          initial: (s.expenses.mileageCentsPerKm / 100).toStringAsFixed(2),
          hint: '0,30',
        );
        final cents = v == null ? null : parseCents(v);
        if (cents != null) await save(SettingKeys.mileageCentsPerKm, cents);
      },
    ),
    _choiceTile(
      icon: Icons.local_laundry_service_outlined,
      title: l.laundryAfterDays,
      value: s.expenses.laundryAfterDays,
      options: {
        0: l.deadlineOff,
        for (var n = 1; n <= 14; n++) n: l.moreThanDays('$n'),
      },
      onChanged: (v) => save(SettingKeys.laundryAfterDays, v),
    ),
    _choiceTile(
      icon: Icons.event_busy_outlined,
      title: l.claimDeadlineMonths,
      hint: l.claimDeadlineHint,
      value: s.expenses.claimDeadlineMonths,
      options: {
        0: l.deadlineOff,
        for (var n = 1; n <= 12; n++) n: l.monthsCount('$n'),
      },
      onChanged: (v) => save(SettingKeys.claimDeadlineMonths, v),
    ),
  ];

  /// A setting picked from a few [options] (value → label).
  Widget _choiceTile({
    required IconData icon,
    required String title,
    String? hint,
    required int value,
    required Map<int, String> options,
    required ValueChanged<int> onChanged,
  }) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: hint == null ? null : Text(hint),
    trailing: DropdownButton<int>(
      value: options.containsKey(value) ? value : options.keys.first,
      onChanged: (v) => v == null ? null : onChanged(v),
      items: [
        for (final MapEntry(:key, :value) in options.entries)
          DropdownMenuItem(value: key, child: Text(value)),
      ],
    ),
  );

  /// Which notices appear as cards (calculations §12); a dismissed card
  /// stays away and only leaves the marker in the calendar.
  List<Widget> notices() {
    final dismissed = ref.watch(dismissedNoticesProvider);
    return [
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
        subtitle: Text(l.dismissedCount('${dismissed.length}')),
        enabled: dismissed.isNotEmpty,
        onTap: () async {
          final repo = ref.read(repositoryProvider);
          for (final key in ref.read(dismissedNoticesProvider)) {
            await repo.delete('dismissed_notices', key);
          }
        },
      ),
    ];
  }

  /// Theme (device-local) and updates (updates.md §3).
  List<Widget> app() => [
    SettingsHeader(l.groupDisplay),
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
    SettingsHeader(l.groupUpdates),
    ListTile(
      leading: const Icon(Icons.system_update_outlined),
      title: Text(l.checkForUpdates),
      subtitle: Text(_versionLine()),
      onTap: () => checkForUpdatesByHand(context, ref),
    ),
    SwitchListTile(
      secondary: const Icon(Icons.update),
      title: Text(l.autoUpdateCheck),
      subtitle: Text(l.autoUpdateCheckHint),
      value: ref.watch(updateStateProvider).value?.auto ?? true,
      onChanged: (v) => ref.read(updateControllerProvider.notifier).setAuto(v),
    ),
    ListTile(
      leading: const Icon(Icons.open_in_new),
      title: Text(l.releasePage),
      onTap: () =>
          launchUrl(releasesPage, mode: LaunchMode.externalApplication),
    ),
  ];

  /// Windows only, all device-local (work-pc.md §1, §3, §4,
  /// booking-transfer.md §1).
  List<Widget> workPc() {
    final workPc = ref.watch(workPcPlatformProvider);
    if (workPc == null) return const [];
    Future<void> setLocal(String key, bool v) => ref
        .read(storeProvider)
        .transaction((tx) => tx.setLocalValue(key, '$v'));
    return [
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
          await setLocal(startPromptKey, v);
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
      SwitchListTile(
        secondary: const Icon(Icons.minimize),
        title: Text(l.closeToTray),
        subtitle: Text(l.closeToTrayHint),
        value: ref.watch(closeToTrayProvider).value ?? true,
        onChanged: (v) async {
          await setLocal(closeToTrayKey, v);
          ref.invalidate(closeToTrayProvider);
        },
      ),
      SwitchListTile(
        secondary: const Icon(Icons.outbox_outlined),
        title: Text(l.monthReportReminder),
        subtitle: Text(l.monthReportReminderHint),
        value: ref.watch(monthReportReminderProvider).value ?? true,
        onChanged: (v) async {
          await setLocal(monthReportReminderKey, v);
          ref.invalidate(monthReportReminderProvider);
        },
      ),
      if (ref.watch(bookingSupportedProvider))
        ListTile(
          leading: const Icon(Icons.upload_outlined),
          title: Text(l.bookingUrl),
          subtitle: Text(
            (ref.watch(bookingUrlProvider).value ?? '').isEmpty
                ? '${l.notSet} · ${l.bookingUrlHint}'
                : '${ref.watch(bookingUrlProvider).value} · ${l.bookingUrlHint}',
          ),
          onTap: () async {
            final url = await showTextPrompt(
              context,
              title: l.bookingUrl,
              okLabel: l.save,
              cancelLabel: l.cancel,
              initial: ref.read(bookingUrlProvider).value ?? '',
              hint: 'http://…',
            );
            if (url == null) return;
            await saveBookingUrl(ref.read(storeProvider), url);
            ref.invalidate(bookingUrlProvider);
          },
        ),
    ];
  }

  /// "Installiert: 0.4.0 · zuletzt geprüft 08.11.2026 10:00".
  String _versionLine() {
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

  /// A deadline as "end of month N" of the year, 0 = off (§10.2).
  Widget _deadlineTile({
    required IconData icon,
    required String title,
    required String hint,
    required int months,
    required ValueChanged<int> onChanged,
  }) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(hint),
      trailing: DropdownButton<int>(
        value: months,
        onChanged: (v) => v == null ? null : onChanged(v),
        items: [
          DropdownMenuItem(value: 0, child: Text(l.deadlineOff)),
          for (var m = 1; m <= 12; m++)
            DropdownMenuItem(
              value: m,
              child: Text(
                l.deadlineEndOf(
                  DateFormat.MMMM(locale).format(DateTime(2000, m)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _scheduleSummary(BuildContext context, List<WorkSchedule> schedules) {
  final current = schedules.reduce(
    (a, b) => a.validFrom.isAfter(b.validFrom) ? a : b,
  );
  return context.l10n.perWeekSummary(
    formatMinutes(current.weekdayMinutes.fold(0, (a, b) => a + b)),
    context.days(current.annualVacationDays),
  );
}

/// "Gelb +300 / −100 · Rot +350 / −150 · Grenze +400 / −200" (§20).
String _limitsSummary(BuildContext context, BalanceLimits b) {
  final l = context.l10n;
  String side(int? plus, int? minus) => [
    if (plus != null) '+${plus ~/ 60}',
    if (minus != null) '−${minus ~/ 60}',
  ].join(' / ');
  return [
    if (b.yellowPlus != null || b.yellowMinus != null)
      '${l.zoneYellowFrom} ${side(b.yellowPlus, b.yellowMinus)}',
    if (b.redPlus != null || b.redMinus != null)
      '${l.zoneRedFrom} ${side(b.redPlus, b.redMinus)}',
    if (b.maxPlus != null || b.maxMinus != null)
      '${l.zoneMax} ${side(b.maxPlus, b.maxMinus)}',
  ].join(' · ');
}

/// The name of a special holiday (calculations §21.1).
String _specialDayName(AppLocalizations l, SpecialDay d) => switch (d) {
  SpecialDay.newYear => l.specialDayNewYear,
  SpecialDay.easterSunday => l.specialDayEasterSunday,
  SpecialDay.easterMonday => l.specialDayEasterMonday,
  SpecialDay.mayDay => l.specialDayMayDay,
  SpecialDay.whitSunday => l.specialDayWhitSunday,
  SpecialDay.whitMonday => l.specialDayWhitMonday,
  SpecialDay.christmasDay => l.specialDayChristmasDay,
  SpecialDay.boxingDay => l.specialDayBoxingDay,
};

/// Picks the special holidays (calculations §21.1).
class _SpecialDaysDialog extends StatefulWidget {
  const _SpecialDaysDialog(this.initial, this.save);

  final Set<SpecialDay> initial;
  final Future<void> Function(String key, Object? value) save;

  @override
  State<_SpecialDaysDialog> createState() => _SpecialDaysDialogState();
}

class _SpecialDaysDialogState extends State<_SpecialDaysDialog> {
  late final _picked = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.specialDays),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.specialDaysHint),
            const SizedBox(height: 8),
            for (final d in SpecialDay.values)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_specialDayName(l, d)),
                value: _picked.contains(d),
                onChanged: (v) => setState(
                  () => v ?? false ? _picked.add(d) : _picked.remove(d),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () async {
            final navigator = Navigator.of(context);
            await widget.save(
              SettingKeys.specialDays,
              [
                for (final d in SpecialDay.values)
                  if (_picked.contains(d)) d.code,
              ].join(','),
            );
            navigator.pop();
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}

/// Asks for a duration in h:mm (or decimal hours); `null` if cancelled.
Future<int?> _askHours(BuildContext context, String initial) {
  final controller = TextEditingController(text: initial.replaceAll('−', '-'));
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

/// The six limits of the overtime account in whole hours; an empty field
/// is no limit (calculations §20).
class _BalanceLimitsDialog extends StatefulWidget {
  const _BalanceLimitsDialog(this.limits, this.save);

  final BalanceLimits limits;
  final Future<void> Function(String key, Object? value) save;

  @override
  State<_BalanceLimitsDialog> createState() => _BalanceLimitsDialogState();
}

class _BalanceLimitsDialogState extends State<_BalanceLimitsDialog> {
  late final _fields =
      {
        SettingKeys.balanceYellowPlus: widget.limits.yellowPlus,
        SettingKeys.balanceYellowMinus: widget.limits.yellowMinus,
        SettingKeys.balanceRedPlus: widget.limits.redPlus,
        SettingKeys.balanceRedMinus: widget.limits.redMinus,
        SettingKeys.balanceMaxPlus: widget.limits.maxPlus,
        SettingKeys.balanceMaxMinus: widget.limits.maxMinus,
      }.map(
        (k, v) => MapEntry(
          k,
          TextEditingController(text: v == null ? '' : '${v ~/ 60}'),
        ),
      );

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget field(String key, String label) => Expanded(
      child: TextField(
        controller: _fields[key],
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, suffixText: 'h'),
      ),
    );
    Widget row(String label, String plus, String minus) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label)),
          field(plus, l.zonePlus),
          const SizedBox(width: 12),
          field(minus, l.zoneMinus),
        ],
      ),
    );
    return AlertDialog(
      title: Text(l.balanceZones),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.balanceZonesDialogHint),
            const SizedBox(height: 16),
            row(
              l.zoneYellowFrom,
              SettingKeys.balanceYellowPlus,
              SettingKeys.balanceYellowMinus,
            ),
            row(
              l.zoneRedFrom,
              SettingKeys.balanceRedPlus,
              SettingKeys.balanceRedMinus,
            ),
            row(
              l.zoneMax,
              SettingKeys.balanceMaxPlus,
              SettingKeys.balanceMaxMinus,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () async {
            final navigator = Navigator.of(context);
            for (final MapEntry(:key, value: c) in _fields.entries) {
              final hours = int.tryParse(c.text.trim().replaceAll('-', ''));
              await widget.save(
                key,
                hours == null || hours <= 0 ? null : hours * 60,
              );
            }
            navigator.pop();
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
