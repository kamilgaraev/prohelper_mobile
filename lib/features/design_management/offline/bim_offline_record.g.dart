// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bim_offline_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetBimOfflineRecordCollection on Isar {
  IsarCollection<BimOfflineRecord> get bimOfflineRecords => this.collection();
}

const BimOfflineRecordSchema = CollectionSchema(
  name: r'BimOfflineRecord',
  id: -9089853165300126766,
  properties: {
    r'attachmentAcks': PropertySchema(
      id: 0,
      name: r'attachmentAcks',
      type: IsarType.stringList,
    ),
    r'attachmentRevisionsJson': PropertySchema(
      id: 1,
      name: r'attachmentRevisionsJson',
      type: IsarType.string,
    ),
    r'attempted': PropertySchema(
      id: 2,
      name: r'attempted',
      type: IsarType.bool,
    ),
    r'attempts': PropertySchema(id: 3, name: r'attempts', type: IsarType.long),
    r'encryptedPath': PropertySchema(
      id: 4,
      name: r'encryptedPath',
      type: IsarType.string,
    ),
    r'geometryBytes': PropertySchema(
      id: 5,
      name: r'geometryBytes',
      type: IsarType.long,
    ),
    r'key': PropertySchema(id: 6, name: r'key', type: IsarType.string),
    r'kind': PropertySchema(id: 7, name: r'kind', type: IsarType.string),
    r'lastError': PropertySchema(
      id: 8,
      name: r'lastError',
      type: IsarType.string,
    ),
    r'manifestJson': PropertySchema(
      id: 9,
      name: r'manifestJson',
      type: IsarType.string,
    ),
    r'nextAttemptAt': PropertySchema(
      id: 10,
      name: r'nextAttemptAt',
      type: IsarType.dateTime,
    ),
    r'propertiesBytes': PropertySchema(
      id: 11,
      name: r'propertiesBytes',
      type: IsarType.long,
    ),
    r'propertiesPath': PropertySchema(
      id: 12,
      name: r'propertiesPath',
      type: IsarType.string,
    ),
    r'scope': PropertySchema(id: 13, name: r'scope', type: IsarType.string),
    r'serverId': PropertySchema(id: 14, name: r'serverId', type: IsarType.long),
    r'serverRevision': PropertySchema(
      id: 15,
      name: r'serverRevision',
      type: IsarType.long,
    ),
    r'status': PropertySchema(id: 16, name: r'status', type: IsarType.string),
    r'title': PropertySchema(id: 17, name: r'title', type: IsarType.string),
    r'versionId': PropertySchema(
      id: 18,
      name: r'versionId',
      type: IsarType.long,
    ),
  },
  estimateSize: _bimOfflineRecordEstimateSize,
  serialize: _bimOfflineRecordSerialize,
  deserialize: _bimOfflineRecordDeserialize,
  deserializeProp: _bimOfflineRecordDeserializeProp,
  idName: r'id',
  indexes: {
    r'scope': IndexSchema(
      id: 152078781581678656,
      name: r'scope',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'scope',
          type: IndexType.value,
          caseSensitive: true,
        ),
      ],
    ),
    r'key': IndexSchema(
      id: -4906094122524121629,
      name: r'key',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'key',
          type: IndexType.value,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},
  getId: _bimOfflineRecordGetId,
  getLinks: _bimOfflineRecordGetLinks,
  attach: _bimOfflineRecordAttach,
  version: '3.1.0+1',
);

