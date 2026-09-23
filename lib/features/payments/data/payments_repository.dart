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

class PaymentsRepository {
  PaymentsRepository(this._dio);
  final Dio _dio;

  static const _base = '/payments/documents';

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
