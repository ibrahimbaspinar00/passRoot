import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../l10n/lang_x.dart';
import '../utils/password_utils.dart';

class SecurityBadge extends StatelessWidget {
  const SecurityBadge({super.key, required this.strength});

  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (label, color) = switch (strength) {
      PasswordStrength.strong => (
          context.tr('Guclu', 'Strong'),
          isDark ? const Color(0xFF56D49D) : const Color(0xFF1D8F62),
        ),
      PasswordStrength.medium => (
          context.tr('Orta', 'Medium'),
          isDark ? const Color(0xFFF0C66A) : const Color(0xFFCA8A04),
        ),
      PasswordStrength.weak => (
          context.tr('Zayif', 'Weak'),
          isDark ? const Color(0xFFF29A9A) : const Color(0xFFDC2626),
        ),
    };
    final pr = context.pr;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.16), pr.softFill),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
