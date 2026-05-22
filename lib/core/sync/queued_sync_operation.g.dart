// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queued_sync_operation.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetQueuedSyncOperationCollection on Isar {
  IsarCollection<QueuedSyncOperation> get queuedSyncOperations =>
      this.collection();
}

const QueuedSyncOperationSchema = CollectionSchema(
  name: r'QueuedSyncOperation',
  id: -1342737641207922496,
  properties: {
    r'attachmentsJson': PropertySchema(
      id: 0,
      name: r'attachmentsJson',
      type: IsarType.string,
    ),
    r'attemptCount': PropertySchema(
      id: 1,
      name: r'attemptCount',
      type: IsarType.long,
    ),
    r'createdAt': PropertySchema(
      id: 2,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'endpoint': PropertySchema(
      id: 3,
      name: r'endpoint',
      type: IsarType.string,
    ),
    r'lastAttemptAt': PropertySchema(
      id: 4,
      name: r'lastAttemptAt',
      type: IsarType.dateTime,
    ),
    r'lastBusinessError': PropertySchema(
      id: 5,
      name: r'lastBusinessError',
      type: IsarType.string,
    ),
    r'localAttachments': PropertySchema(
      id: 6,
      name: r'localAttachments',
      type: IsarType.stringList,
    ),
    r'method': PropertySchema(id: 7, name: r'method', type: IsarType.string),
    r'moduleSlug': PropertySchema(
      id: 8,
      name: r'moduleSlug',
      type: IsarType.string,
    ),
    r'nextAttemptAt': PropertySchema(
      id: 9,
      name: r'nextAttemptAt',
      type: IsarType.dateTime,
    ),
    r'operationType': PropertySchema(
      id: 10,
      name: r'operationType',
      type: IsarType.string,
    ),
    r'payloadJson': PropertySchema(
      id: 11,
      name: r'payloadJson',
      type: IsarType.string,
    ),
    r'status': PropertySchema(id: 12, name: r'status', type: IsarType.string),
  },
  estimateSize: _queuedSyncOperationEstimateSize,
  serialize: _queuedSyncOperationSerialize,
  deserialize: _queuedSyncOperationDeserialize,
  deserializeProp: _queuedSyncOperationDeserializeProp,
  idName: r'id',
  indexes: {
    r'moduleSlug': IndexSchema(
      id: 5592013439354742106,
      name: r'moduleSlug',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'moduleSlug',
          type: IndexType.value,
          caseSensitive: true,
        ),
      ],
    ),
    r'operationType': IndexSchema(
      id: 7940488376024458150,
      name: r'operationType',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'operationType',
          type: IndexType.value,
          caseSensitive: true,
        ),
      ],
    ),
    r'status': IndexSchema(
      id: -107785170620420283,
      name: r'status',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'status',
          type: IndexType.value,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},
  getId: _queuedSyncOperationGetId,
  getLinks: _queuedSyncOperationGetLinks,
  attach: _queuedSyncOperationAttach,
  version: '3.1.0+1',
);

int _queuedSyncOperationEstimateSize(
  QueuedSyncOperation object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.attachmentsJson.length * 3;
  bytesCount += 3 + object.endpoint.length * 3;
  {
    final value = object.lastBusinessError;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.localAttachments.length * 3;
  {
    for (var i = 0; i < object.localAttachments.length; i++) {
      final value = object.localAttachments[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.method.length * 3;
  bytesCount += 3 + object.moduleSlug.length * 3;
  bytesCount += 3 + object.operationType.length * 3;
  bytesCount += 3 + object.payloadJson.length * 3;
  bytesCount += 3 + object.status.length * 3;
  return bytesCount;
}

void _queuedSyncOperationSerialize(
  QueuedSyncOperation object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.attachmentsJson);
  writer.writeLong(offsets[1], object.attemptCount);
  writer.writeDateTime(offsets[2], object.createdAt);
  writer.writeString(offsets[3], object.endpoint);
  writer.writeDateTime(offsets[4], object.lastAttemptAt);
  writer.writeString(offsets[5], object.lastBusinessError);
  writer.writeStringList(offsets[6], object.localAttachments);
  writer.writeString(offsets[7], object.method);
  writer.writeString(offsets[8], object.moduleSlug);
  writer.writeDateTime(offsets[9], object.nextAttemptAt);
  writer.writeString(offsets[10], object.operationType);
  writer.writeString(offsets[11], object.payloadJson);
  writer.writeString(offsets[12], object.status);
}

QueuedSyncOperation _queuedSyncOperationDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = QueuedSyncOperation();
  object.attachmentsJson = reader.readString(offsets[0]);
  object.attemptCount = reader.readLong(offsets[1]);
  object.createdAt = reader.readDateTime(offsets[2]);
  object.endpoint = reader.readString(offsets[3]);
  object.id = id;
  object.lastAttemptAt = reader.readDateTimeOrNull(offsets[4]);
  object.lastBusinessError = reader.readStringOrNull(offsets[5]);
  object.localAttachments = reader.readStringList(offsets[6]) ?? [];
  object.method = reader.readString(offsets[7]);
  object.moduleSlug = reader.readString(offsets[8]);
  object.nextAttemptAt = reader.readDateTimeOrNull(offsets[9]);
  object.operationType = reader.readString(offsets[10]);
  object.payloadJson = reader.readString(offsets[11]);
  object.status = reader.readString(offsets[12]);
  return object;
}

P _queuedSyncOperationDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readDateTime(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readStringList(offset) ?? []) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _queuedSyncOperationGetId(QueuedSyncOperation object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _queuedSyncOperationGetLinks(
  QueuedSyncOperation object,
) {
  return [];
}

void _queuedSyncOperationAttach(
  IsarCollection<dynamic> col,
  Id id,
  QueuedSyncOperation object,
) {
  object.id = id;
}

extension QueuedSyncOperationQueryWhereSort
    on QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QWhere> {
  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhere>
  anyModuleSlug() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'moduleSlug'),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhere>
  anyOperationType() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'operationType'),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhere>
  anyStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'status'),
      );
    });
  }
}

