/// Mirrors Firestore arenas/{arenaId}/courts/{courtId} from scope.md.
enum CourtType { football, padel, indoor, cricket, other }

extension CourtTypeX on CourtType {
  String get label {
    switch (this) {
      case CourtType.football:
        return 'Football';
      case CourtType.padel:
        return 'Padel';
      case CourtType.indoor:
        return 'Indoor';
      case CourtType.cricket:
        return 'Cricket';
      case CourtType.other:
        return 'Other';
    }
  }

  static CourtType fromString(String? type) => CourtType.values.firstWhere(
        (t) => t.name == type,
        orElse: () => CourtType.other,
      );
}

enum CourtSurface { grass, artificial, hardcourt, clay, concrete, other }

extension CourtSurfaceX on CourtSurface {
  String get label {
    switch (this) {
      case CourtSurface.grass:
        return 'Grass';
      case CourtSurface.artificial:
        return 'Artificial Turf';
      case CourtSurface.hardcourt:
        return 'Hard Court';
      case CourtSurface.clay:
        return 'Clay';
      case CourtSurface.concrete:
        return 'Concrete';
      case CourtSurface.other:
        return 'Other';
    }
  }
}

/// Well-known amenities that can be toggled per court.
enum CourtAmenity {
  floodlights,
  changingRooms,
  showers,
  parking,
  cafeteria,
  firstAid,
  wifi,
  scoreboard,
  referee,
  equipment,
}

extension CourtAmenityX on CourtAmenity {
  String get label {
    switch (this) {
      case CourtAmenity.floodlights:
        return 'Floodlights';
      case CourtAmenity.changingRooms:
        return 'Changing Rooms';
      case CourtAmenity.showers:
        return 'Showers';
      case CourtAmenity.parking:
        return 'Parking';
      case CourtAmenity.cafeteria:
        return 'Cafeteria';
      case CourtAmenity.firstAid:
        return 'First Aid';
      case CourtAmenity.wifi:
        return 'Wi-Fi';
      case CourtAmenity.scoreboard:
        return 'Scoreboard';
      case CourtAmenity.referee:
        return 'Referee Available';
      case CourtAmenity.equipment:
        return 'Equipment Rental';
    }
  }

  String get icon {
    switch (this) {
      case CourtAmenity.floodlights:
        return '💡';
      case CourtAmenity.changingRooms:
        return '🚪';
      case CourtAmenity.showers:
        return '🚿';
      case CourtAmenity.parking:
        return '🅿️';
      case CourtAmenity.cafeteria:
        return '☕';
      case CourtAmenity.firstAid:
        return '🩺';
      case CourtAmenity.wifi:
        return '📶';
      case CourtAmenity.scoreboard:
        return '🏆';
      case CourtAmenity.referee:
        return '🟡';
      case CourtAmenity.equipment:
        return '🎒';
    }
  }
}

class CourtModel {
  final String id;
  final String arenaId;
  final String name;
  final String description;
  final CourtType type;
  final CourtSurface surface;
  final int capacity;
  final double pricePerHour;
  final List<String> images;
  final String startTime; // 'HH:mm'
  final String endTime;   // 'HH:mm'
  final int advanceBookingDays;
  final bool hasFloodlights;
  final List<CourtAmenity> amenities;
  final bool isActive;

  const CourtModel({
    required this.id,
    this.arenaId = '',
    required this.name,
    this.description = '',
    required this.type,
    this.surface = CourtSurface.artificial,
    this.capacity = 10,
    required this.pricePerHour,
    this.images = const [],
    this.startTime = '08:00',
    this.endTime = '23:00',
    this.advanceBookingDays = 14,
    this.hasFloodlights = false,
    this.amenities = const [],
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'arenaId': arenaId,
        'name': name,
        'description': description,
        'type': type.name,
        'surface': surface.name,
        'capacity': capacity,
        'pricePerHour': pricePerHour,
        'images': images,
        'startTime': startTime,
        'endTime': endTime,
        'advanceBookingDays': advanceBookingDays,
        'hasFloodlights': hasFloodlights,
        'amenities': amenities.map((a) => a.name).toList(),
        'isActive': isActive,
      };

  factory CourtModel.fromMap(Map<String, dynamic> m) => CourtModel(
        id: m['id'] ?? '',
        arenaId: m['arenaId'] ?? '',
        name: m['name'] ?? '',
        description: m['description'] ?? '',
        type: CourtTypeX.fromString(m['type']),
        surface: CourtSurface.values.firstWhere(
          (s) => s.name == m['surface'],
          orElse: () => CourtSurface.artificial,
        ),
        capacity: (m['capacity'] ?? 10) as int,
        pricePerHour: (m['pricePerHour'] ?? 0).toDouble(),
        images: List<String>.from(m['images'] ?? []),
        startTime: m['startTime'] ?? '08:00',
        endTime: m['endTime'] ?? '23:00',
        advanceBookingDays: (m['advanceBookingDays'] ?? 14) as int,
        hasFloodlights: m['hasFloodlights'] ?? false,
        amenities: CourtAmenity.values
            .where((a) =>
                (m['amenities'] as List<dynamic>? ?? []).contains(a.name))
            .toList(),
        isActive: m['isActive'] ?? true,
      );

  CourtModel copyWith({
    String? name,
    String? description,
    CourtType? type,
    CourtSurface? surface,
    int? capacity,
    double? pricePerHour,
    String? startTime,
    String? endTime,
    int? advanceBookingDays,
    bool? hasFloodlights,
    List<CourtAmenity>? amenities,
    bool? isActive,
  }) =>
      CourtModel(
        id: id,
        arenaId: arenaId,
        name: name ?? this.name,
        description: description ?? this.description,
        type: type ?? this.type,
        surface: surface ?? this.surface,
        capacity: capacity ?? this.capacity,
        pricePerHour: pricePerHour ?? this.pricePerHour,
        images: images,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        advanceBookingDays: advanceBookingDays ?? this.advanceBookingDays,
        hasFloodlights: hasFloodlights ?? this.hasFloodlights,
        amenities: amenities ?? this.amenities,
        isActive: isActive ?? this.isActive,
      );
}
