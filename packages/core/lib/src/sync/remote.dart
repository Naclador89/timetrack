/// A file or folder in the remote sync folder.
final class RemoteEntry {
  /// Creates an entry.
  const RemoteEntry({
    required this.path,
    required this.etag,
    required this.isDirectory,
  });

  /// Path relative to the sync root, without leading slash, e.g.
  /// `devices/1a2b…/ops/…jsonl.gz.enc`.
  final String path;

  /// The server's ETag. For folders it changes whenever anything inside changes.
  final String etag;

  /// Whether this is a folder.
  final bool isDirectory;

  /// The last path segment.
  String get name => path.split('/').last;
}

/// The remote sync folder (spec: sync-format.md §2, §7). Implemented with
/// WebDAV for Nextcloud and by [InMemoryRemoteFolder] in tests.
///
/// Paths are relative to the sync root; `''` is the root itself.
abstract interface class RemoteFolder {
  /// The entry at [path], or `null` if it doesn't exist (PROPFIND Depth 0).
  Future<RemoteEntry?> stat(String path);

  /// The direct children of folder [path]; empty if the folder doesn't exist
  /// (PROPFIND Depth 1).
  Future<List<RemoteEntry>> list(String path);

  /// The content of file [path], or `null` if it doesn't exist (GET).
  Future<List<int>?> read(String path);

  /// Creates file [path] only if it doesn't exist yet (PUT with
  /// `If-None-Match: *`). Returns `false` if it already existed (412).
  Future<bool> createFile(String path, List<int> bytes);

  /// Creates or replaces file [path] (PUT).
  Future<void> writeFile(String path, List<int> bytes);

  /// Creates folder [path]; does nothing if it exists (MKCOL).
  Future<void> makeDirectory(String path);

  /// Deletes [path]; does nothing if it doesn't exist (DELETE).
  Future<void> delete(String path);
}

/// An in-memory [RemoteFolder] that behaves like Nextcloud: folder ETags
/// change whenever anything below them changes. For tests and simulations.
final class InMemoryRemoteFolder implements RemoteFolder {
  final Map<String, List<int>> _files = {};
  final Set<String> _dirs = {''};
  final Map<String, String> _etags = {'': 'e0'};
  int _version = 0;

  /// All file paths, for assertions in tests.
  Iterable<String> get filePaths => _files.keys;

  /// Raw file content, for assertions in tests.
  List<int>? rawFile(String path) => _files[path];

  /// Replaces raw file content without the normal checks (to simulate damage).
  void tamper(String path, List<int> bytes) {
    _files[path] = bytes;
    _touch(path);
  }

  @override
  Future<RemoteEntry?> stat(String path) async {
    if (_dirs.contains(path)) {
      return RemoteEntry(path: path, etag: _etags[path]!, isDirectory: true);
    }
    if (_files.containsKey(path)) {
      return RemoteEntry(path: path, etag: _etags[path]!, isDirectory: false);
    }
    return null;
  }

  @override
  Future<List<RemoteEntry>> list(String path) async {
    if (!_dirs.contains(path)) return const [];
    final prefix = path.isEmpty ? '' : '$path/';
    bool isChild(String p) =>
        p != path &&
        p.startsWith(prefix) &&
        !p.substring(prefix.length).contains('/');
    return [
      for (final d in _dirs.where(isChild))
        RemoteEntry(path: d, etag: _etags[d]!, isDirectory: true),
      for (final f in _files.keys.where(isChild))
        RemoteEntry(path: f, etag: _etags[f]!, isDirectory: false),
    ];
  }

  @override
  Future<List<int>?> read(String path) async => _files[path];

  @override
  Future<bool> createFile(String path, List<int> bytes) async {
    if (_files.containsKey(path)) return false;
    await writeFile(path, bytes);
    return true;
  }

  @override
  Future<void> writeFile(String path, List<int> bytes) async {
    if (!_dirs.contains(_parent(path))) {
      throw StateError('Parent folder of $path does not exist (409)');
    }
    _files[path] = List.unmodifiable(bytes);
    _touch(path);
  }

  @override
  Future<void> makeDirectory(String path) async {
    if (_dirs.contains(path)) return;
    if (!_dirs.contains(_parent(path))) {
      throw StateError('Parent folder of $path does not exist (409)');
    }
    _dirs.add(path);
    _touch(path);
  }

  @override
  Future<void> delete(String path) async {
    if (_files.remove(path) != null) {
      _etags.remove(path);
      _touch(_parent(path));
    }
  }

  static String _parent(String path) {
    final i = path.lastIndexOf('/');
    return i < 0 ? '' : path.substring(0, i);
  }

  /// New ETag for [path] and every folder above it (like Nextcloud).
  void _touch(String path) {
    final etag = 'e${++_version}';
    for (var p = path; ; p = _parent(p)) {
      _etags[p] = etag;
      if (p.isEmpty) break;
    }
  }
}
