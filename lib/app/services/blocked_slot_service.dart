import 'package:cloud_firestore/cloud_firestore.dart';

/// Owner-blocked court hours, stored in the top-level `blockedSlots`
/// collection with deterministic ids `{arenaId}_{courtId}_{dateKey}_{hour}`
/// so blocking is idempotent and unblocking needs no query.
class BlockedSlotService {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('blockedSlots');

  static String dateKey(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  static String docId(String arenaId, String courtId, DateTime date, int hour) =>
      '${arenaId}_${courtId}_${dateKey(date)}_$hour';

  /// Blocked hours per court for one arena + day: `{courtId: {hours…}}`.
  Stream<Map<String, Set<int>>> watchArenaDay(String arenaId, DateTime date) {
    return _col
        .where('arenaId', isEqualTo: arenaId)
        .where('dateKey', isEqualTo: dateKey(date))
        .snapshots()
        .map((snap) {
      final map = <String, Set<int>>{};
      for (final d in snap.docs) {
        final data = d.data();
        final courtId = data['courtId'] as String? ?? '';
        final hour = (data['hour'] ?? -1) as int;
        if (courtId.isEmpty || hour < 0) continue;
        (map[courtId] ??= {}).add(hour);
      }
      return map;
    });
  }

  /// One-shot fetch for the customer slot picker / walk-in screen.
  Future<Set<int>> blockedHours(
      String arenaId, String courtId, DateTime date) async {
    final snap = await _col
        .where('arenaId', isEqualTo: arenaId)
        .where('courtId', isEqualTo: courtId)
        .where('dateKey', isEqualTo: dateKey(date))
        .get();
    return snap.docs.map((d) => (d.data()['hour'] ?? -1) as int).toSet();
  }

  Future<void> block({
    required String arenaId,
    required String courtId,
    required String courtName,
    required String ownerId,
    required DateTime date,
    required int hour,
    String reason = '',
  }) {
    return _col.doc(docId(arenaId, courtId, date, hour)).set({
      'arenaId': arenaId,
      'courtId': courtId,
      'courtName': courtName,
      'ownerId': ownerId,
      'dateKey': dateKey(date),
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'hour': hour,
      if (reason.isNotEmpty) 'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unblock(
      String arenaId, String courtId, DateTime date, int hour) {
    return _col.doc(docId(arenaId, courtId, date, hour)).delete();
  }
}
