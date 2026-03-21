import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../l10n/lang_x.dart';
import '../models/vault_record.dart';
import '../state/vault_store.dart';
import 'security_detail_screen.dart';
import '../widgets/dashboard_stat_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.store,
    required this.onOpenDetail,
  });

  final VaultStore store;
  final ValueChanged<SecurityDetailType> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final topCategories = store.topCategories();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            _DashboardHeader(totalCount: store.totalCount),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width >= 1200
                    ? 4
                    : width >= 760
                    ? 2
                    : 1;
                final childAspectRatio = switch (crossAxisCount) {
                  1 => 1.45,
                  2 => 1.1,
                  _ => 1.2,
                };

                return GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: childAspectRatio,
                  children: [
                    DashboardStatCard(
                      title: context.tr('Guclu Sifreler', 'Strong Passwords'),
                      value: '${store.strongRecords.length}',
                      subtitle: context.tr(
                        'Guvenli kayitlar',
                        'Secure records',
                      ),
                      icon: Icons.stars_rounded,
                      tint: const Color(0xFF1D8F62),
                      onTap: () => onOpenDetail(SecurityDetailType.strong),
                    ),
                    DashboardStatCard(
                      title: context.tr('Zayif Parolalar', 'Weak Passwords'),
                      value: '${store.weakRecords.length}',
                      subtitle: context.tr(
                        'Acil guncelleme onerilir',
                        'Update is recommended',
                      ),
                      icon: Icons.gpp_bad_outlined,
                      tint: const Color(0xFFDC2626),
                      onTap: () => onOpenDetail(SecurityDetailType.weak),
                    ),
                    DashboardStatCard(
                      title: context.tr(
                        'Ayni Sifre Kullanimi',
                        'Reused Passwords',
                      ),
                      value: '${store.repeatedRecordCount}',
                      subtitle: context.tr(
                        '${store.repeatedGroupCount} grup tekrar',
                        '${store.repeatedGroupCount} repeated groups',
                      ),
                      icon: Icons.warning_amber_rounded,
                      tint: const Color(0xFFD97706),
                      onTap: () => onOpenDetail(SecurityDetailType.reused),
                    ),
                    DashboardStatCard(
                      title: context.tr('Toplam Kayit', 'Total Records'),
                      value: '${store.totalCount}',
                      subtitle: context.tr(
                        '${store.favoriteCount} favori kayit',
                        '${store.favoriteCount} favorite records',
                      ),
                      icon: Icons.storage_rounded,
                      tint: const Color(0xFF2563EB),
                      onTap: () => onOpenDetail(SecurityDetailType.total),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pr.panelSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: pr.panelBorder),
                boxShadow: [
                  BoxShadow(
                    color: pr.panelShadow,
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(
                      'En Cok Kullanilan Kategoriler',
                      'Top Categories',
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (topCategories.isEmpty)
                    Text(
                      context.tr(
                        'Kategori dagilimi icin kayit ekleyin.',
                        'Add records to see category distribution.',
                      ),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: pr.textMuted),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in topCategories)
                          Chip(
                            avatar: Icon(entry.key.icon, size: 18),
                            label: Text(
                              '${entry.key.localizedLabel(context)} (${entry.value})',
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.totalCount});

  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    final heroMidColor = Color.lerp(
      pr.heroGradientStart,
      pr.heroGradientEnd,
      0.5,
    )!;
    final useLightForeground =
        ThemeData.estimateBrightnessForColor(heroMidColor) == Brightness.dark;
    final heroTextColor = useLightForeground ? Colors.white : Colors.black;
    final heroMutedTextColor = heroTextColor.withValues(alpha: 0.86);
    final heroChipColor = heroTextColor.withValues(
      alpha: useLightForeground ? 0.14 : 0.08,
    );
    final heroChipBorderColor = heroTextColor.withValues(
      alpha: useLightForeground ? 0.28 : 0.18,
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [pr.heroGradientStart, pr.heroGradientEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: pr.panelShadow.withValues(alpha: 0.48),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Hos geldiniz', 'Welcome'),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: heroMutedTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'PassRoot Security Dashboard',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: heroTextColor,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: heroChipColor,
              border: Border.all(color: heroChipBorderColor),
            ),
            child: Row(
              children: [
                Icon(Icons.insights_rounded, color: heroTextColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr(
                      '$totalCount hassas kayit aktif olarak izleniyor',
                      '$totalCount secure records are actively monitored',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: heroTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
