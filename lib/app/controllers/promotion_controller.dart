import 'dart:async';

import 'package:get/get.dart';

import '../data/models/promotion_model.dart';
import '../services/promotion_service.dart';

class PromotionController extends GetxController {
  final PromotionService _service = PromotionService();

  final promotions = <PromotionModel>[].obs;
  final isLoading = false.obs;

  StreamSubscription<List<PromotionModel>>? _sub;

  void listenForArena(String arenaId) {
    _sub?.cancel();
    _sub = _service
        .ownerPromotions(arenaId)
        .listen((list) => promotions.value = list, onError: (_) {});
  }

  Future<String?> create(PromotionModel promo) async {
    try {
      isLoading.value = true;
      await _service.create(promo);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<String?> edit(String id, Map<String, dynamic> data) async {
    try {
      await _service.update(id, data);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> setStatus(String id, PromotionStatus status) async {
    try {
      await _service.setStatus(id, status);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> delete(String id) async {
    try {
      await _service.delete(id);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
