import 'package:flutter/material.dart';

enum RecordCategory {
  website,
  email,
  socialMedia,
  bank,
  cardInfo,
  app,
  licenseKey,
  gaming,
  wifi,
  secureNote,
  other,
}

extension RecordCategoryX on RecordCategory {
  String get label {
    switch (this) {
      case RecordCategory.website:
        return 'Web Sitesi';
      case RecordCategory.email:
        return 'E-posta';
      case RecordCategory.socialMedia:
        return 'Sosyal Medya';
      case RecordCategory.bank:
        return 'Banka';
      case RecordCategory.cardInfo:
        return 'Kart Bilgisi';
      case RecordCategory.app:
        return 'Uygulama';
      case RecordCategory.licenseKey:
        return 'Lisans Anahtari';
      case RecordCategory.gaming:
        return 'Oyun';
      case RecordCategory.wifi:
        return 'Wi-Fi';
      case RecordCategory.secureNote:
        return 'Not / Ozel Bilgi';
      case RecordCategory.other:
        return 'Diger';
    }
  }

  String get labelEn {
    switch (this) {
      case RecordCategory.website:
        return 'Website';
      case RecordCategory.email:
        return 'E-mail';
      case RecordCategory.socialMedia:
        return 'Social Media';
      case RecordCategory.bank:
        return 'Bank';
      case RecordCategory.cardInfo:
        return 'Card Info';
      case RecordCategory.app:
        return 'Application';
      case RecordCategory.licenseKey:
        return 'License Key';
      case RecordCategory.gaming:
        return 'Gaming';
      case RecordCategory.wifi:
        return 'Wi-Fi';
      case RecordCategory.secureNote:
        return 'Note / Secure Info';
      case RecordCategory.other:
        return 'Other';
    }
  }

  String localizedLabel(BuildContext context) {
    final isEnglish =
        Localizations.maybeLocaleOf(context)?.languageCode == 'en';
    return isEnglish ? labelEn : label;
  }

  IconData get icon {
    switch (this) {
      case RecordCategory.website:
        return Icons.public_rounded;
      case RecordCategory.email:
        return Icons.alternate_email_rounded;
      case RecordCategory.socialMedia:
        return Icons.groups_rounded;
      case RecordCategory.bank:
        return Icons.account_balance_rounded;
      case RecordCategory.cardInfo:
        return Icons.credit_card_rounded;
      case RecordCategory.app:
        return Icons.apps_rounded;
      case RecordCategory.licenseKey:
        return Icons.vpn_key_rounded;
      case RecordCategory.gaming:
        return Icons.sports_esports_rounded;
      case RecordCategory.wifi:
        return Icons.wifi_rounded;
      case RecordCategory.secureNote:
        return Icons.note_alt_rounded;
      case RecordCategory.other:
        return Icons.category_rounded;
    }
  }

  String get storageKey => name;
}

RecordCategory recordCategoryFromStorage(String raw) {
  return switch (raw) {
    'website' => RecordCategory.website,
    'email' => RecordCategory.email,
    'socialMedia' => RecordCategory.socialMedia,
    'bank' => RecordCategory.bank,
    'cardInfo' => RecordCategory.cardInfo,
    'app' => RecordCategory.app,
    'licenseKey' => RecordCategory.licenseKey,
    'gaming' => RecordCategory.gaming,
    'wifi' => RecordCategory.wifi,
    'secureNote' => RecordCategory.secureNote,
    'other' => RecordCategory.other,
    'bankAccount' => RecordCategory.bank,
    'shopping' => RecordCategory.website,
    'business' => RecordCategory.secureNote,
    'education' => RecordCategory.secureNote,
    'digitalWallet' => RecordCategory.cardInfo,
    'apps' => RecordCategory.app,
    'wifiNetwork' => RecordCategory.wifi,
    'identityInfo' => RecordCategory.secureNote,
    'wallet' => RecordCategory.cardInfo,
    'identity' => RecordCategory.secureNote,
    'mail' => RecordCategory.email,
    'emailAccount' => RecordCategory.email,
    'license' => RecordCategory.licenseKey,
    'productKey' => RecordCategory.licenseKey,
    _ => RecordCategory.other,
  };
}

