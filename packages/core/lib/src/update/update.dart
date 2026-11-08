import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import '../sync/store.dart';

/// Where the app looks for releases (spec: updates.md §1).
final latestReleaseUrl = Uri.parse(
  'https://api.github.com/repos/Naclador89/timetrack/releases/latest',
);

/// A `major.minor.patch` version (spec: updates.md §2).
final class AppVersion implements Comparable<AppVersion> {
  /// Creates a version.
  const AppVersion(this.major, this.minor, this.patch);

  /// Reads `0.4.0`, `v0.4.0` or `0.4.0+5`; `null` if it isn't three numbers.
  static AppVersion? tryParse(String text) {
    final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(\+\d+)?$')
        .firstMatch(text.trim());
    if (m == null) return null;
    return AppVersion(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  /// The parts.
  final int major, minor, patch;

  @override
  int compareTo(AppVersion other) => major != other.major
      ? major.compareTo(other.major)
      : minor != other.minor
      ? minor.compareTo(other.minor)
      : patch.compareTo(other.patch);

  /// Whether this is newer than [other].
  bool isNewerThan(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

/// The platforms with a release build, and their asset names
/// (spec: updates.md §1).
enum UpdatePlatform {
  /// The APK.
  android('timetrack-android.apk'),

  /// The tar.gz with `bundle/`.
  linux('timetrack-linux-x64.tar.gz'),

  /// The portable ZIP.
  windows('timetrack-windows-x64.zip');

  const UpdatePlatform(this.assetName);

  /// The release file for this platform.
  final String assetName;

  /// The platform for `Platform.operatingSystem`, or `null` (no builds).
  static UpdatePlatform? of(String operatingSystem) =>
      values.asNameMap()[operatingSystem];
}

/// Name of the checksum file of a release.
const checksumsAssetName = 'SHA256SUMS';

/// One downloadable file of a release.
final class ReleaseAsset {
  /// Creates an asset.
  const ReleaseAsset({required this.name, required this.url, this.size = 0});

  /// File name.
  final String name;

  /// Download URL.
  final Uri url;

  /// Size in bytes (0 = unknown).
  final int size;
}

/// A published release (spec: updates.md §1).
final class Release {
  /// Creates a release.
  const Release({
    required this.version,
    required this.page,
    required this.assets,
    this.notes = '',
  });

  /// Reads the GitHub API form; `null` for drafts, pre-releases and tags
  /// that aren't a version.
  static Release? fromGitHub(Map<String, Object?> json) {
    if (json['draft'] == true || json['prerelease'] == true) return null;
    final version = AppVersion.tryParse(json['tag_name'] as String? ?? '');
    if (version == null) return null;
    return Release(
      version: version,
      page: Uri.parse(json['html_url'] as String? ?? ''),
      notes: json['body'] as String? ?? '',
      assets: [
        for (final a in (json['assets'] as List?) ?? const [])
          if (a case {
            'name': final String name,
            'browser_download_url': final String url,
          })
            ReleaseAsset(
              name: name,
              url: Uri.parse(url),
              size: (a['size'] as int?) ?? 0,
            ),
      ],
    );
  }

  /// The version.
  final AppVersion version;

  /// The release page (fallback when the app can't install itself).
  final Uri page;

  /// Release notes (Markdown).
  final String notes;

  /// Its files.
  final List<ReleaseAsset> assets;

  /// The file named [name], or `null`.
  ReleaseAsset? asset(String name) =>
      assets.where((a) => a.name == name).firstOrNull;

  /// Whether it can be installed on [platform]: its build and the checksums
  /// are attached.
  bool supports(UpdatePlatform platform) =>
      asset(platform.assetName) != null && asset(checksumsAssetName) != null;
}

/// The newest release, or `null` if there is none (404) or it isn't one
/// the app understands. Throws on network and server errors.
Future<Release?> fetchLatestRelease(http.Client client, {Uri? url}) async {
  final response = await client
      .get(
        url ?? latestReleaseUrl,
        headers: const {'Accept': 'application/vnd.github+json'},
      )
      .timeout(const Duration(seconds: 20));
  if (response.statusCode == 404) return null;
  if (response.statusCode != 200) {
    throw http.ClientException(
      'GitHub answered ${response.statusCode}',
      url ?? latestReleaseUrl,
    );
  }
  final json = jsonDecode(response.body);
  return json is Map<String, Object?> ? Release.fromGitHub(json) : null;
}

/// Reads a `sha256sum` file: file name → lowercase hex digest.
Map<String, String> parseSha256Sums(String text) => {
  for (final line in const LineSplitter().convert(text))
    if (RegExp(r'^([0-9a-fA-F]{64})\s+\*?(.+)$').firstMatch(line.trim())
        case final m?)
      m[2]!.trim(): m[1]!.toLowerCase(),
};

/// The SHA-256 of [chunks] as lowercase hex, without holding the whole file
/// in memory.
Future<String> sha256Hex(Stream<List<int>> chunks) async {
  final sink = Sha256().newHashSink();
  await for (final c in chunks) {
    sink.add(c);
  }
  sink.close();
  final hash = await sink.hash();
  return [for (final b in hash.bytes) b.toRadixString(16).padLeft(2, '0')]
      .join();
}

/// What the device remembers about updates (spec: updates.md §3).
final class UpdateState {
  /// Creates a state.
  const UpdateState({
    this.checked,
    this.auto = true,
    this.skipped,
    this.notified,
  });

  /// Reads the stored form; a damaged value reads as the default.
  factory UpdateState.decode(String? raw) {
    if (raw == null) return const UpdateState();
    try {
      final j = jsonDecode(raw) as Map<String, Object?>;
      return UpdateState(
        checked: j['checked'] == null
            ? null
            : DateTime.parse(j['checked']! as String),
        auto: j['auto'] as bool? ?? true,
        skipped: AppVersion.tryParse(j['skipped'] as String? ?? ''),
        notified: AppVersion.tryParse(j['notified'] as String? ?? ''),
      );
    } on Object {
      return const UpdateState();
    }
  }

  /// The last successful check (UTC).
  final DateTime? checked;

  /// Whether the app checks by itself.
  final bool auto;

  /// The version the user chose to skip.
  final AppVersion? skipped;

  /// The newest version a system notification was shown for.
  final AppVersion? notified;

  /// A copy with the given fields changed.
  UpdateState copyWith({
    DateTime? checked,
    bool? auto,
    AppVersion? skipped,
    AppVersion? notified,
  }) => UpdateState(
    checked: checked ?? this.checked,
    auto: auto ?? this.auto,
    skipped: skipped ?? this.skipped,
    notified: notified ?? this.notified,
  );

  /// The stored form.
  String encode() => jsonEncode({
    if (checked != null) 'checked': checked!.toUtc().toIso8601String(),
    'auto': auto,
    if (skipped != null) 'skipped': '$skipped',
    if (notified != null) 'notified': '$notified',
  });
}

/// Decides when to check and what to offer (spec: updates.md §3).
final class UpdateChecker {
  /// Creates the checker. [fetch] returns the newest release (see
  /// [fetchLatestRelease]); [now] is replaced in tests.
  UpdateChecker({
    required this.store,
    required this.installed,
    required this.platform,
    required this.fetch,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  /// Where the [UpdateState] is kept.
  final SyncStore store;

  /// The running version.
  final AppVersion installed;

  /// This device's platform.
  final UpdatePlatform platform;

  /// Reads the newest release.
  final Future<Release?> Function() fetch;

  /// The clock.
  final DateTime Function() now;

  /// The `local_values` key of the [UpdateState].
  static const stateKey = 'update_state';

  /// How often the automatic check runs.
  static const interval = Duration(hours: 24);

  /// The stored state.
  Future<UpdateState> state() => store.transaction(
    (tx) async => UpdateState.decode(await tx.localValue(stateKey)),
  );

  Future<UpdateState> _change(UpdateState Function(UpdateState) f) =>
      store.transaction((tx) async {
        final next = f(UpdateState.decode(await tx.localValue(stateKey)));
        await tx.setLocalValue(stateKey, next.encode());
        return next;
      });

  /// Turns the automatic check on or off.
  Future<void> setAuto(bool on) => _change((s) => s.copyWith(auto: on));

  /// Don't offer [version] again automatically.
  Future<void> skip(AppVersion version) =>
      _change((s) => s.copyWith(skipped: version));

  /// The release to offer, or `null`. With [manual] the 24-h pause, the
  /// automatic switch and a skipped version don't apply, and errors are
  /// thrown instead of swallowed.
  Future<Release?> check({bool manual = false}) async {
    final before = await state();
    if (!manual) {
      if (!before.auto) return null;
      final last = before.checked;
      if (last != null && now().difference(last) < interval) return null;
    }
    final Release? latest;
    try {
      latest = await fetch();
    } on Object {
      if (manual) rethrow;
      return null; // The next start or resume tries again.
    }
    await _change((s) => s.copyWith(checked: now().toUtc()));
    if (latest == null ||
        !latest.version.isNewerThan(installed) ||
        !latest.supports(platform)) {
      return null;
    }
    if (!manual && before.skipped == latest.version) return null;
    return latest;
  }

  /// Whether the system notification for [release] is still due; marks it
  /// shown (once per version, §4).
  Future<bool> takeNotification(Release release) async {
    var due = false;
    await _change((s) {
      final last = s.notified;
      due = last == null || release.version.isNewerThan(last);
      return due ? s.copyWith(notified: release.version) : s;
    });
    return due;
  }
}
