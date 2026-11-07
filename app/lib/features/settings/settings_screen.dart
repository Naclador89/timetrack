import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../sync/sync_controller.dart';
import '../../widgets/dialogs.dart';

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

/// All settings (stored as synced `settings` rows, data-model.md §7).
class SettingsScreen extends ConsumerWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final repo = ref.watch(repositoryProvider);
    final schedules = ref.watch(ledgerDataProvider).schedules;
    final rules = ref.watch(homeOfficeRulesProvider);
    Future<void> save(String key, Object? value) =>
        saveSetting(repo, key, value);
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.navSettings)),
      body: ListView(
        children: [
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
            onTap: () => context.go('/settings/sync'),
          ),
          header(l.general),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: Text(l.federalState),
            trailing: DropdownButton<FederalState>(
              value: s.federalState,
              hint: Text(l.notSet),
              items: [
                for (final e in stateNames.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => save(SettingKeys.federalState, v?.code),
            ),
          ),
          if (s.federalState == FederalState.by)
            SwitchListTile(
              secondary: const SizedBox(width: 24),
              title: const Text('Mariä Himmelfahrt (15.08.)'),
              value: s.bavariaAssumptionDay,
              onChanged: (v) => save(SettingKeys.bavariaAssumptionDay, v),
            ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(l.schedules),
            subtitle: Text(
              schedules.isEmpty
                  ? l.notSet
                  : _scheduleSummary(context, schedules),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/schedules'),
          ),
          ListTile(
            leading: Icon(locationIcon(WorkLocation.home)),
            title: Text(l.homeOfficeRules),
            subtitle: rules.isEmpty ? Text(l.notSet) : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/home-office'),
          ),
          ListTile(
            leading: const Icon(Icons.beach_access_outlined),
            title: Text(l.absences),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/calendar/absences'),
          ),
          ListTile(
            leading: const Icon(Icons.luggage_outlined),
            title: Text(l.trips),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/calendar/trips'),
          ),
          header(l.balance),
          ListTile(
            leading: const Icon(Icons.functions),
            title: Text(l.startingBalance),
            trailing: Text(formatMinutes(s.startingBalance)),
            onTap: () async {
              final v = await _askHours(
                context,
                formatMinutes(s.startingBalance),
              );
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
                ButtonSegment(
                  value: BreakRuleMode.warn,
                  label: Text(l.breakWarn),
                ),
                ButtonSegment(
                  value: BreakRuleMode.deduct,
                  label: Text(l.breakDeduct),
                ),
              ],
              selected: {s.breakMode},
              onSelectionChanged: (v) =>
                  save(SettingKeys.breakRuleMode, v.single),
            ),
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
          header(l.travelRules),
          ListTile(
            leading: const Icon(Icons.weekend_outlined),
            title: Text(l.saturdayCap),
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
          const SizedBox(height: 24),
        ],
      ),
    );
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
