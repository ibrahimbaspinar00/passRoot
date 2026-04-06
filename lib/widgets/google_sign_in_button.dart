import 'package:flutter/material.dart';

import '../app/app_theme.dart';

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingLabel,
  });

  final String label;
  final String? loadingLabel;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    final scheme = Theme.of(context).colorScheme;
    final backgroundColor = Theme.of(context).brightness == Brightness.dark
        ? pr.softFillAlt
        : Colors.white;
    final foregroundColor = scheme.onSurface;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.94),
          foregroundColor: foregroundColor,
          disabledForegroundColor: foregroundColor.withValues(alpha: 0.86),
          elevation: 0,
          side: BorderSide(color: pr.panelBorder),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _GoogleBrandMark(size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                loading ? (loadingLabel ?? label) : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (loading) ...[
              const SizedBox(width: 10),
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoogleBrandMark extends StatelessWidget {
  const _GoogleBrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: const Color(0xFFDCE4EC)),
      ),
      alignment: Alignment.center,
      child: ShaderMask(
        shaderCallback: (bounds) {
          return const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4285F4),
              Color(0xFF34A853),
              Color(0xFFFBBC05),
              Color(0xFFEA4335),
            ],
            stops: [0.0, 0.4, 0.7, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.srcIn,
        child: Text(
          'G',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.72,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
