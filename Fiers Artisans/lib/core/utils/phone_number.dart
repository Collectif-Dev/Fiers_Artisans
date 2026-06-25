import 'package:flutter/services.dart';

const int localPhoneNumberLength = 10;

final RegExp _nonDigits = RegExp(r'\D');
final RegExp _localPhoneNumberRegex = RegExp(r'^\d{10}$');

String normalizeLocalPhoneNumber(String value) {
  var digits = value.replaceAll(_nonDigits, '');

  if (digits.length == 13 && digits.startsWith('225')) {
    digits = digits.substring(3);
  }

  if (digits.length > localPhoneNumberLength) {
    digits = digits.substring(0, localPhoneNumberLength);
  }

  return digits;
}

bool isLocalPhoneNumber(String value) {
  return _localPhoneNumberRegex.hasMatch(normalizeLocalPhoneNumber(value));
}

class LocalPhoneNumberInputFormatter extends TextInputFormatter {
  const LocalPhoneNumberInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = normalizeLocalPhoneNumber(newValue.text);

    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
      composing: TextRange.empty,
    );
  }
}
