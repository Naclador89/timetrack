// spec: updates.md §5 (Windows)
@TestOn('linux')
library;

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/update/installer.dart';

/// A ZIP like the release one: `timetrack.exe` and `data/` at the top.
File releaseZip(Directory tmp, String version) {
  final archive = Archive()
    ..addFile(ArchiveFile.string('timetrack.exe', 'app $version'))
    ..addFile(ArchiveFile.string('data/app.so', 'aot $version'));
  final zip = File('${tmp.path}/timetrack-windows-x64.zip')
    ..writeAsBytesSync(ZipEncoder().encode(archive));
  return zip;
}

void main() {
  late Directory tmp;
  late Directory install;
  late List<String> launched;
  late WindowsUpdateInstaller installer;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tt-windows-update');
    install = Directory('${tmp.path}/TimeTrack')..createSync();
    File('${install.path}/timetrack.exe').writeAsStringSync('app 0.6.2');
    Directory('${install.path}/data').createSync();
    File('${install.path}/data/app.so').writeAsStringSync('aot 0.6.2');
    launched = [];
    installer = WindowsUpdateInstaller(
      executable: '${install.path}/timetrack.exe',
      launch: (exe) async => launched.add(exe),
      quit: () async => throw const _Quit(),
    );
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('§5 no script: the files are swapped in at once, restart starts the new exe', () async {
    expect(await installer.install(releaseZip(tmp, '0.6.3')), isTrue);
    // In place already: a start by hand also gets the new version.
    expect(launched, isEmpty);
    expect(
      File('${install.path}/timetrack.exe').readAsStringSync(),
      'app 0.6.3',
    );
    expect(File('${install.path}/data/app.so').readAsStringSync(), 'aot 0.6.3');
    expect(
      File('${install.path}/timetrack.exe$replacedSuffix').existsSync(),
      isTrue,
      reason: 'the running exe is only renamed',
    );
    await expectLater(installer.restart(), throwsA(isA<_Quit>()));
    expect(launched, ['${install.path}/timetrack.exe']);

    await installer.cleanUp();
    final left =
        install
            .listSync(recursive: true)
            .map((e) => e.path.substring(install.path.length + 1))
            .toList()
          ..sort();
    expect(left, ['data', 'data/app.so', 'timetrack.exe']);
  });

  test('§5 a failed swap puts the old version back', () async {
    final staged = Directory('${tmp.path}/staged')..createSync();
    File('${staged.path}/timetrack.exe').writeAsStringSync('app 0.6.3');
    // A directory where the new version has a file: the move fails.
    Directory('${staged.path}/data').createSync();
    File('${staged.path}/data/app.so').writeAsStringSync('aot 0.6.3');
    File('${install.path}/data/app.so').deleteSync();
    Directory('${install.path}/data/app.so').createSync();
    File('${install.path}/data/app.so/keep').writeAsStringSync('x');

    await expectLater(swapInFolder(staged, install), throwsA(anything));
    expect(
      File('${install.path}/timetrack.exe').readAsStringSync(),
      'app 0.6.2',
    );
    expect(
      File('${install.path}/timetrack.exe$replacedSuffix').existsSync(),
      isFalse,
    );
  });

  test('§5 a ZIP without the exe is refused', () async {
    final zip = File('${tmp.path}/other.zip')
      ..writeAsBytesSync(
        ZipEncoder().encode(Archive()..addFile(ArchiveFile.string('x', 'y'))),
      );
    await expectLater(installer.install(zip), throwsA(isA<UpdateException>()));
    expect(Directory('${install.path}/.update-new').existsSync(), isFalse);
  });
}

class _Quit implements Exception {
  const _Quit();
}