int _bimOfflineRecordEstimateSize(
  BimOfflineRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.attachmentAcks.length * 3;
  {
    for (var i = 0; i < object.attachmentAcks.length; i++) {
      final value = object.attachmentAcks[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.attachmentRevisionsJson.length * 3;
  bytesCount += 3 + object.encryptedPath.length * 3;
  bytesCount += 3 + object.key.length * 3;
  bytesCount += 3 + object.kind.length * 3;
  {
    final value = object.lastError;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.manifestJson.length * 3;
  bytesCount += 3 + object.propertiesPath.length * 3;
  bytesCount += 3 + object.scope.length * 3;
  bytesCount += 3 + object.status.length * 3;
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _bimOfflineRecordSerialize(
  BimOfflineRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeStringList(offsets[0], object.attachmentAcks);
  writer.writeString(offsets[1], object.attachmentRevisionsJson);
  writer.writeBool(offsets[2], object.attempted);
  writer.writeLong(offsets[3], object.attempts);
  writer.writeString(offsets[4], object.encryptedPath);
  writer.writeLong(offsets[5], object.geometryBytes);
  writer.writeString(offsets[6], object.key);
  writer.writeString(offsets[7], object.kind);
  writer.writeString(offsets[8], object.lastError);
  writer.writeString(offsets[9], object.manifestJson);
  writer.writeDateTime(offsets[10], object.nextAttemptAt);
  writer.writeLong(offsets[11], object.propertiesBytes);
  writer.writeString(offsets[12], object.propertiesPath);
  writer.writeString(offsets[13], object.scope);
  writer.writeLong(offsets[14], object.serverId);
  writer.writeLong(offsets[15], object.serverRevision);
  writer.writeString(offsets[16], object.status);
  writer.writeString(offsets[17], object.title);
  writer.writeLong(offsets[18], object.versionId);
}

BimOfflineRecord _bimOfflineRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = BimOfflineRecord();
  object.attachmentAcks = reader.readStringList(offsets[0]) ?? [];
  object.attachmentRevisionsJson = reader.readString(offsets[1]);
  object.attempted = reader.readBool(offsets[2]);
  object.attempts = reader.readLong(offsets[3]);
  object.encryptedPath = reader.readString(offsets[4]);
  object.geometryBytes = reader.readLong(offsets[5]);
  object.id = id;
  object.key = reader.readString(offsets[6]);
  object.kind = reader.readString(offsets[7]);
  object.lastError = reader.readStringOrNull(offsets[8]);
  object.manifestJson = reader.readString(offsets[9]);
  object.nextAttemptAt = reader.readDateTimeOrNull(offsets[10]);
  object.propertiesBytes = reader.readLong(offsets[11]);
  object.propertiesPath = reader.readString(offsets[12]);
  object.scope = reader.readString(offsets[13]);
  object.serverId = reader.readLongOrNull(offsets[14]);
  object.serverRevision = reader.readLongOrNull(offsets[15]);
  object.status = reader.readString(offsets[16]);
  object.title = reader.readString(offsets[17]);
  object.versionId = reader.readLong(offsets[18]);
  return object;
}

P _bimOfflineRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringList(offset) ?? []) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 11:
      return (reader.readLong(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readString(offset)) as P;
    case 14:
      return (reader.readLongOrNull(offset)) as P;
    case 15:
      return (reader.readLongOrNull(offset)) as P;
    case 16:
      return (reader.readString(offset)) as P;
    case 17:
      return (reader.readString(offset)) as P;
    case 18:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _bimOfflineRecordGetId(BimOfflineRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _bimOfflineRecordGetLinks(BimOfflineRecord object) {
  return [];
}

void _bimOfflineRecordAttach(
  IsarCollection<dynamic> col,
  Id id,
  BimOfflineRecord object,
) {
  object.id = id;
}

extension BimOfflineRecordQueryWhereSort
    on QueryBuilder<BimOfflineRecord, BimOfflineRecord, QWhere> {
  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhere> anyScope() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'scope'),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhere> anyKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'key'),
      );
    });
  }
}

