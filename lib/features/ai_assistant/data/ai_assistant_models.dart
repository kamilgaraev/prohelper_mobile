class AiUsageModel {
  const AiUsageModel({
    required this.monthlyLimit,
    required this.used,
    required this.remaining,
    required this.percentageUsed,
    this.tokensUsed,
    this.costRub,
    this.billingContractVersion,
    this.limitingResource,
    this.usageKind,
  });

  final int? monthlyLimit;
  final int used;
  final int? remaining;
  final double? percentageUsed;
  final int? tokensUsed;
  final double? costRub;
  final int? billingContractVersion;
  final String? limitingResource;
  final String? usageKind;

  factory AiUsageModel.fromJson(Map<String, dynamic> json) {
    return AiUsageModel(
      monthlyLimit: _nullableInt(json['monthly_limit']),
      used: _intValue(json['used']),
      remaining: _nullableInt(json['remaining']),
      percentageUsed: _nullableDouble(json['percentage_used']),
      tokensUsed: _nullableInt(json['tokens_used']),
      costRub: _nullableDouble(json['cost_rub']),
      billingContractVersion: _nullableInt(json['billing_contract_version']),
      limitingResource: _stringValue(json['limiting_resource']),
      usageKind: _stringValue(json['usage_kind']),
    );
  }
}

class AiConversationModel {
  const AiConversationModel({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.messagesCount = 0,
    this.uuid,
    this.canWrite = true,
    this.canManageParticipants = false,
    this.scope = 'personal',
  });

  final int id;
  final String title;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final int messagesCount;
  final String? uuid;
  final bool canWrite;
  final bool canManageParticipants;
  final String scope;

  String get stableId => uuid ?? id.toString();

  factory AiConversationModel.fromJson(Map<String, dynamic> json) {
    return AiConversationModel(
      id: _intValue(json['id']),
      title: (json['title'] as String? ?? '').trim(),
      createdAt: _dateTimeValue(json['created_at']),
      updatedAt: _dateTimeValue(json['updated_at']),
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageAt: _dateTimeValue(json['last_message_at']),
      messagesCount: _intValue(json['messages_count']),
      uuid: _stringValue(json['uuid']),
      canWrite: _boolValue(json['can_write'] ?? json['can_edit']),
      canManageParticipants: _boolValue(json['can_manage_participants']),
      scope: _stringValue(json['scope']) ?? 'personal',
    );
  }
}

class AiMessageModel {
  const AiMessageModel({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.metadata,
    this.structuredPayload,
    this.attachments = const <AiImageAttachmentModel>[],
  });

  final int id;
  final String role;
  final String content;
  final DateTime? createdAt;
  final Map<String, dynamic>? metadata;
  final AiAssistantStructuredPayload? structuredPayload;
  final List<AiImageAttachmentModel> attachments;

  String get validationStatus =>
      _stringValue(metadata?['validation_status']) ?? 'unverified';

  List<AiAssistantEvidenceModel> get evidence => [
        ..._asList(metadata?['source_refs']),
        ..._asList(_nullableMap(metadata?['rag_context'])?['sources']),
      ]
      .map(AiAssistantEvidenceModel.fromJson)
      .whereType<AiAssistantEvidenceModel>()
      .toList(growable: false);

  List<AiAssistantSelectedEntity> get selectedEntities =>
      _asList(metadata?['entity_references'])
          .map(AiAssistantSelectedEntity.fromJson)
          .whereType<AiAssistantSelectedEntity>()
          .toList(growable: false);

  bool get isUser => role == 'user';
  List<AiAssistantArtifact> get artifacts =>
      structuredPayload?.artifacts ?? const <AiAssistantArtifact>[];
  List<AiAssistantActionModel> get actions =>
      structuredPayload?.actions ?? const <AiAssistantActionModel>[];

