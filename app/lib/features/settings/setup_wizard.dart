import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../widgets/dialogs.dart';
import 'settings_screen.dart' show FederalStateChips;

/// First-start setup in four steps: federal state, working time, balance
/// and vacation carry-over, home-office limit. Everything can be changed in
/// the settings later; sync is offered at the end.
class SetupWizard extends ConsumerStatefulWidget {
  /// Creates the wizard.
  const SetupWizard({super.key});

  @override
  ConsumerState<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends ConsumerState<SetupWizard> {
  int _step = 0;
  FederalState? _state;
  double _weeklyHours = 40;
  int _workdays = 5;
  int _vacationDays = 30;
  final _balance = TextEditingController(text: '0:00');
  final _carryOver = TextEditingController(text: '0');
  late LocalDate _balanceStart;
  int? _homePercent;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _state = s.federalState;
    final today = ref.read(todayProvider);
    _balanceStart = ref.read(ledgerProvider).settings.balanceStart;
    if (_balanceStart.isAfter(today)) _balanceStart = today;
    _balance.text = formatMinutes(s.startingBalance).replaceAll('−', '-');
    final schedules = ref.read(ledgerDataProvider).schedules;
    if (schedules.isNotEmpty) {
      final current = schedules.reduce(
        (a, b) => a.validFrom.isAfter(b.validFrom) ? a : b,
      );
      final total = current.weekdayMinutes.fold(0, (a, b) => a + b);
      _weeklyHours = total / 60;
      _workdays = current.weekdayMinutes.where((m) => m > 0).length.clamp(1, 7);
      _vacationDays = current.annualVacationDays.round();
    }
    final rules = ref.read(homeOfficeRulesProvider);
    _homePercent = rules
        .where((r) => r.period == QuotaPeriod.month)
        .firstOrNull
        ?.maxPercent;
  }

