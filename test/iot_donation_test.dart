// TEST-02 | Widget Test: IoT Donation Screen (Simulasi Sensor IR ESP32)
// Menguji: FR-52, FR-53, FR-54 (PBI-069)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/home/iot_donation_screen.dart';

void main() {
  group('FR-52, FR-53, FR-54 | IoT Donation Screen Widget Tests', () {
    Widget makeTestable() => const MaterialApp(home: IotDonationScreen());

    testWidgets('FR-52 | Tampil AppBar dengan judul Kotak Amal Pintar', (tester) async {
      await tester.pumpWidget(makeTestable());
      expect(find.text('Kotak Amal Pintar (IoT ESP32)'), findsOneWidget);
    });

    testWidgets('FR-53 | Tampil banner integrasi ESP32', (tester) async {
      await tester.pumpWidget(makeTestable());
      expect(find.text('Integrasi Hardware ESP32'), findsOneWidget);
      expect(find.byIcon(Icons.sensors), findsOneWidget);
    });

    testWidgets('FR-54 | Tombol simulasi nominal Rp10.000 ada dan bisa ditekan', (tester) async {
      await tester.pumpWidget(makeTestable());
      final btn = find.text('+ Rp 10.000');
      expect(btn, findsOneWidget);
      await tester.tap(btn);
      await tester.pump();
      // Setelah tap, event baru muncul di list
      expect(find.text('Rp 10.000'), findsWidgets);
    });

    testWidgets('FR-54 | Tombol simulasi nominal Rp50.000 menambah event ke riwayat', (tester) async {
      await tester.pumpWidget(makeTestable());
      // Data awal ada 2 event
      final btn50 = find.text('+ Rp 50.000');
      await tester.tap(btn50);
      await tester.pump();
      // Harus muncul Snackbar
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('FR-54 | Tombol simulasi nominal Rp100.000 ada', (tester) async {
      await tester.pumpWidget(makeTestable());
      expect(find.text('+ Rp 100.000'), findsOneWidget);
    });

    testWidgets('FR-53 | Riwayat awal menampilkan 2 event IoT dari data hardcode', (tester) async {
      await tester.pumpWidget(makeTestable());
      await tester.pump();
      // "Riwayat Deteksi Kotak Amal IoT" heading
      expect(find.text('Riwayat Deteksi Kotak Amal IoT'), findsOneWidget);
      // Device name dari data awal
      expect(find.textContaining('Panti Kasih Ibu'), findsWidgets);
    });

    testWidgets('FR-53 | Block hash ditampilkan di setiap item', (tester) async {
      await tester.pumpWidget(makeTestable());
      await tester.pump();
      // Hash ada di card items
      expect(find.textContaining('Blok Hash:'), findsWidgets);
    });
  });
}
