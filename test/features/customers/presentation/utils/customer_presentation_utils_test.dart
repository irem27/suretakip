import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/features/customers/presentation/utils/customer_presentation_utils.dart';

void main() {
  group('customerAvatarInitial', () {
    test('normal isimde ilk harfi büyük olarak döner', () {
      expect(customerAvatarInitial('Ayşe Yılmaz'), 'A');
    });

    test('boş metinde çökmeden "?" döner', () {
      expect(customerAvatarInitial(''), '?');
    });

    test('sadece boşluk içeren metinde çökmeden "?" döner', () {
      expect(customerAvatarInitial('   '), '?');
    });

    test('başında boşluk olan isimde trim edilmiş ilk harfi döner', () {
      expect(customerAvatarInitial('  bora'), 'B');
    });
  });
}