extension BimOfflineRecordQueryWhere
    on QueryBuilder<BimOfflineRecord, BimOfflineRecord, QWhereClause> {
  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhereClause>
  idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhereClause>
  scopeEqualTo(String scope) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'scope', value: [scope]),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhereClause>
  scopeNotEqualTo(String scope) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'scope',
                lower: [],
                upper: [scope],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'scope',
                lower: [scope],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'scope',
                lower: [scope],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'scope',
                lower: [],
                upper: [scope],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhereClause>
  scopeGreaterThan(String scope, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'scope',
          lower: [scope],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhereClause>
  scopeLessThan(String scope, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'scope',
          lower: [],
          upper: [scope],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhereClause>
  scopeBetween(
    String lowerScope,
    String upperScope, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'scope',
          lower: [lowerScope],
          includeLower: includeLower,
          upper: [upperScope],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhereClause>
  scopeStartsWith(String ScopePrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'scope',
          lower: [ScopePrefix],
          upper: ['$ScopePrefix\u{FFFFF}'],
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhereClause>
  scopeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'scope', value: ['']),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhereClause>
  scopeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'scope', upper: ['']),
            )
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'scope', lower: ['']),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'scope', lower: ['']),
            )
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'scope', upper: ['']),
            );
      }
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhereClause>
  keyEqualTo(String key) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'key', value: [key]),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhereClause>
  keyNotEqualTo(String key) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'key',
                lower: [],
                upper: [key],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'key',
                lower: [key],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'key',
                lower: [key],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'key',
                lower: [],
                upper: [key],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhereClause>
  keyGreaterThan(String key, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'key',
          lower: [key],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhereClause>
  keyLessThan(String key, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'key',
          lower: [],
          upper: [key],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhereClause>
  keyBetween(
    String lowerKey,
    String upperKey, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'key',
          lower: [lowerKey],
          includeLower: includeLower,
          upper: [upperKey],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhereClause>
  keyStartsWith(String KeyPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'key',
          lower: [KeyPrefix],
          upper: ['$KeyPrefix\u{FFFFF}'],
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhereClause>
  keyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'key', value: ['']),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterWhereClause>
  keyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'key', upper: ['']),
            )
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'key', lower: ['']),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'key', lower: ['']),
            )
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'key', upper: ['']),
            );
      }
    });
  }
}

