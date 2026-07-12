import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../data/dummy_data.dart';
import '../data/models/arena_model.dart';

enum RevenueRange { daily, weekly, monthly }

/// Owner dashboard + my-arenas state. Dummy data for the UI-first phase.
class OwnerController extends GetxController {
  static OwnerController get to => Get.find();

  final RxList<ArenaModel> myArenas = <ArenaModel>[].obs;
  final Rx<RevenueRange> revenueRange = RevenueRange.daily.obs;

  @override
  void onInit() {
    super.onInit();
    loadArenas();
  }

  void loadArenas() {
    final uid = AuthController.to.currentUser.value?.uid;
    myArenas.assignAll(DummyData.arenas.where((a) => a.ownerId == uid));
    // Fallback so the owner UI always has content in the dummy phase.
    if (myArenas.isEmpty) {
      myArenas.assignAll(DummyData.arenas.take(2));
    }
  }

  List<double> get revenuePoints {
    switch (revenueRange.value) {
      case RevenueRange.daily:
        return DummyData.revenueDaily;
      case RevenueRange.weekly:
        return DummyData.revenueWeekly;
      case RevenueRange.monthly:
        return DummyData.revenueMonthly;
    }
  }

  List<String> get revenueLabels {
    switch (revenueRange.value) {
      case RevenueRange.daily:
        return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      case RevenueRange.weekly:
        return ['W1', 'W2', 'W3', 'W4'];
      case RevenueRange.monthly:
        return ['Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'];
    }
  }

  // Dashboard stats (dummy)
  int get totalBookings => 148;
  int get activeCourts =>
      myArenas.fold(0, (sum, a) => sum + a.courts.where((c) => c.isActive).length);
  double get totalEarnings => 245000;
  int get pendingApprovals =>
      myArenas.where((a) => a.status == ArenaStatus.pending).length;

  void toggleArenaActive(String arenaId) {
    final index = myArenas.indexWhere((a) => a.id == arenaId);
    if (index == -1) return;
    final arena = myArenas[index];
    myArenas[index] = arena.copyWith(isActive: !arena.isActive);
    myArenas.refresh();
  }

  void addArena(ArenaModel arena) {
    myArenas.insert(0, arena);
  }
}
