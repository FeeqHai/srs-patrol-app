// File: lib/features/incident/services/incident_service.dart
import 'dart:io';
import 'package:geolocator/geolocator.dart';

class IncidentService {


  Future<void> submitReport({
    required String userId,
    required String title,
    required String description,
    required String category,
    required File imageFile,
    required Position location,
  }) async {
    try {

    } catch (e) {
      throw Exception('Failed to submit report: $e');
    }
  }
}