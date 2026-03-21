import 'package:flutter/material.dart';

import '../l10n/lang_x.dart';
import '../utils/password_utils.dart';

class SecurityBadge extends StatelessWidget {
  const SecurityBadge({super.key, required this.strength});

  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (label, textColor, backgroundColor, borderColor) = switch (strength) {
      PasswordStrength.strong => (
        context.tr('Guclu', 'Strong'),
        isDark ? const Color(0xFF65E3AB) : const Color(0xFF166B47),
        isDark ? const Color(0xFF1E3A32) : const Color(0xFFE4F7EC),
        isDark ? const Color(0xFF336955) : const Color(0xFFC1E7D0),
      ),
      PasswordStrength.medium => (
        context.tr('Orta', 'Medium'),
        isDark ? const Color(0xFFF3CF79) : const Color(0xFF9A6500),
        isDark ? const Color(0xFF40331B) : const Color(0xFFFFF3DD),
        isDark ? const Color(0xFF66512C) : const Color(0xFFF2D7A0),
      ),
      PasswordStrength.weak => (
        context.tr('Zayif', 'Weak'),
        isDark ? const Color(0xFFF3ADB7) : const Color(0xFFB42335),
        isDark ? const Color(0xFF4D2C33) : const Color(0xFFFDEBED),
        isDark ? const Color(0xFF71434C) : const Color(0xFFF6CBD2),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
