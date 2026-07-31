import 'package:flutter/material.dart';
import 'package:suretakip/core/errors/domain_exception.dart';

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    required this.error,
    required this.fallbackMessage,
    required this.onRetry,
    this.padding = const EdgeInsets.all(24),
    this.iconSize = 48,
    super.key,
  });

  final Object error;
  final String fallbackMessage;
  final VoidCallback onRetry;
  final EdgeInsetsGeometry padding;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final networkError = error is NetworkException;
    final message = networkError
        ? NetworkException.offlineMessage
        : fallbackMessage;
    final icon = networkError
        ? Icons.wifi_off_rounded
        : Icons.error_outline_rounded;

    return Semantics(
      container: true,
      liveRegion: true,
      child: Center(
        child: SingleChildScrollView(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(networkError ? 'Yenile' : 'Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