  factory AiMessageModel.fromJson(Map<String, dynamic> json) {
    final metadata = _nullableMap(json['metadata']);

    return AiMessageModel(
      id: _intValue(json['id']),
      role: (json['role'] as String? ?? '').trim(),
      content: (json['content'] as String? ?? '').trim(),
      createdAt: _dateTimeValue(json['created_at']),
      metadata: metadata,
      structuredPayload: AiAssistantStructuredPayload.fromMetadata(metadata),
      attachments: _asList(json['attachments'])
          .map(
            (item) =>
                AiImageAttachmentModel.fromJson(_nullableMap(item) ?? const {}),
          )
          .toList(growable: false),
    );
  }
}

class AiImageAttachmentModel {
  const AiImageAttachmentModel({
    required this.id,
    required this.name,
    required this.mime,
    required this.size,
    this.width,
    this.height,
  });

  final String id;
  final String name;
  final String mime;
  final int size;
  final int? width;
  final int? height;

  factory AiImageAttachmentModel.fromJson(Map<String, dynamic> json) =>
      AiImageAttachmentModel(
        id: _stringValue(json['id']) ?? '',
        name: _stringValue(json['name']) ?? 'Изображение',
        mime: _stringValue(json['mime']) ?? 'image/jpeg',
        size: _intValue(json['size']),
        width: _nullableInt(json['width']),
        height: _nullableInt(json['height']),
      );
}

class AiAssistantStructuredPayload {
  const AiAssistantStructuredPayload({
    this.answer,
    this.artifacts = const <AiAssistantArtifact>[],
    this.actions = const <AiAssistantActionModel>[],
    this.raw = const <String, dynamic>{},
  });

  final String? answer;
  final List<AiAssistantArtifact> artifacts;
  final List<AiAssistantActionModel> actions;
  final Map<String, dynamic> raw;

  factory AiAssistantStructuredPayload.fromMetadata(
    Map<String, dynamic>? metadata,
  ) {
    if (metadata == null || metadata.isEmpty) {
      return const AiAssistantStructuredPayload();
    }

    final nested = _nullableMap(metadata['structured_payload']);
    final payload =
        nested == null ? metadata : <String, dynamic>{...metadata, ...nested};
    final artifacts = _asList(payload['artifacts'])
        .map(AiAssistantArtifact.fromJson)
        .where((artifact) => artifact != null)
        .cast<AiAssistantArtifact>()
        .toList(growable: false);
    final actions = [
          ..._asList(payload['next_actions']),
          ..._asList(payload['proposed_actions']),
        ]
        .map(AiAssistantActionModel.fromJson)
        .where((action) => action != null)
        .cast<AiAssistantActionModel>()
        .toList(growable: false);

    return AiAssistantStructuredPayload(
      answer: _stringValue(payload['answer']),
      artifacts: artifacts,
      actions: actions,
      raw: payload,
    );
  }
}

class AiAssistantActionModel {
  const AiAssistantActionModel({
    this.id,
    required this.type,
    required this.label,
    required this.allowed,
    this.reasonIfDisabled,
    required this.requiresConfirmation,
    required this.actionClass,
    this.toolName,
    this.arguments = const <String, dynamic>{},
    this.requiredPermissions = const <String>[],
    this.target,
    this.raw = const <String, dynamic>{},
  });

  final String? id;
  final String type;
  final String label;
  final bool allowed;
  final String? reasonIfDisabled;
  final bool requiresConfirmation;
  final String actionClass;
  final String? toolName;
  final Map<String, dynamic> arguments;
  final List<String> requiredPermissions;
  final Map<String, dynamic>? target;
  final Map<String, dynamic> raw;

