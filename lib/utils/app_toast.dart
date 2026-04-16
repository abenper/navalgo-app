import 'package:flutter/material.dart';

import '../theme/navalgo_theme.dart';

class AppToast {
  static void info(BuildContext context, String message) {
    _show(
      context,
      message,
      backgroundColor: NavalgoColors.deepSea,
      icon: Icons.info_outline,
    );
  }

  static void success(BuildContext context, String message) {
    _show(
      context,
      message,
      backgroundColor: NavalgoColors.kelp,
      icon: Icons.check_circle_outline,
    );
  }

  static void warning(BuildContext context, String message) {
    _show(
      context,
      message,
      backgroundColor: NavalgoColors.sand,
      icon: Icons.warning_amber_rounded,
    );
  }

  static void error(BuildContext context, String message) {
    _show(
      context,
      message,
      backgroundColor: NavalgoColors.alert,
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
                style: TextStyle(
                  color: backgroundColor == NavalgoColors.sand
                      ? NavalgoColors.ink
                      : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
