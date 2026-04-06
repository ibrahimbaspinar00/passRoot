class GoogleUserProfile {
  const GoogleUserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });

  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;

  bool get hasPhoto => (photoUrl ?? '').trim().isNotEmpty;

  String get initials {
    final normalizedDisplayName = displayName.trim();
    final normalizedEmail = email.trim();

    final source = normalizedDisplayName.isNotEmpty
        ? normalizedDisplayName
        : normalizedEmail;
    if (source.isEmpty) {
      return 'G';
    }

    final parts = source
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty);
    final values = parts.toList(growable: false);
    if (values.isEmpty) {
      return source.substring(0, 1).toUpperCase();
    }

    if (values.length == 1) {
      final first = values.first;
      final head = first.length >= 2 ? first.substring(0, 2) : first;
      return head.toUpperCase();
    }

    final first = values.first.substring(0, 1).toUpperCase();
    final second = values[1].substring(0, 1).toUpperCase();
    return '$first$second';
  }
}
