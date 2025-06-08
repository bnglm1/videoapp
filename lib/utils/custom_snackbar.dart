import 'package:flutter/material.dart';

enum SnackbarType { success, error, info, warning }

class CustomSnackbar {
  static void show({
    required BuildContext context,
    required String message,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 2),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    // Varolan Snackbar'ı kaldır
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // İkon ve renk belirleme
    IconData icon;
    Color backgroundColor;
    Color iconAndTextColor;

    switch (type) {
      case SnackbarType.success:
        icon = Icons.check_circle_outline;
        backgroundColor = const Color(0xFF4CAF50);
        iconAndTextColor = Colors.white;
        break;
      case SnackbarType.error:
        icon = Icons.error_outline;
        backgroundColor = const Color(0xFFF44336);
        iconAndTextColor = Colors.white;
        break;
      case SnackbarType.info:
        icon = Icons.info_outline;
        backgroundColor = const Color(0xFF2196F3);
        iconAndTextColor = Colors.white;
        break;
      case SnackbarType.warning:
        icon = Icons.warning_amber_outlined;
        backgroundColor = const Color(0xFFFFC107);
        iconAndTextColor = Colors.black87;
        break;
    }

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(icon, color: iconAndTextColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: iconAndTextColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      duration: duration,
      action: actionLabel != null && onAction != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: iconAndTextColor,
              onPressed: onAction,
            )
          : null,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}