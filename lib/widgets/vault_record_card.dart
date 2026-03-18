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
    required this.analysis,
    required this.maskedPassword,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  final bool compact;
  final VaultRecord record;
  final PasswordAnalysis analysis;
  final String maskedPassword;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  State<VaultRecordCard> createState() => _VaultRecordCardState();
}

class _VaultRecordCardState extends State<VaultRecordCard> {
  bool _passwordVisible = false;

  @override
  void didUpdateWidget(covariant VaultRecordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.id != widget.record.id) {
      _passwordVisible = false;
      return;
    }
    if (oldWidget.record.password != widget.record.password &&
        _passwordVisible) {
      setState(() {
        _passwordVisible = false;
      });
    }
  }

  bool _isCriticalTag(String rawTag) {
    final lower = rawTag.toLowerCase();
    return lower.contains('kritik') || lower.contains('critical');
  }

  @override
  Widget build(BuildContext context) {
    final palette = _VaultCardPalette.of(context);
    final compact = widget.compact;
    final radius = compact ? 17.0 : 20.0;
    final outerPadding = compact ? 13.0 : 15.0;
    final titleSize = compact ? 14.8 : 16.6;

    final buttonTextStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: compact ? 13 : 14,
    );

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: palette.cardDecoration(radius: radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: widget.onTap,
          child: Padding(
            padding: EdgeInsets.all(outerPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: compact ? 36 : 40,
                      height: compact ? 36 : 40,
                      decoration: BoxDecoration(
                        color: palette.categoryIconBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(
                        widget.record.category.icon,
                        size: compact ? 18 : 20,
                        color: palette.categoryIconColor,
                      ),
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
                              color: palette.titleColor,
                              fontWeight: FontWeight.w700,
                              fontSize: titleSize,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.record.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.subtitleColor,
                              fontWeight: FontWeight.w500,
                              fontSize: compact ? 12.7 : 13.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('Favori', 'Favorite'),
                      splashRadius: 20,
                      onPressed: widget.onToggleFavorite,
                      icon: Icon(
                        widget.record.isFavorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: widget.record.isFavorite
                            ? palette.favoriteActive
                            : palette.favoriteInactive,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 10 : 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _VaultInputLikeField(
                        backgroundColor: palette.inputBackground,
                        borderColor: palette.inputBorder,
                        textColor: palette.inputTextColor,
                        compact: compact,
                        text: widget.record.accountName.isEmpty
                            ? '-'
                            : widget.record.accountName,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SecurityBadge(strength: widget.analysis.strength),
                  ],
                ),
                SizedBox(height: compact ? 8 : 9),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 11 : 12,
                    vertical: compact ? 9 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: palette.passwordFieldBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.passwordFieldBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.key_rounded,
                        size: compact ? 18 : 19,
                        color: palette.fieldIconColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _passwordVisible
                              ? widget.record.password
                              : widget.maskedPassword,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.inputTextColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            fontSize: compact ? 15.2 : 15.8,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.tr(
                          _passwordVisible ? 'Gizle' : 'Goster',
                          _passwordVisible ? 'Hide' : 'Show',
                        ),
                        splashRadius: 18,
                        onPressed: () {
                          setState(() {
                            _passwordVisible = !_passwordVisible;
                          });
                        },
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: palette.eyeIconColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.record.securityTag.trim().isNotEmpty ||
                    widget.record.securityNote.trim().isNotEmpty) ...[
                  SizedBox(height: compact ? 8 : 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (widget.record.securityTag.trim().isNotEmpty)
                        _VaultTagChip(
                          text: widget.record.securityTag,
                          textColor: _isCriticalTag(widget.record.securityTag)
                              ? palette.criticalTagText
                              : palette.tagText,
                          backgroundColor:
                              _isCriticalTag(widget.record.securityTag)
                              ? palette.criticalTagBackground
                              : palette.tagBackground,
                          borderColor: _isCriticalTag(widget.record.securityTag)
                              ? palette.criticalTagBorder
                              : palette.tagBorder,
                          compact: compact,
                          isStrongWeight: true,
                        ),
                      if (widget.record.securityNote.trim().isNotEmpty)
                        _VaultTagChip(
                          text: widget.record.securityNote,
                          textColor: palette.noteChipText,
                          backgroundColor: palette.noteChipBackground,
                          borderColor: palette.noteChipBorder,
                          compact: compact,
                        ),
                    ],
                  ),
                ],
                SizedBox(height: compact ? 10 : 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onEdit,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: palette.editButtonBorder),
                          backgroundColor: palette.editButtonBackground,
                          foregroundColor: palette.editButtonForeground,
                          textStyle: buttonTextStyle,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: Icon(Icons.edit_rounded, size: compact ? 16 : 18),
                        label: Text(context.tr('Duzenle', 'Edit')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onDelete,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: palette.deleteButtonBorder),
                          backgroundColor: palette.deleteButtonBackground,
                          foregroundColor: palette.deleteButtonForeground,
                          textStyle: buttonTextStyle,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: compact ? 16 : 18,
                        ),
                        label: Text(context.tr('Sil', 'Delete')),
                      ),
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

