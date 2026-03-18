enum PasswordStrength { weak, medium, strong }

final RegExp _upperCasePattern = RegExp(r'[A-Z]');
final RegExp _lowerCasePattern = RegExp(r'[a-z]');
final RegExp _numberPattern = RegExp(r'[0-9]');
final RegExp _symbolPattern = RegExp(r'[^A-Za-z0-9]');
final RegExp _tripleRepeatPattern = RegExp(r'(.)\1\1');
final RegExp _commonPasswordPattern = RegExp(
  r'^(1234|12345|123456|12345678|password|qwerty|111111)$',
  caseSensitive: false,
);

class PasswordAnalysis {
  const PasswordAnalysis({
    required this.strength,
    required this.score,
    required this.weakReasons,
  });

  final PasswordStrength strength;
  final int score;
  final List<String> weakReasons;
}

PasswordAnalysis analyzePassword(String value) {
  final password = value.trim();
  var score = 0;
  final reasons = <String>[];

  final hasUpper = _upperCasePattern.hasMatch(password);
  final hasLower = _lowerCasePattern.hasMatch(password);
  final hasNumber = _numberPattern.hasMatch(password);
  final hasSymbol = _symbolPattern.hasMatch(password);

  if (password.length >= 12) {
    score += 2;
  } else if (password.length >= 8) {
    score += 1;
  } else {
    reasons.add('Sifre cok kisa');
  }

  if (hasUpper) score += 1;
  if (hasLower) score += 1;
  if (hasNumber) score += 1;
  if (hasSymbol) score += 1;

  if (!hasUpper && !hasLower && hasNumber) {
    reasons.add('Sadece sayi iceriyor');
  }

  if (_tripleRepeatPattern.hasMatch(password)) {
    reasons.add('Tekrar eden karakter dizisi var');
  }

  if (_commonPasswordPattern.hasMatch(password)) {
    reasons.add('Cok kolay tahmin edilebilir');
  }

  final lowered = password.toLowerCase();
  if (lowered.contains('1234') ||
      lowered.contains('password') ||
      lowered.contains('qwerty')) {
    reasons.add('Basit kaliplar iceriyor');
  }

  final strength = switch (score) {
    >= 5 => PasswordStrength.strong,
    >= 3 => PasswordStrength.medium,
    _ => PasswordStrength.weak,
  };

  return PasswordAnalysis(
    strength: strength,
    score: score,
    weakReasons: reasons.toSet().toList(),
  );
}

String strengthLabel(PasswordStrength strength) {
  return switch (strength) {
    PasswordStrength.strong => 'Guclu',
    PasswordStrength.medium => 'Orta',
    PasswordStrength.weak => 'Zayif',
  };
}
