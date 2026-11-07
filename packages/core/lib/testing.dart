/// Test helpers: a simulated Nextcloud WebDAV server for widget and unit
/// tests. Not part of the app; import `package:timetrack_core/testing.dart`.
library;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'src/sync/remote.dart';

/// A tiny Nextcloud-like WebDAV server backed by [files], for tests: serves
/// PROPFIND (Depth 0/1, ETags, collections), GET, PUT (with `If-None-Match`),
/// MKCOL and DELETE under [davRoot], and answers 401 unless the
/// `Authorization` header equals [auth] (default `alice:secret`).
MockClient fakeNextcloud(
  InMemoryRemoteFolder files, {
  String davRoot = '/remote.php/dav/files/alice/TimeTrack/',
  String auth = 'Basic YWxpY2U6c2VjcmV0',
  List<String>? log,
}) => MockClient((request) async {
  log?.add('${request.method} ${request.url.path}');
  if (request.headers['Authorization'] != auth) return http.Response('', 401);
  final decoded = Uri.decodeComponent(request.url.path);
  if (!decoded.startsWith(davRoot.substring(0, davRoot.length - 1))) {
    return http.Response('', 404);
  }
  final path = decoded.length <= davRoot.length
      ? ''
      : decoded.substring(davRoot.length).replaceAll(RegExp(r'/$'), '');
  switch (request.method) {
    case 'PROPFIND':
      final self = await files.stat(path);
      if (self == null) return http.Response('', 404);
      final entries = [
        self,
        if (request.headers['Depth'] == '1' && self.isDirectory)
          ...await files.list(path),
      ];
      String href(RemoteEntry e) => Uri.encodeFull(
        davRoot + e.path + (e.isDirectory && e.path.isNotEmpty ? '/' : ''),
      );
      final xml = StringBuffer(
        '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">',
      );
      for (final e in entries) {
        xml.write(
          '<d:response><d:href>${href(e)}</d:href><d:propstat><d:prop>'
          '<d:getetag>&quot;${e.etag}&quot;</d:getetag>'
          '<d:resourcetype>${e.isDirectory ? '<d:collection/>' : ''}</d:resourcetype>'
          '</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>',
        );
      }
      xml.write('</d:multistatus>');
      return http.Response(xml.toString(), 207);
    case 'GET':
      final bytes = await files.read(path);
      return bytes == null
          ? http.Response('', 404)
          : http.Response.bytes(bytes, 200);
    case 'PUT':
      try {
        if (request.headers['If-None-Match'] == '*') {
          return http.Response(
            '',
            await files.createFile(path, request.bodyBytes) ? 201 : 412,
          );
        }
        final existed = await files.stat(path) != null;
        await files.writeFile(path, request.bodyBytes);
        return http.Response('', existed ? 204 : 201);
      } on StateError {
        return http.Response('', 409);
      }
    case 'MKCOL':
      if (await files.stat(path) != null) return http.Response('', 405);
      try {
        await files.makeDirectory(path);
        return http.Response('', 201);
      } on StateError {
        return http.Response('', 409);
      }
    case 'DELETE':
      if (await files.stat(path) == null) return http.Response('', 404);
      await files.delete(path);
      return http.Response('', 204);
  }
  return http.Response('', 405);
});
