/// Formato y parseo de montos en pesos argentinos (centavos como `int`).
///
/// Convención local: punto para miles y coma para decimales ("$12.500,50").
library;

/// "$12.500" si no hay centavos, "$12.500,50" si los hay. Negativos con
/// signo adelante: "-$1.000".
String formatCents(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  final pesos = _groupThousands((abs ~/ 100).toString());
  final rest = abs % 100;
  final decimals = rest == 0 ? '' : ',${rest.toString().padLeft(2, '0')}';
  return '$sign\$$pesos$decimals';
}

String _groupThousands(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// Convierte lo que escribe el usuario a centavos. Devuelve `null` si no es
/// un monto válido (vacío, letras, más de 2 decimales, etc.).
///
/// - Si hay coma, la coma es el separador decimal y los puntos son miles:
///   "12.500,5" → 1250050.
/// - Si no hay coma, un punto seguido de 3 dígitos se toma como miles
///   ("12.500" → 1250000) y seguido de 1 o 2 como decimal ("12.5" → 1250).
int? parseCents(String input) {
  final s = input.trim().replaceAll(r'$', '').replaceAll(' ', '');
  if (s.isEmpty) return null;

  String intPart;
  var decPart = '';
  if (s.contains(',')) {
    final parts = s.split(',');
    if (parts.length != 2) return null;
    intPart = parts[0].replaceAll('.', '');
    decPart = parts[1];
  } else {
    final parts = s.split('.');
    final last = parts.last;
    final decimalDot = parts.length > 1 && last.length <= 2;
    final thousands = decimalDot ? parts.sublist(0, parts.length - 1) : parts;
    if (thousands.skip(1).any((p) => p.length != 3)) return null;
    intPart = thousands.join();
    if (decimalDot) decPart = last;
  }

  if (intPart.isEmpty) intPart = '0';
  if (!RegExp(r'^\d+$').hasMatch(intPart)) return null;
  if (decPart.length > 2 || !RegExp(r'^\d*$').hasMatch(decPart)) return null;

  return int.parse(intPart) * 100 + int.parse(decPart.padRight(2, '0'));
}
