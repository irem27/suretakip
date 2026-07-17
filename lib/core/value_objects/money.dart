final class Money {
  Money({required this.minorUnits, required this.currencyCode}) {
    if (!_currencyPattern.hasMatch(currencyCode)) {
      throw ArgumentError.value(
        currencyCode,
        'currencyCode',
        'Para birimi üç büyük harfli ISO 4217 kodu olmalıdır.',
      );
    }
  }

  factory Money.zero(String currencyCode) =>
      Money(minorUnits: 0, currencyCode: currencyCode);

  static final RegExp _currencyPattern = RegExp(r'^[A-Z]{3}$');

  final int minorUnits;
  final String currencyCode;

  Money operator +(Money other) {
    _requireSameCurrency(other);
    return Money(
      minorUnits: minorUnits + other.minorUnits,
      currencyCode: currencyCode,
    );
  }

  Money operator -(Money other) {
    _requireSameCurrency(other);
    return Money(
      minorUnits: minorUnits - other.minorUnits,
      currencyCode: currencyCode,
    );
  }

  Money operator *(int multiplier) =>
      Money(minorUnits: minorUnits * multiplier, currencyCode: currencyCode);

  void _requireSameCurrency(Money other) {
    if (currencyCode != other.currencyCode) {
      throw ArgumentError(
        'Farklı para birimleriyle işlem yapılamaz: '
        '$currencyCode ve ${other.currencyCode}.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          minorUnits == other.minorUnits &&
          currencyCode == other.currencyCode;

  @override
  int get hashCode => Object.hash(minorUnits, currencyCode);

  @override
  String toString() => 'Money($minorUnits $currencyCode)';
}
