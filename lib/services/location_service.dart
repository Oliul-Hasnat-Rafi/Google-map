import 'dart:async';
import 'package:flutter_google_maps_webservices/places.dart' as places;
import 'package:geolocator/geolocator.dart';
import 'package:google_map/consts.dart';

import '../model/LocationPrediction.dart';
import '../model/PlaceLocation.dart';

class LocationService {
  final _locationController = StreamController<Position>.broadcast();
  Stream<Position> get locationStream => _locationController.stream;
  final _places = places.GoogleMapsPlaces(apiKey: googleAPiKeys);

  Future<bool> checkPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationException('Location services are disabled');
      }

      final permission = await Geolocator.requestPermission();
      switch (permission) {
        case LocationPermission.denied:
          throw LocationException('Location permissions are denied');
        case LocationPermission.deniedForever:
          throw LocationException('Location permissions are permanently denied');
        default:
          return true;
      }
    } catch (e) {
      throw LocationException('Failed to check location permission: $e');
    }
  }

  void startLocationUpdates() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (position) => _locationController.add(position),
      onError: (error) => print('Location stream error: $error'),
    );
  }

  Future<List<LocationPrediction>> searchPlace(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final response = await _places.autocomplete(query);
      return response.predictions
          .map((prediction) => LocationPrediction.fromPlacesPrediction(prediction))
          .toList();
    } catch (e) {
      throw LocationException('Failed to search place: $e');
    }
  }

  Future<PlaceLocation> getPlaceDetails(String placeId) async {
    try {
      final response = await _places.getDetailsByPlaceId(placeId);
      final location = response.result.geometry?.location;
      
      if (location == null) {
        throw LocationException('Location not found');
      }
      
      return PlaceLocation(
        lat: location.lat,
        lng: location.lng,
      );
    } catch (e) {
      throw LocationException('Failed to get place details: $e');
    }
  }

  void dispose() {
    _locationController.close();
  }
}

class LocationException implements Exception {
  final String message;

  LocationException(this.message);

  @override
  String toString() => 'LocationException: $message';
}