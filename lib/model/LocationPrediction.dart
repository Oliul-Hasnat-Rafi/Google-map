class LocationPrediction {
  final String placeId;
  final String description;

  LocationPrediction({
    required this.placeId,
    required this.description,
  });

  factory LocationPrediction.fromPlacesPrediction(dynamic prediction) {
    return LocationPrediction(
      placeId: prediction.placeId ?? '',
      description: prediction.description ?? '',
    );
  }
}