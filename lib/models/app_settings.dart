import 'package:flutter/material.dart';

enum AppLanguage { turkish, english }

extension AppLanguageX on AppLanguage {
  String get label => switch (this) {
    AppLanguage.turkish => 'Turkce',
    AppLanguage.english => 'English',
  };

  String localizedLabel(BuildContext context) {
    final isEnglish =
        Localizations.maybeLocaleOf(context)?.languageCode.toLowerCase() ==
        'en';
    if (!isEnglish) return label;
    return switch (this) {
      AppLanguage.turkish => 'Turkish',
      AppLanguage.english => 'English',
    };
  }

  Locale get locale => switch (this) {
    AppLanguage.turkish => const Locale('tr'),
    AppLanguage.english => const Locale('en'),
  };
}

enum AutoLockOption { immediate, seconds30, minute1, minutes5 }

extension AutoLockOptionX on AutoLockOption {
  String get label => switch (this) {
    AutoLockOption.immediate => 'Hemen',
    AutoLockOption.seconds30 => '30 sn',
    AutoLockOption.minute1 => '1 dk',
    AutoLockOption.minutes5 => '5 dk',
  };

  String localizedLabel(BuildContext context) {
    final isEnglish =
        Localizations.maybeLocaleOf(context)?.languageCode.toLowerCase() ==
        'en';
    if (!isEnglish) return label;
    return switch (this) {
      AutoLockOption.immediate => 'Immediately',
      AutoLockOption.seconds30 => '30 sec',
      AutoLockOption.minute1 => '1 min',
      AutoLockOption.minutes5 => '5 min',
    };
  }

  Duration get duration => switch (this) {
    AutoLockOption.immediate => Duration.zero,
    AutoLockOption.seconds30 => const Duration(seconds: 30),
    AutoLockOption.minute1 => const Duration(minutes: 1),
    AutoLockOption.minutes5 => const Duration(minutes: 5),
  };
}

enum FirebaseSessionTimeoutOption { minutes15, hour1, hours8, day1 }

extension FirebaseSessionTimeoutOptionX on FirebaseSessionTimeoutOption {
  String get label => switch (this) {
    FirebaseSessionTimeoutOption.minutes15 => '15 dk',
    FirebaseSessionTimeoutOption.hour1 => '1 saat',
    FirebaseSessionTimeoutOption.hours8 => '8 saat',
    FirebaseSessionTimeoutOption.day1 => '24 saat',
  };

  String localizedLabel(BuildContext context) {
    final isEnglish =
        Localizations.maybeLocaleOf(context)?.languageCode.toLowerCase() ==
        'en';
    if (!isEnglish) return label;
    return switch (this) {
      FirebaseSessionTimeoutOption.minutes15 => '15 min',
      FirebaseSessionTimeoutOption.hour1 => '1 hour',
      FirebaseSessionTimeoutOption.hours8 => '8 hours',
      FirebaseSessionTimeoutOption.day1 => '24 hours',
    };
  }

  Duration get duration => switch (this) {
    FirebaseSessionTimeoutOption.minutes15 => const Duration(minutes: 15),
    FirebaseSessionTimeoutOption.hour1 => const Duration(hours: 1),
    FirebaseSessionTimeoutOption.hours8 => const Duration(hours: 8),
    FirebaseSessionTimeoutOption.day1 => const Duration(days: 1),
  };
}

enum AppThemeAccent { ocean, cobalt, emerald, coral }

extension AppThemeAccentX on AppThemeAccent {
  String get label => switch (this) {
    AppThemeAccent.ocean => 'Ocean',
    AppThemeAccent.cobalt => 'Cobalt',
    AppThemeAccent.emerald => 'Emerald',
    AppThemeAccent.coral => 'Coral',
  };

  String localizedLabel(BuildContext context) {
    final isEnglish =
        Localizations.maybeLocaleOf(context)?.languageCode.toLowerCase() ==
        'en';
    if (isEnglish) return label;
    return switch (this) {
      AppThemeAccent.ocean => 'Okyanus',
      AppThemeAccent.cobalt => 'Kobalt',
      AppThemeAccent.emerald => 'Zumrut',
      AppThemeAccent.coral => 'Mercan',
    };
  }

  Color get seedColor => switch (this) {
    AppThemeAccent.ocean => const Color(0xFF0C6A67),
    AppThemeAccent.cobalt => const Color(0xFF1E4ED8),
    AppThemeAccent.emerald => const Color(0xFF067647),
    AppThemeAccent.coral => const Color(0xFFE45C3A),
  };
}

enum RecordCardStyle { comfy, compact }

extension RecordCardStyleX on RecordCardStyle {
  String get label => switch (this) {
    RecordCardStyle.comfy => 'Konforlu',
    RecordCardStyle.compact => 'Kompakt',
  };

