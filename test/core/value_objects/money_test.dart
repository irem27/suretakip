import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/value_objects/money.dart';

void main() {
  test('aynı para birimindeki tutarları tam sayı olarak toplar', () {
    final total =
        Money(minorUnits: 125, currencyCode: 'TRY') +
        Money(minorUnits: 75, currencyCode: 'TRY');

    expect(total, Money(minorUnits: 200, currencyCode: 'TRY'));
  });

  test('tutarı tam sayı ile çarpar', () {
    final total = Money(minorUnits: 199, currencyCode: 'TRY') * 3;

    expect(total, Money(minorUnits: 597, currencyCode: 'TRY'));
  });

  test('farklı para birimleriyle işlemi reddeder', () {
    expect(
      () =>
          Money(minorUnits: 100, currencyCode: 'TRY') +
          Money(minorUnits: 100, currencyCode: 'USD'),
      throwsArgumentError,
    );
  });

  test('geçersiz ISO para birimi kodunu reddeder', () {
    expect(
      () => Money(minorUnits: 100, currencyCode: 'try'),
      throwsArgumentError,
    );
  });
}
