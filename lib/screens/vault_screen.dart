import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../l10n/lang_x.dart';
import '../models/app_settings.dart';
import '../models/vault_record.dart';
import '../services/biometric_auth_service.dart';
import '../state/app_settings_store.dart';
import '../state/vault_store.dart';
import '../utils/password_utils.dart';
import '../widgets/pin_dialogs.dart';
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
  static const int _pageSize = 48;
  static const double _loadMoreThreshold = 460;
  static const Duration _searchDebounce = Duration(milliseconds: 220);

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  // Performance: keep derived view data per record to avoid repeating expensive work in builders.
  final Map<String, _RecordRenderData> _renderDataCache =
      <String, _RecordRenderData>{};
  final Map<String, _SearchIndexData> _searchIndexCache =
      <String, _SearchIndexData>{};

  Timer? _searchDebounceTimer;
  late final BiometricAuthService _biometricAuthService;

  late final ValueNotifier<RecordCategory?> _selectedCategoryNotifier;
  late final ValueNotifier<String> _searchQueryNotifier;
  late final ValueNotifier<_VaultListState> _listStateNotifier;
  bool _biometricAvailable = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _biometricAuthService = BiometricAuthService();
    _selectedCategoryNotifier = ValueNotifier<RecordCategory?>(null);
    _searchQueryNotifier = ValueNotifier<String>('');
    _listStateNotifier = ValueNotifier<_VaultListState>(
      _VaultListState.empty(
        compact:
            widget.settingsStore.settings.cardStyle == RecordCardStyle.compact,
      ),
    );
    widget.store.addListener(_syncFromStores);
    widget.settingsStore.addListener(_syncFromStores);
    _scrollController.addListener(_onScroll);
    unawaited(_loadBiometricAvailability());
    _syncFromStores(resetVisibleWindow: true);
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
      unawaited(_loadBiometricAvailability());
    }
    _syncFromStores(resetVisibleWindow: true);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _selectedCategoryNotifier.dispose();
    _searchQueryNotifier.dispose();
    _listStateNotifier.dispose();
    widget.store.removeListener(_syncFromStores);
    widget.settingsStore.removeListener(_syncFromStores);
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final state = _listStateNotifier.value;
    if (!state.hasMore) return;
    final position = _scrollController.position;
    final remaining = position.maxScrollExtent - position.pixels;
    if (remaining <= _loadMoreThreshold) {
      _expandVisibleWindow();
    }
  }

  void _expandVisibleWindow() {
    final state = _listStateNotifier.value;
    if (!state.hasMore) return;

    // Performance: page records in chunks to keep first build and updates light.
    final nextVisible = math.min(state.visibleCount + _pageSize, state.total);
    if (nextVisible == state.visibleCount) return;
    _listStateNotifier.value = state.copyWith(visibleCount: nextVisible);
  }

  void _onCategoryChanged(RecordCategory? category) {
    if (_selectedCategoryNotifier.value == category) return;
    _selectedCategoryNotifier.value = category;
    _syncFromStores(resetVisibleWindow: true);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _onSearchChanged(String rawQuery) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounce, () {
      if (!mounted) return;
      final query = rawQuery.trim().toLowerCase();
      if (_searchQueryNotifier.value == query) return;
      _searchQueryNotifier.value = query;
      _syncFromStores(resetVisibleWindow: true);
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadBiometricAvailability() async {
    final available = await _biometricAuthService.canUseBiometrics();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
    });
    if (!available && widget.settingsStore.settings.biometricUnlockEnabled) {
      await widget.settingsStore.setBiometricUnlockEnabled(false);
    }
  }

  Future<String?> _askMasterPassword() async {
    final controller = TextEditingController();
    String? errorText;
    var hidden = true;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                context.tr('Master Password Dogrulama', 'Verify Master Password'),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr(
                      'Bu islem icin master password girin.',
                      'Enter master password for this action.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    obscureText: hidden,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      final value = controller.text.trim();
                      if (value.length < 12) {
                        setDialogState(() {
                          errorText = context.tr(
                            'Master password en az 12 karakter olmali.',
                            'Master password must be at least 12 characters.',
                          );
                        });
                        return;
                      }
                      Navigator.pop(context, value);
                    },
                    decoration: InputDecoration(
                      labelText: context.tr('Master Password', 'Master Password'),
                      errorText: errorText,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setDialogState(() {
                            hidden = !hidden;
                          });
                        },
                        icon: Icon(
                          hidden
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('Iptal', 'Cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.length < 12) {
                      setDialogState(() {
                        errorText = context.tr(
                          'Master password en az 12 karakter olmali.',
                          'Master password must be at least 12 characters.',
                        );
                      });
                      return;
                    }
                    Navigator.pop(context, value);
                  },
                  child: Text(context.tr('Dogrula', 'Verify')),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<bool> _reauthForRecordDelete() async {
    final settings = widget.settingsStore.settings;
    if (settings.biometricUnlockEnabled && _biometricAvailable) {
      final biometricOk = await _biometricAuthService.authenticate(
        reason: context.tr(
          'Kayit silme islemi icin biyometrik dogrulama yapin.',
          'Authenticate biometrically to delete this record.',
        ),
      );
      if (biometricOk) {
        return true;
      }
    }

    await widget.settingsStore.refreshPinAvailability(notify: false);
    if (!mounted) {
      return false;
    }

    if (widget.settingsStore.pinAvailable) {
      return PinDialogs.verifyPin(
        context: context,
        onVerify: widget.settingsStore.vaultKeyService.unlockWithPin,
        title: context.tr('Guvenlik Dogrulamasi', 'Security Verification'),
        description: context.tr(
          'Kaydi silmek icin PIN girin.',
          'Enter PIN to delete this record.',
        ),
      );
    }

    final masterPassword = await _askMasterPassword();
    if (masterPassword == null) {
      return false;
    }
    final unlock = await widget.settingsStore.vaultKeyService
        .unlockWithMasterPasswordDetailed(masterPassword);
    if (!unlock.success && mounted) {
      _snack(
        unlock.message ??
            context.tr(
              'Master password dogrulanamadi.',
              'Master password verification failed.',
            ),
      );
    }
    return unlock.success;
  }

  Future<bool> _confirmDeleteRecord(VaultRecord record) async {
    final titleText = record.title.trim().isEmpty
        ? context.tr('Secili kayit', 'selected record')
        : record.title.trim();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            context.tr(
              'Kayit Sil (Kritik Islem)?',
              'Delete Record (Critical Action)?',
            ),
          ),
          content: Text(
            context.tr(
              '"$titleText" kaydi silinecek. Devam etmeden once kimlik dogrulamasi istenir. Silme sonrasi kisa sureli geri alma sunulur.',
              '"$titleText" will be deleted. Identity verification is required before continuing. A short undo window will be available after deletion.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('Iptal', 'Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                context.tr('Sil ve Dogrula', 'Delete & Verify'),
              ),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _restoreDeletedRecord(VaultRecord record) async {
    final exists = widget.store.records.any((item) => item.id == record.id);
    if (exists) {
      return;
    }
    try {
      await widget.store.addRecord(record.copyWith(updatedAt: DateTime.now()));
      if (!mounted) return;
      _snack(
        context.tr('Kayit geri yuklendi.', 'Record restored.'),
      );
    } on VaultStoreException catch (error) {
      _snack(error.message);
    }
  }

  Future<void> _deleteRecordWithProtection(VaultRecord record) async {
    final confirmed = await _confirmDeleteRecord(record);
    if (!confirmed) {
      return;
    }

    final verified = await _reauthForRecordDelete();
    if (!verified) {
      return;
    }

    try {
      await widget.store.deleteRecord(record.id);
    } on VaultStoreException catch (error) {
      _snack(error.message);
      return;
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(
          context.tr(
            'Kayit silindi. Kisa sure icinde geri alabilirsiniz.',
            'Record deleted. You can undo for a short time.',
          ),
        ),
        action: SnackBarAction(
          label: context.tr('Geri Al', 'Undo'),
          onPressed: () {
            unawaited(_restoreDeletedRecord(record));
          },
        ),
      ),
    );
  }

  void _syncFromStores({bool resetVisibleWindow = false}) {
    final selectedCategory = _selectedCategoryNotifier.value;
    final searchQuery = _searchQueryNotifier.value;
    final compact =
        widget.settingsStore.settings.cardStyle == RecordCardStyle.compact;
    final sourceRecords = selectedCategory == null
        ? widget.store.sortedRecords
        : widget.store.recordsForCategory(selectedCategory);
    final records = searchQuery.isEmpty
        ? sourceRecords
        : _filterBySearch(sourceRecords, searchQuery);

    final previous = _listStateNotifier.value;
    final recordsChanged = !_sameRecords(previous.records, records);
    final compactChanged = previous.compact != compact;
    if (!recordsChanged && !compactChanged && !resetVisibleWindow) {
      return;
    }

    if (recordsChanged) {
      _dropUnusedRenderData(records);
    }

    final nextVisible = resetVisibleWindow || recordsChanged || compactChanged
        ? _initialVisibleCount(records.length)
        : math.min(previous.visibleCount, records.length);

    _listStateNotifier.value = _VaultListState(
      records: records,
      compact: compact,
      visibleCount: nextVisible,
    );
  }

  int _initialVisibleCount(int total) {
    return math.min(total, _pageSize);
  }

  bool _sameRecords(List<VaultRecord> left, List<VaultRecord> right) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      final a = left[i];
      final b = right[i];
      if (a.id != b.id || a.updatedAt != b.updatedAt) {
        return false;
      }
    }
    return true;
  }

  void _dropUnusedRenderData(List<VaultRecord> records) {
    final ids = records.map((record) => record.id).toSet();
    _renderDataCache.removeWhere((id, _) => !ids.contains(id));
    _searchIndexCache.removeWhere((id, _) => !ids.contains(id));
  }

  List<VaultRecord> _filterBySearch(List<VaultRecord> source, String query) {
    // Performance: search matching is pre-normalized and cached per record update.
    final filtered = <VaultRecord>[];
    for (final record in source) {
      if (_resolveSearchIndex(record).normalized.contains(query)) {
        filtered.add(record);
      }
    }
    return filtered;
  }

  _SearchIndexData _resolveSearchIndex(VaultRecord record) {
    final cached = _searchIndexCache[record.id];
    if (cached != null && cached.updatedAt == record.updatedAt) {
      return cached;
    }
    final next = _SearchIndexData(
      updatedAt: record.updatedAt,
      normalized:
          '${record.title} ${record.subtitle} ${record.accountName} ${record.websiteOrDescription} ${record.note}'
              .toLowerCase(),
    );
    _searchIndexCache[record.id] = next;
    return next;
  }

  _RecordRenderData _resolveRenderData(VaultRecord record) {
    final cached = _renderDataCache[record.id];
    if (cached != null && cached.updatedAt == record.updatedAt) {
      return cached;
    }
    final next = _RecordRenderData(
      updatedAt: record.updatedAt,
      analysis: widget.store.analysisForRecord(record),
      maskedPassword: widget.store.maskedPasswordForRecord(record),
    );
    _renderDataCache[record.id] = next;
    return next;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pr = context.pr;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Column(
      children: [
        RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ValueListenableBuilder<RecordCategory?>(
              valueListenable: _selectedCategoryNotifier,
              builder: (context, selectedCategory, _) {
                return _VaultTopArea(
                  selectedCategory: selectedCategory,
                  onCategoryChanged: _onCategoryChanged,
                  searchController: _searchController,
                  onSearchChanged: _onSearchChanged,
                  onCreate: widget.onCreate,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ValueListenableBuilder<_VaultListState>(
            valueListenable: _listStateNotifier,
            builder: (context, state, _) {
              if (state.records.isEmpty) {
                return Center(
                  child: Text(
                    context.tr(
                      'Bu filtrede kayit bulunmuyor.',
                      'No records match this filter.',
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: pr.textMuted),
                  ),
                );
              }

              final visibleCount = state.visibleCount;
              final childCount = visibleCount + (state.hasMore ? 1 : 0);
              final spacing = state.compact ? 8.0 : 10.0;

              return ListView.builder(
                key: const PageStorageKey<String>('vault-record-list'),
                controller: _scrollController,
                cacheExtent: 1000,
                padding: EdgeInsets.fromLTRB(16, 8, 16, 176 + safeBottom),
                itemCount: childCount,
                itemBuilder: (context, index) {
                  if (index >= visibleCount) {
                    return const _LoadMoreListTile();
                  }

                  final record = state.records[index];
                  final renderData = _resolveRenderData(record);

                  return Padding(
                    padding: EdgeInsets.only(bottom: spacing),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 920),
                        child: RepaintBoundary(
                          child: VaultRecordCard(
                            key: ValueKey<String>(record.id),
                            compact: state.compact,
                            record: record,
                            analysis: renderData.analysis,
                            maskedPassword: renderData.maskedPassword,
                            onToggleFavorite: () async {
                              try {
                                await widget.store.toggleFavorite(record.id);
                              } on VaultStoreException catch (error) {
                                _snack(error.message);
                              }
                            },
                            onEdit: () {
                              widget.onEdit(record);
                            },
                            onDelete: () async {
                              await _deleteRecordWithProtection(record);
                            },
                            onTap: () {
                              widget.onEdit(record);
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
    required this.searchController,
    required this.onSearchChanged,
    required this.onCreate,
  });

  final RecordCategory? selectedCategory;
  final ValueChanged<RecordCategory?> onCategoryChanged;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
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
                color: pr.panelShadow.withValues(alpha: 0.45),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Kayit Kasasi', 'Vault'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: Text(context.tr('Yeni Kayit', 'New Record')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: searchController,
          textInputAction: TextInputAction.search,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: context.tr(
              'Kasa icinde ara (baslik, platform, hesap...)',
              'Search in vault (title, platform, account...)',
            ),
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

@immutable
class _VaultListState {
  const _VaultListState({
    required this.records,
    required this.compact,
    required this.visibleCount,
  });

  final List<VaultRecord> records;
  final bool compact;
  final int visibleCount;

  int get total => records.length;
  bool get hasMore => visibleCount < total;

  factory _VaultListState.empty({required bool compact}) {
    return _VaultListState(
      records: const <VaultRecord>[],
      compact: compact,
      visibleCount: 0,
    );
  }

  _VaultListState copyWith({
    List<VaultRecord>? records,
    bool? compact,
    int? visibleCount,
  }) {
    return _VaultListState(
      records: records ?? this.records,
      compact: compact ?? this.compact,
      visibleCount: visibleCount ?? this.visibleCount,
    );
  }
}

class _RecordRenderData {
  const _RecordRenderData({
    required this.updatedAt,
    required this.analysis,
    required this.maskedPassword,
  });

  final DateTime updatedAt;
  final PasswordAnalysis analysis;
  final String maskedPassword;
}

class _SearchIndexData {
  const _SearchIndexData({required this.updatedAt, required this.normalized});

  final DateTime updatedAt;
  final String normalized;
}

class _LoadMoreListTile extends StatelessWidget {
  const _LoadMoreListTile();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              context.tr('Kayitlar yukleniyor...', 'Loading records...'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
