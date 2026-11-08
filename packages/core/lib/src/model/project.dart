/// A project time can be booked on (spec: concept.md §2, `projects` table).
final class Project {
  /// Creates a project.
  const Project({
    required this.id,
    required this.name,
    this.projectNumber = '',
    this.orderNumber = '',
    this.client = '',
    this.favorite = false,
    this.archived = false,
    this.budgetMinutes,
  });

  /// Row id (UUIDv7).
  final String id;

  /// Project name, e.g. `Werk Süd Umbau`.
  final String name;

  /// Project number, e.g. `P-2026/014`. Empty if unknown.
  final String projectNumber;

  /// Order number (Auftragsnummer), e.g. `A-778812`. Empty if unknown.
  final String orderNumber;

  /// Client, e.g. `Bosch`. Empty if unknown.
  final String client;

  /// Shown as a chip on the Today screen.
  final bool favorite;

  /// Hidden from the picker unless archived projects are switched on.
  final bool archived;

  /// Hour budget in minutes, if any (calculations.md §3.1).
  final int? budgetMinutes;
}