  bool get isExecutableCandidate =>
      allowed && (type == 'navigate' || (toolName?.isNotEmpty ?? false));

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'type': type,
      'label': label,
      'allowed': allowed,
      if (reasonIfDisabled != null) 'reason_if_disabled': reasonIfDisabled,
      'requires_confirmation': requiresConfirmation,
      'action_class': actionClass,
      if (toolName != null) 'tool_name': toolName,
      if (arguments.isNotEmpty) 'arguments': arguments,
      if (requiredPermissions.isNotEmpty)
        'required_permissions': requiredPermissions,
      if (target != null) 'target': target,
    };
  }

  static AiAssistantActionModel? fromJson(dynamic value) {
    final json = _nullableMap(value);
    if (json == null) {
      return null;
    }

    final label =
        _stringValue(json['label']) ??
        (json['tool_name'] == null ? null : 'Изменить данные');
    final type =
        _stringValue(json['type']) ??
        (json['tool_name'] == null ? null : 'action');

    if (label == null || type == null) {
      return null;
    }

    return AiAssistantActionModel(
      id: _stringValue(json['id']),
      type: type,
      label: label,
      allowed: _boolValue(json['allowed']),
      reasonIfDisabled: _stringValue(json['reason_if_disabled']),
      requiresConfirmation: _boolValue(json['requires_confirmation']),
      actionClass: _stringValue(json['action_class']) ?? 'safe',
      toolName: _stringValue(json['tool_name']),
      arguments: _nullableMap(json['arguments']) ?? const <String, dynamic>{},
      requiredPermissions: _asList(json['required_permissions'])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      target: _nullableMap(json['target']),
      raw: json,
    );
  }
}

class AiActionSummaryItem {
  const AiActionSummaryItem({required this.label, required this.value});

  final String label;
  final String value;

  static AiActionSummaryItem? fromJson(dynamic value) {
    final json = _nullableMap(value);
    if (json == null) {
      return null;
    }

    final label = _stringValue(json['label']);
    final itemValue = _stringValue(json['value']);

    if (label == null || itemValue == null) {
      return null;
    }

    return AiActionSummaryItem(label: label, value: itemValue);
  }
}

class AiActionPreviewModel {
  const AiActionPreviewModel({
    required this.title,
    required this.description,
    required this.requiresConfirmation,
    required this.actionClass,
    required this.action,
    required this.warnings,
    required this.summaryItems,
    this.navigationTarget,
    required this.executable,
    required this.previewToken,
    this.raw = const <String, dynamic>{},
  });

  final String title;
  final String description;
  final bool requiresConfirmation;
  final String actionClass;
  final AiAssistantActionModel action;
  final List<String> warnings;
  final List<AiActionSummaryItem> summaryItems;
  final Map<String, dynamic>? navigationTarget;
  final bool executable;
  final String previewToken;
  final Map<String, dynamic> raw;

  factory AiActionPreviewModel.fromJson(Map<String, dynamic> json) {
    final action = AiAssistantActionModel.fromJson(json['action']);
    final token = _stringValue(json['preview_token']);

    if (action == null || token == null) {
      throw const FormatException(
        'Некорректный предварительный просмотр действия.',
      );
    }

    return AiActionPreviewModel(
      title: _stringValue(json['title']) ?? action.label,
      description: _stringValue(json['description']) ?? '',
      requiresConfirmation: _boolValue(json['requires_confirmation']),
      actionClass: _stringValue(json['action_class']) ?? action.actionClass,
      action: action,
      warnings: _asList(json['warnings'])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      summaryItems: _asList(json['summary_items'])
          .map(AiActionSummaryItem.fromJson)
          .where((item) => item != null)
          .cast<AiActionSummaryItem>()
          .toList(growable: false),
      navigationTarget: _nullableMap(json['navigation_target']),
      executable: _boolValue(json['executable']),
      previewToken: token,
      raw: json,
    );
  }
}

class AiActionExecutionModel {
  const AiActionExecutionModel({
    this.messageText,
    this.message,
    this.navigationTarget,
    this.action,
    this.result,
    this.raw = const <String, dynamic>{},
  });

  final String? messageText;
  final AiMessageModel? message;
  final Map<String, dynamic>? navigationTarget;
  final AiAssistantActionModel? action;
  final Object? result;
  final Map<String, dynamic> raw;

  factory AiActionExecutionModel.fromJson(Map<String, dynamic> json) {
    final messagePayload = _nullableMap(json['message']);

    return AiActionExecutionModel(
      messageText:
          json['message'] is String
              ? _stringValue(json['message'])
              : _stringValue(messagePayload?['content']),
      message:
          messagePayload == null
              ? null
              : AiMessageModel.fromJson(messagePayload),
      navigationTarget: _nullableMap(json['navigation_target']),
      action: AiAssistantActionModel.fromJson(json['action']),
      result: json['result'],
      raw: json,
    );
  }
}

