import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Restores and persists the user's interface language preference.
class LocaleController extends ChangeNotifier {
  static const _key = 'pawmate.locale';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  Future<void> restore() async {
    final value = await _storage.read(key: _key);
    if (value == 'en' || value == 'zh') {
      _locale = Locale(value!);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode != 'en' && locale.languageCode != 'zh') return;
    _locale = Locale(locale.languageCode);
    notifyListeners();
    await _storage.write(key: _key, value: _locale.languageCode);
  }
}

/// Makes the app-wide locale controller available to onboarding screens.
class LocaleControllerScope extends InheritedNotifier<LocaleController> {
  const LocaleControllerScope({
    required super.notifier,
    required super.child,
    super.key,
  });

  static LocaleController of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<LocaleControllerScope>()!
      .notifier!;
}
