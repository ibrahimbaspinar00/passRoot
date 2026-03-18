import 'package:flutter/material.dart';

import '../../models/vault_record.dart';

class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final RecordCategory value;
  final ValueChanged<RecordCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in RecordCategory.values)
          ChoiceChip(
            selected: value == category,
            avatar: Icon(category.icon, size: 18),
            label: Text(category.localizedLabel(context)),
            onSelected: (_) => onChanged(category),
          ),
      ],
    );
  }
}
