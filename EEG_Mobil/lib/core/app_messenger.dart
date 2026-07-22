import 'package:flutter/material.dart';

/// Merkezi SnackBar yönetimi — tek kanal, tutarlı stil.
class AppMessenger {
  AppMessenger._();

  static final GlobalKey<ScaffoldMessengerState> key =
      GlobalKey<ScaffoldMessengerState>();

  static void show(
    String message, {
    bool isError = false,
    bool isSuccess = false,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = key.currentState;
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? const Color(0xFFC44B4B)
            : isSuccess
                ? const Color(0xFF2E9B63)
                : null,
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  static void success(String message) => show(message, isSuccess: true);

  static void error(String message) =>
      show(message, isError: true, duration: const Duration(seconds: 4));

  static void info(String message) => show(message);
}
