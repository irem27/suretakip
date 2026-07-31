import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/utils/duration_calculator.dart';

void main() {
  group('calculateChargedMinutes', () {
    test('aktif saniyeyi yukarı yuvarlayıp aralığa tamamlar', () {
      expect(
        calculateChargedMinutes(
          activeDuration: const Duration(minutes: 10, seconds: 1),
          roundingIntervalMinutes: 5,
          minimumChargeMinutes: 0,
        ),
        15,
      );
    });

    test('minimum ücret süresini uygular', () {
      expect(
        calculateChargedMinutes(
          activeDuration: const Duration(minutes: 3),
          roundingIntervalMinutes: 5,
          minimumChargeMinutes: 20,
        ),
        20,
      );
    });

    test('sıfır aktif sürede minimum yoksa sıfır döner', () {
      expect(
        calculateChargedMinutes(
          activeDuration: Duration.zero,
          roundingIntervalMinutes: 5,
          minimumChargeMinutes: 0,
        ),
        0,
      );
    });

    test('tam aralık değerini değiştirmez', () {
      expect(
        calculateChargedMinutes(
          activeDuration: const Duration(minutes: 15),
          roundingIntervalMinutes: 5,
          minimumChargeMinutes: 0,
        ),
        15,
      );
    });

    test('geçersiz yuvarlama aralığını reddeder', () {
      expect(
        () => calculateChargedMinutes(
          activeDuration: const Duration(minutes: 1),
          roundingIntervalMinutes: 0,
          minimumChargeMinutes: 0,
        ),
        throwsArgumentError,
      );
    });

    test('negatif minimum süreyi reddeder', () {
      expect(
        () => calculateChargedMinutes(
          activeDuration: const Duration(minutes: 1),
          roundingIntervalMinutes: 1,
          minimumChargeMinutes: -1,
        ),
        throwsArgumentError,
      );
    });

    test('negatif aktif süreyi reddeder', () {
      expect(
        () => calculateChargedMinutes(
          activeDuration: const Duration(seconds: -1),
          roundingIntervalMinutes: 1,
          minimumChargeMinutes: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('sumActiveDuration', () {
    test('yalnızca verilen tamamlanmış aralıkları toplar', () {
      final duration = sumDurations([
        const Duration(minutes: 2, seconds: 30),
        const Duration(minutes: 7, seconds: 30),
      ]);

      expect(duration, const Duration(minutes: 10));
    });
  });
}
