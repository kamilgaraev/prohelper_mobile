import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import 'ai_assistant_models.dart';
import 'ai_assistant_document_models.dart';

final aiAssistantRepositoryProvider = Provider<AiAssistantRepository>((ref) {
  return AiAssistantRepository(ref.read(dioProvider));
});

class AiAssistantRepository {
  AiAssistantRepository(
    this._dio, {
    String sourceBaseUrl = const String.fromEnvironment(
      'ASSISTANT_SOURCE_BASE_URL',
      defaultValue: 'https://lk.xn--1-xtbgmf.xn--p1ai',
    ),
  }) : _sourceBaseUrl = sourceBaseUrl;

  final String _sourceBaseUrl;

  final Dio _dio;

  Future<AiImageAttachmentModel> uploadImage({
    required String fileName,
    required String mime,
    required Uint8List bytes,
    int? conversationId,
    ProgressCallback? onSendProgress,
  }) async {
    final response = await _dio.post(
      '/ai-assistant/attachments',
      data: FormData.fromMap({
        'image': MultipartFile.fromBytes(bytes, filename: fileName),
        if (conversationId != null) 'conversation_id': conversationId,
      }),
      onSendProgress: onSendProgress,
    );
    return AiImageAttachmentModel.fromJson(_asMap(_unwrapData(response.data)));
  }

  Future<Uint8List> fetchImageContent(String id) async {
    final response = await _dio.get<List<int>>(
      '/ai-assistant/attachments/$id/content',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const <int>[]);
  }

  Future<AiAssistantHomeModel> fetchHome() async {
    try {
      final responses = await Future.wait([
        _dio.get('/ai-assistant/usage'),
        _dio.get('/ai-assistant/conversations'),
        _dio.get('/ai-assistant/credits/balance'),
      ]);

      final usageData = _unwrapData(responses[0].data);
      final conversationsResponse = MobileApiResponse.list(responses[1].data);
      final balanceData = _unwrapData(responses[2].data);

      final usage = AiUsageModel.fromJson(_asMap(usageData));
      final conversations =
          conversationsResponse.data.map(AiConversationModel.fromJson).toList();

      final meta = conversationsResponse.meta;
      final current = _intValue(meta['current_page']);
      final last = _intValue(meta['last_page']);
      return AiAssistantHomeModel(
        usage: usage,
        conversations: conversations,
        nextPage: current > 0 && current < last ? current + 1 : null,
        balance: AiCreditsBalanceModel.fromJson(_asMap(balanceData)),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить данные AI-ассистента.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось загрузить данные AI-ассистента.');
    }
  }

  Future<AiConversationDetailsModel> fetchConversation(int id) async {
    try {
      final response = await _dio.get('/ai-assistant/conversations/$id');
      final payload = _asMap(_unwrapData(response.data));

      final conversation = AiConversationModel.fromJson(
        _asMap(payload['conversation']),
      );
      final messages =
          _asList(
            payload['messages'],
          ).map((item) => AiMessageModel.fromJson(_asMap(item))).toList();

      return AiConversationDetailsModel(
        conversation: conversation,
        messages: messages,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить историю диалога.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось загрузить историю диалога.');
    }
  }

  Future<AiAssistantPage<AiConversationModel>> fetchConversations({
    int page = 1,
  }) async {
    try {
      final response = await _dio.get(
        '/ai-assistant/conversations',
        queryParameters: {'page': page},
      );
      final payload = _unwrapData(response.data);
      final map = _asMap(payload);
      final rows = _asList(map['data']).isNotEmpty ? map['data'] : payload;
      final meta = MobileApiResponse.list(response.data).meta;
      final current = _intValue(meta['current_page']);
      final last = _intValue(meta['last_page']);
      return AiAssistantPage(
        items: _asList(rows)
            .map((item) => AiConversationModel.fromJson(_asMap(item)))
            .toList(growable: false),
        nextPage: current > 0 && last > current ? current + 1 : null,
        total: _intValue(meta['total']),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить диалоги.',
      );
    }
  }

  Future<AiAssistantPage<AiMessageModel>> fetchMessages(
    int conversationId, {
    int page = 1,
  }) async {
    try {
      final response = await _dio.get(
        '/ai-assistant/conversations/$conversationId/history',
        queryParameters: {'page': page},
      );
      final payload = _unwrapData(response.data);
      final map = _asMap(payload);
      final rows = _asList(map['data']).isNotEmpty ? map['data'] : payload;
      final meta = MobileApiResponse.list(response.data).meta;
      final current = _intValue(meta['current_page']);
      final last = _intValue(meta['last_page']);
      return AiAssistantPage(
        items: _asList(rows)
            .map((item) => AiMessageModel.fromJson(_asMap(item)))
            .toList(growable: false),
        nextPage: current > 0 && last > current ? current + 1 : null,
        total: _intValue(meta['total']),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось загрузить сообщения.',
      );
    }
  }

  Future<AiConversationDetailsModel> sendMessage({
    required String message,
    int? conversationId,
    String? goal,
    String? desiredMode,
    bool? allowActions,
    Map<String, dynamic>? context,
    String? requestId,
    String? quoteId,
    bool? maxConfirmed,
    CancelToken? cancelToken,
  }) async {
    try {
      final payload = {
        'message': message,
        if (conversationId != null) 'conversation_id': conversationId,
        if ((goal ?? '').trim().isNotEmpty) 'goal': goal!.trim(),
        if ((desiredMode ?? '').trim().isNotEmpty)
          'desired_mode': desiredMode!.trim(),
        if (allowActions != null) 'allow_actions': allowActions,
        if (context != null && context.isNotEmpty) 'context': context,
        if ((requestId ?? '').trim().isNotEmpty)
          'request_id': requestId!.trim(),
        if ((quoteId ?? '').trim().isNotEmpty) 'quote_id': quoteId!.trim(),
        if (maxConfirmed != null) 'max_confirmed': maxConfirmed,
      };
      final response = await _dio.post(
        '/ai-assistant/chat',
        data: payload,
        cancelToken: cancelToken,
      );

      final responsePayload = _asMap(_unwrapData(response.data));
      final nextConversationId = _intValue(responsePayload['conversation_id']);

      if (nextConversationId <= 0) {
        throw const ApiException('Сервер не вернул идентификатор диалога.');
      }

      return fetchConversation(nextConversationId);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось отправить сообщение ассистенту.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось отправить сообщение ассистенту.');
    }
  }

  Future<AiAssistantChatRequest> sendMessageRequest({
    required String message,
    required String requestId,
    int? conversationId,
    String? quoteId,
    required bool maxConfirmed,
    String profile = 'normal',
    bool allowActions = true,
    Map<String, dynamic>? context,
    List<String> attachmentIds = const <String>[],
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        '/ai-assistant/chat',
        data: {
          'message': message,
          'request_id': requestId,
          'async': true,
          if (conversationId != null) 'conversation_id': conversationId,
          if ((quoteId ?? '').trim().isNotEmpty) 'quote_id': quoteId!.trim(),
          'profile': profile,
          'allow_actions': allowActions,
          if (context != null && context.isNotEmpty) 'context': context,
          if (attachmentIds.isNotEmpty) 'attachment_ids': attachmentIds,
        },
        cancelToken: cancelToken,
      );
      final payload = _asMap(_unwrapData(response.data));
      final request =
          response.statusCode == 202
              ? AiAssistantChatRequest.fromJson(payload)
              : AiAssistantChatRequest(
                requestId: requestId,
                status: 'completed',
                result: AiAssistantChatResult.fromJson(payload),
              );
      if (request.requestId != requestId ||
          (request.conversationId != null &&
              conversationId != null &&
              request.conversationId != conversationId) ||
          (request.status == 'completed' &&
              !_validChatResult(request.result, requestId, conversationId))) {
        throw const ApiException('Получен ответ для другого запроса.');
      }
      return request;
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось отправить сообщение ассистенту.',
      );
    }
  }

