import 'dart:math';

import '../models/app_settings.dart';

const String _upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const String _lower = 'abcdefghijkmnopqrstuvwxyz';
const String _numbers = '23456789';
const String _symbols = '!@#\$%^&*()_+-={}[]:;,.?';

String generatePassword(PasswordGeneratorSettings settings) {
  final random = Random.secure();
  final pools = <String>[];
  if (settings.includeUppercase) pools.add(_upper);
  if (settings.includeLowercase) pools.add(_lower);
  if (settings.includeNumbers) pools.add(_numbers);
  if (settings.includeSymbols) pools.add(_symbols);
  if (pools.isEmpty) pools.add(_lower);

  final allChars = pools.join();
  final chars = <String>[];

  for (final pool in pools) {
    chars.add(pool[random.nextInt(pool.length)]);
  }

  while (chars.length < settings.length) {
    chars.add(allChars[random.nextInt(allChars.length)]);
  }

  chars.shuffle(random);
  return chars.join();
}
