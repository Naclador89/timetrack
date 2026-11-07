import 'dart:convert';
import 'dart:io' show gzip;

import 'change.dart';

/// The sync format version this code reads and writes (spec: sync-format.md §9).
const int syncFormatVersion = 1;

/// Thrown when a batch file can't be read.
final class BatchFormatException implements Exception {
  /// Creates the exception.
  BatchFormatException(this.message);

  /// What is wrong.
  final String message;

  @override
  String toString() => 'BatchFormatException: $message';
}

/// The file name of a batch: the HLC of its first change
/// (spec: sync-format.md §5).
String batchFileName(List<Change> changes) =>
    '${changes.first.hlc}.jsonl.gz.enc';

/// Encodes the [changes] of [deviceId] as gzip-compressed JSON Lines with a
/// header line (spec: sync-format.md §5). Encryption is applied separately.
List<int> encodeBatch(String deviceId, List<Change> changes) {
  if (changes.isEmpty) throw ArgumentError('A batch needs at least one change');
  final sorted = [...changes]..sort((a, b) => a.hlc.compareTo(b.hlc));
  final lines = [
    jsonEncode({
      'format': syncFormatVersion,
      'deviceId': deviceId,
      'count': sorted.length,
    }),
    for (final c in sorted) jsonEncode(c.toJson()),
  ];
  return gzip.encode(utf8.encode('${lines.join('\n')}\n'));
}

/// Decodes a batch encoded by [encodeBatch]; checks the header.
List<Change> decodeBatch(List<int> bytes, {String? expectedDeviceId}) {
  final List<String> lines;
  try {
    lines = utf8
        .decode(gzip.decode(bytes))
        .split('\n')
        .where((l) => l.isNotEmpty)
        .toList();
  } on FormatException catch (e) {
    throw BatchFormatException('Not a gzip/UTF-8 batch: ${e.message}');
  }
  if (lines.isEmpty) throw BatchFormatException('Empty batch');
  final header = jsonDecode(lines.first) as Map<String, Object?>;
  final format = header['format'];
  if (format is! int || format > syncFormatVersion) {
    throw BatchFormatException('Unsupported format $format');
  }
  if (expectedDeviceId != null && header['deviceId'] != expectedDeviceId) {
    throw BatchFormatException('Batch belongs to ${header['deviceId']}');
  }
  final changes = [
    for (final line in lines.skip(1))
      Change.fromJson(jsonDecode(line) as Map<String, Object?>),
  ];
  if (header['count'] != changes.length) {
    throw BatchFormatException('Expected ${header['count']} changes');
  }
  return changes;
}
