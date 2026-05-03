// File: lib/features/incident/services/incident_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';

class IncidentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// --- THE NEW FUNCTION: GET REAL-TIME FEED ---
  /// This returns a Stream that your IncidentScreen listens to.
  /// It orders them so the most recent patrol reports appear at the top.
  Stream<QuerySnapshot> getIncidentStream() {
    return _db
        .collection('incident_reports')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> submitReport({
    required String userId,
    required String title,
    required String description,
    required String category,
    required File imageFile,
    required Position location,
  }) async {
    try {
      // 1. Generate a unique filename based on the current time
      String fileName = 'incident_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 2. Upload the physical image file to Firebase Storage
      Reference storageRef = _storage.ref().child('incident_evidence/$fileName');
      // Force the app to wait until the upload is 100% complete and verified
      await storageRef.putFile(imageFile).whenComplete(() => null);
      // Now that it is guaranteed to be there, grab the URL directly from the reference
      String downloadUrl = await storageRef.getDownloadURL();

      // 3. Save the complete report payload to the Firestore Database
      await _db.collection('incident_reports').add({
        'reporterId': userId,
        'title': title,
        'description': description,
        'category': category,
        'imageUrl': downloadUrl, // The link to the photo we just uploaded
        'latitude': location.latitude,
        'longitude': location.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // KRT Admin will change this to 'resolved' later
      });

    } catch (e) {
      throw Exception('Failed to submit report: $e');
    }
  }
}