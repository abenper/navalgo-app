import 'package:flutter/material.dart';

class AppToast {
  static void info(BuildContext context, String message) {
    _show(
      context,
      message,
      backgroundColor: const Color(0xFF0B57D0),
      icon: Icons.info_outline,
    );
  }

  static void success(BuildContext context, String message) {
    _show(
      context,
      message,
      backgroundColor: const Color(0xFF1B8F3A),
      icon: Icons.check_circle_outline,
    );
  }

  static void warning(BuildContext context, String message) {
    _show(
      context,
      message,
      backgroundColor: const Color(0xFFB26A00),
      icon: Icons.warning_amber_rounded,
    );
  }

  static void error(BuildContext context, String message) {
    _show(
      context,
      message,
      backgroundColor: const Color(0xFF8C2F39),
      icon: Icons.error_outline,
    );
  }

  static void _show(
    BuildContext context,
    String message, {
    required Color backgroundColor,
    required IconData icon,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