class AiAssistantArtifact {
  const AiAssistantArtifact({
    this.id,
    this.title,
    this.name,
    this.filename,
    this.fileName,
    this.type,
    this.mimeType,
    this.url,
    this.href,
    this.path,
    this.downloadUrl,
    this.storageDisk,
    this.storagePath,
    this.expiresAt,
    this.reportType,
    this.filters = const <String, dynamic>{},
    this.sourceTool,
    this.reportFileId,
    this.size,
    this.raw = const <String, dynamic>{},
  });

  final Object? id;
  final String? title;
  final String? name;
  final String? filename;
  final String? fileName;
  final String? type;
  final String? mimeType;
  final String? url;
  final String? href;
  final String? path;
  final String? downloadUrl;
  final String? storageDisk;
  final String? storagePath;
  final String? expiresAt;
  final String? reportType;
  final Map<String, dynamic> filters;
  final String? sourceTool;
  final Object? reportFileId;
  final int? size;
  final Map<String, dynamic> raw;

  bool get isReport =>
      reportType != null ||
      (sourceTool?.startsWith('generate_') ?? false) ||
      (storagePath?.contains('/reports/') ?? false);

  String? get trustedUrl {
    final candidate = downloadUrl ?? url ?? href ?? path;
    final uri = Uri.tryParse(candidate ?? '');

    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }

    return uri.toString();
  }

  String get displayTitle {
    final value = title ?? name ?? filename ?? fileName;

    if (value == null || value.trim().isEmpty) {
      return 'Отчет';
    }

    return value.trim();
  }

  static AiAssistantArtifact? fromJson(dynamic value) {
    final json = _nullableMap(value);
    if (json == null) {
      return null;
    }

    return AiAssistantArtifact(
      id: json['id'] is int || json['id'] is String ? json['id'] : null,
      title: _stringValue(json['title']),
      name: _stringValue(json['name']),
      filename: _stringValue(json['filename']),
      fileName: _stringValue(json['file_name']),
      type: _stringValue(json['type']),
      mimeType: _stringValue(json['mime_type']),
      url: _stringValue(json['url']),
      href: _stringValue(json['href']),
      path: _stringValue(json['path']),
      downloadUrl: _stringValue(json['download_url']),
      storageDisk: _stringValue(json['storage_disk']),
      storagePath: _stringValue(json['storage_path']),
      expiresAt: _stringValue(json['expires_at']),
      reportType: _stringValue(json['report_type']),
      filters: _nullableMap(json['filters']) ?? const <String, dynamic>{},
      sourceTool: _stringValue(json['source_tool']),
      reportFileId:
          json['report_file_id'] is int || json['report_file_id'] is String
              ? json['report_file_id']
              : null,
      size: _nullableInt(json['size']),
      raw: json,
    );
  }
}

class AiConversationDetailsModel {
  const AiConversationDetailsModel({
    required this.conversation,
    required this.messages,
  });

  final AiConversationModel conversation;
  final List<AiMessageModel> messages;
}

class AiAssistantHomeModel {
  const AiAssistantHomeModel({
    required this.usage,
    required this.conversations,
    this.nextPage,
    this.balance,
  });

  final AiUsageModel usage;
  final List<AiConversationModel> conversations;
  final int? nextPage;
  final AiCreditsBalanceModel? balance;
}

class AiAssistantPage<T> {
  const AiAssistantPage({required this.items, this.nextPage, this.total});

  final List<T> items;
  final int? nextPage;
  final int? total;

  bool get hasNextPage => nextPage != null;
}

class AiAssistantEvidenceModel {
  const AiAssistantEvidenceModel({
    required this.title,
    this.source,
    this.url,
    this.status,
    this.fetchedAt,
    this.projectId,
    this.entityId,
    this.entityType,
    this.excerpt,
  });

