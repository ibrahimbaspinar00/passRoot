class AccountProfile {
  const AccountProfile({
    required this.username,
    required this.email,
    this.photoUrl,
    required this.createdAtIso,
    required this.updatedAtIso,
    this.lastLoginAtIso,
  });

  final String username;
  final String email;
  final String? photoUrl;
  final String createdAtIso;
  final String updatedAtIso;
  final String? lastLoginAtIso;

  DateTime? get createdAt => DateTime.tryParse(createdAtIso);
  DateTime? get updatedAt => DateTime.tryParse(updatedAtIso);
  DateTime? get lastLoginAt => DateTime.tryParse(lastLoginAtIso ?? '');

  bool get hasPhoto => (photoUrl ?? '').trim().isNotEmpty;

  String get initials {
    final raw = username.trim();
    if (raw.isEmpty) return 'PR';
    final parts = raw.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final values = parts.toList(growable: false);
    if (values.isEmpty) return 'PR';
    if (values.length == 1) {
      final first = values.first;
      final fallback = first.length >= 2 ? first.substring(0, 2) : first;
      return fallback.toUpperCase();
    }
    final first = values.first.isNotEmpty ? values.first.substring(0, 1) : '';
    final second = values[1].isNotEmpty ? values[1].substring(0, 1) : '';
    final merged = '$first$second'.trim();
    return merged.isEmpty ? 'PR' : merged.toUpperCase();
  }

  AccountProfile copyWith({
    String? username,
    String? email,
    Object? photoUrl = _unset,
    String? createdAtIso,
    String? updatedAtIso,
    Object? lastLoginAtIso = _unset,
  }) {
    return AccountProfile(
      username: username ?? this.username,
      email: email ?? this.email,
      photoUrl: identical(photoUrl, _unset) ? this.photoUrl : photoUrl as String?,
      createdAtIso: createdAtIso ?? this.createdAtIso,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
      lastLoginAtIso: identical(lastLoginAtIso, _unset)
          ? this.lastLoginAtIso
          : lastLoginAtIso as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'username': username,
      'email': email,
      'photoUrl': photoUrl,
      'createdAtIso': createdAtIso,
      'updatedAtIso': updatedAtIso,
      'lastLoginAtIso': lastLoginAtIso,
    };
  }

  factory AccountProfile.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toIso8601String();
    final username = (json['username'] as String? ?? '').trim();
    final email = (json['email'] as String? ?? '').trim().toLowerCase();
    return AccountProfile(
      username: username.isEmpty ? 'PassRoot User' : username,
      email: email,
      photoUrl: (json['photoUrl'] as String?)?.trim(),
      createdAtIso: (json['createdAtIso'] as String?)?.trim().isNotEmpty == true
          ? (json['createdAtIso'] as String).trim()
          : now,
      updatedAtIso: (json['updatedAtIso'] as String?)?.trim().isNotEmpty == true
          ? (json['updatedAtIso'] as String).trim()
          : now,
      lastLoginAtIso: (json['lastLoginAtIso'] as String?)?.trim(),
    );
  }
}

const Object _unset = Object();
