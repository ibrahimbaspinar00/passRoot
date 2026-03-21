import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

class RecordFormSectionCard extends StatelessWidget {
  const RecordFormSectionCard({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pr.panelSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pr.panelBorder),
        boxShadow: [
          BoxShadow(
            color: pr.panelShadow,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
