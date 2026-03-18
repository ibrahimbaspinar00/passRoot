import 'package:flutter/widgets.dart';

extension LangX on BuildContext {
  bool get isEnglish =>
      Localizations.maybeLocaleOf(this)?.languageCode.toLowerCase() == 'en';

  String tr(String turkish, String english) => isEnglish ? english : turkish;
}
