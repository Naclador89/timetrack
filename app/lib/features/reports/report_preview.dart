import 'package:flutter/material.dart';

/// One export of a previewed report: label (`PDF`, `CSV`) and what it does.
typedef PreviewExport = (String label, Future<void> Function() run);

/// Shows a report's contents in the app before it is downloaded: the same
/// table as in the PDF/CSV, the totals and an explanation. The exports are in
/// the app bar.
class ReportPreviewScreen extends StatelessWidget {
  /// Creates the preview.
  const ReportPreviewScreen({
    super.key,
    required this.title,
    required this.table,
    this.figures = const [],
    this.legend,
    this.numericColumns = const {},
    required this.exports,
  });

  /// E.g. "Stundenzettel November 2026".
  final String title;

  /// Header row plus data rows, as in the export.
  final List<List<String>> table;

  /// Totals as (label, value).
  final List<(String, String)> figures;

  /// Explanation under the totals.
  final String? legend;

  /// Columns aligned right (numbers).
  final Set<int> numericColumns;

  /// Download buttons.
  final List<PreviewExport> exports;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final header = table.first;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          for (final (label, run) in exports)
            TextButton.icon(
              onPressed: run,
              icon: Icon(
                label == 'PDF'
                    ? Icons.picture_as_pdf_outlined
                    : Icons.table_chart_outlined,
              ),
              label: Text(label),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 48,
                columnSpacing: 16,
                headingTextStyle: text.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                columns: [
                  for (final (i, h) in header.indexed)
                    DataColumn(
                      label: Text(h),
                      numeric: numericColumns.contains(i),
                    ),
                ],
                rows: [
                  for (final row in table.skip(1))
                    DataRow(
                      cells: [
                        for (final cell in row)
                          DataCell(Text(cell, style: text.bodySmall)),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (figures.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    for (final (label, value) in figures)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: text.labelSmall),
                          Text(value, style: text.titleMedium),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          if (legend != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                legend!,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}
