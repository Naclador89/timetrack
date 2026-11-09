import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../sync/sync_controller.dart';
import '../../widgets/dialogs.dart';
import 'settings_sections.dart';

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

/// The settings overview (navigation.md, "Settings structure"): sync, one
/// tile per [SettingsSection] page, home office and the setup; the search
/// covers the tiles of every page.
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
    final sync = ref.watch(syncControllerProvider);
    final syncTile = ListTile(
      leading: Icon(switch (sync.phase) {
        SyncPhase.notConfigured => Icons.cloud_off_outlined,
        SyncPhase.error => Icons.sync_problem,
        _ => Icons.cloud_done_outlined,
      }),
      title: Text(l.sync),
      subtitle: Text(switch (sync) {
        SyncStatus(phase: SyncPhase.notConfigured) => l.syncNotConnected,
        SyncStatus(phase: SyncPhase.error) => l.syncError,
        final st => st.root?.host ?? '',
      }),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/settings/sync'),
    );
    final homeOfficeTile = ListTile(
      leading: Icon(locationIcon(WorkLocation.home)),
      title: Text(l.homeOfficeRules),
      subtitle: ref.watch(homeOfficeRulesProvider).isEmpty
          ? Text(l.notSet)
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/settings/home-office'),
    );
    final setupTile = ListTile(
      leading: const Icon(Icons.rocket_launch_outlined),
      title: Text(l.setupTitle),
      subtitle: Text(l.setupAgainHint),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/setup'),
    );
    final sections = [
      for (final section in SettingsSection.values)
        if (section.available(ref)) section,
    ];
    final List<Widget> tiles;
    if (_query.isEmpty) {
      tiles = [
        syncTile,
        const SettingsHeader(''),
        for (final section in sections) ...[
          ListTile(
            leading: Icon(section.icon),
            title: Text(section.title(l)),
            subtitle: Text(section.summary(context, ref)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/${section.path}'),
          ),
          if (section == SettingsSection.clocking) homeOfficeTile,
        ],
        const SettingsHeader(''),
        setupTile,
      ];
    } else {
      // Every page's tiles; a group is titled "Page › Group".
      tiles = [
        SettingsHeader(l.sync),
        syncTile,
        for (final section in sections) ..._prefixed(section),
        SettingsHeader(l.homeOfficeRules),
        homeOfficeTile,
        SettingsHeader(l.setupTitle),
        setupTile,
      ];
    }
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
          ...groupedSettings(context, tiles, query: _query),
        ],
      ),
    );
  }

  List<Widget> _prefixed(SettingsSection section) {
    final title = section.title(context.l10n);
    final tiles = section.tiles(context, ref);
    return [
      if (tiles.firstOrNull is! SettingsHeader) SettingsHeader(title),
      for (final t in tiles)
        if (t is SettingsHeader)
          SettingsHeader('$title › ${t.text}', description: t.description)
        else
          t,
    ];
  }
}

/// Starts a group of settings (see [groupedSettings]); an empty [text]
/// starts a card without a title.
class SettingsHeader extends StatelessWidget {
  /// Creates the header.
  const SettingsHeader(this.text, {super.key, this.description});

  /// The group's title.
  final String text;

  /// What the group is about, shown under the title.
  final String? description;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Puts the tiles after each [SettingsHeader] into one card (tiles before
/// the first header too); with a [query], only the tiles whose texts match,
/// or all of a group whose title matches.
List<Widget> groupedSettings(
  BuildContext context,
  List<Widget> tiles, {
  String query = '',
}) {
  final q = query.toLowerCase();
  final theme = Theme.of(context);
  final out = <Widget>[];
  var title = '';
  String? description;
  var group = <Widget>[];
  var titleMatches = false;
  void flush() {
    if (group.isEmpty) return;
    if (title.isNotEmpty) {
      out.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              if (description != null && q.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(description, style: theme.textTheme.bodySmall),
                ),
            ],
          ),
        ),
      );
    } else if (out.isNotEmpty) {
      out.add(const SizedBox(height: 12));
    }
    out.add(Card(child: Column(children: group)));
    group = [];
  }

  for (final t in tiles) {
    if (t is SettingsHeader) {
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
String _searchText(Widget w) {
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
