import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../services/arena_service.dart';

class FavoritesController extends GetxController {
  static FavoritesController get to => Get.find();

  final ArenaService _svc = ArenaService();
  final RxSet<String> _ids = <String>{}.obs;

  Set<String> get ids => _ids;

  bool isFav(String arenaId) => _ids.contains(arenaId);

  StreamSubscription<Set<String>>? _sub;

  @override
  void onInit() {
    super.onInit();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _sub = _svc.favoritesStream(uid).listen((set) => _ids.assignAll(set));
    }
  }

  Future<void> toggle(String arenaId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (isFav(arenaId)) {
      await _svc.removeFavorite(uid, arenaId);
    } else {
      await _svc.addFavorite(uid, arenaId);
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
