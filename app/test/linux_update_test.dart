// spec: updates.md §5 (Linux)
@TestOn('linux')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/update/installer.dart';

/// A tar.gz like the release one: `bundle/timetrack` plus a data file.
Future<File> releaseArchive(
  Directory tmp,
  String version, {
  bool bundle = true,
}) async {
  final src = Directory(
    '${tmp.path}/src-$version/${bundle ? 'bundle' : 'other'}',
  )..createSync(recursive: true);
  File('${src.path}/timetrack').writeAsStringSync('app $version');
  File('${src.path}/version.txt').writeAsStringSync(version);
  final archive = File('${tmp.path}/timetrack-$version.tar.gz');
  final r = await Process.run('tar', [
    '-czf',
    archive.path,
    '-C',
    src.parent.path,
    bundle ? 'bundle' : 'other',
  ]);
  expect(r.exitCode, 0, reason: '${r.stderr}');
  return archive;
}

void main() {
  late Directory tmp;
  late Directory install;
  late LinuxUpdateInstaller installer;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tt-linux-update');
    install = Directory('${tmp.path}/opt/timetrack')
      ..createSync(recursive: true);
    File('${install.path}/timetrack').writeAsStringSync('app 0.4.0');
    File('${install.path}/stale.txt')
        .writeAsStringSync('only in the old version');
    installer = LinuxUpdateInstaller(executable: '${install.path}/timetrack');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test(
    'the new bundle replaces the folder; the old one is cleaned up next start',
    () async {
      expect(await installer.canSelfInstall(), isTrue);
      final archive = await releaseArchive(tmp, '0.4.1');
      expect(
        await installer.install(archive),
        isTrue,
        reason: 'restart finishes it',
      );

      expect(File('${install.path}/timetrack').readAsStringSync(), 'app 0.4.1');
      expect(File('${install.path}/stale.txt').existsSync(), isFalse);
      expect(Directory('${install.path}.old').existsSync(), isTrue);
      expect(archive.existsSync(), isFalse);

      await installer.cleanUp();
      expect(Directory('${install.path}.old').existsSync(), isFalse);
      expect(Directory('${install.path}.new').existsSync(), isFalse);
    },
  );

  test('an archive without bundle/ leaves the installed app alone', () async {
    final archive = await releaseArchive(tmp, '0.4.1', bundle: false);
    await expectLater(
      installer.install(archive),
      throwsA(isA<UpdateException>()),
    );
    expect(File('${install.path}/timetrack').readAsStringSync(), 'app 0.4.0');
    expect(Directory('${install.path}.old').existsSync(), isFalse);
  });

  test('a read-only parent folder means: only open the release page', () async {
    final parent = install.parent;
    await Process.run('chmod', ['a-w', parent.path]);
    addTearDown(() => Process.run('chmod', ['u+w', parent.path]));
    expect(await installer.canSelfInstall(), isFalse);
  });
}
