// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SyncedRowsTable extends SyncedRows
    with TableInfo<$SyncedRowsTable, SyncedRowData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncedRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tblMeta = const VerificationMeta('tbl');
  @override
  late final GeneratedColumn<String> tbl = GeneratedColumn<String>(
    'tbl',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldsMeta = const VerificationMeta('fields');
  @override
  late final GeneratedColumn<String> fields = GeneratedColumn<String>(
    'fields',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldClockMeta = const VerificationMeta(
    'fieldClock',
  );
  @override
  late final GeneratedColumn<String> fieldClock = GeneratedColumn<String>(
    'field_clock',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [tbl, rowId, fields, fieldClock];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'synced_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncedRowData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tbl')) {
      context.handle(
        _tblMeta,
        tbl.isAcceptableOrUnknown(data['tbl']!, _tblMeta),
      );
    } else if (isInserting) {
      context.missing(_tblMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('fields')) {
      context.handle(
        _fieldsMeta,
        fields.isAcceptableOrUnknown(data['fields']!, _fieldsMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldsMeta);
    }
    if (data.containsKey('field_clock')) {
      context.handle(
        _fieldClockMeta,
        fieldClock.isAcceptableOrUnknown(data['field_clock']!, _fieldClockMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldClockMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tbl, rowId};
  @override
  SyncedRowData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncedRowData(
      tbl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tbl'],
      )!,
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      fields: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fields'],
      )!,
      fieldClock: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_clock'],
      )!,
    );
  }

  @override
  $SyncedRowsTable createAlias(String alias) {
    return $SyncedRowsTable(attachedDatabase, alias);
  }
}

class SyncedRowData extends DataClass implements Insertable<SyncedRowData> {
  /// Synced table name, e.g. `work_sessions`.
  final String tbl;

  /// Row id (UUIDv7, or the key for `settings`).
  final String rowId;

  /// JSON object of field values.
  final String fields;

