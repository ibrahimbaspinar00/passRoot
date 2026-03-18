import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../../l10n/lang_x.dart';

final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidEmail(String value) => _emailRegex.hasMatch(value.trim());

String firebaseAuthErrorText(BuildContext context, FirebaseAuthException error) {
  switch (error.code) {
    case 'invalid-email':
      return context.tr(
        'E-posta formati gecersiz.',
        'Email format is invalid.',
      );
    case 'user-not-found':
      return context.tr(
        'Bu e-posta ile hesap bulunamadi.',
        'No account found for this email.',
      );
    case 'wrong-password':
    case 'invalid-credential':
      return context.tr(
        'E-posta veya sifre hatali.',
        'Email or password is incorrect.',
      );
    case 'email-already-in-use':
      return context.tr(
        'Bu e-posta zaten kayitli.',
        'This email is already in use.',
      );
    case 'weak-password':
      return context.tr(
        'Sifre cok zayif (en az 6 karakter).',
        'Password is too weak (minimum 6 characters).',
      );
    case 'operation-not-allowed':
      return context.tr(
        'Bu giris yontemi Firebase Authentication icinde aktif degil.',
        'This sign-in method is not enabled in Firebase Authentication.',
      );
    case 'too-many-requests':
      return context.tr(
        'Cok fazla deneme yapildi, lutfen sonra tekrar deneyin.',
        'Too many attempts, please try again later.',
      );
    case 'user-disabled':
      return context.tr(
        'Bu hesap devre disi birakilmis.',
        'This account has been disabled.',
      );
    case 'network-request-failed':
      return context.tr(
        'Ag baglantisi hatasi. Internet baglantinizi kontrol edin.',
        'Network error. Check your internet connection.',
      );
    case 'account-exists-with-different-credential':
      return context.tr(
        'Bu e-posta farkli bir giris yontemiyle kayitli.',
        'This email is registered with a different sign-in method.',
      );
    case 'credential-already-in-use':
      return context.tr(
        'Bu giris bilgisi baska bir hesapta kullaniliyor.',
        'This credential is already used by another account.',
      );
    case 'provider-already-linked':
      return context.tr(
        'Bu giris yontemi zaten bu hesaba bagli.',
        'This provider is already linked to this account.',
      );
    default:
      return context.tr(
        'Islem basarisiz: ${error.message ?? error.code}',
        'Request failed: ${error.message ?? error.code}',
      );
  }
}