  final String title;
  final String? source;
  final String? url;
  final String? status;
  final DateTime? fetchedAt;
  final String? projectId;
  final String? entityId;
  final String? entityType;
  final String? excerpt;

  static AiAssistantEvidenceModel? fromJson(dynamic value) {
    final json = _nullableMap(value);
    final title =
        _stringValue(json?['title']) ??
        _stringValue(json?['label']) ??
        _sourceTitle(json);
    if (json == null || title == null) return null;
    return AiAssistantEvidenceModel(
      title: title,
      source:
          json['source'] is String
              ? _stringValue(json['source'])
              : (json['provenance'] is String
                  ? _stringValue(json['provenance'])
                  : null),
      url:
          _stringValue(_nullableMap(json['navigation'])?['url']) ??
          _stringValue(_nullableMap(json['navigation_target'])?['route']) ??
          _stringValue(json['url']),
      status: _stringValue(json['status']),
      fetchedAt: _dateTimeValue(json['fetched_at']),
      projectId: _stringValue(json['project_id']),
      entityId: _stringValue(json['entity_id'] ?? json['id']),
      entityType: _stringValue(
        json['entity_type'] ?? json['source_type'] ?? json['type'],
      ),
      excerpt: _stringValue(json['excerpt']),
    );
  }
}

class AiAssistantSelectedEntity {
  const AiAssistantSelectedEntity({
    required this.id,
    required this.type,
    required this.label,
  });

  final String id;
  final String type;
  final String label;

  static AiAssistantSelectedEntity? fromJson(dynamic value) {
    final json = _nullableMap(value);
    final id =
        _stringValue(json?['id']) ??
        _stringValue(json?['entity_id']) ??
        _stringValue(json?['uuid']);
    if (json == null || id == null) return null;
    return AiAssistantSelectedEntity(
      id: id,
      type: _stringValue(json['type'] ?? json['entity_type']) ?? 'entity',
      label: _stringValue(json['label']) ?? _stringValue(json['name']) ?? id,
    );
  }
}

class AiAssistantProgressModel {
  const AiAssistantProgressModel({
    required this.id,
    required this.code,
    required this.state,
  });

  final int id;
  final String code;
  final String state;
}

List<AiAssistantProgressModel> _assistantProgressList(dynamic value) {
  const codes = <String>{
    'rag_search',
    'estimates',
    'warehouse',
    'projects',
    'contracts',
    'procurement',
    'schedule',
    'work_volumes',
    'materials',
    'reports',
    'financial_data',
  };
  final unique = <int, AiAssistantProgressModel>{};
  final items = _asList(value);
  for (final item in items.skip(items.length > 24 ? items.length - 24 : 0)) {
    final json = _nullableMap(item);
    if (json == null) continue;
    final id = _intValue(json['id']);
    final code = _stringValue(json['code']);
    final state = _stringValue(json['state']);
    if (id <= 0 ||
        !codes.contains(code) ||
        (state != 'started' && state != 'completed')) {
      continue;
    }
    unique[id] = AiAssistantProgressModel(id: id, code: code!, state: state!);
  }
  final result =
      unique.values.toList()
        ..sort((left, right) => left.id.compareTo(right.id));
  return result.take(24).toList(growable: false);
}

class AiAssistantChatResult {
  const AiAssistantChatResult({
    required this.requestId,
    required this.conversationId,
    this.message,
    this.creditUsage,
    this.progress = const [],
  });

  final String requestId;
  final int conversationId;
  final AiMessageModel? message;
  final AiCreditUsageModel? creditUsage;
  final List<AiAssistantProgressModel> progress;

  factory AiAssistantChatResult.fromJson(Map<String, dynamic> json) {
    final messageJson = _nullableMap(json['message']);
    return AiAssistantChatResult(
      requestId: _stringValue(json['request_id']) ?? '',
      conversationId: _intValue(json['conversation_id']),
      message:
          messageJson == null ? null : AiMessageModel.fromJson(messageJson),
      creditUsage: AiCreditUsageModel.fromJson(
        _nullableMap(json['credit_usage']),
      ),
      progress: _assistantProgressList(json['progress']),
    );
  }
}