  @override
  void dispose() {
    _balance.dispose();
    _carryOver.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final repo = ref.read(repositoryProvider);
    final today = ref.read(todayProvider);
    if (_state != null) {
      await saveSetting(repo, SettingKeys.federalState, _state!.code);
    }
    const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final perDay = (_weeklyHours * 60 / _workdays).round();
    // From the start of the balance year, so earlier entries of that year
    // have a target too; a version from the same day is replaced.
    final validFrom = LocalDate(
      (_balanceStart.isAfter(today) ? today : _balanceStart).year,
      1,
      1,
    );
    final existing = ref
        .read(ledgerDataProvider)
        .schedules
        .where((s) => s.validFrom == validFrom)
        .firstOrNull;
    await repo.write('work_schedules', existing?.id ?? repo.newId(), {
      'valid_from': '$validFrom',
      for (var i = 0; i < 7; i++)
        'minutes_${days[i]}': i < _workdays ? perDay : 0,
      'vacation_days': _vacationDays,
    });
    final balance = parseHours(_balance.text);
    if (balance != null) {
      await saveSetting(repo, SettingKeys.startingBalance, balance);
    }
    await saveSetting(repo, SettingKeys.balanceStartDate, '$_balanceStart');
    final carry = double.tryParse(_carryOver.text.replaceAll(',', '.'));
    if (carry != null) {
      await saveSetting(
        repo,
        SettingKeys.vacationCarryOver(_balanceStart.year),
        carry,
      );
    }
    final rule = ref
        .read(homeOfficeRulesProvider)
        .where((r) => r.period == QuotaPeriod.month)
        .firstOrNull;
    if (_homePercent != null && _homePercent != rule?.maxPercent) {
      await repo.write('home_office_rules', rule?.id ?? repo.newId(), {
        'valid_from': '${rule?.validFrom ?? _balanceStart.startOfMonth}',
        'period': QuotaPeriod.month.name,
        'unit': QuotaUnit.days.name,
        'max_percent': _homePercent,
        'basis': QuotaBasis.worked.name,
      });
    }
    if (mounted) setState(() => _step = 4);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    // The data may arrive after the first frame (app opened on /setup).
    _state ??= ref.watch(settingsProvider).federalState;
    final steps = [
      (l.federalState, l.setupStateHint, _stateStep()),
      (l.schedules, l.setupScheduleHint, _scheduleStep()),
      (l.balance, l.setupBalanceHint, _balanceStep()),
      (l.homeOfficeRules, l.setupHomeOfficeHint, _homeStep()),
      (l.setupDone, l.setupDoneHint, _doneStep()),
    ];
    final (title, hint, body) = steps[_step];
    final canNext = _step != 0 || _state != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.setupTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: (_step + 1) / steps.length),
            duration: const Duration(milliseconds: 300),
            builder: (_, v, _) => LinearProgressIndicator(value: v),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: ListView(
                      key: ValueKey(_step),
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(title, style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text(hint, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 24),
                        body,
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (_step > 0 && _step < 4)
                        TextButton(
                          onPressed: () => setState(() => _step--),
                          child: Text(l.back),
                        ),
                      const Spacer(),
                      if (_step < 3)
                        FilledButton(
                          onPressed: canNext
                              ? () => setState(() => _step++)
                              : null,
                          child: Text(l.next),
                        )
                      else if (_step == 3)
                        FilledButton(onPressed: _finish, child: Text(l.save))
                      else
                        FilledButton(
                          onPressed: () => context.pop(),
                          child: Text(l.done),
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

  Widget _stateStep() => FederalStateChips(
    selected: _state,
    onSelected: (v) => setState(() => _state = v),
  );

  Widget _scheduleStep() {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.weeklyHours, style: theme.textTheme.labelLarge),
        Wrap(
          spacing: 8,
          children: [
            for (final h in const [40.0, 39.0, 38.5, 37.5, 35.0, 30.0, 20.0])
              ChoiceChip(
                label: Text(formatMinutes((h * 60).round())),
                selected: _weeklyHours == h,
                onSelected: (_) => setState(() => _weeklyHours = h),
              ),
          ],
        ),
        Slider(
          value: _weeklyHours.clamp(5, 48),
          min: 5,
          max: 48,
          divisions: 86,
          label: formatMinutes((_weeklyHours * 60).round()),
          onChanged: (v) => setState(() => _weeklyHours = v),
        ),
        const SizedBox(height: 8),
        Text(l.workdaysPerWeek, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: [
            for (final d in const [4, 5, 6])
              ButtonSegment(value: d, label: Text('$d')),
          ],
          selected: {_workdays.clamp(4, 6)},
          onSelectionChanged: (v) => setState(() => _workdays = v.single),
        ),
        const SizedBox(height: 8),
        Text(
          l.perDaySummary(
            formatMinutes((_weeklyHours * 60 / _workdays).round()),
          ),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        Text(l.vacationDaysPerYear, style: theme.textTheme.labelLarge),
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _vacationDays--),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$_vacationDays', style: theme.textTheme.headlineSmall),
            IconButton(
              onPressed: () => setState(() => _vacationDays++),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ],
    );
  }

  Widget _balanceStep() {
    final l = context.l10n;
    return Column(
      children: [
        DateTile(
          leading: const Icon(Icons.event_outlined),
          label: l.balanceStart,
          value: _balanceStart,
          onChanged: (d) => setState(() => _balanceStart = d),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _balance,
          keyboardType: const TextInputType.numberWithOptions(
            signed: true,
            decimal: true,
          ),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.functions),
            labelText: l.startingBalance,
            helperText: l.startingBalanceHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _carryOver,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.beach_access_outlined),
            labelText: l.vacationCarryOver,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _homeStep() {
    final l = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: Text(l.noLimit),
          selected: _homePercent == null,
          onSelected: (_) => setState(() => _homePercent = null),
        ),
        for (final p in const [20, 40, 50, 60, 80])
          ChoiceChip(
            label: Text(l.percentPerMonth('$p')),
            selected: _homePercent == p,
            onSelected: (_) => setState(() => _homePercent = p),
          ),
      ],
    );
  }

  Widget _doneStep() {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => context.pushReplacement('/settings/sync'),
          icon: const Icon(Icons.cloud_outlined),
          label: Text(l.setupConnectSync),
        ),
      ],
    );
  }
}