extension BimOfflineRecordQueryFilter
    on QueryBuilder<BimOfflineRecord, BimOfflineRecord, QFilterCondition> {
  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentAcksElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'attachmentAcks',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentAcksElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'attachmentAcks',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentAcksElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'attachmentAcks',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentAcksElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'attachmentAcks',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentAcksElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'attachmentAcks',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentAcksElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'attachmentAcks',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentAcksElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'attachmentAcks',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentAcksElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'attachmentAcks',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentAcksElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'attachmentAcks', value: ''),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentAcksElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'attachmentAcks', value: ''),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentAcksLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'attachmentAcks', length, true, length, true);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentAcksIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'attachmentAcks', 0, true, 0, true);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentAcksIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'attachmentAcks', 0, false, 999999, true);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentAcksLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'attachmentAcks', 0, true, length, include);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentAcksLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'attachmentAcks', length, include, 999999, true);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentAcksLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'attachmentAcks',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentRevisionsJsonEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'attachmentRevisionsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentRevisionsJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'attachmentRevisionsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentRevisionsJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'attachmentRevisionsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentRevisionsJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'attachmentRevisionsJson',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentRevisionsJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'attachmentRevisionsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentRevisionsJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'attachmentRevisionsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentRevisionsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'attachmentRevisionsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentRevisionsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'attachmentRevisionsJson',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentRevisionsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'attachmentRevisionsJson',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attachmentRevisionsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'attachmentRevisionsJson',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attemptedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'attempted', value: value),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attemptsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'attempts', value: value),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attemptsGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'attempts',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attemptsLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'attempts',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  attemptsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'attempts',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  encryptedPathEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'encryptedPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  encryptedPathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'encryptedPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  encryptedPathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'encryptedPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  encryptedPathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'encryptedPath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  encryptedPathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'encryptedPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  encryptedPathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'encryptedPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  encryptedPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'encryptedPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  encryptedPathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'encryptedPath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  encryptedPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'encryptedPath', value: ''),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  encryptedPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'encryptedPath', value: ''),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  geometryBytesEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'geometryBytes', value: value),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  geometryBytesGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'geometryBytes',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  geometryBytesLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'geometryBytes',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  geometryBytesBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'geometryBytes',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  keyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  keyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  keyLessThan(String value, {bool include = false, bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  keyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'key',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  keyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  keyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  keyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'key',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  keyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'key',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  keyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'key', value: ''),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  keyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'key', value: ''),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  kindEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  kindGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  kindLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  kindBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'kind',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  kindStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  kindEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  kindContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'kind',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  kindMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'kind',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  kindIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'kind', value: ''),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  kindIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'kind', value: ''),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  lastErrorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastError'),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  lastErrorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastError'),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  lastErrorEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lastError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  lastErrorGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  lastErrorLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  lastErrorBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastError',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  lastErrorStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'lastError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  lastErrorEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'lastError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  lastErrorContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'lastError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  lastErrorMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'lastError',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  lastErrorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastError', value: ''),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  lastErrorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'lastError', value: ''),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  manifestJsonEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'manifestJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  manifestJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'manifestJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  manifestJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'manifestJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  manifestJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'manifestJson',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  manifestJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'manifestJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  manifestJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'manifestJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  manifestJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'manifestJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  manifestJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'manifestJson',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  manifestJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'manifestJson', value: ''),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  manifestJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'manifestJson', value: ''),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  nextAttemptAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'nextAttemptAt'),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  nextAttemptAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'nextAttemptAt'),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  nextAttemptAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'nextAttemptAt', value: value),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  nextAttemptAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'nextAttemptAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  nextAttemptAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'nextAttemptAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  nextAttemptAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'nextAttemptAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  propertiesBytesEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'propertiesBytes', value: value),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  propertiesBytesGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'propertiesBytes',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  propertiesBytesLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'propertiesBytes',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  propertiesBytesBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'propertiesBytes',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  propertiesPathEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'propertiesPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  propertiesPathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'propertiesPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  propertiesPathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'propertiesPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  propertiesPathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'propertiesPath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  propertiesPathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'propertiesPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  propertiesPathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'propertiesPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  propertiesPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'propertiesPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  propertiesPathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'propertiesPath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  propertiesPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'propertiesPath', value: ''),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  propertiesPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'propertiesPath', value: ''),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  scopeEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'scope',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  scopeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'scope',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  scopeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'scope',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  scopeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'scope',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  scopeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'scope',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  scopeEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'scope',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  scopeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'scope',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  scopeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'scope',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  scopeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'scope', value: ''),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  scopeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'scope', value: ''),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  serverIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'serverId'),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  serverIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'serverId'),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  serverIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'serverId', value: value),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  serverIdGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'serverId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  serverIdLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'serverId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  serverIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'serverId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  serverRevisionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'serverRevision'),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  serverRevisionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'serverRevision'),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  serverRevisionEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'serverRevision', value: value),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  serverRevisionGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'serverRevision',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  serverRevisionLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'serverRevision',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  serverRevisionBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'serverRevision',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  statusEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  statusGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  statusLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  statusBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'status',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  statusStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  statusEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  statusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  statusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'status',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'status', value: ''),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'status', value: ''),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  titleEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'title',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  titleStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  titleEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'title',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  versionIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'versionId', value: value),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  versionIdGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'versionId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  versionIdLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'versionId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterFilterCondition>
  versionIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'versionId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension BimOfflineRecordQueryObject
    on QueryBuilder<BimOfflineRecord, BimOfflineRecord, QFilterCondition> {}

extension BimOfflineRecordQueryLinks
    on QueryBuilder<BimOfflineRecord, BimOfflineRecord, QFilterCondition> {}