class VaultRecord {
  const VaultRecord({
    required this.id,
    required this.title,
    required this.category,
    required this.platform,
    required this.accountName,
    required this.password,
    required this.note,
    required this.websiteOrDescription,
    required this.isFavorite,
    required this.securityNote,
    required this.securityTag,
    this.tags = const <String>[],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final RecordCategory category;
  final String platform;
  final String accountName;
  final String password;
  final String note;
  final String websiteOrDescription;
  final bool isFavorite;
  final String securityNote;
  final String securityTag;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get subtitle {
    if (platform.trim().isNotEmpty) {
      return platform.trim();
    }
    if (websiteOrDescription.trim().isNotEmpty) {
      return websiteOrDescription.trim();
    }
    return category.label;
  }

  VaultRecord copyWith({
    String? title,
    RecordCategory? category,
    String? platform,
    String? accountName,
    String? password,
    String? note,
    String? websiteOrDescription,
    bool? isFavorite,
    String? securityNote,
    String? securityTag,
    List<String>? tags,
    DateTime? updatedAt,
  }) {
    return VaultRecord(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      platform: platform ?? this.platform,
      accountName: accountName ?? this.accountName,
      password: password ?? this.password,
      note: note ?? this.note,
      websiteOrDescription: websiteOrDescription ?? this.websiteOrDescription,
      isFavorite: isFavorite ?? this.isFavorite,
      securityNote: securityNote ?? this.securityNote,
      securityTag: securityTag ?? this.securityTag,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'category': category.storageKey,
      'platform': platform,
      'accountName': accountName,
      'password': password,
      'note': note,
      'websiteOrDescription': websiteOrDescription,
      'isFavorite': isFavorite,
      'securityNote': securityNote,
      'securityTag': securityTag,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory VaultRecord.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final rawTags = json['tags'];
    final parsedTags = rawTags is List
        ? rawTags
              .whereType<String>()
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toList()
        : <String>[];
    final legacySecurityTag = (json['securityTag'] as String? ?? '').trim();
    final securityNote = (json['securityNote'] as String? ?? '').trim();
    final resolvedSecurityTag = legacySecurityTag.isNotEmpty
        ? legacySecurityTag
        : (parsedTags.isNotEmpty ? parsedTags.first : securityNote);

    final websiteOrDescription = (json['websiteOrDescription'] as String? ?? '')
        .trim();
    final platform = (json['platform'] as String? ?? '').trim();
    final resolvedPlatform = platform.isNotEmpty
        ? platform
        : websiteOrDescription;

    return VaultRecord(
      id: (json['id'] as String? ?? now.microsecondsSinceEpoch.toString()),
      title: (json['title'] as String? ?? '').trim(),
      category: recordCategoryFromStorage(
        (json['category'] as String? ?? 'other').trim(),
      ),
      platform: resolvedPlatform,
      accountName: (json['accountName'] as String? ?? '').trim(),
      password: (json['password'] as String? ?? '').trim(),
      note: (json['note'] as String? ?? '').trim(),
      websiteOrDescription: websiteOrDescription,
      isFavorite: json['isFavorite'] == true,
      securityNote: securityNote,
      securityTag: resolvedSecurityTag,
      tags: parsedTags.isNotEmpty
          ? parsedTags
          : (resolvedSecurityTag.isEmpty
                ? const <String>[]
                : <String>[resolvedSecurityTag]),
      createdAt: _parseDateTime(json['createdAt'], now),
      updatedAt: _parseDateTime(json['updatedAt'], now),
    );
  }
}

DateTime _parseDateTime(dynamic value, DateTime fallback) {
  if (value is String) {
    return DateTime.tryParse(value) ?? fallback;
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return fallback;
}
