import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import 'payment_document_model.dart';

final paymentsRepositoryProvider = Provider<PaymentsRepository>(
  (ref) => PaymentsRepository(ref.read(dioProvider)),
);

class PaymentDocumentPage {
  const PaymentDocumentPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.canCreate,
  });
  final List<PaymentDocumentModel> items;
  final int currentPage;
  final int lastPage;
  final bool canCreate;
}

class PaymentPartyOption {
  const PaymentPartyOption({
    required this.id,
    required this.name,
    required this.type,
    this.inn,
  });

  final int id;
  final String name;
  final String type;
  final String? inn;

  factory PaymentPartyOption.fromJson(Map<String, dynamic> json, String type) {
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse('$rawId');
    if (id == null || id <= 0) {
      throw const FormatException('Некорректный ID участника платежа');
    }
    return PaymentPartyOption(
      id: id,
      name: '${json['name'] ?? ''}'.trim(),
      type: type,
      inn: json['inn']?.toString(),
    );
  }

  String get key => '$type:$id';
  String get label => inn == null || inn!.isEmpty ? name : '$name · ИНН $inn';
}

class PaymentContractorPage {
  const PaymentContractorPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<PaymentPartyOption> items;
  final int currentPage;
  final int lastPage;
  final int total;
}

class PaymentFormOptions {
  const PaymentFormOptions({
    required this.currentOrganization,
    required this.contractors,
  });

  final PaymentPartyOption currentOrganization;
  final PaymentContractorPage contractors;
}

class PaymentsRepository {
  PaymentsRepository(this._dio);
  final Dio _dio;

  static const _base = '/payments/documents';

  Future<PaymentFormOptions> formOptions({
    int? projectId,
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await _dio.get(
        '$_base/options',
        queryParameters: {
          if (projectId != null) 'project_id': projectId,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
          'page': page,
          'per_page': perPage,
        },
      );
      final data = MobileApiResponse.dataMap(response.data);
      final rawOrg = data['current_organization'];
      if (rawOrg is! Map) {
        throw const FormatException('Не получена текущая организация');
      }
      final currentOrganization = PaymentPartyOption.fromJson(
        Map<String, dynamic>.from(rawOrg),
        'organization',
      );
      final rawContractors = data['contractors'];
      final contractors =
          rawContractors is Map
              ? Map<String, dynamic>.from(rawContractors)
              : const <String, dynamic>{};
      final rows =
          contractors['items'] is List
              ? contractors['items'] as List
              : const <dynamic>[];
      final meta =
          contractors['meta'] is Map
              ? Map<String, dynamic>.from(contractors['meta'] as Map)
              : const <String, dynamic>{};
      return PaymentFormOptions(
        currentOrganization: currentOrganization,
        contractors: PaymentContractorPage(
          items: rows
              .whereType<Map>()
              .map(
                (row) => PaymentPartyOption.fromJson(
                  Map<String, dynamic>.from(row),
                  'contractor',
                ),
              )
              .toList(growable: false),
          currentPage: _int(meta['current_page'], page),
          lastPage: _int(meta['last_page'], page),
          total: _int(meta['total'], rows.length),
        ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<PaymentDocumentPage> list({
    required int projectId,
    int page = 1,
    String? status,
    String? search,
  }) async {
    try {
      final response = await _dio.get(
        _base,
        queryParameters: {
          'project_id': projectId,
          'page': page,
          'per_page': 20,
          if (status != null && status.isNotEmpty) 'status': status,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        },
      );
      final data = MobileApiResponse.dataMap(response.data);
      final rows =
          (data['items'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (row) => PaymentDocumentModel.fromJson(
                  Map<String, dynamic>.from(row),
                ),
              )
              .toList();
      final meta =
          data['meta'] is Map
              ? Map<String, dynamic>.from(data['meta'] as Map)
              : MobileApiResponse.map(response.data).meta;
      final rawCapabilities = meta['capabilities'];
      final capabilities =
          rawCapabilities is Map
              ? Map<String, dynamic>.from(rawCapabilities)
              : const <String, dynamic>{};
      return PaymentDocumentPage(
        items: rows,
        currentPage: _int(meta['current_page'], page),
        lastPage: _int(meta['last_page'], page),
        canCreate: capabilities['can_create'] == true,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<PaymentDocumentModel> detail(int id) async {
    try {
      final response = await _dio.get('$_base/$id');
      return PaymentDocumentModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<PaymentDocumentModel> create(
    Map<String, dynamic> values, {
    required String idempotencyKey,
  }) => _save(null, values, idempotencyKey: idempotencyKey);
  Future<PaymentDocumentModel> update(int id, Map<String, dynamic> values) =>
      _save(id, values);

  Future<PaymentDocumentModel> _save(
    int? id,
    Map<String, dynamic> values, {
    String? idempotencyKey,
  }) async {
    try {
      final response =
          id == null
              ? await _dio.post(
                _base,
                data: values,
                options: Options(headers: {'Idempotency-Key': idempotencyKey}),
              )
              : await _dio.put('$_base/$id', data: values);
      return PaymentDocumentModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<PaymentDocumentModel> submit(int id) async {
    try {
      final response = await _dio.post('$_base/$id/submit');
      return PaymentDocumentModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<PaymentDocumentModel> decide(
    int id, {
    required bool approve,
    required String comment,
  }) async {
    try {
      final response = await _dio.post(
        '$_base/$id/${approve ? 'approve' : 'reject'}',
        data: approve ? {'comment': comment} : {'reason': comment},
      );
      return PaymentDocumentModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<PaymentDocumentModel> registerPayment(
    int id,
    Map<String, dynamic> values, {
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dio.post(
        '$_base/$id/payments',
        data: values,
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return PaymentDocumentModel.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

int _int(dynamic value, int fallback) =>
    value is int ? value : int.tryParse('$value') ?? fallback;