class AiAssistantChatRequest {
  const AiAssistantChatRequest({
    required this.requestId,
    required this.status,
    this.stage,
    this.progress = const [],
    this.conversationId,
    this.result,
    this.errorCode,
  });

  final String requestId;
  final String status;
  final String? stage;
  final List<AiAssistantProgressModel> progress;
  final int? conversationId;
  final AiAssistantChatResult? result;
  final String? errorCode;

  bool get isTerminal =>
      status == 'completed' || status == 'failed' || status == 'cancelled';

  factory AiAssistantChatRequest.fromJson(Map<String, dynamic> json) {
    final response = _nullableMap(json['response']);
    return AiAssistantChatRequest(
      requestId: _stringValue(json['request_id']) ?? '',
      status: _stringValue(json['status']) ?? '',
      stage: _stringValue(json['stage']),
      progress: _assistantProgressList(json['progress']),
      conversationId:
          json['conversation_id'] == null
              ? null
              : _intValue(json['conversation_id']),
      result:
          response == null ? null : AiAssistantChatResult.fromJson(response),
      errorCode: _stringValue(json['error_code']),
    );
  }
}

class AiCreditUsageModel {
  const AiCreditUsageModel({
    this.actualCharge,
    this.balance,
    this.availableAfterMinor,
    this.chargingEnabled,
  });

  final String? actualCharge;
  final AiCreditsBalanceModel? balance;
  final int? availableAfterMinor;
  final bool? chargingEnabled;

  static AiCreditUsageModel? fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    return AiCreditUsageModel(
      actualCharge: formatAiMinor(_intValue(json['charged_minor'])),
      availableAfterMinor: _nullableInt(json['available_after_minor']),
      balance: AiCreditsBalanceModel.fromJson(_nullableMap(json['balance'])),
      chargingEnabled: _nullableBool(json['charging_enabled']),
    );
  }
}

class AiCreditsBalanceModel {
  const AiCreditsBalanceModel({
    required this.organizationName,
    required this.unit,
    required this.base,
    required this.purchased,
    required this.reserved,
    required this.available,
    this.canPurchase = false,
    this.chargingEnabled = false,
    this.billingMode,
    this.canManageBilling = false,
    this.packPurchaseEnabled = false,
    this.packs = const [],
    this.basePeriodExpiresAt,
  });

  final String organizationName;
  final String unit;
  final String base;
  final String purchased;
  final String reserved;
  final String available;
  final bool canPurchase;
  final bool chargingEnabled;
  final String? billingMode;
  final bool canManageBilling;
  final bool packPurchaseEnabled;
  final List<AiCreditPack> packs;
  final DateTime? basePeriodExpiresAt;

  factory AiCreditsBalanceModel.fromJson(Map<String, dynamic>? json) {
    final value = json ?? const <String, dynamic>{};
    return AiCreditsBalanceModel(
      organizationName: _stringValue(value['organization_name']) ?? '',
      unit: _stringValue(value['unit']) ?? 'ед. МОСТ',
      base: formatAiMinor(_intValue(value['included_minor'])),
      purchased: formatAiMinor(_intValue(value['purchased_minor'])),
      reserved: formatAiMinor(_intValue(value['reserved_minor'])),
      available: formatAiMinor(_intValue(value['available_minor'])),
      canPurchase: _boolValue(value['can_purchase']),
      chargingEnabled: _boolValue(value['charging_enabled']),
      billingMode: _stringValue(value['billing_mode']),
      canManageBilling: _boolValue(value['can_manage_billing']),
      packPurchaseEnabled:
          value.containsKey('pack_purchase_enabled')
              ? _boolValue(value['pack_purchase_enabled'])
              : _boolValue(value['can_purchase']),
      basePeriodExpiresAt: _dateTimeValue(value['base_period_expires_at']),
      packs:
          _asList(value['packs'])
              .map((item) => AiCreditPack.fromJson(_nullableMap(item) ?? {}))
              .where((item) => item.id.isNotEmpty)
              .toList(),
    );
  }
}

