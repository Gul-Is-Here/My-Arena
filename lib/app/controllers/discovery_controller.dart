import 'package:get/get.dart';

import '../data/dummy_data.dart';
import '../data/models/arena_model.dart';
import '../data/models/court_model.dart';

/// Customer arena discovery — featured + nearby (30km) with filters.
/// GPS + geo queries arrive with the backend phase; distances are dummy.
class DiscoveryController extends GetxController {
  static DiscoveryController get to => Get.find();

  final RxBool isMapView = false.obs;
  final Rxn<CourtType> typeFilter = Rxn<CourtType>();
  final RxDouble maxPrice = 5000.0.obs;
  final RxDouble maxDistance = 30.0.obs;
  final RxString searchQuery = ''.obs;

  /// Only approved + active arenas are discoverable (per scope.md).
  List<ArenaModel> get _visible => DummyData.arenas
      .where((a) => a.status == ArenaStatus.approved && a.isActive)
      .toList();

  List<ArenaModel> get featured =>
      _visible.where((a) => a.isFeatured).toList();

  List<ArenaModel> get nearby {
    final list = _visible.where((a) {
      if (a.distanceKm > maxDistance.value) return false;
      if (typeFilter.value != null &&
          !a.courts.any((c) => c.type == typeFilter.value)) {
        return false;
      }
      if (a.minPrice > maxPrice.value) return false;
      if (searchQuery.value.isNotEmpty &&
          !a.name.toLowerCase().contains(searchQuery.value.toLowerCase())) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return list;
  }

  void clearFilters() {
    typeFilter.value = null;
    maxPrice.value = 5000;
    maxDistance.value = 30;
    searchQuery.value = '';
  }
}
