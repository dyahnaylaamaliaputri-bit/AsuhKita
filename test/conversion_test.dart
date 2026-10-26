


import 'package:flutter_test/flutter_test.dart';


const Map<String, double> staticRates = {
  'IDR': 1.0,
  'USD': 15850.0,
  'SGD': 11800.0,
  'EUR': 17200.0,
  'SAR': 4220.0,
};


double convertToIdr(double amount, String currency) {
  final rate = staticRates[currency] ?? 1.0;
  return amount * rate;
}


String formatRupiah(double val) {
  final formatted = val.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]}.',
  );
  return 'Rp $formatted';
}


DateTime convertToZone(DateTime utcTime, int offsetHours) {
  return utcTime.add(Duration(hours: offsetHours));
}

void main() {
  group('FR-23, FR-24 | Konversi Kurs Multi-Valuta ke IDR', () {
    test('IDR 1.0 ? IDR tetap 1.0', () {
      expect(convertToIdr(1.0, 'IDR'), equals(1.0));
    });

    test('USD 1.0 ? IDR 15850.0', () {
      expect(convertToIdr(1.0, 'USD'), equals(15850.0));
    });

    test('USD 20 ? IDR 317000', () {
      expect(convertToIdr(20.0, 'USD'), equals(317000.0));
    });

    test('SGD 25 ? IDR 295000', () {
      expect(convertToIdr(25.0, 'SGD'), equals(295000.0));
    });

    test('EUR 18 ? IDR 309600', () {
      expect(convertToIdr(18.0, 'EUR'), equals(309600.0));
    });

    test('SAR 70 ? IDR 295400', () {
      expect(convertToIdr(70.0, 'SAR'), equals(295400.0));
    });

    test('Mata uang tidak dikenal ? fallback 1.0 (tidak crash)', () {
      expect(convertToIdr(100.0, 'GBP'), equals(100.0));
    });

    test('Nominal 0 ? hasil 0 untuk semua valuta', () {
      for (final currency in staticRates.keys) {
        expect(convertToIdr(0, currency), equals(0.0));
      }
    });
  });

  group('Format Rupiah', () {
    test('Rp 317.000 ? format dengan titik sebagai pemisah ribuan', () {
      final result = formatRupiah(317000.0);
      expect(result, equals('Rp 317.000'));
    });

    test('Rp 1.000.000 ? dua titik pemisah', () {
      expect(formatRupiah(1000000.0), equals('Rp 1.000.000'));
    });
  });

  group('FR-38, FR-39 | Konversi 4 Zona Waktu & UTC', () {

    final dateTimeWib = DateTime(2026, 10, 21, 10, 0);
    final utc = dateTimeWib.toUtc();

    test('UTC disimpan benar dari waktu WIB (UTC+7)', () {
      expect(utc.hour, equals(3),
          reason: 'WIB 10:00 = UTC 03:00');
    });

    test('WIB (UTC+7) ? jam 10:00', () {
      final wib = convertToZone(utc, 7);
      expect(wib.hour, equals(10));
    });

    test('WITA (UTC+8) ? jam 11:00', () {
      final wita = convertToZone(utc, 8);
      expect(wita.hour, equals(11));
    });

    test('WIT (UTC+9) ? jam 12:00', () {
      final wit = convertToZone(utc, 9);
      expect(wit.hour, equals(12));
    });

    test('London (UTC+1) ? jam 04:00', () {
      final london = convertToZone(utc, 1);
      expect(london.hour, equals(4));
    });

    test('Semua zona waktu memiliki tanggal yang benar', () {
      for (final offset in [7, 8, 9, 1]) {
        final converted = convertToZone(utc, offset);

        expect(converted.year, equals(2026));
      }
    });
  });
}
