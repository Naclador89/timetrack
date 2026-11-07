import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'remote.dart';

/// A failed WebDAV request (anything but the expected status codes).
final class RemoteException implements Exception {
  /// Creates the exception.
  RemoteException(this.method, this.path, this.statusCode, [this.body = '']);

  /// HTTP method, e.g. `PROPFIND`.
  final String method;

  /// Path relative to the sync root.
  final String path;

  /// HTTP status code.
  final int statusCode;

  /// Response body (truncated), for the sync log.
  final String body;

  /// Whether the credentials were rejected (the app password was revoked).
  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => 'RemoteException: $method $path → $statusCode';
}

/// [RemoteFolder] over WebDAV, as served by Nextcloud
/// (spec: sync-format.md §2, §7).
///
/// [root] is the sync folder's WebDAV URL, e.g.
/// `https://cloud.example.com/remote.php/dav/files/alice/TimeTrack/`.
final class WebDavRemoteFolder implements RemoteFolder {
  /// Creates a client authenticating with [username] and [appPassword].
  WebDavRemoteFolder({
    required Uri root,
    required String username,
    required String appPassword,
    http.Client? client,
  }) : root = root.path.endsWith('/')
           ? root
           : root.replace(path: '${root.path}/'),
       _client = client ?? http.Client(),
       _auth = 'Basic ${base64Encode(utf8.encode('$username:$appPassword'))}';

  /// The sync root URL (always ending in `/`).
  final Uri root;
  final http.Client _client;
  final String _auth;

  static const _propfindBody =
      '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop>'
      '<d:getetag/><d:resourcetype/></d:prop></d:propfind>';

  /// The WebDAV URL of a path relative to the root.
  Uri uriOf(String path) => path.isEmpty
      ? root
      : root.replace(
          path: root.path + path.split('/').map(Uri.encodeComponent).join('/'),
        );

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String> headers = const {},
    List<int>? body,
  }) async {
    final request = http.Request(method, uriOf(path))
      ..headers['Authorization'] = _auth
      ..headers.addAll(headers);
    if (body != null) request.bodyBytes = body;
    return http.Response.fromStream(await _client.send(request));
  }

  Never _fail(String method, String path, http.Response r) =>
      throw RemoteException(
        method,
        path,
        r.statusCode,
        r.body.length > 300 ? r.body.substring(0, 300) : r.body,
      );

  Future<List<RemoteEntry>> _propfind(String path, String depth) async {
    final r = await _send(
      'PROPFIND',
      path,
      headers: {
        'Depth': depth,
        'Content-Type': 'application/xml; charset=utf-8',
      },
      body: utf8.encode(_propfindBody),
    );
    if (r.statusCode == 404) return const [];
    if (r.statusCode != 207) _fail('PROPFIND', path, r);
    return _parseMultistatus(utf8.decode(r.bodyBytes));
  }

  List<RemoteEntry> _parseMultistatus(String body) {
    final doc = XmlDocument.parse(body);
    final rootPath = Uri.decodeComponent(root.path);
    final entries = <RemoteEntry>[];
    for (final response in doc.findAllElements(
      'response',
      namespaceUri: 'DAV:',
    )) {
      final href =
          response.getElement('href', namespaceUri: 'DAV:')?.innerText ?? '';
      var hrefPath = Uri.decodeComponent(Uri.parse(href).path);
      if (!hrefPath.startsWith(rootPath)) {
        if ('$hrefPath/' != rootPath) continue;
        hrefPath = rootPath; // the root itself, reported without the slash
      }
      final relative = hrefPath
          .substring(rootPath.length)
          .replaceAll(RegExp(r'/$'), '');
      final etag = response
          .findAllElements('getetag', namespaceUri: 'DAV:')
          .map((e) => e.innerText)
          .firstOrNull;
      final isDirectory = response
          .findAllElements('collection', namespaceUri: 'DAV:')
          .isNotEmpty;
      entries.add(
        RemoteEntry(path: relative, etag: etag ?? '', isDirectory: isDirectory),
      );
    }
    return entries;
  }

  @override
  Future<RemoteEntry?> stat(String path) async {
    final entries = await _propfind(path, '0');
    return entries.isEmpty ? null : entries.first;
  }

  @override
  Future<List<RemoteEntry>> list(String path) async => [
    for (final e in await _propfind(path, '1'))
      if (e.path != path) e,
  ];

  @override
  Future<List<int>?> read(String path) async {
    final r = await _send('GET', path);
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) _fail('GET', path, r);
    return r.bodyBytes;
  }

  @override
  Future<bool> createFile(String path, List<int> bytes) async {
    final r = await _send(
      'PUT',
      path,
      headers: {
        'If-None-Match': '*',
        'Content-Type': 'application/octet-stream',
      },
      body: bytes,
    );
    if (r.statusCode == 412) return false;
    if (r.statusCode != 201 && r.statusCode != 204) _fail('PUT', path, r);
    return true;
  }

  @override
  Future<void> writeFile(String path, List<int> bytes) async {
    final r = await _send(
      'PUT',
      path,
      headers: {'Content-Type': 'application/octet-stream'},
      body: bytes,
    );
    if (r.statusCode != 201 && r.statusCode != 204) _fail('PUT', path, r);
  }

  @override
  Future<void> makeDirectory(String path) async {
    final r = await _send('MKCOL', path);
    // 405: already exists.
    if (r.statusCode != 201 && r.statusCode != 405) _fail('MKCOL', path, r);
  }

  @override
  Future<void> delete(String path) async {
    final r = await _send('DELETE', path);
    if (r.statusCode != 204 && r.statusCode != 200 && r.statusCode != 404) {
      _fail('DELETE', path, r);
    }
  }
}

