import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../app/format.dart';

/// Hands a generated file to the user: the share sheet on Android (save to
/// files, mail, Nextcloud …), a save dialog on Linux and Windows.
Future<void> exportBytes(
  BuildContext context,
  List<int> bytes,
  String fileName,
  String mimeType,
) async {
  final data = Uint8List.fromList(bytes);
  if (Platform.isAndroid || Platform.isIOS) {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(data, name: fileName, mimeType: mimeType)],
        fileNameOverrides: [fileName],
      ),
    );
    return;
  }
  final location = await getSaveLocation(suggestedName: fileName);
  if (location == null) return;
  await File(location.path).writeAsBytes(data);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.savedTo(location.path))),
    );
  }
}
