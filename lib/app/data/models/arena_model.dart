import 'court_model.dart';

/// Mirrors Firestore arenas/{arenaId} from scope.md.
enum ArenaStatus { pending, approved, rejected, suspended, off }

class ArenaLocation {
  final String address;
  final double lat;
  final double lng;

  const ArenaLocation({
    required this.address,
    this.lat = 0,
    this.lng = 0,
  });
}

class ArenaModel {
  final String id;
  final String ownerId;
  final String name;
  final String description;
  final List<String> images;
  final ArenaLocation location;
  final ArenaStatus status;
  final bool isActive; // Owner ON/OFF
  final bool isFeatured;
  final DateTime? featuredUntil;
  final List<CourtModel> courts;
  final double rating;
  final double distanceKm; // dummy discovery distance

  const ArenaModel({
    required this.id,
    this.ownerId = '',
    required this.name,
    this.description = '',
    this.images = const [],
    required this.location,
    this.status = ArenaStatus.pending,
    this.isActive = true,
    this.isFeatured = false,
    this.featuredUntil,
    this.courts = const [],
    this.rating = 4.5,
    this.distanceKm = 0,
  });

  double get minPrice => courts.isEmpty
      ? 0
      : courts.map((c) => c.pricePerHour).reduce((a, b) => a < b ? a : b);

  ArenaModel copyWith({
    String? name,
    String? description,
    List<String>? images,
    ArenaLocation? location,
    ArenaStatus? status,
    bool? isActive,
    bool? isFeatured,
    List<CourtModel>? courts,
  }) =>
      ArenaModel(
        id: id,
        ownerId: ownerId,
        name: name ?? this.name,
        description: description ?? this.description,
        images: images ?? this.images,
        location: location ?? this.location,
        status: status ?? this.status,
        isActive: isActive ?? this.isActive,
        isFeatured: isFeatured ?? this.isFeatured,
        featuredUntil: featuredUntil,
        courts: courts ?? this.courts,
        rating: rating,
        distanceKm: distanceKm,
      );
}