extension QueuedSyncOperationQueryWhere
    on QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QWhereClause> {
  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
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

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  idBetween(
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

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  moduleSlugEqualTo(String moduleSlug) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'moduleSlug', value: [moduleSlug]),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  moduleSlugNotEqualTo(String moduleSlug) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'moduleSlug',
                lower: [],
                upper: [moduleSlug],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'moduleSlug',
                lower: [moduleSlug],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'moduleSlug',
                lower: [moduleSlug],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'moduleSlug',
                lower: [],
                upper: [moduleSlug],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  moduleSlugGreaterThan(String moduleSlug, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'moduleSlug',
          lower: [moduleSlug],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  moduleSlugLessThan(String moduleSlug, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'moduleSlug',
          lower: [],
          upper: [moduleSlug],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  moduleSlugBetween(
    String lowerModuleSlug,
    String upperModuleSlug, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'moduleSlug',
          lower: [lowerModuleSlug],
          includeLower: includeLower,
          upper: [upperModuleSlug],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  moduleSlugStartsWith(String ModuleSlugPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'moduleSlug',
          lower: [ModuleSlugPrefix],
          upper: ['$ModuleSlugPrefix\u{FFFFF}'],
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  moduleSlugIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'moduleSlug', value: ['']),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  moduleSlugIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'moduleSlug', upper: ['']),
            )
            .addWhereClause(
              IndexWhereClause.greaterThan(
                indexName: r'moduleSlug',
                lower: [''],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.greaterThan(
                indexName: r'moduleSlug',
                lower: [''],
              ),
            )
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'moduleSlug', upper: ['']),
            );
      }
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  operationTypeEqualTo(String operationType) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'operationType',
          value: [operationType],
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  operationTypeNotEqualTo(String operationType) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'operationType',
                lower: [],
                upper: [operationType],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'operationType',
                lower: [operationType],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'operationType',
                lower: [operationType],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'operationType',
                lower: [],
                upper: [operationType],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  operationTypeGreaterThan(String operationType, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'operationType',
          lower: [operationType],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  operationTypeLessThan(String operationType, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'operationType',
          lower: [],
          upper: [operationType],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  operationTypeBetween(
    String lowerOperationType,
    String upperOperationType, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'operationType',
          lower: [lowerOperationType],
          includeLower: includeLower,
          upper: [upperOperationType],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  operationTypeStartsWith(String OperationTypePrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'operationType',
          lower: [OperationTypePrefix],
          upper: ['$OperationTypePrefix\u{FFFFF}'],
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  operationTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'operationType', value: ['']),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  operationTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.lessThan(
                indexName: r'operationType',
                upper: [''],
              ),
            )
            .addWhereClause(
              IndexWhereClause.greaterThan(
                indexName: r'operationType',
                lower: [''],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.greaterThan(
                indexName: r'operationType',
                lower: [''],
              ),
            )
            .addWhereClause(
              IndexWhereClause.lessThan(
                indexName: r'operationType',
                upper: [''],
              ),
            );
      }
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  statusEqualTo(String status) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'status', value: [status]),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  statusNotEqualTo(String status) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'status',
                lower: [],
                upper: [status],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'status',
                lower: [status],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'status',
                lower: [status],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'status',
                lower: [],
                upper: [status],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  statusGreaterThan(String status, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'status',
          lower: [status],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  statusLessThan(String status, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'status',
          lower: [],
          upper: [status],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  statusBetween(
    String lowerStatus,
    String upperStatus, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'status',
          lower: [lowerStatus],
          includeLower: includeLower,
          upper: [upperStatus],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  statusStartsWith(String StatusPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'status',
          lower: [StatusPrefix],
          upper: ['$StatusPrefix\u{FFFFF}'],
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'status', value: ['']),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterWhereClause>
  statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'status', upper: ['']),
            )
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'status', lower: ['']),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'status', lower: ['']),
            )
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'status', upper: ['']),
            );
      }
    });
  }
}

