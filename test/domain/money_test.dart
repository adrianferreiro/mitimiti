import 'package:flutter_test/flutter_test.dart';
import 'package:mitimiti/domain/money.dart';

void main() {
  group('formatCents', () {
    test('sin centavos no muestra decimales', () {
      expect(formatCents(0), r'$0');
      expect(formatCents(100), r'$1');
      expect(formatCents(1250000), r'$12.500');
      expect(formatCents(123456700), r'$1.234.567');
    });

    test('con centavos usa coma y dos dígitos', () {
      expect(formatCents(1250050), r'$12.500,50');
      expect(formatCents(105), r'$1,05');
      expect(formatCents(5), r'$0,05');
    });

    test('negativos llevan el signo adelante', () {
      expect(formatCents(-100000), r'-$1.000');
    });
  });

  group('parseCents', () {
    test('enteros', () {
      expect(parseCents('12500'), 1250000);
      expect(parseCents(' 0 '), 0);
      expect(parseCents(r'$ 350'), 35000);
    });

    test('coma decimal y puntos de miles', () {
      expect(parseCents('12.500,50'), 1250050);
      expect(parseCents('12500,5'), 1250050);
      expect(parseCents(',5'), 50);
      expect(parseCents('1.234.567,89'), 123456789);
    });

    test('sin coma: punto con 3 dígitos es miles, con 1-2 es decimal', () {
      expect(parseCents('12.500'), 1250000);
      expect(parseCents('1.234.567'), 123456700);
      expect(parseCents('12.5'), 1250);
      expect(parseCents('12.50'), 1250);
    });

    test('inválidos devuelven null', () {
      for (final s in [
        '',
        'abc',
        '12,345',
        '1,2,3',
        '12.34.5',
        '1.5000',
        '-5',
      ]) {
        expect(parseCents(s), isNull, reason: s);
      }
    });

    test('ida y vuelta con formatCents', () {
      for (final c in [0, 5, 100, 1250050, 123456789]) {
        expect(parseCents(formatCents(c)), c);
      }
    });
  });
}