class _VaultInputLikeField extends StatelessWidget {
  const _VaultInputLikeField({
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.text,
    required this.compact,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 11 : 12,
        vertical: compact ? 9 : 10,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: compact ? 13.7 : 14.3,
        ),
      ),
    );
  }
}

class _VaultTagChip extends StatelessWidget {
  const _VaultTagChip({
    required this.text,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.compact,
    this.isStrongWeight = false,
  });

  final String text;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;
  final bool compact;
  final bool isStrongWeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 11,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontSize: compact ? 11.3 : 12.1,
          fontWeight: isStrongWeight ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }
}

@immutable
class _VaultCardPalette {
  const _VaultCardPalette({
    required this.cardBackground,
    required this.cardGradient,
    required this.cardBorder,
    required this.cardShadows,
    required this.titleColor,
    required this.subtitleColor,
    required this.categoryIconBg,
    required this.categoryIconColor,
    required this.favoriteActive,
    required this.favoriteInactive,
    required this.inputBackground,
    required this.inputBorder,
    required this.passwordFieldBackground,
    required this.passwordFieldBorder,
    required this.inputTextColor,
    required this.fieldIconColor,
    required this.eyeIconColor,
    required this.tagBackground,
    required this.tagBorder,
    required this.tagText,
    required this.criticalTagBackground,
    required this.criticalTagBorder,
    required this.criticalTagText,
    required this.noteChipBackground,
    required this.noteChipBorder,
    required this.noteChipText,
    required this.editButtonBackground,
    required this.editButtonBorder,
    required this.editButtonForeground,
    required this.deleteButtonBackground,
    required this.deleteButtonBorder,
    required this.deleteButtonForeground,
  });

  final Color cardBackground;
  final Gradient? cardGradient;
  final Color cardBorder;
  final List<BoxShadow> cardShadows;
  final Color titleColor;
  final Color subtitleColor;
  final Color categoryIconBg;
  final Color categoryIconColor;
  final Color favoriteActive;
  final Color favoriteInactive;
  final Color inputBackground;
  final Color inputBorder;
  final Color passwordFieldBackground;
  final Color passwordFieldBorder;
  final Color inputTextColor;
  final Color fieldIconColor;
  final Color eyeIconColor;
  final Color tagBackground;
  final Color tagBorder;
  final Color tagText;
  final Color criticalTagBackground;
  final Color criticalTagBorder;
  final Color criticalTagText;
  final Color noteChipBackground;
  final Color noteChipBorder;
  final Color noteChipText;
  final Color editButtonBackground;
  final Color editButtonBorder;
  final Color editButtonForeground;
  final Color deleteButtonBackground;
  final Color deleteButtonBorder;
  final Color deleteButtonForeground;

  factory _VaultCardPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pr = context.pr;
    final isDark = theme.brightness == Brightness.dark;

