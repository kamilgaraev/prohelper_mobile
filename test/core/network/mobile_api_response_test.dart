import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/mobile_api_response.dart';

void main() {
  test('extracts list from flat data list', () {
    final response = MobileApiResponse.list({
      'success': true,
      'data': [
        {'id': 1},
        {'id': 2},
      ],
    });

    expect(response.success, isTrue);
    expect(response.data, hasLength(2));
    expect(response.data.first['id'], 1);
  });

  test('extracts list from paginated data.data', () {
    final response = MobileApiResponse.list({
      'success': true,
      'data': {
        'data': [
          {'id': 7},
        ],
        'current_page': 2,
        'total': 9,
      },
    });

    expect(response.data.single['id'], 7);
    expect(response.meta['current_page'], 2);
    expect(response.meta['total'], 9);
    expect(response.meta.containsKey('data'), isFalse);
  });

  test('extracts list from data.items', () {
    final response = MobileApiResponse.list({
      'success': true,
      'data': {
        'items': [
          {'id': 3},
        ],
        'summary': {'open': 1},
      },
    });

    expect(response.data.single['id'], 3);
    expect(response.meta['summary'], {'open': 1});
    expect(response.meta.containsKey('items'), isFalse);
  });

  test('extracts map from data object', () {
    final response = MobileApiResponse.map({
      'success': true,
      'message': 'ok',
      'data': {'id': 10},
      'meta': {'trace': 'abc'},
    });

    expect(response.data['id'], 10);
    expect(response.message, 'ok');
    expect(response.meta['trace'], 'abc');
  });

  test('returns empty list for missing data', () {
    final response = MobileApiResponse.list({'success': true});

    expect(response.data, isEmpty);
  });

  test('preserves meta from Laravel response', () {
    final response = MobileApiResponse.list({
      'success': true,
      'data': [
        {'id': 1},
      ],
      'meta': {'current_page': 1, 'total': 1},
    });

    expect(response.meta['current_page'], 1);
    expect(response.meta['total'], 1);
  });
}