  String localizedLabel(BuildContext context) {
    final isEnglish =
        Localizations.maybeLocaleOf(context)?.languageCode.toLowerCase() ==
        'en';
    if (!isEnglish) return label;
    return switch (this) {
      RecordCardStyle.comfy => 'Comfy',
      RecordCardStyle.compact => 'Compact',
    };
  }
}

class PasswordGeneratorSettings {
  const PasswordGeneratorSettings({
    this.length = 16,
    this.includeUppercase = true,
    this.includeLowercase = true,
    this.includeNumbers = true,
    this.includeSymbols = true,
  });

  final int length;
  final bool includeUppercase;
  final bool includeLowercase;
  final bool includeNumbers;
  final bool includeSymbols;

  PasswordGeneratorSettings copyWith({
    int? length,
    bool? includeUppercase,
    bool? includeLowercase,
    bool? includeNumbers,
    bool? includeSymbols,
  }) {
    final updated = PasswordGeneratorSettings(
      length: length ?? this.length,
      includeUppercase: includeUppercase ?? this.includeUppercase,
      includeLowercase: includeLowercase ?? this.includeLowercase,
      includeNumbers: includeNumbers ?? this.includeNumbers,
      includeSymbols: includeSymbols ?? this.includeSymbols,
    );
    return updated.hasAnyEnabledGroup
        ? updated
        : updated.copyWith(includeLowercase: true);
  }

  bool get hasAnyEnabledGroup =>
      includeUppercase || includeLowercase || includeNumbers || includeSymbols;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'length': length,
      'includeUppercase': includeUppercase,
      'includeLowercase': includeLowercase,
      'includeNumbers': includeNumbers,
      'includeSymbols': includeSymbols,
    };
  }

  factory PasswordGeneratorSettings.fromJson(Map<String, dynamic> json) {
    return PasswordGeneratorSettings(
      length: (json['length'] as int? ?? 16).clamp(8, 40),
      includeUppercase: json['includeUppercase'] != false,
      includeLowercase: json['includeLowercase'] != false,
      includeNumbers: json['includeNumbers'] != false,
      includeSymbols: json['includeSymbols'] != false,
    );
  }
}

class SecurityNotificationSettings {
  const SecurityNotificationSettings({
    this.weakPasswordAlert = true,
    this.reusedPasswordAlert = true,
    this.backupReminder = true,
  });

  final bool weakPasswordAlert;
  final bool reusedPasswordAlert;
  final bool backupReminder;

  SecurityNotificationSettings copyWith({
    bool? weakPasswordAlert,
    bool? reusedPasswordAlert,
    bool? backupReminder,
  }) {
    return SecurityNotificationSettings(
      weakPasswordAlert: weakPasswordAlert ?? this.weakPasswordAlert,
      reusedPasswordAlert: reusedPasswordAlert ?? this.reusedPasswordAlert,
      backupReminder: backupReminder ?? this.backupReminder,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'weakPasswordAlert': weakPasswordAlert,
      'reusedPasswordAlert': reusedPasswordAlert,
      'backupReminder': backupReminder,
    };
  }

  factory SecurityNotificationSettings.fromJson(Map<String, dynamic> json) {
    return SecurityNotificationSettings(
      weakPasswordAlert: json['weakPasswordAlert'] != false,
      reusedPasswordAlert: json['reusedPasswordAlert'] != false,
      backupReminder: json['backupReminder'] != false,
    );
  }
}

const Object _unset = Object();

class AppSettings {
  const AppSettings({
    this.darkMode = false,
    this.themeAccent = AppThemeAccent.ocean,
    this.cardStyle = RecordCardStyle.comfy,
    this.appLockEnabled = false,
    this.pinCode,
    this.biometricEnabled = false,
    this.autoLockOption = AutoLockOption.minute1,
    this.firebaseSessionTimeoutEnabled = false,
    this.firebaseSessionTimeoutOption = FirebaseSessionTimeoutOption.hour1,
    this.language = AppLanguage.turkish,
    this.passwordGenerator = const PasswordGeneratorSettings(),
    this.notifications = const SecurityNotificationSettings(),
    this.lastBackupIso,
  });

  final bool darkMode;
  final AppThemeAccent themeAccent;
  final RecordCardStyle cardStyle;
  final bool appLockEnabled;
  final String? pinCode;
  final bool biometricEnabled;
  final AutoLockOption autoLockOption;
  final bool firebaseSessionTimeoutEnabled;
  final FirebaseSessionTimeoutOption firebaseSessionTimeoutOption;
  final AppLanguage language;
  final PasswordGeneratorSettings passwordGenerator;
  final SecurityNotificationSettings notifications;
  final String? lastBackupIso;

