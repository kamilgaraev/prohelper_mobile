import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/utils/quantity_format.dart';

void main() {
  test('keeps backend-supported fractional quantities visible', () {
    expect(formatQuantity(0.001), '0.001');
    expect(formatQuantity(0.0001), '0.0001');
  });

  test('trims trailing zeroes and preserves ordinary signed quantities', () {
    expect(formatQuantity(2), '2');
    expect(formatQuantity(2.5), '2.5');
    expect(formatQuantity(2.5000), '2.5');
    expect(formatQuantity(-1.25), '-1.25');
    expect(formatQuantity(0), '0');
  });

  test('can render a quantity to a narrower API precision', () {
    expect(formatQuantity(2.125, maxFractionDigits: 3), '2.125');
    expect(formatQuantity(0.0001, maxFractionDigits: 3), '0');
  });

  test('preserves estimate precision up to eight decimal places', () {
    expect(formatQuantity(0.00000001, maxFractionDigits: 8), '0.00000001');
    expect(formatQuantity(0.00001, maxFractionDigits: 8), '0.00001');
  });
}
