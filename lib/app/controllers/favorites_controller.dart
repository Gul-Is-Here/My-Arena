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
  StreamSubscription? _authSub;

  @override
  void onInit() {
    super.onInit();
    // Use authStateChanges() so the Firestore stream only starts after the
    // SDK has a valid auth token — avoids PERMISSION_DENIED on first login.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _sub?.cancel();
      if (user != null) {
        _sub = _svc.favoritesStream(user.uid).listen((set) => _ids.assignAll(set));
      } else {
        _ids.clear();
      }
    });
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
    _authSub?.cancel();
    _sub?.cancel();
    super.onClose();
  }
}
