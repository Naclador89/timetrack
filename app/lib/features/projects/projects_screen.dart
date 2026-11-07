import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import 'project_picker.dart';

/// All projects, searchable; tap to edit.
class ProjectsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  final _query = TextEditingController();
  bool _archived = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final projects = ref.watch(projectsProvider);
    final results = searchProjects(
      _query.text,
      projects,
      usage: ref.watch(projectUsageProvider),
      includeArchived: _archived,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navProjects),
        actions: [
          IconButton(
            tooltip: l.showArchived,
            isSelected: _archived,
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2),
            onPressed: () => setState(() => _archived = !_archived),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showProjectEditor(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l.newProject),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _query,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l.searchProjects,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: projects.isEmpty
                ? Center(child: Text(l.noProjects))
                : ListView(
                    padding: const EdgeInsets.only(bottom: 88),
                    children: [
                      for (final m in results)
                        ProjectTile(
                          match: m,
                          onTap: () => showProjectEditor(
                            context,
                            ref,
                            project: m.project,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
