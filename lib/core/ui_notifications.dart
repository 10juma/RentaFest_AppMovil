import 'package:flutter/material.dart';
import 'theme.dart';

class AppNotifications {
  static void showSuccess(BuildContext context, String message) {
    _showCustomToast(
      context,
      message,
      icon: Icons.check_circle_rounded,
      backgroundColor: AppColors.mint,
    );
  }

  static void showError(BuildContext context, String message) {
    _showCustomToast(
      context,
      message,
      icon: Icons.error_rounded,
      backgroundColor: AppColors.coral,
    );
  }

  static void _showCustomToast(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color backgroundColor,
  }) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Eliminamos cualquier snackbar previo para evitar acumulación
    scaffoldMessenger.removeCurrentSnackBar();

    scaffoldMessenger.showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        duration: const Duration(seconds: 3),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
