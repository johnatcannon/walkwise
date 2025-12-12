class FunFact {
  final String imageUrl;
  final String audioUrl;
  final int cityId;
  final String locationName;

  FunFact({
    required this.imageUrl,
    required this.audioUrl,
    required this.cityId,
    required this.locationName,
  });

  factory FunFact.fromFirestore(Map<String, dynamic> data) {
    return FunFact(
      imageUrl: data['imageURL'] ?? '',
      audioUrl: data['audioURL'] ?? '',
      cityId: data['city_id'] ?? 0,
      locationName: data['location_name'] ?? '',
    );
  }
} 