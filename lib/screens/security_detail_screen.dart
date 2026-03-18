import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../l10n/lang_x.dart';
import '../models/vault_record.dart';
import '../state/vault_store.dart';
import '../utils/password_utils.dart';
import '../widgets/security_badge.dart';

enum SecurityDetailType { strong, weak, reused, total }

class SecurityDetailScreen extends StatelessWidget {
  const SecurityDetailScreen({
    super.key,
    required this.type,
    required this.store,
  });

  final SecurityDetailType type;
  final VaultStore store;

  @override
  Widget build(BuildContext context) {
    final title = switch (type) {
      SecurityDetailType.strong => context.tr('Guclu Sifreler', 'Strong Passwords'),
      SecurityDetailType.weak => context.tr('Zayif Parolalar', 'Weak Passwords'),
      SecurityDetailType.reused => context.tr('Ayni Sifre Kullanilanlar', 'Reused Passwords'),
      SecurityDetailType.total => context.tr('Tum Kayitlar', 'All Records'),
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          return switch (type) {
            SecurityDetailType.strong => _StrongList(
              records: store.strongRecords,
            ),
            SecurityDetailType.weak => _WeakList(records: store.weakRecords),
            SecurityDetailType.reused => _ReusedList(
              groups: store.repeatedPasswordGroups,
            ),
            SecurityDetailType.total => _AllRecordsList(
              records: store.sortedRecords,
            ),
          };
        },
      ),
    );
  }
}

class _StrongList extends StatelessWidget {
  const _StrongList({required this.records});

  final List<VaultRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return _EmptyState(
        message: context.tr(
          'Guclu sifre bulunan kayit yok.',
          'No strong-password records found.',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final record = records[index];
        return _DetailTile(
          record: record,
          analysis: analyzePassword(record.password),
        );
      },
    );
  }
}

class _WeakList extends StatelessWidget {
  const _WeakList({required this.records});

  final List<VaultRecord> records;

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    final scheme = Theme.of(context).colorScheme;
    if (records.isEmpty) {
      return _EmptyState(
        message: context.tr('Zayif parola tespit edilmedi.', 'No weak passwords found.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final record = records[index];
        final analysis = analyzePassword(record.password);
        final reasons = analysis.weakReasons;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: pr.panelSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.error.withValues(alpha: 0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailTileHeader(record: record, analysis: analysis),
              const SizedBox(height: 8),
              if (reasons.isEmpty)
                Text(
                  context.tr(
                    'Bu parola zayif sinifinda gorunuyor.',
                    'This password appears to be weak.',
                  ),
                  style: TextStyle(color: scheme.error.withValues(alpha: 0.88)),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final reason in reasons)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Color.alphaBlend(
                            scheme.error.withValues(alpha: 0.16),
                            pr.dangerSoft,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: scheme.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          reason,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ReusedList extends StatelessWidget {
  const _ReusedList({required this.groups});

  final Map<String, List<VaultRecord>> groups;

  String _maskedPassword(String value) {
    if (value.length <= 3) return '***';
    return '${'*' * (value.length - 3)}${value.substring(value.length - 3)}';
  }

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    final scheme = Theme.of(context).colorScheme;
    if (groups.isEmpty) {
      return _EmptyState(
        message: context.tr('Ayni sifre kullanimi bulunmuyor.', 'No password reuse found.'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: pr.warningSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.tertiary.withValues(alpha: 0.35)),
          ),
          child: Text(
            context.tr(
              'Birden fazla kayitta ayni sifre kullaniyorsunuz. Bu guvenlik riski olusturur.',
              'You are using the same password in multiple records. This is a security risk.',
            ),
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        for (final entry in groups.entries) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pr.panelSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: pr.panelBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    'Grup (${entry.value.length}) • ${_maskedPassword(entry.key)}',
                    'Group (${entry.value.length}) • ${_maskedPassword(entry.key)}',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                for (final record in entry.value)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(record.category.icon),
                    title: Text(record.title),
                    subtitle: Text(
                      '${record.category.localizedLabel(context)} • ${record.accountName}',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _AllRecordsList extends StatelessWidget {
  const _AllRecordsList({required this.records});

  final List<VaultRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return _EmptyState(message: context.tr('Kayit bulunmuyor.', 'No records found.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final record = records[index];
        return _DetailTile(
          record: record,
          analysis: analyzePassword(record.password),
        );
      },
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.record, required this.analysis});

  final VaultRecord record;
  final PasswordAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pr.panelSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pr.panelBorder),
      ),
      child: _DetailTileHeader(record: record, analysis: analysis),
    );
  }
}

class _DetailTileHeader extends StatelessWidget {
  const _DetailTileHeader({required this.record, required this.analysis});

  final VaultRecord record;
  final PasswordAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(radius: 18, child: Icon(record.category.icon, size: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text('${record.category.localizedLabel(context)} • ${record.accountName}'),
            ],
          ),
        ),
        SecurityBadge(strength: analysis.strength),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    return Center(
      child: Text(
        message,
        style: TextStyle(color: pr.textMuted, fontSize: 15),
      ),
    );
  }
}

