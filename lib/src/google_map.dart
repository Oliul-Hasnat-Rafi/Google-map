import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_map/consts.dart';
import 'package:google_map/services/location_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui';

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
  LatLng? _sourceLocation;
  bool _isLoading = true;
  bool _isLocationUpdateActive = false;
  double _distance = 0.0;
  List<LocationPrediction> _predictions = [];

  @override
  void initState() {
    super.initState();
    _initializeMap();
   
  }

  Future<BitmapDescriptor> customIcon()  async {
  return await BitmapDescriptor.asset(
    const ImageConfiguration(size: Size(48, 48)),
    'images/car.png',
  );
}


  Future<void> _initializeMap() async {
    try {
      setState(() => _isLoading = true);

      await _locationService.checkPermission();
      await _updateCurrentLocation();
      _setupLocationListener();
      await _updateMapMarkers();
      if (_sourceLocation != null) {
        await _updatePolyline();
      }

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
              title: 'Destination',
              snippet: 'Selected location',
            ),
           
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
    // _locationService.locationStream.listen(
    //   (position) {
    //     setState(() {
    //       _currentLocation = LatLng(position.latitude, position.longitude);
    //       _updateMapMarkers();
    //       if (_sourceLocation != null) {
    //         _updatePolyline();
    //       }
    //       _updateCamera();
    //     });
    //   },
    //   onError: (error) {
    //     _isLocationUpdateActive = false;
    //     showError(context, 'Location update error: $error');
    //   },
    //   cancelOnError: false,
    // );
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (position) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _updateMapMarkers();
          if (_sourceLocation != null) {
            _updatePolyline();
          }
          _updateCamera();
        });
      },
      onError: (error) => print('Location stream error: $error'),
    );
  }

  Future<void> _updateMapMarkers() async {
    setState(() async {
      _markers.removeWhere((marker) => marker.markerId != const MarkerId('sourceLocation'));
      _markers.add(
        Marker(
          markerId: const MarkerId('currentLocation'),
          position: _currentLocation,
          infoWindow: const InfoWindow(
            title: 'Current Location',
            snippet: 'You are here',
          ),
          icon:await customIcon()
        ),
      );
    });
  }

  Future<void> _updatePolyline() async {
    if (_sourceLocation == null) {
      setState(() {
        _polylines.clear();
        _distance = 0.0;
      });
      return;
    }

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
    if (_sourceLocation == null) {
      throw Exception('Source location not set');
    }

    final polylinePoints = PolylinePoints();
    final result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: googleAPiKeys,
      request: PolylineRequest(
        origin: PointLatLng(_currentLocation.latitude, _currentLocation.longitude),
        destination: PointLatLng(_sourceLocation!.latitude, _sourceLocation!.longitude),
        mode: TravelMode.driving,
      ),
    );

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
            _buildGoogleMap(),
            _buildSearchBar(),
            if (_isLoading)
              const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(defaultHight),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            if (_distance != 0.0) _buildDistance(),
            _isLoading ? const SizedBox() : _buildFloatingActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleMap() {
    return GoogleMap(
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
    );
  }

  Widget _buildSearchBar() {
    return Positioned(
      top: defaultHight,
      left: defaultHight - 10,
      right: defaultHight - 10,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(defaultHight),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: defaultHight / 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(defaultHight),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Colors.blue,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                _sourceLocation = null;
                                _updatePolyline();
                                setState(() => _predictions = []);
                              },
                            )
                          : null,
                      hintText: 'Search location',
                      hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey,
                          ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: defaultHight,
                        vertical: defaultHight,
                      ),
                    ),
                    onChanged: (value) => _onSearchChanged(value),
                  ),
                ),
              ),
            ),

            // Predictions list with animations
            if (_predictions.isNotEmpty)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(top: defaultHight / 2),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.3,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(defaultHight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(defaultHight),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _predictions.length,
                    itemBuilder: (context, index) {
                      final prediction = _predictions[index];
                      return TweenAnimationBuilder(
                        duration: Duration(milliseconds: 200 + (index * 50)),
                        tween: Tween<double>(begin: 0, end: 1),
                        builder: (context, double value, child) {
                          return Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: Opacity(
                              opacity: value,
                              child: child,
                            ),
                          );
                        },
                        child: InkWell(
                          onTap: () => _handlePredictionTap(prediction),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        prediction.description,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Positioned(
      bottom: defaultHight,
      right: defaultHight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            backgroundColor: Colors.white,
            heroTag: 'refresh_location',
            onPressed: _isLoading ? null : _updateCurrentLocation,
            child: const Icon(Icons.my_location, color: Colors.blue),
          ),
          const SizedBox(height: defaultHight / 2),
          FloatingActionButton(
            backgroundColor: Colors.white,
            heroTag: 'refresh_route',
            onPressed: (_isLoading || _sourceLocation == null) ? null : _updatePolyline,
            child: Icon(
              Icons.route,
              color: (_isLoading || _sourceLocation == null) ? Colors.grey : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistance() {
    if (_sourceLocation == null || _distance == 0.0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: defaultHight * 8,
      left: defaultHight,
      right: defaultHight,
      child: Center(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(defaultHight),
                      ),
                      child: const Icon(
                        Icons.directions_car,
                        size: 24,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: defaultHight),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated Distance',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              (_distance / 1000).toStringAsFixed(2),
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                            ),
                            Text(' km',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.black,
                                    )),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: defaultHight),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: defaultHight,
                        vertical: defaultHight / 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: defaultHight / 3),
                          Text(
                            '${(_distance / 1000 / 50 * 60).toStringAsFixed(0)} min',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.green,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