/// Credentials returned by Nextcloud Login Flow v2.
final class NextcloudCredentials {
  /// Creates credentials.
  const NextcloudCredentials({
    required this.server,
    required this.loginName,
    required this.appPassword,
  });

  /// Server base URL as reported by Nextcloud.
  final Uri server;

  /// The user's login name (used in WebDAV URLs and Basic auth).
  final String loginName;

  /// A per-device app password; never store it in the database.
  final String appPassword;

  /// The WebDAV URL of [folder] in the user's files.
  Uri webDavRoot([String folder = 'TimeTrack']) => server.replace(
    path:
        '${server.path.replaceAll(RegExp(r'/$'), '')}/remote.php/dav/files/'
        '${Uri.encodeComponent(loginName)}/${Uri.encodeComponent(folder)}/',
  );
}

/// A started Login Flow v2: open [loginUrl] in a browser, then [poll].
final class LoginFlow {
  LoginFlow._(this.loginUrl, this._endpoint, this._token, this._client);

  /// Starts the flow on [server] (e.g. `https://cloud.example.com`)
  /// (Nextcloud docs: "Login Flow v2").
  static Future<LoginFlow> start(Uri server, {http.Client? client}) async {
    final c = client ?? http.Client();
    final base = server.path.endsWith('/')
        ? server
        : server.replace(path: '${server.path}/');
    final r = await c.post(
      base.resolve('index.php/login/v2'),
      headers: {'User-Agent': 'TimeTrack'},
    );
    if (r.statusCode != 200) {
      throw RemoteException('POST', 'index.php/login/v2', r.statusCode, r.body);
    }
    final json = jsonDecode(r.body) as Map<String, Object?>;
    final poll = (json['poll']! as Map).cast<String, Object?>();
    return LoginFlow._(
      Uri.parse(json['login']! as String),
      Uri.parse(poll['endpoint']! as String),
      poll['token']! as String,
      c,
    );
  }

  /// The page the user approves the login on.
  final Uri loginUrl;
  final Uri _endpoint;
  final String _token;
  final http.Client _client;

  /// Checks once whether the user has approved; `null` while still pending.
  Future<NextcloudCredentials?> poll() async {
    final r = await _client.post(_endpoint, body: {'token': _token});
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) {
      throw RemoteException('POST', _endpoint.path, r.statusCode, r.body);
    }
    final json = jsonDecode(r.body) as Map<String, Object?>;
    return NextcloudCredentials(
      server: Uri.parse(json['server']! as String),
      loginName: json['loginName']! as String,
      appPassword: json['appPassword']! as String,
    );
  }

  /// Polls until the user has approved the login, and returns the
  /// credentials; `null` if [cancelled] returns true or the flow expired.
  ///
  /// Built for mobile: Android freezes apps in the background while the user
  /// is in the browser, which can leave a request hanging on a dead
  /// connection. So every poll has a [requestTimeout], network errors only
  /// lead to the next attempt, the deadline is wall-clock time ([expiry],
  /// Nextcloud tokens live 20 minutes), and [wakeUp] (e.g. "app resumed")
  /// triggers an immediate poll instead of waiting for [interval].
  Future<NextcloudCredentials?> waitForApproval({
    Duration interval = const Duration(seconds: 2),
    Duration requestTimeout = const Duration(seconds: 10),
    Duration expiry = const Duration(minutes: 20),
    Stream<void>? wakeUp,
    bool Function()? cancelled,
  }) async {
    final deadline = DateTime.now().add(expiry);
    final wake = StreamController<void>.broadcast();
    final subscription = wakeUp?.listen(wake.add);
    try {
      while (DateTime.now().isBefore(deadline) &&
          !(cancelled?.call() ?? false)) {
        try {
          final credentials = await poll().timeout(requestTimeout);
          if (credentials != null) return credentials;
        } on TimeoutException {
          // Hanging request (frozen app, dead connection): just poll again.
        } on Exception {
          // Network hiccup or a transient server error: retry until the deadline.
        }
        await Future.any([Future<void>.delayed(interval), wake.stream.first]);
      }
      return null;
    } finally {
      await subscription?.cancel();
      await wake.close();
    }
  }
}