extension BimOfflineRecordQuerySortBy
    on QueryBuilder<BimOfflineRecord, BimOfflineRecord, QSortBy> {
  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByAttachmentRevisionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentRevisionsJson', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByAttachmentRevisionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentRevisionsJson', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByAttempted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attempted', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByAttemptedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attempted', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByAttempts() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attempts', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByAttemptsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attempts', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByEncryptedPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'encryptedPath', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByEncryptedPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'encryptedPath', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByGeometryBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'geometryBytes', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByGeometryBytesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'geometryBytes', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy> sortByKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'key', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'key', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy> sortByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByLastError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastError', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByLastErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastError', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByManifestJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'manifestJson', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByManifestJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'manifestJson', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByNextAttemptAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextAttemptAt', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByNextAttemptAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextAttemptAt', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByPropertiesBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'propertiesBytes', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByPropertiesBytesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'propertiesBytes', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByPropertiesPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'propertiesPath', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByPropertiesPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'propertiesPath', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy> sortByScope() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scope', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByScopeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scope', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByServerId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverId', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByServerIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverId', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByServerRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverRevision', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByServerRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverRevision', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByVersionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionId', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  sortByVersionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionId', Sort.desc);
    });
  }
}

extension BimOfflineRecordQuerySortThenBy
    on QueryBuilder<BimOfflineRecord, BimOfflineRecord, QSortThenBy> {
  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByAttachmentRevisionsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentRevisionsJson', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByAttachmentRevisionsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentRevisionsJson', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByAttempted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attempted', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByAttemptedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attempted', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByAttempts() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attempts', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByAttemptsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attempts', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByEncryptedPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'encryptedPath', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByEncryptedPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'encryptedPath', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByGeometryBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'geometryBytes', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByGeometryBytesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'geometryBytes', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy> thenByKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'key', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'key', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy> thenByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByLastError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastError', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByLastErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastError', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByManifestJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'manifestJson', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByManifestJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'manifestJson', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByNextAttemptAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextAttemptAt', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByNextAttemptAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextAttemptAt', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByPropertiesBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'propertiesBytes', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByPropertiesBytesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'propertiesBytes', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByPropertiesPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'propertiesPath', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByPropertiesPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'propertiesPath', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy> thenByScope() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scope', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByScopeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scope', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByServerId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverId', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByServerIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverId', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByServerRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverRevision', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByServerRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverRevision', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByVersionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionId', Sort.asc);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QAfterSortBy>
  thenByVersionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'versionId', Sort.desc);
    });
  }
}

