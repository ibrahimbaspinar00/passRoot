import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../l10n/lang_x.dart';
import '../models/vault_record.dart';
import '../utils/password_utils.dart';
import 'security_badge.dart';

class VaultRecordCard extends StatefulWidget {
  const VaultRecordCard({
    super.key,
    required this.compact,
    required this.record,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  final bool compact;
  final VaultRecord record;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  State<VaultRecordCard> createState() => _VaultRecordCardState();
}

class _VaultRecordCardState extends State<VaultRecordCard> {
  bool _passwordVisible = false;
  late PasswordAnalysis _analysis;
  late String _maskedPassword;

  @override
  void initState() {
    super.initState();
    _recomputePasswordDerivedValues();
  }

  @override
  void didUpdateWidget(covariant VaultRecordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.password != widget.record.password) {
      _recomputePasswordDerivedValues();
    }
  }

  void _recomputePasswordDerivedValues() {
    _analysis = analyzePassword(widget.record.password);
    _maskedPassword = _masked(widget.record.password);
  }

  String _masked(String password) {
    if (password.length <= 3) return '***';
    return '${'*' * (password.length - 3)}${password.substring(password.length - 3)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pr = context.pr;
    final favoriteColor = theme.colorScheme.secondary;
    final compact = widget.compact;
    final outerPadding = compact ? 12.0 : 14.0;
    final titleFontSize = compact ? 14.5 : 16.0;
    final baseRadius = compact ? 16.0 : 18.0;

    return Material(
      color: pr.panelSurface,
      borderRadius: BorderRadius.circular(baseRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(baseRadius),
        onTap: widget.onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(baseRadius),
            border: Border.all(color: pr.panelBorder),
            boxShadow: [
              BoxShadow(
                color: pr.panelShadow.withValues(alpha: 0.82),
                blurRadius: compact ? 9 : 11,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(outerPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: compact ? 16 : 18,
                      backgroundColor: pr.accentSoft,
                      foregroundColor: theme.colorScheme.primary,
                      child: Icon(widget.record.category.icon, size: compact ? 17 : 19),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.record.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: titleFontSize,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.record.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: pr.textMuted,
                              fontWeight: FontWeight.w500,
                              fontSize: compact ? 12.5 : 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('Favori', 'Favorite'),
                      onPressed: widget.onToggleFavorite,
                      icon: Icon(
                        widget.record.isFavorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: widget.record.isFavorite
                            ? favoriteColor
                            : pr.iconMuted,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 8 : 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: pr.softFill,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: pr.panelBorder),
                        ),
                        child: Text(
                          widget.record.accountName.isEmpty
                              ? '-'
                              : widget.record.accountName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: compact ? 13 : 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SecurityBadge(strength: _analysis.strength),
                  ],
                ),
                SizedBox(height: compact ? 6 : 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: pr.softFillAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: pr.panelBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.key_rounded,
                        size: 18,
                        color: pr.iconMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _passwordVisible ? widget.record.password : _maskedPassword,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.tr(
                          _passwordVisible ? 'Gizle' : 'Goster',
                          _passwordVisible ? 'Hide' : 'Show',
                        ),
                        onPressed: () {
                          setState(() {
                            _passwordVisible = !_passwordVisible;
                          });
                        },
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.record.securityTag.trim().isNotEmpty ||
                    widget.record.securityNote.trim().isNotEmpty) ...[
                  SizedBox(height: compact ? 6 : 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (widget.record.securityTag.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: pr.accentSoft,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: pr.panelBorder),
                          ),
                          child: Text(
                            widget.record.securityTag,
                            style: TextStyle(
                              fontSize: compact ? 11 : 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (widget.record.securityNote.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: pr.softFill,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: pr.panelBorder),
                          ),
                          child: Text(
                            widget.record.securityNote,
                            style: TextStyle(
                              color: pr.textMuted,
                              fontSize: compact ? 11 : 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
                SizedBox(height: compact ? 6 : 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.onEdit,
                      icon: Icon(
                        Icons.edit_rounded,
                        size: compact ? 16 : 18,
                      ),
                      label: Text(context.tr('Duzenle', 'Edit')),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: widget.onDelete,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: compact ? 16 : 18,
                      ),
                      label: Text(context.tr('Sil', 'Delete')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