  Future<AiCreditsBalanceModel> fetchCreditsBalance() async {
    final response = await _dio.get('/ai-assistant/credits/balance');
    return AiCreditsBalanceModel.fromJson(_asMap(_unwrapData(response.data)));
  }

  Future<AiCreditQuoteModel> quoteCredits({
    required String message,
    required String requestId,
    String profile = 'normal',
    bool allowActions = true,
    int? conversationId,
    Map<String, dynamic>? context,
    List<String> attachmentIds = const <String>[],
  }) async {
    final response = await _dio.post(
      '/ai-assistant/credits/quote',
      data: {
        'message': message,
        'request_id': requestId,
        'profile': profile,
        'allow_actions': allowActions,
        if (conversationId != null) 'conversation_id': conversationId,
        if (context != null && context.isNotEmpty) 'context': context,
        if (attachmentIds.isNotEmpty) 'attachment_ids': attachmentIds,
      },
    );
    final payload = _asMap(_unwrapData(response.data));
    final quote = AiCreditQuoteModel.fromJson(payload);
    final expires = DateTime.tryParse(payload['expires_at']?.toString() ?? '');
    if (quote.id.isEmpty ||
        !payload.containsKey('max_units_minor') ||
        (expires != null && !expires.isAfter(DateTime.now()))) {
      throw const ApiException('Оценка расхода недоступна или устарела.');
    }
    return quote;
  }