  bool get hasPinCode => (pinCode ?? '').trim().isNotEmpty;

  DateTime? get lastBackupAt {
    final value = lastBackupIso;
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  AppSettings copyWith({
    bool? darkMode,
    AppThemeAccent? themeAccent,
    RecordCardStyle? cardStyle,
    bool? appLockEnabled,
    Object? pinCode = _unset,
    bool? biometricEnabled,
    AutoLockOption? autoLockOption,
    bool? firebaseSessionTimeoutEnabled,
    FirebaseSessionTimeoutOption? firebaseSessionTimeoutOption,
    AppLanguage? language,
    PasswordGeneratorSettings? passwordGenerator,
    SecurityNotificationSettings? notifications,
    String? lastBackupIso,
  }) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      themeAccent: themeAccent ?? this.themeAccent,
      cardStyle: cardStyle ?? this.cardStyle,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      pinCode: identical(pinCode, _unset) ? this.pinCode : pinCode as String?,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      autoLockOption: autoLockOption ?? this.autoLockOption,
      firebaseSessionTimeoutEnabled:
          firebaseSessionTimeoutEnabled ?? this.firebaseSessionTimeoutEnabled,
      firebaseSessionTimeoutOption:
          firebaseSessionTimeoutOption ?? this.firebaseSessionTimeoutOption,
      language: language ?? this.language,
      passwordGenerator: passwordGenerator ?? this.passwordGenerator,
      notifications: notifications ?? this.notifications,
      lastBackupIso: lastBackupIso ?? this.lastBackupIso,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'darkMode': darkMode,
      'themeAccent': themeAccent.name,
      'cardStyle': cardStyle.name,
      'appLockEnabled': appLockEnabled,
      'pinCode': pinCode,
      'biometricEnabled': biometricEnabled,
      'autoLockOption': autoLockOption.name,
      'firebaseSessionTimeoutEnabled': firebaseSessionTimeoutEnabled,
      'firebaseSessionTimeoutOption': firebaseSessionTimeoutOption.name,
      'language': language.name,
      'passwordGenerator': passwordGenerator.toJson(),
      'notifications': notifications.toJson(),
      'lastBackupIso': lastBackupIso,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final passwordGeneratorMap =
        json['passwordGenerator'] is Map<String, dynamic>
        ? json['passwordGenerator'] as Map<String, dynamic>
        : <String, dynamic>{};
    final notificationMap = json['notifications'] is Map<String, dynamic>
        ? json['notifications'] as Map<String, dynamic>
        : <String, dynamic>{};

    return AppSettings(
      darkMode: json['darkMode'] == true,
      themeAccent: _themeAccentFromName((json['themeAccent'] as String?) ?? ''),
      cardStyle: _cardStyleFromName((json['cardStyle'] as String?) ?? ''),
      appLockEnabled: json['appLockEnabled'] == true,
      pinCode: (json['pinCode'] as String?)?.trim(),
      biometricEnabled: json['biometricEnabled'] == true,
      autoLockOption: _autoLockFromName(
        (json['autoLockOption'] as String?) ?? '',
      ),
      firebaseSessionTimeoutEnabled:
          json['firebaseSessionTimeoutEnabled'] == true,
      firebaseSessionTimeoutOption: _firebaseSessionTimeoutFromName(
        (json['firebaseSessionTimeoutOption'] as String?) ?? '',
      ),
      language: _languageFromName((json['language'] as String?) ?? ''),
      passwordGenerator: PasswordGeneratorSettings.fromJson(
        passwordGeneratorMap,
      ),
      notifications: SecurityNotificationSettings.fromJson(notificationMap),
      lastBackupIso: (json['lastBackupIso'] as String?)?.trim(),
    );
  }
}

AutoLockOption _autoLockFromName(String raw) {
  for (final option in AutoLockOption.values) {
    if (option.name == raw) return option;
  }
  return AutoLockOption.minute1;
}

FirebaseSessionTimeoutOption _firebaseSessionTimeoutFromName(String raw) {
  for (final option in FirebaseSessionTimeoutOption.values) {
    if (option.name == raw) return option;
  }
  return FirebaseSessionTimeoutOption.hour1;
}

AppLanguage _languageFromName(String raw) {
  for (final language in AppLanguage.values) {
    if (language.name == raw) return language;
  }
  return AppLanguage.turkish;
}

AppThemeAccent _themeAccentFromName(String raw) {
  for (final accent in AppThemeAccent.values) {
    if (accent.name == raw) return accent;
  }
  return AppThemeAccent.ocean;
}

RecordCardStyle _cardStyleFromName(String raw) {
  for (final style in RecordCardStyle.values) {
    if (style.name == raw) return style;
  }
  return RecordCardStyle.comfy;
}
