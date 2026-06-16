import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/tracking_service.dart';

class TrackingProvider with ChangeNotifier {
  final TrackingService _service = TrackingService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<bool> triggerSos(String userId) async {
    _setLoading(true);

    try {
      // 1. Check Permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _errorMessage = 'Sila aktifkan perkhidmatan lokasi (GPS).';
        _setLoading(false);
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _errorMessage = 'Kebenaran lokasi ditolak.';
          _setLoading(false);
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _errorMessage = 'Kebenaran lokasi ditolak secara kekal.';
        _setLoading(false);
        return false;
      }

      // 2. Get Location
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 3. Send SOS
      final error = await _service.sendSosAlert(
        userId: userId,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (error == null) {
        _errorMessage = null;
        _setLoading(false);
        return true;
      } else {
        _errorMessage = error;
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'Gagal mendapatkan kordinat: $e';
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
