// spec: updates.md
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

Map<String, Object?> githubRelease(
  String tag, {
  bool prerelease = false,
  List<String> assets = const [
    'timetrack-android.apk',
    'timetrack-linux-x64.tar.gz',
    'timetrack-windows-x64.zip',
    'SHA256SUMS',
  ],
}) => {
  'tag_name': tag,
  'html_url': 'https://github.com/Naclador89/timetrack/releases/tag/$tag',
  'body': 'Neu: Updates',
  'draft': false,
  'prerelease': prerelease,
  'assets': [
    for (final a in assets)
      {
        'name': a,
        'browser_download_url':
            'https://github.com/Naclador89/timetrack/releases/download/$tag/$a',
        'size': 42,
      },
  ],
};

void main() {
  test('§2 versions compare as numbers; build numbers and v are ignored', () {
    final v = AppVersion.tryParse;
    expect(v('0.10.0')!.isNewerThan(v('0.9.0')!), isTrue);
    expect(v('v0.4.0'), v('0.4.0+5'));
    expect(v('1.0.0')!.isNewerThan(v('0.99.99')!), isTrue);
    expect(v('0.4.0')!.isNewerThan(v('0.4.0')!), isFalse);
    expect(v('0.4'), isNull);
    expect(v('nightly'), isNull);
    expect('${v('v1.2.3')}', '1.2.3');
  });

  test('§1 a release needs the platform build and SHA256SUMS; pre-releases are ignored', () {
    final full = Release.fromGitHub(githubRelease('v0.4.0'))!;
    expect(full.version, const AppVersion(0, 4, 0));
    expect(full.supports(UpdatePlatform.android), isTrue);
    expect(
      full.asset('timetrack-android.apk')!.url.path,
      '/Naclador89/timetrack/releases/download/v0.4.0/timetrack-android.apk',
    );
    final old = Release.fromGitHub(
      githubRelease('v0.3.0', assets: ['timetrack-android.apk']),
    )!;
    expect(
      old.supports(UpdatePlatform.android),
      isFalse,
      reason: 'no checksums',
    );
    expect(
      Release.fromGitHub(githubRelease('v0.5.0', prerelease: true)),
      isNull,
    );
    expect(Release.fromGitHub(githubRelease('latest')), isNull);
    expect(UpdatePlatform.of('linux'), UpdatePlatform.linux);
    expect(UpdatePlatform.of('macos'), isNull);
  });

  test('§1 fetching: 404 means no release, other errors throw', () async {
    final ok = MockClient(
      (_) async => http.Response(jsonEncode(githubRelease('v0.4.0')), 200),
    );
    expect((await fetchLatestRelease(ok))!.version, const AppVersion(0, 4, 0));
    expect(
      await fetchLatestRelease(MockClient((_) async => http.Response('', 404))),
      isNull,
    );
    expect(
      () => fetchLatestRelease(MockClient((_) async => http.Response('', 504))),
      throwsA(isA<http.ClientException>()),
    );
  });

  test('§5 checksums: sha256sum format, streamed digest', () async {
    final sums = parseSha256Sums(
      '${'A' * 64}  timetrack-android.apk\n'
      '${'b' * 64} *timetrack-windows-x64.zip\n'
      'garbage\n',
    );
    expect(sums, {
      'timetrack-android.apk': 'a' * 64,
      'timetrack-windows-x64.zip': 'b' * 64,
    });
    expect(
      await sha256Hex(
        Stream.fromIterable([utf8.encode('ab'), utf8.encode('c')]),
      ),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  group('§3 when to check', () {
    late DateTime now;
    late int fetches;
    late Object? Function() answer;
    UpdateChecker checker(SyncStore store) => UpdateChecker(
      store: store,
      installed: const AppVersion(0, 4, 0),
      platform: UpdatePlatform.linux,
      now: () => now,
      fetch: () async {
        fetches++;
        final a = answer();
        if (a is Exception) throw a;
        return a as Release?;
      },
    );

    setUp(() {
      now = DateTime.utc(2026, 11, 8, 10);
      fetches = 0;
      answer = () => Release.fromGitHub(githubRelease('v0.4.1'));
    });

    test('at most once per 24 h; a manual check any time', () async {
      final c = checker(InMemorySyncStore());
      expect((await c.check())!.version, const AppVersion(0, 4, 1));
      now = now.add(const Duration(hours: 23));
      expect(await c.check(), isNull);
      expect(fetches, 1);
      expect(await c.check(manual: true), isNotNull);
      now = now.add(const Duration(hours: 25));
      expect(await c.check(), isNotNull);
      expect(fetches, 3);
    });

    test('only newer versions; a skipped one only by hand', () async {
      final c = checker(InMemorySyncStore());
      answer = () => Release.fromGitHub(githubRelease('v0.4.0'));
      expect(await c.check(manual: true), isNull, reason: 'same version');
      answer = () => Release.fromGitHub(githubRelease('v0.4.1'));
      await c.skip(const AppVersion(0, 4, 1));
      expect(await c.check(), isNull);
      expect(await c.check(manual: true), isNotNull);
      answer = () => Release.fromGitHub(githubRelease('v0.4.2'));
      now = now.add(const Duration(days: 2));
      expect((await c.check())!.version, const AppVersion(0, 4, 2));
    });

    test('turned off: no automatic check, no request', () async {
      final c = checker(InMemorySyncStore());
      await c.setAuto(false);
      expect(await c.check(), isNull);
      expect(fetches, 0);
      expect((await c.state()).auto, isFalse);
    });

    test('errors: silent automatically, thrown by hand, and retried', () async {
      final c = checker(InMemorySyncStore());
      answer = () => Exception('offline');
      expect(await c.check(), isNull);
      expect(
        (await c.state()).checked,
        isNull,
        reason: 'a failed check retries',
      );
      await expectLater(c.check(manual: true), throwsException);
      answer = () => Release.fromGitHub(githubRelease('v0.4.1'));
      expect(await c.check(), isNotNull);
    });

    test('§4 the system notification comes once per version', () async {
      final c = checker(InMemorySyncStore());
      final r = (await c.check())!;
      expect(await c.takeNotification(r), isTrue);
      expect(await c.takeNotification(r), isFalse);
      final newer = Release.fromGitHub(githubRelease('v0.4.2'))!;
      expect(await c.takeNotification(newer), isTrue);
    });
  });

  test('§3 a damaged state reads as the default', () {
    expect(UpdateState.decode('{nope').auto, isTrue);
    final s = UpdateState.decode(
      const UpdateState(auto: false, skipped: AppVersion(1, 2, 3)).encode(),
    );
    expect((s.auto, s.skipped), (false, const AppVersion(1, 2, 3)));
  });
}
