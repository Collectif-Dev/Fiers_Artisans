import 'phone_number.dart';

class Validators {
  Validators._();

  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'Ce champ'} est requis';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Numéro de téléphone requis';
    }
    if (!isLocalPhoneNumber(value)) {
      return 'Numéro à 10 chiffres attendu';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mot de passe requis';
    }
    if (value.length < 6) {
      return 'Minimum 6 caractères';
    }
    return null;
  }

  static String? confirmPassword(String? value, String? password) {
    if (value != password) {
      return 'Les mots de passe ne correspondent pas';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.isEmpty) return null; // Optional
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Email invalide';
    }
    return null;
  }

  static String? otp(String? value) {
    if (value == null || value.isEmpty) {
      return 'Code requis';
    }
    if (value.length != 6 || !RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'Code à 6 chiffres attendu';
    }
    return null;
  }

  static String? minLength(String? value, int min, {String? fieldName}) {
    if (value != null && value.length < min) {
      return '${fieldName ?? 'Ce champ'} doit contenir au moins $min caractères';
    }
    return null;
  }
}