extension QueuedSyncOperationQueryFilter
    on
        QueryBuilder<
          QueuedSyncOperation,
          QueuedSyncOperation,
          QFilterCondition
        > {
  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  attachmentsJsonEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'attachmentsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  attachmentsJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'attachmentsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  attachmentsJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'attachmentsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  attachmentsJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'attachmentsJson',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  attachmentsJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'attachmentsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  attachmentsJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'attachmentsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  attachmentsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'attachmentsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  attachmentsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'attachmentsJson',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  attachmentsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'attachmentsJson', value: ''),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  attachmentsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'attachmentsJson', value: ''),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  attemptCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'attemptCount', value: value),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  attemptCountGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'attemptCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  attemptCountLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'attemptCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  attemptCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'attemptCount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  createdAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  createdAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  endpointEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'endpoint',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  endpointGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'endpoint',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  endpointLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'endpoint',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  endpointBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'endpoint',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  endpointStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'endpoint',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  endpointEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'endpoint',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  endpointContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'endpoint',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  endpointMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'endpoint',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  endpointIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'endpoint', value: ''),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  endpointIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'endpoint', value: ''),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
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

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
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

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
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

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  lastAttemptAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastAttemptAt'),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  lastAttemptAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastAttemptAt'),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  lastAttemptAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastAttemptAt', value: value),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  lastAttemptAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastAttemptAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  lastAttemptAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastAttemptAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  lastAttemptAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastAttemptAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  lastBusinessErrorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastBusinessError'),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  lastBusinessErrorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastBusinessError'),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  lastBusinessErrorEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lastBusinessError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  lastBusinessErrorGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastBusinessError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  lastBusinessErrorLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastBusinessError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  lastBusinessErrorBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastBusinessError',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  lastBusinessErrorStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'lastBusinessError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  lastBusinessErrorEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'lastBusinessError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  lastBusinessErrorContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'lastBusinessError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  lastBusinessErrorMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'lastBusinessError',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  lastBusinessErrorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastBusinessError', value: ''),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  lastBusinessErrorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'lastBusinessError', value: ''),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  localAttachmentsElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'localAttachments',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  localAttachmentsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'localAttachments',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  localAttachmentsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'localAttachments',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  localAttachmentsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'localAttachments',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  localAttachmentsElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'localAttachments',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  localAttachmentsElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'localAttachments',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  localAttachmentsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'localAttachments',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  localAttachmentsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'localAttachments',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  localAttachmentsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'localAttachments', value: ''),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  localAttachmentsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'localAttachments', value: ''),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  localAttachmentsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'localAttachments', length, true, length, true);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  localAttachmentsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'localAttachments', 0, true, 0, true);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  localAttachmentsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'localAttachments', 0, false, 999999, true);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  localAttachmentsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'localAttachments', 0, true, length, include);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  localAttachmentsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'localAttachments',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  localAttachmentsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'localAttachments',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  methodEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'method',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  methodGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'method',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  methodLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'method',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  methodBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'method',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  methodStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'method',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  methodEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'method',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  methodContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'method',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  methodMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'method',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  methodIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'method', value: ''),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  methodIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'method', value: ''),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  moduleSlugEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'moduleSlug',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  moduleSlugGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'moduleSlug',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  moduleSlugLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'moduleSlug',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  moduleSlugBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'moduleSlug',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  moduleSlugStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'moduleSlug',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  moduleSlugEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'moduleSlug',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  moduleSlugContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'moduleSlug',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  moduleSlugMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'moduleSlug',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  moduleSlugIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'moduleSlug', value: ''),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  moduleSlugIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'moduleSlug', value: ''),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  nextAttemptAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'nextAttemptAt'),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  nextAttemptAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'nextAttemptAt'),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  nextAttemptAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'nextAttemptAt', value: value),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
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

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
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

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
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

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  operationTypeEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'operationType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  operationTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'operationType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  operationTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'operationType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  operationTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'operationType',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  operationTypeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'operationType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  operationTypeEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'operationType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  operationTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'operationType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  operationTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'operationType',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  operationTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'operationType', value: ''),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  operationTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'operationType', value: ''),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  payloadJsonEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  payloadJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  payloadJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  payloadJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'payloadJson',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  payloadJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  payloadJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  payloadJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  payloadJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'payloadJson',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  payloadJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'payloadJson', value: ''),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  payloadJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'payloadJson', value: ''),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
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

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
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

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
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

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
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

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
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

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
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

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
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

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
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

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'status', value: ''),
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterFilterCondition>
  statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'status', value: ''),
      );
    });
  }
}

