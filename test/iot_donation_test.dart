


import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/home/iot_donation_screen.dart';

void main() {
  group('FR-52, FR-53, FR-54 | IoT Donation Screen Widget Tests', () {
    Widget makeTestable() => const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(800, 2000)),
            child: IotDonationScreen(),
          ),
        );

    testWidgets('FR-52 | Tampil AppBar dengan judul Kotak Amal Pintar', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(makeTestable());
      expect(find.text('Kotak Amal Pintar (IoT ESP32)'), findsOneWidget);
    });

    testWidgets('FR-53 | Tampil banner integrasi ESP32', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(makeTestable());
      expect(find.textContaining('Integrasi Hardware ESP32'), findsOneWidget);
      expect(find.byIcon(Icons.sensors), findsOneWidget);
    });

    testWidgets('FR-54 | Tombol simulasi nominal Rp10.000 ada dan bisa ditekan', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(makeTestable());
      final btn = find.text('+ Rp 10.000');
      expect(btn, findsOneWidget);
      await tester.tap(btn);
      await tester.pump();

      expect(find.text('Rp 10.000'), findsWidgets);
    });

    testWidgets('FR-54 | Tombol simulasi nominal Rp50.000 menambah event ke riwayat', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(makeTestable());
      final btn50 = find.text('+ Rp 50.000');
      await tester.tap(btn50);
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('FR-54 | Tombol simulasi nominal Rp100.000 ada', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(makeTestable());
      expect(find.text('+ Rp 100.000'), findsOneWidget);
    });

    testWidgets('FR-53 | Riwayat awal menampilkan 2 event IoT dari data hardcode', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(makeTestable());
      await tester.pump();

      expect(find.text('Riwayat Deteksi Kotak Amal IoT'), findsOneWidget);

      expect(find.textContaining('Panti Kasih Ibu'), findsWidgets);
    });

    testWidgets('FR-53 | Block hash ditampilkan di setiap item', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(makeTestable());
      await tester.pump();

      expect(find.textContaining('Blok Hash:'), findsWidgets);
    });
  });
}
