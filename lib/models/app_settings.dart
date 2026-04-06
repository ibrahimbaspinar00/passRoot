import 'package:flutter/material.dart';

enum AppLanguage { turkish, english }

extension AppLanguageX on AppLanguage {
  String get label => switch (this) {
    AppLanguage.turkish => 'Türkçe',
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
      AppThemeAccent.emerald => 'Zümrüt',
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
    this.appLockEnabled = true,
    this.lockOnAppLaunch = true,
    this.lockOnAppResume = false,
    this.pinEnabled = false,
    this.pinCode,
    this.biometricUnlockEnabled = false,
    this.autoLockOption = AutoLockOption.minute1,
    this.language = AppLanguage.turkish,
    this.passwordGenerator = const PasswordGeneratorSettings(),
    this.notifications = const SecurityNotificationSettings(),
    this.lastBackupIso,
  });

  final bool darkMode;
  final AppThemeAccent themeAccent;
  final RecordCardStyle cardStyle;
  final bool appLockEnabled;
  final bool lockOnAppLaunch;
  final bool lockOnAppResume;
  final bool pinEnabled;
  // Legacy value kept only for migration from plaintext PIN storage.
  final String? pinCode;
  final bool biometricUnlockEnabled;
  final AutoLockOption autoLockOption;
  final AppLanguage language;
  final PasswordGeneratorSettings passwordGenerator;
  final SecurityNotificationSettings notifications;
  final String? lastBackupIso;

  bool get hasPinCode => pinEnabled || (pinCode ?? '').trim().isNotEmpty;

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
    bool? lockOnAppLaunch,
    bool? lockOnAppResume,
    bool? pinEnabled,
    Object? pinCode = _unset,
    bool? biometricUnlockEnabled,
    AutoLockOption? autoLockOption,
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
      lockOnAppLaunch: lockOnAppLaunch ?? this.lockOnAppLaunch,
      lockOnAppResume: lockOnAppResume ?? this.lockOnAppResume,
      pinEnabled: pinEnabled ?? this.pinEnabled,
      pinCode: identical(pinCode, _unset) ? this.pinCode : pinCode as String?,
      biometricUnlockEnabled:
          biometricUnlockEnabled ?? this.biometricUnlockEnabled,
      autoLockOption: autoLockOption ?? this.autoLockOption,
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
      'lockOnAppLaunch': lockOnAppLaunch,
      'lockOnAppResume': lockOnAppResume,
      'pinEnabled': pinEnabled,
      'pinCode': pinCode,
      'biometricUnlockEnabled': biometricUnlockEnabled,
      'autoLockOption': autoLockOption.name,
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
      appLockEnabled: json.containsKey('appLockEnabled')
          ? json['appLockEnabled'] == true
          : true,
      lockOnAppLaunch: json['lockOnAppLaunch'] != false,
      lockOnAppResume: json['lockOnAppResume'] == true,
      pinEnabled:
          json['pinEnabled'] == true ||
          ((json['pinCode'] as String?)?.trim().isNotEmpty ?? false),
      pinCode: (json['pinCode'] as String?)?.trim(),
      biometricUnlockEnabled: json['biometricUnlockEnabled'] == true,
      autoLockOption: _autoLockFromName(
        (json['autoLockOption'] as String?) ?? '',
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