class AiCreditQuoteModel {
  const AiCreditQuoteModel({
    required this.id,
    required this.maxConfirmed,
    required this.amount,
    required this.unit,
  });

  final String id;
  final bool maxConfirmed;
  final String amount;
  final String unit;

  factory AiCreditQuoteModel.fromJson(Map<String, dynamic> json) {
    return AiCreditQuoteModel(
      id: _stringValue(json['quote_id']) ?? _stringValue(json['id']) ?? '',
      maxConfirmed: _boolValue(json['max_confirmed']),
      amount: formatAiMinor(_intValue(json['max_units_minor'])),
      unit: _stringValue(json['unit']) ?? 'ед. МОСТ',
    );
  }
}

class AiMemoryModel {
  const AiMemoryModel({
    required this.id,
    required this.scope,
    required this.content,
    this.updatedAt,
  });

  final String id;
  final String scope;
  final String content;
  final DateTime? updatedAt;

  factory AiMemoryModel.fromJson(Map<String, dynamic> json) => AiMemoryModel(
    id: _stringValue(json['id']) ?? _stringValue(json['uuid']) ?? '',
    scope: _stringValue(json['scope']) ?? 'user',
    content: _stringValue(json['content']) ?? _stringValue(json['value']) ?? '',
    updatedAt: _dateTimeValue(json['updated_at']),
  );
}

class AiConversationParticipantModel {
  const AiConversationParticipantModel({
    required this.userId,
    required this.role,
    this.name,
  });

  final String userId;
  final String role;
  final String? name;

  factory AiConversationParticipantModel.fromJson(Map<String, dynamic> json) =>
      AiConversationParticipantModel(
        userId: _stringValue(json['user_id']) ?? _stringValue(json['id']) ?? '',
        role: _stringValue(json['role']) ?? 'viewer',
        name: _stringValue(json['name']),
      );
}

int _intValue(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _nullableDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

DateTime? _dateTimeValue(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(raw);
}

Map<String, dynamic>? _nullableMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  return null;
}

List<dynamic> _asList(dynamic value) {
  if (value is List<dynamic>) {
    return value;
  }

  if (value is List) {
    return value.cast<dynamic>();
  }

  return const <dynamic>[];
}

String? _stringValue(dynamic value) {
  final raw = value?.toString().trim();

  if (raw == null || raw.isEmpty) {
    return null;
  }

  return raw;
}

int? _nullableInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '');
}

bool? _nullableBool(dynamic value) {
  if (value is bool) return value;
  if (value == null) return null;
  return _boolValue(value);
}

bool _boolValue(dynamic value) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  final raw = value?.toString().trim().toLowerCase();
  return raw == 'true' || raw == '1' || raw == 'yes';
}

String formatAiMinor(int minor) =>
    '${minor < 0 ? '-' : ''}${minor.abs() ~/ 100}.${(minor.abs() % 100).toString().padLeft(2, '0')}';

class AiCreditPack {
  const AiCreditPack({
    required this.id,
    required this.unitsMinor,
    required this.amountMinor,
  });
  final String id;
  final int unitsMinor;
  final int amountMinor;
  factory AiCreditPack.fromJson(Map<String, dynamic> json) => AiCreditPack(
    id: _stringValue(json['id']) ?? '',
    unitsMinor: _intValue(json['units_minor']),
    amountMinor: _intValue(json['amount_minor']),
  );
}

String? _sourceTitle(Map<String, dynamic>? json) {
  if (json == null) return null;
  final type = _stringValue(
    json['type'] ?? json['entity_type'] ?? json['source_type'],
  );
  final label = switch (type) {
    'estimate' || 'estimate_item' || 'estimate_section' => 'Смета',
    'project' => 'Проект',
    'contract' => 'Договор',
    'completed_work' => 'Выполненные работы',
    'material' => 'Материал',
    'file_document' || 'assistant_document' => 'Документ',
    _ => 'Источник',
  };
  final id = _stringValue(json['id'] ?? json['entity_id'] ?? json['source_id']);
  return id == null ? label : '$label №$id';
}