extension QueuedSyncOperationQueryObject
    on
        QueryBuilder<
          QueuedSyncOperation,
          QueuedSyncOperation,
          QFilterCondition
        > {}

extension QueuedSyncOperationQueryLinks
    on
        QueryBuilder<
          QueuedSyncOperation,
          QueuedSyncOperation,
          QFilterCondition
        > {}

extension QueuedSyncOperationQuerySortBy
    on QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QSortBy> {
  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByAttachmentsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentsJson', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByAttachmentsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentsJson', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByAttemptCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByAttemptCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByEndpoint() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endpoint', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByEndpointDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endpoint', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByLastAttemptAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAttemptAt', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByLastAttemptAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAttemptAt', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByLastBusinessError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastBusinessError', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByLastBusinessErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastBusinessError', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByMethod() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'method', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByMethodDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'method', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByModuleSlug() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleSlug', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByModuleSlugDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleSlug', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByNextAttemptAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextAttemptAt', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByNextAttemptAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextAttemptAt', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByOperationType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'operationType', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByOperationTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'operationType', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByPayloadJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByPayloadJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }
}

extension QueuedSyncOperationQuerySortThenBy
    on QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QSortThenBy> {
  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByAttachmentsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentsJson', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByAttachmentsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attachmentsJson', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByAttemptCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByAttemptCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptCount', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByEndpoint() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endpoint', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByEndpointDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endpoint', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByLastAttemptAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAttemptAt', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByLastAttemptAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAttemptAt', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByLastBusinessError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastBusinessError', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByLastBusinessErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastBusinessError', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByMethod() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'method', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByMethodDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'method', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByModuleSlug() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleSlug', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByModuleSlugDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleSlug', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByNextAttemptAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextAttemptAt', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByNextAttemptAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextAttemptAt', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByOperationType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'operationType', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByOperationTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'operationType', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByPayloadJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByPayloadJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.desc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QAfterSortBy>
  thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }
}

extension QueuedSyncOperationQueryWhereDistinct
    on QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QDistinct> {
  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QDistinct>
  distinctByAttachmentsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'attachmentsJson',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QDistinct>
  distinctByAttemptCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attemptCount');
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QDistinct>
  distinctByEndpoint({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'endpoint', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QDistinct>
  distinctByLastAttemptAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastAttemptAt');
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QDistinct>
  distinctByLastBusinessError({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'lastBusinessError',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QDistinct>
  distinctByLocalAttachments() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'localAttachments');
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QDistinct>
  distinctByMethod({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'method', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QDistinct>
  distinctByModuleSlug({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'moduleSlug', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QDistinct>
  distinctByNextAttemptAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nextAttemptAt');
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QDistinct>
  distinctByOperationType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'operationType',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QDistinct>
  distinctByPayloadJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'payloadJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QDistinct>
  distinctByStatus({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }
}

extension QueuedSyncOperationQueryProperty
    on QueryBuilder<QueuedSyncOperation, QueuedSyncOperation, QQueryProperty> {
  QueryBuilder<QueuedSyncOperation, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<QueuedSyncOperation, String, QQueryOperations>
  attachmentsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attachmentsJson');
    });
  }

  QueryBuilder<QueuedSyncOperation, int, QQueryOperations>
  attemptCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attemptCount');
    });
  }

  QueryBuilder<QueuedSyncOperation, DateTime, QQueryOperations>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<QueuedSyncOperation, String, QQueryOperations>
  endpointProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'endpoint');
    });
  }

  QueryBuilder<QueuedSyncOperation, DateTime?, QQueryOperations>
  lastAttemptAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastAttemptAt');
    });
  }

  QueryBuilder<QueuedSyncOperation, String?, QQueryOperations>
  lastBusinessErrorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastBusinessError');
    });
  }

  QueryBuilder<QueuedSyncOperation, List<String>, QQueryOperations>
  localAttachmentsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'localAttachments');
    });
  }

  QueryBuilder<QueuedSyncOperation, String, QQueryOperations> methodProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'method');
    });
  }

  QueryBuilder<QueuedSyncOperation, String, QQueryOperations>
  moduleSlugProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'moduleSlug');
    });
  }

  QueryBuilder<QueuedSyncOperation, DateTime?, QQueryOperations>
  nextAttemptAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nextAttemptAt');
    });
  }

  QueryBuilder<QueuedSyncOperation, String, QQueryOperations>
  operationTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'operationType');
    });
  }

  QueryBuilder<QueuedSyncOperation, String, QQueryOperations>
  payloadJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'payloadJson');
    });
  }

  QueryBuilder<QueuedSyncOperation, String, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }
}