extension BimOfflineRecordQueryWhereDistinct
    on QueryBuilder<BimOfflineRecord, BimOfflineRecord, QDistinct> {
  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QDistinct>
  distinctByAttachmentAcks() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attachmentAcks');
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QDistinct>
  distinctByAttachmentRevisionsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'attachmentRevisionsJson',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QDistinct>
  distinctByAttempted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attempted');
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QDistinct>
  distinctByAttempts() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attempts');
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QDistinct>
  distinctByEncryptedPath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'encryptedPath',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QDistinct>
  distinctByGeometryBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'geometryBytes');
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QDistinct> distinctByKey({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'key', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QDistinct> distinctByKind({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'kind', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QDistinct>
  distinctByLastError({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastError', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QDistinct>
  distinctByManifestJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'manifestJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QDistinct>
  distinctByNextAttemptAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nextAttemptAt');
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QDistinct>
  distinctByPropertiesBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'propertiesBytes');
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QDistinct>
  distinctByPropertiesPath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'propertiesPath',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QDistinct> distinctByScope({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'scope', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QDistinct>
  distinctByServerId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'serverId');
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QDistinct>
  distinctByServerRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'serverRevision');
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QDistinct> distinctByStatus({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QDistinct> distinctByTitle({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BimOfflineRecord, BimOfflineRecord, QDistinct>
  distinctByVersionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'versionId');
    });
  }
}

extension BimOfflineRecordQueryProperty
    on QueryBuilder<BimOfflineRecord, BimOfflineRecord, QQueryProperty> {
  QueryBuilder<BimOfflineRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<BimOfflineRecord, List<String>, QQueryOperations>
  attachmentAcksProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attachmentAcks');
    });
  }

  QueryBuilder<BimOfflineRecord, String, QQueryOperations>
  attachmentRevisionsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attachmentRevisionsJson');
    });
  }

  QueryBuilder<BimOfflineRecord, bool, QQueryOperations> attemptedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attempted');
    });
  }

  QueryBuilder<BimOfflineRecord, int, QQueryOperations> attemptsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attempts');
    });
  }

  QueryBuilder<BimOfflineRecord, String, QQueryOperations>
  encryptedPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'encryptedPath');
    });
  }

  QueryBuilder<BimOfflineRecord, int, QQueryOperations>
  geometryBytesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'geometryBytes');
    });
  }

  QueryBuilder<BimOfflineRecord, String, QQueryOperations> keyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'key');
    });
  }

  QueryBuilder<BimOfflineRecord, String, QQueryOperations> kindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'kind');
    });
  }

  QueryBuilder<BimOfflineRecord, String?, QQueryOperations>
  lastErrorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastError');
    });
  }

  QueryBuilder<BimOfflineRecord, String, QQueryOperations>
  manifestJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'manifestJson');
    });
  }

  QueryBuilder<BimOfflineRecord, DateTime?, QQueryOperations>
  nextAttemptAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nextAttemptAt');
    });
  }

  QueryBuilder<BimOfflineRecord, int, QQueryOperations>
  propertiesBytesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'propertiesBytes');
    });
  }

  QueryBuilder<BimOfflineRecord, String, QQueryOperations>
  propertiesPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'propertiesPath');
    });
  }

  QueryBuilder<BimOfflineRecord, String, QQueryOperations> scopeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'scope');
    });
  }

  QueryBuilder<BimOfflineRecord, int?, QQueryOperations> serverIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'serverId');
    });
  }

  QueryBuilder<BimOfflineRecord, int?, QQueryOperations>
  serverRevisionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'serverRevision');
    });
  }

  QueryBuilder<BimOfflineRecord, String, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<BimOfflineRecord, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<BimOfflineRecord, int, QQueryOperations> versionIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'versionId');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetBimElementIndexCollection on Isar {
  IsarCollection<BimElementIndex> get bimElementIndexs => this.collection();
}

const BimElementIndexSchema = CollectionSchema(
  name: r'BimElementIndex',
  id: 739554270029937309,
  properties: {
    r'expressId': PropertySchema(
      id: 0,
      name: r'expressId',
      type: IsarType.long,
    ),
    r'length': PropertySchema(id: 1, name: r'length', type: IsarType.long),
    r'offset': PropertySchema(id: 2, name: r'offset', type: IsarType.long),
    r'packageKey': PropertySchema(
      id: 3,
      name: r'packageKey',
      type: IsarType.string,
    ),
    r'scope': PropertySchema(id: 4, name: r'scope', type: IsarType.string),
  },
  estimateSize: _bimElementIndexEstimateSize,
  serialize: _bimElementIndexSerialize,
  deserialize: _bimElementIndexDeserialize,
  deserializeProp: _bimElementIndexDeserializeProp,
  idName: r'id',
  indexes: {
    r'scope': IndexSchema(
      id: 152078781581678656,
      name: r'scope',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'scope',
          type: IndexType.value,
          caseSensitive: true,
        ),
      ],
    ),
    r'packageKey': IndexSchema(
      id: 2251351584113781320,
      name: r'packageKey',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'packageKey',
          type: IndexType.value,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},
  getId: _bimElementIndexGetId,
  getLinks: _bimElementIndexGetLinks,
  attach: _bimElementIndexAttach,
  version: '3.1.0+1',
);

int _bimElementIndexEstimateSize(
  BimElementIndex object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.packageKey.length * 3;
  bytesCount += 3 + object.scope.length * 3;
  return bytesCount;
}

void _bimElementIndexSerialize(
  BimElementIndex object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.expressId);
  writer.writeLong(offsets[1], object.length);
  writer.writeLong(offsets[2], object.offset);
  writer.writeString(offsets[3], object.packageKey);
  writer.writeString(offsets[4], object.scope);
}

