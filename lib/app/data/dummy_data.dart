import 'models/arena_model.dart';
import 'models/boost_request_model.dart';
import 'models/court_model.dart';

/// Mock data for the UI-first phase. Replaced by Firestore repositories
/// in the backend integration phase.
class DummyData {
  DummyData._();

  static final List<ArenaModel> arenas = [
    ArenaModel(
      id: 'arena-1',
      ownerId: 'mock-login',
      name: 'Champions Arena',
      description:
          'Premium multi-sport complex with floodlit courts, changing rooms and free parking. Home of the city padel league.',
      location: const ArenaLocation(
          address: 'Gulberg III, Lahore', lat: 31.5204, lng: 74.3587),
      status: ArenaStatus.approved,
      isActive: true,
      isFeatured: true,
      rating: 4.8,
      distanceKm: 2.4,
      courts: const [
        CourtModel(
          id: 'court-1',
          arenaId: 'arena-1',
          name: 'Padel Court A',
          description: 'Professional glass-walled padel court with panoramic views.',
          type: CourtType.padel,
          surface: CourtSurface.artificial,
          capacity: 4,
          pricePerHour: 3000,
          hasFloodlights: true,
          amenities: [
            CourtAmenity.floodlights,
            CourtAmenity.changingRooms,
            CourtAmenity.showers,
            CourtAmenity.parking,
          ],
        ),
        CourtModel(
          id: 'court-2',
          arenaId: 'arena-1',
          name: 'Football Ground',
          description: '14-a-side FIFA standard grass pitch with full drainage system.',
          type: CourtType.football,
          surface: CourtSurface.grass,
          capacity: 14,
          pricePerHour: 5000,
          startTime: '09:00',
          endTime: '02:00',
          hasFloodlights: true,
          amenities: [
            CourtAmenity.floodlights,
            CourtAmenity.parking,
            CourtAmenity.cafeteria,
            CourtAmenity.firstAid,
            CourtAmenity.scoreboard,
          ],
        ),
      ],
    ),
    ArenaModel(
      id: 'arena-2',
      ownerId: 'mock-login',
      name: 'Victory Sports Club',
      description:
          'Indoor cricket and futsal facility with professional turf and night lighting.',
      location: const ArenaLocation(
          address: 'DHA Phase 5, Lahore', lat: 31.4697, lng: 74.4108),
      status: ArenaStatus.pending,
      isActive: true,
      rating: 4.5,
      distanceKm: 5.1,
      courts: const [
        CourtModel(
          id: 'court-3',
          arenaId: 'arena-2',
          name: 'Indoor Cricket Net 1',
          type: CourtType.cricket,
          capacity: 12,
          pricePerHour: 2500,
        ),
      ],
    ),
    ArenaModel(
      id: 'arena-3',
      ownerId: 'other-owner',
      name: 'Padel Pro Center',
      description:
          'Dedicated padel facility — 4 panoramic courts, pro shop and coaching academy.',
      location: const ArenaLocation(
          address: 'Johar Town, Lahore', lat: 31.4676, lng: 74.2679),
      status: ArenaStatus.approved,
      isActive: true,
      isFeatured: true,
      rating: 4.9,
      distanceKm: 7.8,
      courts: const [
        CourtModel(
          id: 'court-4',
          arenaId: 'arena-3',
          name: 'Panorama Court 1',
          type: CourtType.padel,
          capacity: 4,
          pricePerHour: 3500,
        ),
        CourtModel(
          id: 'court-5',
          arenaId: 'arena-3',
          name: 'Panorama Court 2',
          type: CourtType.padel,
          capacity: 4,
          pricePerHour: 3500,
        ),
      ],
    ),
    ArenaModel(
      id: 'arena-4',
      ownerId: 'other-owner',
      name: 'Kick Off Futsal Park',
      description:
          'Outdoor futsal grounds with cafe seating for spectators.',
      location: const ArenaLocation(
          address: 'Model Town, Lahore', lat: 31.4805, lng: 74.3239),
      status: ArenaStatus.approved,
      isActive: false,
      rating: 4.2,
      distanceKm: 11.3,
      courts: const [
        CourtModel(
          id: 'court-6',
          arenaId: 'arena-4',
          name: 'Futsal Ground A',
          type: CourtType.football,
          capacity: 10,
          pricePerHour: 2000,
        ),
      ],
    ),
    ArenaModel(
      id: 'arena-5',
      ownerId: 'other-owner',
      name: 'Smash Indoor Sports',
      description:
          'Air-conditioned indoor courts for badminton, futsal and cricket practice.',
      location: const ArenaLocation(
          address: 'Bahria Town, Lahore', lat: 31.3684, lng: 74.1855),
      status: ArenaStatus.approved,
      isActive: true,
      rating: 4.6,
      distanceKm: 18.9,
      courts: const [
        CourtModel(
          id: 'court-7',
          arenaId: 'arena-5',
          name: 'Indoor Court 1',
          type: CourtType.indoor,
          capacity: 8,
          pricePerHour: 1800,
        ),
        CourtModel(
          id: 'court-8',
          arenaId: 'arena-5',
          name: 'Cricket Net',
          type: CourtType.cricket,
          capacity: 6,
          pricePerHour: 1500,
        ),
      ],
    ),
  ];

  /// Revenue points for the owner dashboard chart (PKR thousands).
  static const List<double> revenueDaily = [12, 18, 9, 22, 30, 26, 34];
  static const List<double> revenueWeekly = [80, 95, 120, 110];
  static const List<double> revenueMonthly = [320, 410, 380, 460, 520, 490];

  static const List<Map<String, String>> ownerActivity = [
    {'title': 'New booking — Padel Court A', 'time': '10 min ago'},
    {'title': 'Deposit submitted by Ali Raza', 'time': '1 hr ago'},
    {'title': 'Booking confirmed — Football Ground', 'time': '3 hrs ago'},
    {'title': 'Victory Sports Club submitted for review', 'time': 'Yesterday'},
    {'title': 'Boost approved for Champions Arena', 'time': '2 days ago'},
  ];

  static final List<BoostRequestModel> boostRequests = [
    BoostRequestModel(
      id: 'boost-1',
      arenaId: 'arena-1',
      arenaName: 'Champions Arena',
      duration: BoostDuration.oneMonth,
      price: BoostDuration.oneMonth.price,
      status: 'approved',
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
    BoostRequestModel(
      id: 'boost-2',
      arenaId: 'arena-2',
      arenaName: 'Victory Sports Club',
      duration: BoostDuration.oneWeek,
      price: BoostDuration.oneWeek.price,
      status: 'pending',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
  ];

  static const String jazzCashNumber = '0300-1234567';
}