  /// JSON object `field → HLC` of the last applied write per field.
  final String fieldClock;
  const SyncedRowData({
    required this.tbl,
    required this.rowId,
    required this.fields,
    required this.fieldClock,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tbl'] = Variable<String>(tbl);
    map['row_id'] = Variable<String>(rowId);
    map['fields'] = Variable<String>(fields);
    map['field_clock'] = Variable<String>(fieldClock);
    return map;
  }

  SyncedRowsCompanion toCompanion(bool nullToAbsent) {
    return SyncedRowsCompanion(
      tbl: Value(tbl),
      rowId: Value(rowId),
      fields: Value(fields),
      fieldClock: Value(fieldClock),
    );
  }

  factory SyncedRowData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncedRowData(
      tbl: serializer.fromJson<String>(json['tbl']),
      rowId: serializer.fromJson<String>(json['rowId']),
      fields: serializer.fromJson<String>(json['fields']),
      fieldClock: serializer.fromJson<String>(json['fieldClock']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tbl': serializer.toJson<String>(tbl),
      'rowId': serializer.toJson<String>(rowId),
      'fields': serializer.toJson<String>(fields),
      'fieldClock': serializer.toJson<String>(fieldClock),
    };
  }

  SyncedRowData copyWith({
    String? tbl,
    String? rowId,
    String? fields,
    String? fieldClock,
  }) => SyncedRowData(
    tbl: tbl ?? this.tbl,
    rowId: rowId ?? this.rowId,
    fields: fields ?? this.fields,
    fieldClock: fieldClock ?? this.fieldClock,
  );
  SyncedRowData copyWithCompanion(SyncedRowsCompanion data) {
    return SyncedRowData(
      tbl: data.tbl.present ? data.tbl.value : this.tbl,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      fields: data.fields.present ? data.fields.value : this.fields,
      fieldClock: data.fieldClock.present
          ? data.fieldClock.value
          : this.fieldClock,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncedRowData(')
          ..write('tbl: $tbl, ')
          ..write('rowId: $rowId, ')
          ..write('fields: $fields, ')
          ..write('fieldClock: $fieldClock')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tbl, rowId, fields, fieldClock);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncedRowData &&
          other.tbl == this.tbl &&
          other.rowId == this.rowId &&
          other.fields == this.fields &&
          other.fieldClock == this.fieldClock);
}

class SyncedRowsCompanion extends UpdateCompanion<SyncedRowData> {
  final Value<String> tbl;
  final Value<String> rowId;
  final Value<String> fields;
  final Value<String> fieldClock;
  final Value<int> rowid;
  const SyncedRowsCompanion({
    this.tbl = const Value.absent(),
    this.rowId = const Value.absent(),
    this.fields = const Value.absent(),
    this.fieldClock = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncedRowsCompanion.insert({
    required String tbl,
    required String rowId,
    required String fields,
    required String fieldClock,
    this.rowid = const Value.absent(),
  }) : tbl = Value(tbl),
       rowId = Value(rowId),
       fields = Value(fields),
       fieldClock = Value(fieldClock);
  static Insertable<SyncedRowData> custom({
    Expression<String>? tbl,
    Expression<String>? rowId,
    Expression<String>? fields,
    Expression<String>? fieldClock,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tbl != null) 'tbl': tbl,
      if (rowId != null) 'row_id': rowId,
      if (fields != null) 'fields': fields,
      if (fieldClock != null) 'field_clock': fieldClock,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncedRowsCompanion copyWith({
    Value<String>? tbl,
    Value<String>? rowId,
    Value<String>? fields,
    Value<String>? fieldClock,
    Value<int>? rowid,
  }) {
    return SyncedRowsCompanion(
      tbl: tbl ?? this.tbl,
      rowId: rowId ?? this.rowId,
      fields: fields ?? this.fields,
      fieldClock: fieldClock ?? this.fieldClock,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tbl.present) {
      map['tbl'] = Variable<String>(tbl.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (fields.present) {
      map['fields'] = Variable<String>(fields.value);
    }
    if (fieldClock.present) {
      map['field_clock'] = Variable<String>(fieldClock.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncedRowsCompanion(')
          ..write('tbl: $tbl, ')
          ..write('rowId: $rowId, ')
          ..write('fields: $fields, ')
          ..write('fieldClock: $fieldClock, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _changeMeta = const VerificationMeta('change');
  @override
  late final GeneratedColumn<String> change = GeneratedColumn<String>(
    'change',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [seq, change];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('change')) {
      context.handle(
        _changeMeta,
        change.isAcceptableOrUnknown(data['change']!, _changeMeta),
      );
    } else if (isInserting) {
      context.missing(_changeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  OutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEntry(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      change: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}change'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxEntry extends DataClass implements Insertable<OutboxEntry> {
  /// Insertion order, which is also HLC order for local writes.
  final int seq;

  /// The change as JSON (`Change.toJson`).
  final String change;
  const OutboxEntry({required this.seq, required this.change});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['change'] = Variable<String>(change);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(seq: Value(seq), change: Value(change));
  }

  factory OutboxEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEntry(
      seq: serializer.fromJson<int>(json['seq']),
      change: serializer.fromJson<String>(json['change']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'change': serializer.toJson<String>(change),
    };
  }

  OutboxEntry copyWith({int? seq, String? change}) =>
      OutboxEntry(seq: seq ?? this.seq, change: change ?? this.change);
  OutboxEntry copyWithCompanion(OutboxCompanion data) {
    return OutboxEntry(
      seq: data.seq.present ? data.seq.value : this.seq,
      change: data.change.present ? data.change.value : this.change,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntry(')
          ..write('seq: $seq, ')
          ..write('change: $change')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(seq, change);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEntry &&
          other.seq == this.seq &&
          other.change == this.change);
}

class OutboxCompanion extends UpdateCompanion<OutboxEntry> {
  final Value<int> seq;
  final Value<String> change;
  const OutboxCompanion({
    this.seq = const Value.absent(),
    this.change = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.seq = const Value.absent(),
    required String change,
  }) : change = Value(change);
  static Insertable<OutboxEntry> custom({
    Expression<int>? seq,
    Expression<String>? change,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (change != null) 'change': change,
    });
  }

  OutboxCompanion copyWith({Value<int>? seq, Value<String>? change}) {
    return OutboxCompanion(seq: seq ?? this.seq, change: change ?? this.change);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (change.present) {
      map['change'] = Variable<String>(change.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('seq: $seq, ')
          ..write('change: $change')
          ..write(')'))
        .toString();
  }
}

class $PendingBatchesTable extends PendingBatches
    with TableInfo<$PendingBatchesTable, PendingBatchRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingBatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<int> slot = GeneratedColumn<int>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _changesMeta = const VerificationMeta(
    'changes',
  );
  @override
  late final GeneratedColumn<String> changes = GeneratedColumn<String>(
    'changes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [slot, name, changes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_batches';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingBatchRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('changes')) {
      context.handle(
        _changesMeta,
        changes.isAcceptableOrUnknown(data['changes']!, _changesMeta),
      );
    } else if (isInserting) {
      context.missing(_changesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {slot};
  @override
  PendingBatchRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingBatchRow(
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}slot'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      changes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}changes'],
      )!,
    );
  }

  @override
  $PendingBatchesTable createAlias(String alias) {
    return $PendingBatchesTable(attachedDatabase, alias);
  }
}

class PendingBatchRow extends DataClass implements Insertable<PendingBatchRow> {
  /// Always 0.
  final int slot;

  /// File name of the batch.
  final String name;

  /// JSON array of the changes.
  final String changes;
  const PendingBatchRow({
    required this.slot,
    required this.name,
    required this.changes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['slot'] = Variable<int>(slot);
    map['name'] = Variable<String>(name);
    map['changes'] = Variable<String>(changes);
    return map;
  }

  PendingBatchesCompanion toCompanion(bool nullToAbsent) {
    return PendingBatchesCompanion(
      slot: Value(slot),
      name: Value(name),
      changes: Value(changes),
    );
  }

  factory PendingBatchRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingBatchRow(
      slot: serializer.fromJson<int>(json['slot']),
      name: serializer.fromJson<String>(json['name']),
      changes: serializer.fromJson<String>(json['changes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'slot': serializer.toJson<int>(slot),
      'name': serializer.toJson<String>(name),
      'changes': serializer.toJson<String>(changes),
    };
  }

  PendingBatchRow copyWith({int? slot, String? name, String? changes}) =>
      PendingBatchRow(
        slot: slot ?? this.slot,
        name: name ?? this.name,
        changes: changes ?? this.changes,
      );
  PendingBatchRow copyWithCompanion(PendingBatchesCompanion data) {
    return PendingBatchRow(
      slot: data.slot.present ? data.slot.value : this.slot,
      name: data.name.present ? data.name.value : this.name,
      changes: data.changes.present ? data.changes.value : this.changes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingBatchRow(')
          ..write('slot: $slot, ')
          ..write('name: $name, ')
          ..write('changes: $changes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(slot, name, changes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingBatchRow &&
          other.slot == this.slot &&
          other.name == this.name &&
          other.changes == this.changes);
}

class PendingBatchesCompanion extends UpdateCompanion<PendingBatchRow> {
  final Value<int> slot;
  final Value<String> name;
  final Value<String> changes;
  const PendingBatchesCompanion({
    this.slot = const Value.absent(),
    this.name = const Value.absent(),
    this.changes = const Value.absent(),
  });
  PendingBatchesCompanion.insert({
    this.slot = const Value.absent(),
    required String name,
    required String changes,
  }) : name = Value(name),
       changes = Value(changes);
  static Insertable<PendingBatchRow> custom({
    Expression<int>? slot,
    Expression<String>? name,
    Expression<String>? changes,
  }) {
    return RawValuesInsertable({
      if (slot != null) 'slot': slot,
      if (name != null) 'name': name,
      if (changes != null) 'changes': changes,
    });
  }

  PendingBatchesCompanion copyWith({
    Value<int>? slot,
    Value<String>? name,
    Value<String>? changes,
  }) {
    return PendingBatchesCompanion(
      slot: slot ?? this.slot,
      name: name ?? this.name,
      changes: changes ?? this.changes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (slot.present) {
      map['slot'] = Variable<int>(slot.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (changes.present) {
      map['changes'] = Variable<String>(changes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingBatchesCompanion(')
          ..write('slot: $slot, ')
          ..write('name: $name, ')
          ..write('changes: $changes')
          ..write(')'))
        .toString();
  }
}

class $SeenFilesTable extends SeenFiles
    with TableInfo<$SeenFilesTable, SeenFile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeenFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [path, etag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'seen_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeenFile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    } else if (isInserting) {
      context.missing(_etagMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  SeenFile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeenFile(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      )!,
    );
  }

  @override
  $SeenFilesTable createAlias(String alias) {
    return $SeenFilesTable(attachedDatabase, alias);
  }
}

class SeenFile extends DataClass implements Insertable<SeenFile> {
  /// Path relative to the sync root.
  final String path;

  /// ETag when applied.
  final String etag;
  const SeenFile({required this.path, required this.etag});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['etag'] = Variable<String>(etag);
    return map;
  }

  SeenFilesCompanion toCompanion(bool nullToAbsent) {
    return SeenFilesCompanion(path: Value(path), etag: Value(etag));
  }

  factory SeenFile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeenFile(
      path: serializer.fromJson<String>(json['path']),
      etag: serializer.fromJson<String>(json['etag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'etag': serializer.toJson<String>(etag),
    };
  }

  SeenFile copyWith({String? path, String? etag}) =>
      SeenFile(path: path ?? this.path, etag: etag ?? this.etag);
  SeenFile copyWithCompanion(SeenFilesCompanion data) {
    return SeenFile(
      path: data.path.present ? data.path.value : this.path,
      etag: data.etag.present ? data.etag.value : this.etag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeenFile(')
          ..write('path: $path, ')
          ..write('etag: $etag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, etag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeenFile && other.path == this.path && other.etag == this.etag);
}

class SeenFilesCompanion extends UpdateCompanion<SeenFile> {
  final Value<String> path;
  final Value<String> etag;
  final Value<int> rowid;
  const SeenFilesCompanion({
    this.path = const Value.absent(),
    this.etag = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeenFilesCompanion.insert({
    required String path,
    required String etag,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       etag = Value(etag);
  static Insertable<SeenFile> custom({
    Expression<String>? path,
    Expression<String>? etag,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (etag != null) 'etag': etag,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeenFilesCompanion copyWith({
    Value<String>? path,
    Value<String>? etag,
    Value<int>? rowid,
  }) {
    return SeenFilesCompanion(
      path: path ?? this.path,
      etag: etag ?? this.etag,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeenFilesCompanion(')
          ..write('path: $path, ')
          ..write('etag: $etag, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FolderEtagsTable extends FolderEtags
    with TableInfo<$FolderEtagsTable, FolderEtag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FolderEtagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [path, etag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folder_etags';
  @override
  VerificationContext validateIntegrity(
    Insertable<FolderEtag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    } else if (isInserting) {
      context.missing(_etagMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  FolderEtag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FolderEtag(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      )!,
    );
  }

  @override
  $FolderEtagsTable createAlias(String alias) {
    return $FolderEtagsTable(attachedDatabase, alias);
  }
}

class FolderEtag extends DataClass implements Insertable<FolderEtag> {
  /// Folder path relative to the sync root.
  final String path;

  /// ETag when fully applied.
  final String etag;
  const FolderEtag({required this.path, required this.etag});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['etag'] = Variable<String>(etag);
    return map;
  }

  FolderEtagsCompanion toCompanion(bool nullToAbsent) {
    return FolderEtagsCompanion(path: Value(path), etag: Value(etag));
  }

  factory FolderEtag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FolderEtag(
      path: serializer.fromJson<String>(json['path']),
      etag: serializer.fromJson<String>(json['etag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'etag': serializer.toJson<String>(etag),
    };
  }

  FolderEtag copyWith({String? path, String? etag}) =>
      FolderEtag(path: path ?? this.path, etag: etag ?? this.etag);
  FolderEtag copyWithCompanion(FolderEtagsCompanion data) {
    return FolderEtag(
      path: data.path.present ? data.path.value : this.path,
      etag: data.etag.present ? data.etag.value : this.etag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FolderEtag(')
          ..write('path: $path, ')
          ..write('etag: $etag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, etag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FolderEtag &&
          other.path == this.path &&
          other.etag == this.etag);
}

class FolderEtagsCompanion extends UpdateCompanion<FolderEtag> {
  final Value<String> path;
  final Value<String> etag;
  final Value<int> rowid;
  const FolderEtagsCompanion({
    this.path = const Value.absent(),
    this.etag = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FolderEtagsCompanion.insert({
    required String path,
    required String etag,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       etag = Value(etag);
  static Insertable<FolderEtag> custom({
    Expression<String>? path,
    Expression<String>? etag,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (etag != null) 'etag': etag,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FolderEtagsCompanion copyWith({
    Value<String>? path,
    Value<String>? etag,
    Value<int>? rowid,
  }) {
    return FolderEtagsCompanion(
      path: path ?? this.path,
      etag: etag ?? this.etag,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FolderEtagsCompanion(')
          ..write('path: $path, ')
          ..write('etag: $etag, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalValuesTable extends LocalValues
    with TableInfo<$LocalValuesTable, LocalValue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalValuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_values';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalValue> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  LocalValue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalValue(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $LocalValuesTable createAlias(String alias) {
    return $LocalValuesTable(attachedDatabase, alias);
  }
}

class LocalValue extends DataClass implements Insertable<LocalValue> {
  /// Key, e.g. `hlc`.
  final String key;

  /// Value.
  final String value;
  const LocalValue({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  LocalValuesCompanion toCompanion(bool nullToAbsent) {
    return LocalValuesCompanion(key: Value(key), value: Value(value));
  }

  factory LocalValue.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalValue(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  LocalValue copyWith({String? key, String? value}) =>
      LocalValue(key: key ?? this.key, value: value ?? this.value);
  LocalValue copyWithCompanion(LocalValuesCompanion data) {
    return LocalValue(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalValue(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalValue &&
          other.key == this.key &&
          other.value == this.value);
}

class LocalValuesCompanion extends UpdateCompanion<LocalValue> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const LocalValuesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalValuesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<LocalValue> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalValuesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return LocalValuesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalValuesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$TimeTrackDatabase extends GeneratedDatabase {
  _$TimeTrackDatabase(QueryExecutor e) : super(e);
  $TimeTrackDatabaseManager get managers => $TimeTrackDatabaseManager(this);
  late final $SyncedRowsTable syncedRows = $SyncedRowsTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $PendingBatchesTable pendingBatches = $PendingBatchesTable(this);
  late final $SeenFilesTable seenFiles = $SeenFilesTable(this);
  late final $FolderEtagsTable folderEtags = $FolderEtagsTable(this);
  late final $LocalValuesTable localValues = $LocalValuesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    syncedRows,
    outbox,
    pendingBatches,
    seenFiles,
    folderEtags,
    localValues,
  ];
}

typedef $$SyncedRowsTableCreateCompanionBuilder = SyncedRowsCompanion Function({
  required String tbl,
  required String rowId,
  required String fields,
  required String fieldClock,
  Value<int> rowid,
});
typedef $$SyncedRowsTableUpdateCompanionBuilder = SyncedRowsCompanion Function({
  Value<String> tbl,
  Value<String> rowId,
  Value<String> fields,
  Value<String> fieldClock,
  Value<int> rowid,
});

class $$SyncedRowsTableFilterComposer
    extends Composer<_$TimeTrackDatabase, $SyncedRowsTable> {
  $$SyncedRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tbl => $composableBuilder(
    column: $table.tbl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fields => $composableBuilder(
    column: $table.fields,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldClock => $composableBuilder(
    column: $table.fieldClock,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncedRowsTableOrderingComposer
    extends Composer<_$TimeTrackDatabase, $SyncedRowsTable> {
  $$SyncedRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tbl => $composableBuilder(
    column: $table.tbl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fields => $composableBuilder(
    column: $table.fields,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldClock => $composableBuilder(
    column: $table.fieldClock,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncedRowsTableAnnotationComposer
    extends Composer<_$TimeTrackDatabase, $SyncedRowsTable> {
  $$SyncedRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tbl =>
      $composableBuilder(column: $table.tbl, builder: (column) => column);

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<String> get fields =>
      $composableBuilder(column: $table.fields, builder: (column) => column);

  GeneratedColumn<String> get fieldClock => $composableBuilder(
    column: $table.fieldClock,
    builder: (column) => column,
  );
}

class $$SyncedRowsTableTableManager
    extends
        RootTableManager<
          _$TimeTrackDatabase,
          $SyncedRowsTable,
          SyncedRowData,
          $$SyncedRowsTableFilterComposer,
          $$SyncedRowsTableOrderingComposer,
          $$SyncedRowsTableAnnotationComposer,
          $$SyncedRowsTableCreateCompanionBuilder,
          $$SyncedRowsTableUpdateCompanionBuilder,
          (
            SyncedRowData,
            BaseReferences<
              _$TimeTrackDatabase,
              $SyncedRowsTable,
              SyncedRowData
            >,
          ),
          SyncedRowData,
          PrefetchHooks Function()
        > {
  $$SyncedRowsTableTableManager(_$TimeTrackDatabase db, $SyncedRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncedRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncedRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncedRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tbl = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<String> fields = const Value.absent(),
                Value<String> fieldClock = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncedRowsCompanion(
                tbl: tbl,
                rowId: rowId,
                fields: fields,
                fieldClock: fieldClock,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tbl,
                required String rowId,
                required String fields,
                required String fieldClock,
                Value<int> rowid = const Value.absent(),
              }) => SyncedRowsCompanion.insert(
                tbl: tbl,
                rowId: rowId,
                fields: fields,
                fieldClock: fieldClock,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncedRowsTable, SyncedRowData>(table),
                  BaseReferences<
                    _$TimeTrackDatabase,
                    $SyncedRowsTable,
                    SyncedRowData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncedRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$TimeTrackDatabase,
      $SyncedRowsTable,
      SyncedRowData,
      $$SyncedRowsTableFilterComposer,
      $$SyncedRowsTableOrderingComposer,
      $$SyncedRowsTableAnnotationComposer,
      $$SyncedRowsTableCreateCompanionBuilder,
      $$SyncedRowsTableUpdateCompanionBuilder,
      (
        SyncedRowData,
        BaseReferences<_$TimeTrackDatabase, $SyncedRowsTable, SyncedRowData>,
      ),
      SyncedRowData,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  Value<int> seq,
  required String change,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<int> seq,
  Value<String> change,
});

class $$OutboxTableFilterComposer
    extends Composer<_$TimeTrackDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get change => $composableBuilder(
    column: $table.change,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$TimeTrackDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get change => $composableBuilder(
    column: $table.change,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$TimeTrackDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get change =>
      $composableBuilder(column: $table.change, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$TimeTrackDatabase,
          $OutboxTable,
          OutboxEntry,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (
            OutboxEntry,
            BaseReferences<_$TimeTrackDatabase, $OutboxTable, OutboxEntry>,
          ),
          OutboxEntry,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$TimeTrackDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> seq = const Value.absent(),
            Value<String> change = const Value.absent(),
          }) => OutboxCompanion(seq: seq, change: change),
          createCompanionCallback: ({
            Value<int> seq = const Value.absent(),
            required String change,
          }) => OutboxCompanion.insert(seq: seq, change: change),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxTable, OutboxEntry>(table),
                  BaseReferences<
                    _$TimeTrackDatabase,
                    $OutboxTable,
                    OutboxEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$TimeTrackDatabase,
      $OutboxTable,
      OutboxEntry,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (
        OutboxEntry,
        BaseReferences<_$TimeTrackDatabase, $OutboxTable, OutboxEntry>,
      ),
      OutboxEntry,
      PrefetchHooks Function()
    >;
typedef $$PendingBatchesTableCreateCompanionBuilder =
    PendingBatchesCompanion Function({
      Value<int> slot,
      required String name,
      required String changes,
    });
typedef $$PendingBatchesTableUpdateCompanionBuilder =
    PendingBatchesCompanion Function({
      Value<int> slot,
      Value<String> name,
      Value<String> changes,
    });

class $$PendingBatchesTableFilterComposer
    extends Composer<_$TimeTrackDatabase, $PendingBatchesTable> {
  $$PendingBatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get changes => $composableBuilder(
    column: $table.changes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingBatchesTableOrderingComposer
    extends Composer<_$TimeTrackDatabase, $PendingBatchesTable> {
  $$PendingBatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get changes => $composableBuilder(
    column: $table.changes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingBatchesTableAnnotationComposer
    extends Composer<_$TimeTrackDatabase, $PendingBatchesTable> {
  $$PendingBatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get changes =>
      $composableBuilder(column: $table.changes, builder: (column) => column);
}

class $$PendingBatchesTableTableManager
    extends
        RootTableManager<
          _$TimeTrackDatabase,
          $PendingBatchesTable,
          PendingBatchRow,
          $$PendingBatchesTableFilterComposer,
          $$PendingBatchesTableOrderingComposer,
          $$PendingBatchesTableAnnotationComposer,
          $$PendingBatchesTableCreateCompanionBuilder,
          $$PendingBatchesTableUpdateCompanionBuilder,
          (
            PendingBatchRow,
            BaseReferences<
              _$TimeTrackDatabase,
              $PendingBatchesTable,
              PendingBatchRow
            >,
          ),
          PendingBatchRow,
          PrefetchHooks Function()
        > {
  $$PendingBatchesTableTableManager(
    _$TimeTrackDatabase db,
    $PendingBatchesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingBatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingBatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingBatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> slot = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> changes = const Value.absent(),
              }) => PendingBatchesCompanion(
                slot: slot,
                name: name,
                changes: changes,
              ),
          createCompanionCallback:
              ({
                Value<int> slot = const Value.absent(),
                required String name,
                required String changes,
              }) => PendingBatchesCompanion.insert(
                slot: slot,
                name: name,
                changes: changes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingBatchesTable, PendingBatchRow>(table),
                  BaseReferences<
                    _$TimeTrackDatabase,
                    $PendingBatchesTable,
                    PendingBatchRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingBatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$TimeTrackDatabase,
      $PendingBatchesTable,
      PendingBatchRow,
      $$PendingBatchesTableFilterComposer,
      $$PendingBatchesTableOrderingComposer,
      $$PendingBatchesTableAnnotationComposer,
      $$PendingBatchesTableCreateCompanionBuilder,
      $$PendingBatchesTableUpdateCompanionBuilder,
      (
        PendingBatchRow,
        BaseReferences<
          _$TimeTrackDatabase,
          $PendingBatchesTable,
          PendingBatchRow
        >,
      ),
      PendingBatchRow,
      PrefetchHooks Function()
    >;
typedef $$SeenFilesTableCreateCompanionBuilder = SeenFilesCompanion Function({
  required String path,
  required String etag,
  Value<int> rowid,
});
typedef $$SeenFilesTableUpdateCompanionBuilder = SeenFilesCompanion Function({
  Value<String> path,
  Value<String> etag,
  Value<int> rowid,
});

class $$SeenFilesTableFilterComposer
    extends Composer<_$TimeTrackDatabase, $SeenFilesTable> {
  $$SeenFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SeenFilesTableOrderingComposer
    extends Composer<_$TimeTrackDatabase, $SeenFilesTable> {
  $$SeenFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SeenFilesTableAnnotationComposer
    extends Composer<_$TimeTrackDatabase, $SeenFilesTable> {
  $$SeenFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);
}

class $$SeenFilesTableTableManager
    extends
        RootTableManager<
          _$TimeTrackDatabase,
          $SeenFilesTable,
          SeenFile,
          $$SeenFilesTableFilterComposer,
          $$SeenFilesTableOrderingComposer,
          $$SeenFilesTableAnnotationComposer,
          $$SeenFilesTableCreateCompanionBuilder,
          $$SeenFilesTableUpdateCompanionBuilder,
          (
            SeenFile,
            BaseReferences<_$TimeTrackDatabase, $SeenFilesTable, SeenFile>,
          ),
          SeenFile,
          PrefetchHooks Function()
        > {
  $$SeenFilesTableTableManager(_$TimeTrackDatabase db, $SeenFilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeenFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeenFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeenFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> path = const Value.absent(),
            Value<String> etag = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SeenFilesCompanion(path: path, etag: etag, rowid: rowid),
          createCompanionCallback: ({
            required String path,
            required String etag,
            Value<int> rowid = const Value.absent(),
          }) => SeenFilesCompanion.insert(path: path, etag: etag, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SeenFilesTable, SeenFile>(table),
                  BaseReferences<
                    _$TimeTrackDatabase,
                    $SeenFilesTable,
                    SeenFile
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SeenFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$TimeTrackDatabase,
      $SeenFilesTable,
      SeenFile,
      $$SeenFilesTableFilterComposer,
      $$SeenFilesTableOrderingComposer,
      $$SeenFilesTableAnnotationComposer,
      $$SeenFilesTableCreateCompanionBuilder,
      $$SeenFilesTableUpdateCompanionBuilder,
      (
        SeenFile,
        BaseReferences<_$TimeTrackDatabase, $SeenFilesTable, SeenFile>,
      ),
      SeenFile,
      PrefetchHooks Function()
    >;
typedef $$FolderEtagsTableCreateCompanionBuilder =
    FolderEtagsCompanion Function({
      required String path,
      required String etag,
      Value<int> rowid,
    });
typedef $$FolderEtagsTableUpdateCompanionBuilder =
    FolderEtagsCompanion Function({
      Value<String> path,
      Value<String> etag,
      Value<int> rowid,
    });

class $$FolderEtagsTableFilterComposer
    extends Composer<_$TimeTrackDatabase, $FolderEtagsTable> {
  $$FolderEtagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FolderEtagsTableOrderingComposer
    extends Composer<_$TimeTrackDatabase, $FolderEtagsTable> {
  $$FolderEtagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FolderEtagsTableAnnotationComposer
    extends Composer<_$TimeTrackDatabase, $FolderEtagsTable> {
  $$FolderEtagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);
}

class $$FolderEtagsTableTableManager
    extends
        RootTableManager<
          _$TimeTrackDatabase,
          $FolderEtagsTable,
          FolderEtag,
          $$FolderEtagsTableFilterComposer,
          $$FolderEtagsTableOrderingComposer,
          $$FolderEtagsTableAnnotationComposer,
          $$FolderEtagsTableCreateCompanionBuilder,
          $$FolderEtagsTableUpdateCompanionBuilder,
          (
            FolderEtag,
            BaseReferences<_$TimeTrackDatabase, $FolderEtagsTable, FolderEtag>,
          ),
          FolderEtag,
          PrefetchHooks Function()
        > {
  $$FolderEtagsTableTableManager(
    _$TimeTrackDatabase db,
    $FolderEtagsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FolderEtagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FolderEtagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FolderEtagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> path = const Value.absent(),
            Value<String> etag = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => FolderEtagsCompanion(path: path, etag: etag, rowid: rowid),
          createCompanionCallback:
              ({
                required String path,
                required String etag,
                Value<int> rowid = const Value.absent(),
              }) => FolderEtagsCompanion.insert(
                path: path,
                etag: etag,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FolderEtagsTable, FolderEtag>(table),
                  BaseReferences<
                    _$TimeTrackDatabase,
                    $FolderEtagsTable,
                    FolderEtag
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FolderEtagsTableProcessedTableManager =
    ProcessedTableManager<
      _$TimeTrackDatabase,
      $FolderEtagsTable,
      FolderEtag,
      $$FolderEtagsTableFilterComposer,
      $$FolderEtagsTableOrderingComposer,
      $$FolderEtagsTableAnnotationComposer,
      $$FolderEtagsTableCreateCompanionBuilder,
      $$FolderEtagsTableUpdateCompanionBuilder,
      (
        FolderEtag,
        BaseReferences<_$TimeTrackDatabase, $FolderEtagsTable, FolderEtag>,
      ),
      FolderEtag,
      PrefetchHooks Function()
    >;
typedef $$LocalValuesTableCreateCompanionBuilder =
    LocalValuesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$LocalValuesTableUpdateCompanionBuilder =
    LocalValuesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$LocalValuesTableFilterComposer
    extends Composer<_$TimeTrackDatabase, $LocalValuesTable> {
  $$LocalValuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalValuesTableOrderingComposer
    extends Composer<_$TimeTrackDatabase, $LocalValuesTable> {
  $$LocalValuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalValuesTableAnnotationComposer
    extends Composer<_$TimeTrackDatabase, $LocalValuesTable> {
  $$LocalValuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$LocalValuesTableTableManager
    extends
        RootTableManager<
          _$TimeTrackDatabase,
          $LocalValuesTable,
          LocalValue,
          $$LocalValuesTableFilterComposer,
          $$LocalValuesTableOrderingComposer,
          $$LocalValuesTableAnnotationComposer,
          $$LocalValuesTableCreateCompanionBuilder,
          $$LocalValuesTableUpdateCompanionBuilder,
          (
            LocalValue,
            BaseReferences<_$TimeTrackDatabase, $LocalValuesTable, LocalValue>,
          ),
          LocalValue,
          PrefetchHooks Function()
        > {
  $$LocalValuesTableTableManager(
    _$TimeTrackDatabase db,
    $LocalValuesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalValuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalValuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalValuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => LocalValuesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => LocalValuesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalValuesTable, LocalValue>(table),
                  BaseReferences<
                    _$TimeTrackDatabase,
                    $LocalValuesTable,
                    LocalValue
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalValuesTableProcessedTableManager =
    ProcessedTableManager<
      _$TimeTrackDatabase,
      $LocalValuesTable,
      LocalValue,
      $$LocalValuesTableFilterComposer,
      $$LocalValuesTableOrderingComposer,
      $$LocalValuesTableAnnotationComposer,
      $$LocalValuesTableCreateCompanionBuilder,
      $$LocalValuesTableUpdateCompanionBuilder,
      (
        LocalValue,
        BaseReferences<_$TimeTrackDatabase, $LocalValuesTable, LocalValue>,
      ),
      LocalValue,
      PrefetchHooks Function()
    >;

class $TimeTrackDatabaseManager {
  final _$TimeTrackDatabase _db;
  $TimeTrackDatabaseManager(this._db);
  $$SyncedRowsTableTableManager get syncedRows =>
      $$SyncedRowsTableTableManager(_db, _db.syncedRows);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$PendingBatchesTableTableManager get pendingBatches =>
      $$PendingBatchesTableTableManager(_db, _db.pendingBatches);
  $$SeenFilesTableTableManager get seenFiles =>
      $$SeenFilesTableTableManager(_db, _db.seenFiles);
  $$FolderEtagsTableTableManager get folderEtags =>
      $$FolderEtagsTableTableManager(_db, _db.folderEtags);
  $$LocalValuesTableTableManager get localValues =>
      $$LocalValuesTableTableManager(_db, _db.localValues);
}