    if (isDark) {
      final surface = Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.07),
        pr.panelSurface,
      );
      return _VaultCardPalette(
        cardBackground: surface,
        cardGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(scheme.primary.withValues(alpha: 0.08), surface),
            Color.alphaBlend(const Color(0x14000000), surface),
          ],
        ),
        cardBorder: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.14),
          pr.panelBorder,
        ),
        cardShadows: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF03070D).withValues(alpha: 0.5),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.16),
            blurRadius: 16,
            spreadRadius: -6,
            offset: const Offset(0, 4),
          ),
        ],
        titleColor: theme.colorScheme.onSurface,
        subtitleColor: pr.textMuted,
        categoryIconBg: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.2),
          const Color(0xFF1A2B3D),
        ),
        categoryIconColor: scheme.primary.withValues(alpha: 0.95),
        favoriteActive: scheme.secondary,
        favoriteInactive: pr.iconMuted.withValues(alpha: 0.9),
        inputBackground: Color.alphaBlend(const Color(0x1DFFFFFF), pr.softFill),
        inputBorder: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.16),
          pr.panelBorder,
        ),
        passwordFieldBackground: Color.alphaBlend(
          const Color(0x17000000),
          pr.softFillAlt,
        ),
        passwordFieldBorder: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.12),
          pr.panelBorder,
        ),
        inputTextColor: theme.colorScheme.onSurface,
        fieldIconColor: pr.iconMuted,
        eyeIconColor: scheme.onSurface.withValues(alpha: 0.9),
        tagBackground: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.2),
          pr.accentSoft,
        ),
        tagBorder: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.18),
          pr.panelBorder,
        ),
        tagText: theme.colorScheme.onSurface,
        criticalTagBackground: const Color(0xFF4C2E37),
        criticalTagBorder: const Color(0xFF6D4350),
        criticalTagText: const Color(0xFFF8B3BF),
        noteChipBackground: Color.alphaBlend(
          const Color(0x12000000),
          pr.softFill,
        ),
        noteChipBorder: pr.panelBorder,
        noteChipText: pr.textMuted,
        editButtonBackground: const Color(0x14000000),
        editButtonBorder: pr.panelBorder,
        editButtonForeground: theme.colorScheme.onSurface,
        deleteButtonBackground: const Color(0x22A83644),
        deleteButtonBorder: const Color(0x886A3441),
        deleteButtonForeground: const Color(0xFFF4C5CB),
      );
    }

    return _VaultCardPalette(
      cardBackground: const Color(0xFFFDFEFF),
      cardGradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFFFDFEFF), Color(0xFFF8FBFF)],
      ),
      cardBorder: const Color(0xFFE2EAF4),
      cardShadows: const <BoxShadow>[
        BoxShadow(
          color: Color(0x14455F78),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
      titleColor: const Color(0xFF172432),
      subtitleColor: const Color(0xFF657688),
      categoryIconBg: const Color(0xFFEAF2FD),
      categoryIconColor: const Color(0xFF2E63D7),
      favoriteActive: const Color(0xFF2563EB),
      favoriteInactive: const Color(0xFF8190A3),
      inputBackground: const Color(0xFFF7FAFD),
      inputBorder: const Color(0xFFDCE6F2),
      passwordFieldBackground: const Color(0xFFF3F7FC),
      passwordFieldBorder: const Color(0xFFD8E3EF),
      inputTextColor: const Color(0xFF111C28),
      fieldIconColor: const Color(0xFF748399),
      eyeIconColor: const Color(0xFF4D5E72),
      tagBackground: const Color(0xFFEEF3FA),
      tagBorder: const Color(0xFFDCE6F1),
      tagText: const Color(0xFF2C3E52),
      criticalTagBackground: const Color(0xFFFCECEE),
      criticalTagBorder: const Color(0xFFF6CCD3),
      criticalTagText: const Color(0xFFB42335),
      noteChipBackground: const Color(0xFFF7FAFD),
      noteChipBorder: const Color(0xFFDCE6F2),
      noteChipText: const Color(0xFF5F7287),
      editButtonBackground: Colors.white,
      editButtonBorder: const Color(0xFFD2DEEB),
      editButtonForeground: const Color(0xFF1D2E41),
      deleteButtonBackground: const Color(0xFFFFF4F3),
      deleteButtonBorder: const Color(0xFFF2C7C2),
      deleteButtonForeground: const Color(0xFFB1362A),
    );
  }

  BoxDecoration cardDecoration({required double radius}) {
    return BoxDecoration(
      color: cardBackground,
      gradient: cardGradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: cardBorder),
      boxShadow: cardShadows,
    );
  }
}