BimElementIndex _bimElementIndexDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = BimElementIndex();
  object.expressId = reader.readLong(offsets[0]);
  object.id = id;
  object.length = reader.readLong(offsets[1]);
  object.offset = reader.readLong(offsets[2]);
  object.packageKey = reader.readString(offsets[3]);
  object.scope = reader.readString(offsets[4]);
  return object;
}

P _bimElementIndexDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _bimElementIndexGetId(BimElementIndex object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _bimElementIndexGetLinks(BimElementIndex object) {
  return [];
}

void _bimElementIndexAttach(
  IsarCollection<dynamic> col,
  Id id,
  BimElementIndex object,
) {
  object.id = id;
}

extension BimElementIndexQueryWhereSort
    on QueryBuilder<BimElementIndex, BimElementIndex, QWhere> {
  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhere> anyScope() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'scope'),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhere> anyPackageKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'packageKey'),
      );
    });
  }
}

extension BimElementIndexQueryWhere
    on QueryBuilder<BimElementIndex, BimElementIndex, QWhereClause> {
  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhereClause>
  idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhereClause>
  scopeEqualTo(String scope) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'scope', value: [scope]),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhereClause>
  scopeNotEqualTo(String scope) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'scope',
                lower: [],
                upper: [scope],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'scope',
                lower: [scope],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'scope',
                lower: [scope],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'scope',
                lower: [],
                upper: [scope],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhereClause>
  scopeGreaterThan(String scope, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'scope',
          lower: [scope],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhereClause>
  scopeLessThan(String scope, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'scope',
          lower: [],
          upper: [scope],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhereClause>
  scopeBetween(
    String lowerScope,
    String upperScope, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'scope',
          lower: [lowerScope],
          includeLower: includeLower,
          upper: [upperScope],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhereClause>
  scopeStartsWith(String ScopePrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'scope',
          lower: [ScopePrefix],
          upper: ['$ScopePrefix\u{FFFFF}'],
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhereClause>
  scopeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'scope', value: ['']),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhereClause>
  scopeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'scope', upper: ['']),
            )
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'scope', lower: ['']),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'scope', lower: ['']),
            )
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'scope', upper: ['']),
            );
      }
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhereClause>
  packageKeyEqualTo(String packageKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'packageKey', value: [packageKey]),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhereClause>
  packageKeyNotEqualTo(String packageKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'packageKey',
                lower: [],
                upper: [packageKey],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'packageKey',
                lower: [packageKey],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'packageKey',
                lower: [packageKey],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'packageKey',
                lower: [],
                upper: [packageKey],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhereClause>
  packageKeyGreaterThan(String packageKey, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'packageKey',
          lower: [packageKey],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhereClause>
  packageKeyLessThan(String packageKey, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'packageKey',
          lower: [],
          upper: [packageKey],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhereClause>
  packageKeyBetween(
    String lowerPackageKey,
    String upperPackageKey, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'packageKey',
          lower: [lowerPackageKey],
          includeLower: includeLower,
          upper: [upperPackageKey],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhereClause>
  packageKeyStartsWith(String PackageKeyPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'packageKey',
          lower: [PackageKeyPrefix],
          upper: ['$PackageKeyPrefix\u{FFFFF}'],
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhereClause>
  packageKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'packageKey', value: ['']),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterWhereClause>
  packageKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'packageKey', upper: ['']),
            )
            .addWhereClause(
              IndexWhereClause.greaterThan(
                indexName: r'packageKey',
                lower: [''],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.greaterThan(
                indexName: r'packageKey',
                lower: [''],
              ),
            )
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'packageKey', upper: ['']),
            );
      }
    });
  }
}

