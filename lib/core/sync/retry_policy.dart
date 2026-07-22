import 'dart:math';

/// Geçici hatalarda exponential backoff + jitter üretir (Bölüm 12). Jitter,
/// çok sayıda cihazın aynı anda yeniden bağlanmasında sunucu yükünü dağıtır.
class RetryPolicy {
  RetryPolicy({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Deneme sayısına göre temel gecikme (saniye). Son eleman üzerine çıkan
  /// denemeler için tavan olarak kullanılır.
  static const _baseDelaysSeconds = <int>[2, 5, 15, 30, 60, 300, 900];

  /// `attemptCount` = şimdiye kadar yapılmış deneme sayısı (>= 1).
  Duration nextDelay(int attemptCount) {
    final index = (attemptCount - 1).clamp(0, _baseDelaysSeconds.length - 1);
    final base = _baseDelaysSeconds[index];
    // %0-25 arası jitter ekle.
    final jitterMs = _random.nextInt(base * 250 + 1);
    return Duration(seconds: base, milliseconds: jitterMs);
  }
}
