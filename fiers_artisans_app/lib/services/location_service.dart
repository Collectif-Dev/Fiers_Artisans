import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';

enum LocationIssueType {
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
  positionReadFailed,
  reverseGeocodingFailed,
  unknown,
}

class LocationResult {
  final LocationSnapshot? snapshot;
  final LocationIssueType? issueType;
  final String? message;

  const LocationResult({this.snapshot, this.issueType, this.message});

  bool get isSuccess => snapshot != null;
}

class LocationSnapshot {
  final double latitude;
  final double longitude;
  final String? city;
  final String? commune;
  final String? address;

  const LocationSnapshot({
    required this.latitude,
    required this.longitude,
    this.city,
    this.commune,
    this.address,
  });
}

class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() => _instance;

  LocationService._internal();

  final ApiClient _api = ApiClient();

  static const double fallbackLatitude = 5.3600;
  static const double fallbackLongitude = -4.0083;

  static const String _servicesDisabledMessage =
      'La geolocalisation est desactivee. Activez le GPS puis reessayez.';
  static const String _permissionDeniedMessage =
      'La permission de localisation est requise pour utiliser cette fonctionnalite.';
  static const String _permissionDeniedForeverMessage =
      'La permission de localisation est refusee de facon permanente. Activez-la dans les reglages de l\'application.';
  static const String _positionReadFailedMessage =
      'Impossible de recuperer votre position actuelle. Verifiez votre GPS puis reessayez.';
  static const String _reverseGeocodingFailedMessage =
      'Position recuperee, mais impossible de determiner la ville/commune automatiquement.';

  LocationResult _fallbackAbidjanResult() {
    return const LocationResult(
      snapshot: LocationSnapshot(
        latitude: fallbackLatitude,
        longitude: fallbackLongitude,
        city: 'Abidjan',
      ),
    );
  }

  Future<LocationResult> getCurrentLocationResult({
    bool reverseGeocode = false,
    bool fallbackToAbidjan = false,
    bool requestPermission = true,
    LocationAccuracy accuracy = LocationAccuracy.medium,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        if (fallbackToAbidjan) {
          return _fallbackAbidjanResult();
        }
        return const LocationResult(
          issueType: LocationIssueType.servicesDisabled,
          message: _servicesDisabledMessage,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (fallbackToAbidjan) {
          return _fallbackAbidjanResult();
        }
        return const LocationResult(
          issueType: LocationIssueType.permissionDeniedForever,
          message: _permissionDeniedForeverMessage,
        );
      }

      if (permission == LocationPermission.denied) {
        if (fallbackToAbidjan) {
          return _fallbackAbidjanResult();
        }
        return const LocationResult(
          issueType: LocationIssueType.permissionDenied,
          message: _permissionDeniedMessage,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeout,
        ),
      );

      String? city;
      String? commune;
      String? address;
      LocationIssueType? issueType;
      String? message;

      if (reverseGeocode) {
        try {
          final marks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (marks.isNotEmpty) {
            final mark = marks.first;
            city = _firstNonEmpty([mark.locality, mark.administrativeArea]);
            commune = _firstNonEmpty([
              mark.subAdministrativeArea,
              mark.subLocality,
              mark.locality,
            ]);
            address = _firstNonEmpty([
              mark.street,
              mark.name,
              mark.thoroughfare,
            ]);
          } else {
            issueType = LocationIssueType.reverseGeocodingFailed;
            message = _reverseGeocodingFailedMessage;
          }
        } catch (_) {
          issueType = LocationIssueType.reverseGeocodingFailed;
          message = _reverseGeocodingFailedMessage;
        }
      }

      return LocationResult(
        snapshot: LocationSnapshot(
          latitude: position.latitude,
          longitude: position.longitude,
          city: city,
          commune: commune,
          address: address,
        ),
        issueType: issueType,
        message: message,
      );
    } catch (_) {
      if (fallbackToAbidjan) {
        return _fallbackAbidjanResult();
      }
      return const LocationResult(
        issueType: LocationIssueType.positionReadFailed,
        message: _positionReadFailedMessage,
      );
    }
  }

  Future<LocationSnapshot?> getCurrentLocation({
    bool reverseGeocode = false,
    bool fallbackToAbidjan = false,
    LocationAccuracy accuracy = LocationAccuracy.medium,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final result = await getCurrentLocationResult(
      reverseGeocode: reverseGeocode,
      fallbackToAbidjan: fallbackToAbidjan,
      requestPermission: true,
      accuracy: accuracy,
      timeout: timeout,
    );
    return result.snapshot;
  }

  Future<bool> syncUserLocation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _api.put(
        ApiEndpoints.updateUserLocation,
        data: {'lat': latitude, 'lng': longitude},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<LocationSnapshot?> captureAndSyncForAuthenticatedUser({
    bool reverseGeocode = false,
    bool fallbackToAbidjan = false,
  }) async {
    final snapshot = await getCurrentLocation(
      reverseGeocode: reverseGeocode,
      fallbackToAbidjan: fallbackToAbidjan,
    );

    if (snapshot == null) {
      return null;
    }

    await syncUserLocation(
      latitude: snapshot.latitude,
      longitude: snapshot.longitude,
    );
    return snapshot;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }
}
