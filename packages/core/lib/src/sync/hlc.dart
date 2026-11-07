import 'dart:math';

/// A hybrid logical clock timestamp (spec: sync-format.md §3).
///
/// Its string form `<ms>-<counter>-<deviceId>` has fixed widths, so comparing
/// strings gives the same order as comparing clocks.
final class Hlc implements Comparable<Hlc> {
  /// Creates a timestamp. [deviceId] must be 16 lowercase hex characters.
  Hlc(this.millis, this.counter, this.deviceId) {
    if (millis < 0 || millis > 9999999999999) {
      throw ArgumentError.value(millis, 'millis', 'Needs 13 digits');
    }
    if (counter < 0 || counter > 0xffff) {
      throw ArgumentError.value(counter, 'counter', 'Needs 0..ffff');
    }
    if (!_deviceIdPattern.hasMatch(deviceId)) {
      throw ArgumentError.value(deviceId, 'deviceId', 'Needs 16 hex chars');
    }
  }

  /// Parses the string form, e.g. `1794067200123-0000-1a2b3c4d5e6f7081`.
  factory Hlc.parse(String text) {
    final m = RegExp(r'^(\d{13})-([0-9a-f]{4})-([0-9a-f]{16})$')
        .firstMatch(text);
    if (m == null) throw FormatException('Not an HLC', text);
    return Hlc(int.parse(m[1]!), int.parse(m[2]!, radix: 16), m[3]!);
  }

  static final _deviceIdPattern = RegExp(r'^[0-9a-f]{16}$');

  /// Wall-clock part, Unix milliseconds.
  final int millis;

  /// Logical counter for events within the same millisecond.
  final int counter;

  /// The device that created the timestamp; breaks ties.
  final String deviceId;

  @override
  int compareTo(Hlc other) => toString().compareTo(other.toString());

  /// Whether this timestamp is later than [other].
  bool isAfter(Hlc other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is Hlc && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() =>
      '${millis.toString().padLeft(13, '0')}-'
      '${counter.toRadixString(16).padLeft(4, '0')}-$deviceId';
}

/// Creates a random device id: 16 lowercase hex characters (spec: sync-format.md §2).
String newDeviceId([Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
}

/// The local hybrid logical clock of one device (spec: sync-format.md §3).
///
/// Persist [last] after every [tick] or [receive], so the clock never goes
/// backwards across restarts.
final class HlcClock {
  /// Creates a clock for [deviceId], continuing from [last] if given.
  /// [now] returns the wall clock in Unix milliseconds (injectable for tests).
  HlcClock(this.deviceId, {Hlc? last, int Function()? now})
    : _now = now ?? _systemMillis,
      _millis = last?.millis ?? 0,
      _counter = last?.counter ?? 0;

  /// This device's id.
  final String deviceId;
  final int Function() _now;
  int _millis;
  int _counter;

  static int _systemMillis() => DateTime.now().millisecondsSinceEpoch;

  /// The latest timestamp issued or seen.
  Hlc get last => Hlc(_millis, _counter, deviceId);

  /// A new timestamp for a local event, later than everything seen so far.
  Hlc tick() {
    final pt = _now();
    if (pt > _millis) {
      _millis = pt;
      _counter = 0;
    } else {
      _increment();
    }
    return last;
  }

  /// Merges a timestamp received from another device.
  void receive(Hlc remote) {
    final pt = _now();
    if (pt > _millis && pt > remote.millis) {
      _millis = pt;
      _counter = 0;
    } else if (_millis == remote.millis) {
      _counter = max(_counter, remote.counter);
      _increment();
    } else if (_millis > remote.millis) {
      _increment();
    } else {
      _millis = remote.millis;
      _counter = remote.counter;
      _increment();
    }
  }

  void _increment() {
    if (_counter == 0xffff) {
      _millis++;
      _counter = 0;
    } else {
      _counter++;
    }
  }
}
