// File: lib/features/attendance/services/attendance_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class AttendanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // The primary clock-in function
  Future<void> clockIn(String userId, String qrPayload) async {
    // 1. Get the user's live GPS coordinates
    Position currentPos = await _determinePosition();

    // 2. Query Firebase to see if this QR code matches an active shift tonight
    QuerySnapshot shiftQuery = await _db
        .collection('daily_shifts')
        .where('dynamicQrPayload', isEqualTo: qrPayload)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (shiftQuery.docs.isEmpty) {
      throw Exception('Invalid or expired QR Code. Please contact Admin.');
    }

    var shiftDoc = shiftQuery.docs.first;
    GeoPoint pondokLocation = shiftDoc['adminBaseLocation'];

    // 3. Anti-Cheat: Calculate the distance between the phone and the Pondok
    double distanceInMeters = Geolocator.distanceBetween(
      currentPos.latitude,
      currentPos.longitude,
      pondokLocation.latitude,
      pondokLocation.longitude,
    );

    // If they are more than 50 meters away, reject the scan
    if (distanceInMeters > 50) {
      throw Exception('Anti-Cheat: You are ${distanceInMeters.round()}m away from the KRT Pondok. Move closer.');
    }

    // 4. Verification Passed: Write the timestamp to the database
    await _db
        .collection('daily_shifts')
        .doc(shiftDoc.id)
        .collection('attendance_logs')
        .doc(userId)
        .set({
      'clockInTime': FieldValue.serverTimestamp(),
      'clockInLocation': GeoPoint(currentPos.latitude, currentPos.longitude),
      'clockOutTime': null, // Null until they scan out at the end of the night
      'status': 'present'
    }, SetOptions(merge: true));
  }

  // Standard boilerplate to request GPS permissions from the user
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services are disabled. Please turn on GPS.');

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
    );
  }
}