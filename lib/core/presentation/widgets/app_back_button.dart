import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// AppBar'larda kullanılan ortak geri tuşu.
///
/// Navigasyon yığınında geri gidilebilecek bir sayfa varsa `pop` eder.
/// Yığın boşsa (derin bağlantı, yönlendirme veya `go` ile gelinmişse)
/// [fallbackRouteName] ile mantıksal üst sayfaya döner. Böylece her sayfada
/// çalışan bir geri tuşu bulunur.
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    required this.fallbackRouteName,
    this.tooltip = 'Geri',
    super.key,
  });

  /// Yığın boşken dönülecek üst sayfanın rota adı ([AppRouteNames]).
  final String fallbackRouteName;

  final String tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back_rounded),
    tooltip: tooltip,
    onPressed: () =>
        context.canPop() ? context.pop() : context.goNamed(fallbackRouteName),
  );
}
