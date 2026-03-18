import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../l10n/lang_x.dart';
import '../models/app_settings.dart';
import '../models/vault_record.dart';
import '../state/app_settings_store.dart';
import '../state/vault_store.dart';
import '../widgets/vault_record_card.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({
    super.key,
    required this.store,
    required this.settingsStore,
    required this.onCreate,
    required this.onEdit,
  });

  final VaultStore store;
  final AppSettingsStore settingsStore;
  final VoidCallback onCreate;
  final ValueChanged<VaultRecord> onEdit;

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen>
    with AutomaticKeepAliveClientMixin<VaultScreen> {
  RecordCategory? _selectedCategory;
  late RecordCardStyle _cardStyle;
  List<VaultRecord> _records = const <VaultRecord>[];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cardStyle = widget.settingsStore.settings.cardStyle;
    _records = _computeVisibleRecords();
    widget.store.addListener(_syncFromStores);
    widget.settingsStore.addListener(_syncFromStores);
  }

  @override
  void didUpdateWidget(covariant VaultScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_syncFromStores);
      widget.store.addListener(_syncFromStores);
    }
    if (oldWidget.settingsStore != widget.settingsStore) {
      oldWidget.settingsStore.removeListener(_syncFromStores);
      widget.settingsStore.addListener(_syncFromStores);
    }
    _syncFromStores();
  }

  @override
  void dispose() {
    widget.store.removeListener(_syncFromStores);
    widget.settingsStore.removeListener(_syncFromStores);
    super.dispose();
  }

  List<VaultRecord> _computeVisibleRecords() {
    if (_selectedCategory == null) {
      return widget.store.sortedRecords;
    }
    return widget.store.recordsForCategory(_selectedCategory!);
  }

  bool _sameRecords(List<VaultRecord> a, List<VaultRecord> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].updatedAt != b[i].updatedAt) {
        return false;
      }
    }
    return true;
  }

  void _syncFromStores() {
    final nextCardStyle = widget.settingsStore.settings.cardStyle;
    final nextRecords = _computeVisibleRecords();
    if (nextCardStyle == _cardStyle && _sameRecords(nextRecords, _records)) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _cardStyle = nextCardStyle;
      _records = nextRecords;
    });
  }

  void _onCategoryChanged(RecordCategory? category) {
    if (_selectedCategory == category) return;
    setState(() {
      _selectedCategory = category;
      _records = _computeVisibleRecords();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pr = context.pr;
    final records = _records;
    final compact = _cardStyle == RecordCardStyle.compact;

    return CustomScrollView(
      key: const PageStorageKey<String>('vault-scroll'),
      cacheExtent: 900,
      slivers: [
        SliverToBoxAdapter(
          child: RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _VaultTopArea(
                selectedCategory: _selectedCategory,
                onCategoryChanged: _onCategoryChanged,
                onCreate: widget.onCreate,
              ),
            ),
          ),
        ),
        if (records.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                context.tr(
                  'Bu filtrede kayit bulunmuyor.',
                  'No records match this filter.',
                ),
                style: TextStyle(color: pr.textMuted),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final useGrid = compact ? width >= 780 : width >= 920;
                final spacing = compact ? 8.0 : 10.0;

                if (!useGrid) {
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final record = records[index];
                        final isLast = index == records.length - 1;
                        return Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 0 : spacing),
                          child: RepaintBoundary(
                            child: VaultRecordCard(
                              compact: compact,
                              record: record,
                              onToggleFavorite: () {
                                widget.store.toggleFavorite(record.id);
                              },
                              onEdit: () {
                                widget.onEdit(record);
                              },
                              onDelete: () {
                                widget.store.deleteRecord(record.id);
                              },
                              onTap: () {
                                widget.onEdit(record);
                              },
                            ),
                          ),
                        );
                      },
                      childCount: records.length,
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: false,
                      addSemanticIndexes: false,
                    ),
                  );
                }

                return SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final record = records[index];
                      return RepaintBoundary(
                        child: VaultRecordCard(
                          compact: compact,
                          record: record,
                          onToggleFavorite: () {
                            widget.store.toggleFavorite(record.id);
                          },
                          onEdit: () {
                            widget.onEdit(record);
                          },
                          onDelete: () {
                            widget.store.deleteRecord(record.id);
                          },
                          onTap: () {
                            widget.onEdit(record);
                          },
                        ),
                      );
                    },
                    childCount: records.length,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: false,
                    addSemanticIndexes: false,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: compact ? 1.5 : 1.34,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _VaultTopArea extends StatelessWidget {
  const _VaultTopArea({
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.onCreate,
  });

  final RecordCategory? selectedCategory;
  final ValueChanged<RecordCategory?> onCategoryChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: pr.panelSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: pr.panelBorder),
            boxShadow: [
              BoxShadow(
                color: pr.panelShadow.withValues(alpha: 0.85),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Kayit Kasasi', 'Vault'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: Text(context.tr('Yeni Kayit', 'New Record')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                selected: selectedCategory == null,
                label: Text(context.tr('Tum Kayitlar', 'All Records')),
                onSelected: (_) => onCategoryChanged(null),
              ),
              const SizedBox(width: 8),
              for (final category in RecordCategory.values) ...[
                FilterChip(
                  selected: selectedCategory == category,
                  avatar: Icon(category.icon, size: 16),
                  label: Text(category.localizedLabel(context)),
                  onSelected: (_) => onCategoryChanged(category),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
