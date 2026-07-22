import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String cancelLabel = 'Vazgeç',
  String confirmLabel = 'Sil',
  bool isDestructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: Text(
          message,
          style: TextStyle(
            color: AppColors.secondary(ctx),
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
