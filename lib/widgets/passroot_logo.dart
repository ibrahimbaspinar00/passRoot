import 'package:flutter/material.dart';

class PassRootLogo extends StatelessWidget {
  const PassRootLogo({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/passroot_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.shield_rounded, size: size * 0.62);
      },
    );
  }
}
