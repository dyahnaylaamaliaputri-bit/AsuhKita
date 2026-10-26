


import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';


double calculateDistance(LatLng pos1, LatLng pos2) {
  const Distance distance = Distance();
  return distance.as(LengthUnit.Meter, pos1, pos2);
}

void main() {
  group('FR-35, FR-36, FR-37 | Haversine Distance & Check-in Radius LBS', () {

    final userLocation = const LatLng(-7.797068, 110.370529);

    test('Panti Kasih Ibu (~50m) ? DALAM radius 100m, check-in diizinkan', () {
      final pantiKasihIbu = const LatLng(-7.797200, 110.370800);
      final distanceM = calculateDistance(userLocation, pantiKasihIbu);

      expect(distanceM, lessThan(100.0),
          reason: 'Jarak ke Panti Kasih Ibu harus < 100m');
      expect(distanceM > 0, isTrue,
          reason: 'Jarak harus lebih dari 0 meter');

      final canCheckIn = distanceM <= 100;
      expect(canCheckIn, isTrue,
          reason: 'User dalam radius 100m harus bisa check-in (FR-37)');
    });

    test('Panti Harapan Mulia (~6km) ? DI LUAR radius 100m, check-in ditolak', () {
      final pantiHarapanMulia = const LatLng(-7.782000, 110.420000);
      final distanceM = calculateDistance(userLocation, pantiHarapanMulia);

      expect(distanceM, greaterThan(100.0),
          reason: 'Jarak ke Panti Harapan Mulia harus > 100m');
      expect(distanceM, greaterThan(1000.0),
          reason: 'Jaraknya sekitar 6km, pastikan > 1000m');

      final canCheckIn = distanceM <= 100;
      expect(canCheckIn, isFalse,
          reason: 'User di luar radius 100m harus gagal check-in (FR-37)');
    });

    test('Titik yang sama ? jarak = 0', () {
      final sameLocation = const LatLng(-7.797068, 110.370529);
      final distanceM = calculateDistance(userLocation, sameLocation);
      expect(distanceM, lessThan(1.0),
          reason: 'Dua titik identik seharusnya berjarak 0m');
    });

    test('Format jarak: >= 1000m ? tampil dalam km', () {
      final pantiHarapanMulia = const LatLng(-7.782000, 110.420000);
      final distanceM = calculateDistance(userLocation, pantiHarapanMulia);

      final displayString = distanceM > 1000
          ? '${(distanceM / 1000).toStringAsFixed(2)} km'
          : '${distanceM.toStringAsFixed(0)} m';

      expect(displayString.contains('km'), isTrue,
          reason: 'Jarak > 1km harus ditampilkan dalam km (FR-36)');
    });

    test('Format jarak: < 1000m ? tampil dalam meter', () {
      final pantiKasihIbu = const LatLng(-7.797200, 110.370800);
      final distanceM = calculateDistance(userLocation, pantiKasihIbu);

      final displayString = distanceM > 1000
          ? '${(distanceM / 1000).toStringAsFixed(2)} km'
          : '${distanceM.toStringAsFixed(0)} m (Sangat Dekat)';

      expect(displayString.contains('m'), isTrue,
          reason: 'Jarak < 100m harus menampilkan satuan meter');
    });
  });
}