extension BimElementIndexQueryFilter
    on QueryBuilder<BimElementIndex, BimElementIndex, QFilterCondition> {
  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  expressIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'expressId', value: value),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  expressIdGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'expressId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  expressIdLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'expressId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  expressIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'expressId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  lengthEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'length', value: value),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  lengthGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'length',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  lengthLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'length',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  lengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'length',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  offsetEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'offset', value: value),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  offsetGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'offset',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  offsetLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'offset',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  offsetBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'offset',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  packageKeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'packageKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  packageKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'packageKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  packageKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'packageKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  packageKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'packageKey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  packageKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'packageKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  packageKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'packageKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  packageKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'packageKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  packageKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'packageKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  packageKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'packageKey', value: ''),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  packageKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'packageKey', value: ''),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  scopeEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'scope',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  scopeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'scope',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  scopeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'scope',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  scopeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'scope',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  scopeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'scope',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  scopeEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'scope',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  scopeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'scope',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  scopeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'scope',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  scopeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'scope', value: ''),
      );
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterFilterCondition>
  scopeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'scope', value: ''),
      );
    });
  }
}

extension BimElementIndexQueryObject
    on QueryBuilder<BimElementIndex, BimElementIndex, QFilterCondition> {}

extension BimElementIndexQueryLinks
    on QueryBuilder<BimElementIndex, BimElementIndex, QFilterCondition> {}

extension BimElementIndexQuerySortBy
    on QueryBuilder<BimElementIndex, BimElementIndex, QSortBy> {
  QueryBuilder<BimElementIndex, BimElementIndex, QAfterSortBy>
  sortByExpressId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expressId', Sort.asc);
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterSortBy>
  sortByExpressIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expressId', Sort.desc);
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterSortBy> sortByLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'length', Sort.asc);
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterSortBy>
  sortByLengthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'length', Sort.desc);
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterSortBy> sortByOffset() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'offset', Sort.asc);
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterSortBy>
  sortByOffsetDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'offset', Sort.desc);
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterSortBy>
  sortByPackageKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'packageKey', Sort.asc);
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterSortBy>
  sortByPackageKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'packageKey', Sort.desc);
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterSortBy> sortByScope() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scope', Sort.asc);
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterSortBy>
  sortByScopeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scope', Sort.desc);
    });
  }
}

extension BimElementIndexQuerySortThenBy
    on QueryBuilder<BimElementIndex, BimElementIndex, QSortThenBy> {
  QueryBuilder<BimElementIndex, BimElementIndex, QAfterSortBy>
  thenByExpressId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expressId', Sort.asc);
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterSortBy>
  thenByExpressIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expressId', Sort.desc);
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterSortBy> thenByLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'length', Sort.asc);
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterSortBy>
  thenByLengthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'length', Sort.desc);
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterSortBy> thenByOffset() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'offset', Sort.asc);
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterSortBy>
  thenByOffsetDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'offset', Sort.desc);
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterSortBy>
  thenByPackageKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'packageKey', Sort.asc);
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterSortBy>
  thenByPackageKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'packageKey', Sort.desc);
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterSortBy> thenByScope() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scope', Sort.asc);
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QAfterSortBy>
  thenByScopeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scope', Sort.desc);
    });
  }
}

extension BimElementIndexQueryWhereDistinct
    on QueryBuilder<BimElementIndex, BimElementIndex, QDistinct> {
  QueryBuilder<BimElementIndex, BimElementIndex, QDistinct>
  distinctByExpressId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'expressId');
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QDistinct> distinctByLength() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'length');
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QDistinct> distinctByOffset() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'offset');
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QDistinct>
  distinctByPackageKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'packageKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<BimElementIndex, BimElementIndex, QDistinct> distinctByScope({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'scope', caseSensitive: caseSensitive);
    });
  }
}

extension BimElementIndexQueryProperty
    on QueryBuilder<BimElementIndex, BimElementIndex, QQueryProperty> {
  QueryBuilder<BimElementIndex, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<BimElementIndex, int, QQueryOperations> expressIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'expressId');
    });
  }

  QueryBuilder<BimElementIndex, int, QQueryOperations> lengthProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'length');
    });
  }

  QueryBuilder<BimElementIndex, int, QQueryOperations> offsetProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'offset');
    });
  }

  QueryBuilder<BimElementIndex, String, QQueryOperations> packageKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'packageKey');
    });
  }

  QueryBuilder<BimElementIndex, String, QQueryOperations> scopeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'scope');
    });
  }
}
