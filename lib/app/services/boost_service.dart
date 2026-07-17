import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../data/models/boost_request_model.dart';

class BoostService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('boostRequests');

  Future<String> createRequest(BoostRequestModel req, File screenshot) async {
    final ref = _col.doc();
    final storageRef = _storage.ref(
        'boostRequests/${ref.id}/payment_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await storageRef.putFile(screenshot);
    final url = await storageRef.getDownloadURL();

    await ref.set({
      ...req.toMap(),
      'id': ref.id,
      'ownerId': FirebaseAuth.instance.currentUser?.uid ?? '',
      'paymentScreenshot': url,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Stream<List<BoostRequestModel>> ownerRequests(String ownerId) => _col
      .where('ownerId', isEqualTo: ownerId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => BoostRequestModelX.fromMap({...d.data(), 'id': d.id}))
          .toList());

  Stream<List<BoostRequestModel>> pendingRequests() => _col
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => BoostRequestModelX.fromMap({...d.data(), 'id': d.id}))
          .toList());

  Future<void> updateStatus(String id, String status) =>
      _col.doc(id).update({'status': status});

  Stream<List<BoostRequestModel>> allRequests() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => BoostRequestModelX.fromMap({...d.data(), 'id': d.id}))
          .toList());

  Future<Map<String, double>> fetchPricing() async {
    final doc = await _db.collection('settings').doc('boostPricing').get();
    if (!doc.exists) {
      return {'1_week': 1500, '2_week': 2500, '1_month': 4000};
    }
    final data = doc.data()!;
    return {
      '1_week': (data['1_week'] ?? 1500).toDouble(),
      '2_week': (data['2_week'] ?? 2500).toDouble(),
      '1_month': (data['1_month'] ?? 4000).toDouble(),
    };
  }
}
