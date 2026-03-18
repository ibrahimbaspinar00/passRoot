import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_theme.dart';
import '../l10n/lang_x.dart';
import '../models/vault_record.dart';
import '../state/app_settings_store.dart';
import '../utils/password_generator.dart';
import '../utils/password_utils.dart';
import '../widgets/record_form/category_selector.dart';
import '../widgets/record_form/record_form_section_card.dart';
import '../widgets/security_badge.dart';

class RecordFormScreen extends StatefulWidget {
  const RecordFormScreen({super.key, this.initial, required this.settingsStore});

  final VaultRecord? initial;
  final AppSettingsStore settingsStore;

  bool get isEdit => initial != null;

  @override
  State<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends State<RecordFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _accountController;
  late final TextEditingController _passwordController;
  late final TextEditingController _noteController;
  late final TextEditingController _platformController;
  late final TextEditingController _tagsController;

  late RecordCategory _selectedCategory;
  bool _passwordVisible = false;
  bool _saving = false;
  bool _favorite = false;

  @override
  void initState() {
    super.initState();
    final record = widget.initial;
    _titleController = TextEditingController(text: record?.title ?? '');
    _accountController = TextEditingController(text: record?.accountName ?? '');
    _passwordController = TextEditingController(text: record?.password ?? '');
    _noteController = TextEditingController(text: record?.note ?? '');
    _platformController = TextEditingController(
      text: record?.websiteOrDescription.isNotEmpty == true
          ? record!.websiteOrDescription
          : (record?.platform ?? ''),
    );
    _tagsController = TextEditingController(
      text: (record?.tags ?? const <String>[]).join(', '),
    );
    _selectedCategory = record?.category ?? RecordCategory.website;
    _favorite = record?.isFavorite ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _accountController.dispose();
    _passwordController.dispose();
    _noteController.dispose();
    _platformController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  PasswordAnalysis get _analysis => analyzePassword(_passwordController.text);

  Future<void> _generatePassword() async {
    final generated = generatePassword(
      widget.settingsStore.settings.passwordGenerator,
    );
    setState(() {
      _passwordController.text = generated;
    });
    await Clipboard.setData(ClipboardData(text: generated));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            'Guclu sifre olusturuldu ve kopyalandi.',
            'A strong password was generated and copied.',
          ),
        ),
      ),
    );
  }

  Future<void> _copyPassword() async {
    final value = _passwordController.text.trim();
    if (value.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Kopyalanacak sifre bulunamadi.',
              'No password to copy.',
            ),
          ),
        ),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('Sifre kopyalandi.', 'Password copied.'))),
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
    });

    final now = DateTime.now();
    final source = widget.initial;
    final tags = _tagsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final platform = _platformController.text.trim();

    final record = VaultRecord(
      id: source?.id ?? now.microsecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      category: _selectedCategory,
      platform: platform,
      accountName: _accountController.text.trim(),
      password: _passwordController.text.trim(),
      note: _noteController.text.trim(),
      websiteOrDescription: platform,
      isFavorite: _favorite,
      securityNote: source?.securityNote ?? '',
      securityTag: tags.isNotEmpty ? tags.first : '',
      tags: tags,
      createdAt: source?.createdAt ?? now,
      updatedAt: now,
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
    });
    Navigator.pop(context, record);
  }

  @override
  Widget build(BuildContext context) {
    final pr = context.pr;
    final analysis = _analysis;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(
            widget.isEdit ? 'Kaydi Duzenle' : 'Kayit Ekle',
            widget.isEdit ? 'Edit Record' : 'Add Record',
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: Text(
            context.tr(
              widget.isEdit ? 'Degisiklikleri Kaydet' : 'Kaydi Kaydet',
              widget.isEdit ? 'Save Changes' : 'Save Record',
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pr.panelSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: pr.panelBorder),
              ),
              child: Text(
                context.tr(
                  'Temel bilgileri doldurun, gerekiyorsa gelismis alanlari acin.',
                  'Fill the essentials first, then open advanced fields if needed.',
                ),
                style: TextStyle(
                  color: pr.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            RecordFormSectionCard(
              title: context.tr('Temel Alanlar', 'Basic Fields'),
              children: [
                Text(
                  context.tr('Kayit Turu / Kategori', 'Record Type / Category'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                CategorySelector(
                  value: _selectedCategory,
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.tr('Baslik', 'Title'),
                    hintText: context.tr(
                      'Orn: Instagram Ana Hesap',
                      'e.g. Instagram Main Account',
                    ),
                    prefixIcon: const Icon(Icons.title_rounded),
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) {
                      return context.tr(
                        'Baslik zorunludur.',
                        'Title is required.',
                      );
                    }
                    if (text.length < 3) {
                      return context.tr(
                        'Daha acik bir baslik girin.',
                        'Enter a clearer title.',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _accountController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.tr(
                      'Kullanici Adi / E-posta',
                      'Username / E-mail',
                    ),
                    hintText: 'ibrahim@example.com',
                    prefixIcon: const Icon(Icons.person_rounded),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return context.tr(
                        'Kullanici alani zorunludur.',
                        'Username is required.',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  textInputAction: TextInputAction.next,
                  obscureText: !_passwordVisible,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: context.tr('Sifre', 'Password'),
                    prefixIcon: const Icon(Icons.key_rounded),
                    suffixIcon: IconButton(
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
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) {
                      return context.tr('Sifre zorunludur.', 'Password is required.');
                    }
                    if (text.length < 4) {
                      return context.tr('En az 4 karakter girin.', 'Use at least 4 characters.');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SecurityBadge(strength: analysis.strength),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        analysis.weakReasons.isEmpty
                            ? context.tr(
                                'Sifre yapisi dengeli gorunuyor.',
                                'Password structure looks balanced.',
                              )
                            : analysis.weakReasons.join(' - '),
                        style: TextStyle(
                          color: pr.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _generatePassword,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(context.tr('Sifre Uret', 'Generate')),
                    ),
                    OutlinedButton.icon(
                      onPressed: _copyPassword,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(context.tr('Kopyala', 'Copy')),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    labelText: context.tr('Not', 'Note'),
                    alignLabelWithHint: true,
                    hintText: context.tr(
                      'Kisa bir not ekleyin',
                      'Add a short note',
                    ),
                    prefixIcon: const Icon(Icons.sticky_note_2_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _platformController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.tr(
                      'Web Sitesi veya Platform',
                      'Website or Platform',
                    ),
                    hintText: context.tr(
                      'Orn: https://example.com veya Steam',
                      'e.g. https://example.com or Steam',
                    ),
                    prefixIcon: const Icon(Icons.public_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            RecordFormSectionCard(
              title: context.tr('Gelismis Alanlar', 'Advanced Fields'),
              children: [
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text(
                    context.tr('Opsiyonel Alanlari Goster', 'Show Optional Fields'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    context.tr('Etiketler ve favori secenegi', 'Tags and favorite option'),
                    style: TextStyle(color: pr.textMuted),
                  ),
                  children: [
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _tagsController,
                      decoration: InputDecoration(
                        labelText: context.tr('Etiketler (Opsiyonel)', 'Tags (Optional)'),
                        hintText: context.tr(
                          'Orn: kritik, is, yenilenmeli',
                          'e.g. critical, work, rotate',
                        ),
                        prefixIcon: const Icon(Icons.sell_rounded),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _favorite,
                      title: Text(context.tr('Favorilere Ekle', 'Add to Favorites')),
                      subtitle: Text(
                        context.tr(
                          'Kaydi listede one cikarir',
                          'Highlights record in lists',
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _favorite = value;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
