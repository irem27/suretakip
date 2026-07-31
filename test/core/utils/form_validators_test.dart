import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/utils/form_validators.dart';

void main() {
  group('FormValidators', () {
    test('e-posta alanını Türkçe mesajlarla doğrular', () {
      expect(FormValidators.email(''), 'E-posta zorunlu.');
      expect(
        FormValidators.email('yanlis-adres'),
        'Geçerli bir e-posta adresi girin.',
      );
      expect(FormValidators.email('kullanici@example.com'), isNull);
    });

    test('para değerini kuruşa çevirir', () {
      expect(FormValidators.moneyToMinor('12,50'), 1250);
      expect(FormValidators.nonNegativeMoney('-1', 'fiyat'), isNotNull);
      expect(FormValidators.nonNegativeMoney('12,345', 'fiyat'), isNotNull);
    });

    test('moneyToMinor float yuvarlama hatası üretmez', () {
      // Klasik float tuzağı: 19.99*100 = 1998.9999..., 0.07*100 = 7.0000001
      expect(FormValidators.moneyToMinor('19,99'), 1999);
      expect(FormValidators.moneyToMinor('0,07'), 7);
      expect(FormValidators.moneyToMinor('100'), 10000);
      expect(FormValidators.moneyToMinor('3,5'), 350);
    });
  });
}
