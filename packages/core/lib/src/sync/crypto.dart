import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Thrown when the passphrase is wrong or a file was damaged or tampered with.
final class SyncCryptoException implements Exception {
  /// Creates the exception.
  SyncCryptoException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'SyncCryptoException: $message';
}

const _magic = [0x54, 0x54, 0x45, 0x31]; // "TTE1"
const _nonceLength = 12;
const _macLength = 16;
const _keyCheckPlaintext = 'timetrack-key-check-v1';
const _keyCheckAad = 'format.json';

/// Key-derivation parameters and key check stored in `format.json`
/// (spec: sync-format.md §10).
final class EncryptionParams {
  /// Creates parameters.
  const EncryptionParams({
    required this.salt,
    required this.keyCheck,
    this.memoryKiB = 65536,
    this.iterations = 3,
    this.parallelism = 1,
  });

  /// Reads the `encryption` object of `format.json`.
  factory EncryptionParams.fromJson(Map<String, Object?> json) {
    if (json['kdf'] != 'argon2id') {
      throw SyncCryptoException('Unsupported KDF ${json['kdf']}');
    }
    return EncryptionParams(
      salt: base64Decode(json['salt']! as String),
      keyCheck: base64Decode(json['keyCheck']! as String),
      memoryKiB: json['memoryKiB']! as int,
      iterations: json['iterations']! as int,
      parallelism: json['parallelism']! as int,
    );
  }

  /// Random 16-byte salt.
  final List<int> salt;

  /// The encrypted check value used to verify a passphrase.
  final List<int> keyCheck;

  /// Argon2id memory in KiB.
  final int memoryKiB;

  /// Argon2id iterations.
  final int iterations;

  /// Argon2id parallelism.
  final int parallelism;

  /// The `encryption` object for `format.json`.
  Map<String, Object?> toJson() => {
    'kdf': 'argon2id',
    'salt': base64Encode(salt),
    'memoryKiB': memoryKiB,
    'iterations': iterations,
    'parallelism': parallelism,
    'keyCheck': base64Encode(keyCheck),
  };
}

/// Encrypts and decrypts sync files with one derived key (spec: sync-format.md §10).
final class SyncCipher {
  /// Creates a cipher for a 32-byte [key] (as returned by [createEncryption]
  /// or [unlockEncryption], or loaded from secure storage).
  SyncCipher(this.key);

  /// The derived key. Store its bytes in secure storage, never in the database.
  final SecretKey key;

  static final _aes = AesGcm.with256bits();

  /// Encrypts [plaintext], binding it to [path] (the AAD).
  Future<List<int>> seal(List<int> plaintext, String path) async {
    final box = await _aes.encrypt(
      plaintext,
      secretKey: key,
      nonce: _aes.newNonce(),
      aad: utf8.encode(path),
    );
    return [..._magic, ...box.nonce, ...box.cipherText, ...box.mac.bytes];
  }

  /// Decrypts a file sealed for [path]. Throws [SyncCryptoException] if the
  /// key is wrong or the data was changed.
  Future<List<int>> open(List<int> sealed, String path) async {
    const header = 4 + _nonceLength;
    if (sealed.length < header + _macLength || !_startsWithMagic(sealed)) {
      throw SyncCryptoException('Not an encrypted TimeTrack file: $path');
    }
    final box = SecretBox(
      sealed.sublist(header, sealed.length - _macLength),
      nonce: sealed.sublist(4, header),
      mac: Mac(sealed.sublist(sealed.length - _macLength)),
    );
    try {
      return await _aes.decrypt(box, secretKey: key, aad: utf8.encode(path));
    } on SecretBoxAuthenticationError {
      throw SyncCryptoException('Wrong passphrase or damaged file: $path');
    }
  }

  static bool _startsWithMagic(List<int> bytes) {
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return false;
    }
    return true;
  }
}

Future<SecretKey> _derive(String passphrase, EncryptionParams p) => Argon2id(
  parallelism: p.parallelism,
  memory: p.memoryKiB,
  iterations: p.iterations,
  hashLength: 32,
).deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: p.salt);

/// Sets up encryption on the first device: random salt, derived key and key
/// check (spec: sync-format.md §10). Lower [memoryKiB]/[iterations] only in tests.
Future<(EncryptionParams, SyncCipher)> createEncryption(
  String passphrase, {
  int memoryKiB = 65536,
  int iterations = 3,
  Random? random,
}) async {
  final r = random ?? Random.secure();
  final draft = EncryptionParams(
    salt: List.generate(16, (_) => r.nextInt(256)),
    keyCheck: const [],
    memoryKiB: memoryKiB,
    iterations: iterations,
  );
  final cipher = SyncCipher(await _derive(passphrase, draft));
  final check = await cipher.seal(
    utf8.encode(_keyCheckPlaintext),
    _keyCheckAad,
  );
  return (
    EncryptionParams(
      salt: draft.salt,
      keyCheck: check,
      memoryKiB: memoryKiB,
      iterations: iterations,
      parallelism: draft.parallelism,
    ),
    cipher,
  );
}

/// Derives the key on a further device and checks it against the key check.
/// Throws [SyncCryptoException] for a wrong passphrase.
Future<SyncCipher> unlockEncryption(
  String passphrase,
  EncryptionParams params,
) async {
  final cipher = SyncCipher(await _derive(passphrase, params));
  final plain = await cipher.open(params.keyCheck, _keyCheckAad);
  if (utf8.decode(plain) != _keyCheckPlaintext) {
    throw SyncCryptoException('Key check failed');
  }
  return cipher;
}
