import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_map/consts.dart';
import 'package:google_map/services/location_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../model/LocationPrediction.dart';

class GoogleMapScreen extends StatefulWidget {
  const GoogleMapScreen({super.key});

  @override
  State<GoogleMapScreen> createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  final LocationService _locationService = LocationService();
  final Set<Marker> _markers = {};
  final Set<Polygon> _polygons = {};
  final Map<PolylineId, Polyline> _polylines = {};
  late GoogleMapController _mapController;
  final TextEditingController _searchController = TextEditingController();
  LatLng _currentLocation = const LatLng(22.3248384, 91.7897216);
  LatLng ?_sourceLocation ;
  bool _isLoading = true;
  bool _isLocationUpdateActive = false;
  double _distance = 0.0;
  List<LocationPrediction> _predictions = [];

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      setState(() => _isLoading = true);

      await _locationService.checkPermission();
      await _updateCurrentLocation();
      _setupLocationListener();
      await _updateMapMarkers();
      await _updatePolyline();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      showError(context, 'Failed to initialize map: $e');
    }
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() => _predictions = []);
      return;
    }

    try {
      final predictions = await _locationService.searchPlace(query);
      setState(() => _predictions = predictions);
    } catch (e) {
      showError(context, 'Search failed: $e');
    }
  }

  Future<void> _handlePredictionTap(LocationPrediction prediction) async {
    try {
      final place = await _locationService.getPlaceDetails(prediction.placeId);

      setState(() {
        _sourceLocation = LatLng(place.lat, place.lng);
        _predictions = [];
        _searchController.text = prediction.description;

        _markers.add(
          Marker(
            markerId: const MarkerId('sourceLocation'),
            position: _sourceLocation!,
            infoWindow: const InfoWindow(
              title: 'Source Location',
              snippet: 'You are here',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
          ),
        );
      });

      await _updateMapMarkers();
      await _updatePolyline();
    } catch (e) {
      showError(context, 'Failed to get place details: $e');
    }
  }

  Future<void> _updateCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      _updateCamera();
    } catch (e) {
      showError(context, 'Failed to get current location: $e');
    }
  }

  void _setupLocationListener() {
    if (_isLocationUpdateActive) return;

    _isLocationUpdateActive = true;
    _locationService.locationStream.listen(
      (position) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _updateMapMarkers();
          _updateCamera();
        });
      },
      onError: (error) {
        _isLocationUpdateActive = false;
        showError(context, 'Location update error: $error');
      },
      cancelOnError: false,
    );
  }

  Future<void> _updateMapMarkers() async {
    setState(() {
      //  _markers.clear();
      _markers.addAll({
        Marker(
          markerId: const MarkerId('currentLocation'),
          position: _currentLocation,
          infoWindow: const InfoWindow(
            title: 'Current Location',
            snippet: 'You are here',
          ),
        ),
      });
    });
  }

  Future<void> _updatePolyline() async {
    try {
      final coordinates = await _getPolylineCoordinates();

      final distance = Geolocator.distanceBetween(
        _currentLocation.latitude,
        _currentLocation.longitude,
        _sourceLocation!.latitude,
        _sourceLocation!.longitude,
      );

      setState(() {
        _polylines.clear();
        const id = PolylineId('route');
        final polyline = Polyline(
          polylineId: id,
          color: polylineColor,
          points: coordinates,
          width: polylineWidth.toInt(),
        );
        _polylines[id] = polyline;
        _distance = distance;
      });
    } catch (e) {
      showError(context, 'Failed to update route: $e');
    }
  }

  Future<List<LatLng>> _getPolylineCoordinates() async {
    final polylinePoints = PolylinePoints();
    final result = await polylinePoints.getRouteBetweenCoordinates(googleApiKey: googleAPiKeys, request: PolylineRequest(origin: PointLatLng(_currentLocation.latitude, _currentLocation.longitude), destination: PointLatLng(_sourceLocation!.latitude, _sourceLocation!.longitude), mode: TravelMode.driving));

    if (result.points.isEmpty) {
      throw Exception('No route found');
    }

    return result.points.map((point) => LatLng(point.latitude, point.longitude)).toList();
  }

  void _updateCamera() {
    if (!mounted) return;

    _mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentLocation,
          zoom: initialZoom,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
                _updateCamera();
              },
              initialCameraPosition: CameraPosition(
                target: _currentLocation,
                zoom: initialZoom,
              ),
              markers: _markers,
              polygons: _polygons,
              polylines: Set<Polyline>.of(_polylines.values),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              mapToolbarEnabled: false,
              compassEnabled: true,
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    child: TextFormField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        prefix: Icon(Icons.search),
                        hintText: 'Search location',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(defaultHight)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (value) => _onSearchChanged(value),
                    ),
                  ),
                   InkWell(
                    onTap: () async{
                      _searchController.clear();
                    //await  _updateCurrentLocation();
                    },
                    child: const Icon(
                      Icons.search,
                      color: Colors.white,
                    ),
                  ),
                  if (_predictions.isNotEmpty)
                    Container(
                      color: Colors.white,
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.3,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _predictions.length,
                        itemBuilder: (context, index) {
                          final prediction = _predictions[index];
                          return ListTile(
                            title: Text(prediction.description),
                            onTap: () => _handlePredictionTap(prediction),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            if (_isLoading)
              const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(defaultHight),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
              
            Positioned(
              top: defaultHight * 8,
              left: MediaQuery.of(context).size.width / 2 - defaultHight * 5,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(defaultHight),
                child: Text('Distance: ${(_distance / 1000).toStringAsFixed(2)} km'),
              ),
            ),
            Positioned(
              bottom: defaultHight,
              right: defaultHight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    backgroundColor: Colors.white,
                    heroTag: 'refresh_location',
                    onPressed: _isLoading ? null : _updateCurrentLocation,
                    child: const Icon(Icons.my_location),
                  ),
                  const SizedBox(height: defaultHight / 2),
                  FloatingActionButton(
                    backgroundColor: Colors.white,
                    heroTag: 'refresh_route',
                    onPressed: _isLoading ? null : _updatePolyline,
                    child: const Icon(Icons.route),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
