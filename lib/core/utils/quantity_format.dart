String formatQuantity(double value, {int maxFractionDigits = 4}) {
  if (maxFractionDigits < 0 || maxFractionDigits > 20) {
    throw ArgumentError.value(
      maxFractionDigits,
      'maxFractionDigits',
      'Must be between 0 and 20',
    );
  }

  final fixed = value.toStringAsFixed(maxFractionDigits);
  if (!fixed.contains('.')) {
    return fixed;
  }

  final trimmed = fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return trimmed == '-0' ? '0' : trimmed;
}