  Future<AiAssistantPage<Map<String, dynamic>>> fetchCreditHistory({
    int page = 1,
  }) async {
    final response = await _dio.get(
      '/ai-assistant/credits/history',
      queryParameters: {'page': page},
    );
    final parsed = MobileApiResponse.list(response.data);
    final current = _intValue(parsed.meta['current_page']);
    final last = _intValue(parsed.meta['last_page']);
    return AiAssistantPage(
      items: parsed.data,
      nextPage: current > 0 && current < last ? current + 1 : null,
      total: _intValue(parsed.meta['total']),
    );
  }

  Future<String?> purchaseCredits({int? pack, String? packId}) async {
    final response = await _dio.post(
      '/ai-assistant/credits/purchase',
      data: {'pack_id': packId ?? 'ai-credits-$pack'},
    );
    final payload = _asMap(_unwrapData(response.data));
    return payload['confirmation_url']?.toString();
  }

  Future<List<AiMemoryModel>> fetchMemory({String? scope}) async {
    final response = await _dio.get(
      '/ai-assistant/memory',
      queryParameters: {if (scope != null) 'scope': scope},
    );
    final payload = _unwrapData(response.data);
    final map = _asMap(payload);
    final rows = _asList(map['data']).isNotEmpty ? map['data'] : payload;
    return _asList(rows)
        .map((item) => AiMemoryModel.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<AiMemoryModel> createMemory({
    required String scope,
    required String content,
  }) async {
    final response = await _dio.post(
      '/ai-assistant/memory',
      data: {'content': content, 'confirmed': true},
    );
    return AiMemoryModel.fromJson(_asMap(_unwrapData(response.data)));
  }

  Future<AiMemoryModel> updateMemory(
    String id, {
    required String content,
  }) async {
    final response = await _dio.patch(
      '/ai-assistant/memory/$id',
      data: {'content': content, 'confirmed': true},
    );
    return AiMemoryModel.fromJson(_asMap(_unwrapData(response.data)));
  }

  Future<void> deleteMemory(String id) =>
      _dio.delete('/ai-assistant/memory/$id');

  Future<List<AiConversationParticipantModel>> fetchParticipants(
    int conversationId,
  ) async {
    final response = await _dio.get(
      '/ai-assistant/conversations/$conversationId/participants',
    );
    final payload = _unwrapData(response.data);
    final map = _asMap(payload);
    final rows = _asList(map['data']).isNotEmpty ? map['data'] : payload;
    return _asList(rows)
        .map((item) => AiConversationParticipantModel.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<void> updateParticipants(
    int conversationId,
    List<AiConversationParticipantModel> participants,
  ) async {
    await _dio.put(
      '/ai-assistant/conversations/$conversationId/participants',
      data: {
        'participants': [
          for (final participant in participants)
            {'user_id': participant.userId, 'role': participant.role},
        ],
      },
    );
  }

  Future<AiActionPreviewModel> previewAction({
    required AiAssistantActionModel action,
    int? conversationId,
  }) async {
    try {
      final response = await _dio.post(
        '/ai-assistant/actions/preview',
        data: {
          if (conversationId != null) 'conversation_id': conversationId,
          'action': action.toJson(),
        },
      );

      return AiActionPreviewModel.fromJson(_asMap(_unwrapData(response.data)));
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось подготовить действие ассистента.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось подготовить действие ассистента.');
    }
  }

  Future<AiActionExecutionModel> executeAction({
    required AiActionPreviewModel preview,
    int? conversationId,
  }) async {
    if (preview.previewToken.trim().isEmpty || preview.action.id == null) {
      throw const ApiException(
        'Сначала подтвердите предварительный просмотр действия.',
      );
    }

    if (!preview.executable) {
      throw const ApiException('Действие недоступно текущему пользователю.');
    }

    try {
      final response = await _dio.post(
        '/ai-assistant/actions/execute',
        data: {
          if (conversationId != null) 'conversation_id': conversationId,
          'action': {
            'id': preview.action.id,
            'preview_token': preview.previewToken,
            'confirmed': true,
          },
        },
      );

      return AiActionExecutionModel.fromJson(
        _asMap(_unwrapData(response.data)),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось выполнить действие ассистента.',
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw const ApiException('Не удалось выполнить действие ассистента.');
    }
  }

  Future<AiDocumentProcessingStatus> fetchDocumentProcessing({
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get(
      '/ai-assistant/rag/status',
      cancelToken: cancelToken,
    );
    return AiDocumentProcessingStatus.fromJson(
      _asMap(_unwrapData(response.data)),
    );
  }

  Future<AiDocumentBudget> fetchDocumentBudget() async {
    final response = await _dio.get('/ai-assistant/documents/settings');
    return AiDocumentBudget.fromJson(_asMap(_unwrapData(response.data)));
  }

  Future<AiDocumentBudget> approveDocumentBudget({
    required bool enabled,
    required String scope,
    required int limitMinor,
  }) async {
    if (!['new', 'archive'].contains(scope) ||
        limitMinor < 0 ||
        limitMinor > 1000000000) {
      throw const ApiException('Проверьте период и лимит распознавания.');
    }
    final response = await _dio.put(
      '/ai-assistant/documents/settings',
      data: {
        'enabled': enabled,
        'scope': scope,
        'limit_minor': limitMinor,
        'confirmed': true,
      },
    );
    return AiDocumentBudget.fromJson(_asMap(_unwrapData(response.data)));
  }

  Future<AiDownloadedReport> downloadReport(
    AiAssistantArtifact artifact, {
    Directory? temporaryDirectory,
  }) async {
    final rawUrl =
        artifact.downloadUrl ?? artifact.url ?? artifact.href ?? artifact.path;
    final uri = sourceUri(rawUrl, apiOrigin: true);
    if (uri == null) throw const ApiException('Ссылка на отчёт недоступна.');
    final name =
        artifact.filename ?? artifact.fileName ?? artifact.displayTitle;
    final extension = name.split('.').last.toLowerCase();
    if (!['pdf', 'xlsx', 'csv', 'docx', 'txt'].contains(extension)) {
      throw const ApiException('Формат отчёта не поддерживается.');
    }
    final root = temporaryDirectory ?? await getTemporaryDirectory();
    final directory = await root.createTemp('most-assistant-report-');
    final file = File('${directory.path}/report.$extension');
    try {
      final response = await _dio.download(
        uri.toString(),
        file.path,
        options: Options(
          followRedirects: false,
          receiveTimeout: const Duration(minutes: 2),
          headers: {'Accept': '*/*'},
        ),
      );
      final contentType =
          response.headers.value(Headers.contentTypeHeader)?.split(';').first;
      if (contentType == 'text/html' || contentType == 'application/json') {
        throw const ApiException('Сервер не вернул файл отчёта.');
      }
      if (!await file.exists() || await file.length() == 0) {
        throw const ApiException('Сервер вернул пустой отчёт.');
      }
      return AiDownloadedReport(file.path, directory);
    } catch (error) {
      if (await directory.exists()) await directory.delete(recursive: true);
      rethrow;
    }
  }

  Uri? sourceUri(String? value, {bool apiOrigin = false}) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final source = Uri.tryParse(value);
    final origin = Uri.tryParse(
      apiOrigin ? _dio.options.baseUrl : _sourceBaseUrl,
    );
    if (source == null || origin == null || !origin.hasAuthority) return null;
    final resolved = origin.resolveUri(source);
    if ((resolved.scheme != 'https' && resolved.scheme != 'http') ||
        resolved.host != origin.host ||
        resolved.port != origin.port ||
        resolved.userInfo.isNotEmpty) {
      return null;
    }
    return resolved;
  }

  Future<Map<String, dynamic>> fetchRequest(String requestId) async {
    final response = await _dio.get('/ai-assistant/requests/$requestId');
    return _asMap(_unwrapData(response.data));
  }

  Future<AiAssistantChatRequest> fetchChatRequest(
    String requestId, {
    int? conversationId,
  }) async {
    try {
      final request = AiAssistantChatRequest.fromJson(
        await fetchRequest(requestId),
      );
      if (request.requestId != requestId ||
          (request.conversationId != null &&
              conversationId != null &&
              request.conversationId != conversationId) ||
          (request.status == 'completed' &&
              !_validChatResult(request.result, requestId, conversationId))) {
        throw const ApiException('Получен ответ для другого запроса.');
      }
      return request;
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось проверить состояние запроса.',
      );
    }
  }

  bool _validChatResult(
    AiAssistantChatResult? result,
    String requestId,
    int? conversationId,
  ) =>
      result != null &&
      result.conversationId > 0 &&
      result.requestId == requestId &&
      (conversationId == null || result.conversationId == conversationId);

  Future<AiAssistantChatRequest> cancelRequest(String requestId) async {
    try {
      final response = await _dio.post(
        '/ai-assistant/requests/$requestId/cancel',
      );
      final request = AiAssistantChatRequest.fromJson(
        _asMap(_unwrapData(response.data)),
      );
      if (request.requestId != requestId) {
        throw const ApiException('Получен ответ для другого запроса.');
      }
      return request;
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось остановить запрос.',
      );
    }
  }

  Future<void> deleteConversation(int id) async {
    try {
      await _dio.delete('/ai-assistant/conversations/$id');
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallbackMessage: 'Не удалось удалить диалог.',
      );
    } catch (_) {
      throw const ApiException('Не удалось удалить диалог.');
    }
  }

  dynamic _unwrapData(dynamic response) {
    return MobileApiResponse.payload(response);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }

    return const <String, dynamic>{};
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

  int _intValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class AiDownloadedReport {
  const AiDownloadedReport(this.path, this.directory);
  final String path;
  final Directory directory;
  Future<void> dispose() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
