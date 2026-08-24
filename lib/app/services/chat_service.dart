import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/chat_model.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');

  // ── Chat room creation ───────────────────────────────────────────────

  /// One chat per customer–arena pair. Lookup order:
  ///  1. canonical pair chat (`pairKey`)
  ///  2. legacy per-booking chat for this booking → upgraded in place
  ///  3. create a fresh pair chat
  ///
  /// Every query filters by `participants` (arrayContains) — not just the
  /// target field — so Firestore can statically verify it against the chats
  /// read rule (`uid() in resource.data.participants`); without it the query
  /// is denied outright.
  Future<String> getOrCreateBookingChat({
    required String bookingId,
    required String arenaId,
    required String customerId,
    required String ownerId,
    required String title,
    required String subtitle,
    required String requesterUid,
    BookingSnapshot? bookingSnapshot,
    String? customerName,
  }) async {
    final pairKey = '${arenaId}_$customerId';

    final byPair = await _chats
        .where('participants', arrayContains: requesterUid)
        .where('pairKey', isEqualTo: pairKey)
        .limit(1)
        .get();
    if (byPair.docs.isNotEmpty) return byPair.docs.first.id;

    // Legacy chat created for this specific booking: adopt it as the
    // canonical pair chat, keeping its full message history.
    final legacy = await _chats
        .where('participants', arrayContains: requesterUid)
        .where('bookingId', isEqualTo: bookingId)
        .limit(1)
        .get();
    if (legacy.docs.isNotEmpty) {
      await legacy.docs.first.reference.set({
        'pairKey': pairKey,
        'arenaId': arenaId,
        'customerId': customerId,
        'activeBookingId': bookingId,
      }, SetOptions(merge: true));
      return legacy.docs.first.id;
    }

    final ref = _chats.doc();
    await ref.set({
      'type': 'booking',
      'participants': [customerId, ownerId],
      'bookingId': bookingId,
      'pairKey': pairKey,
      'arenaId': arenaId,
      'customerId': customerId,
      if (customerName != null && customerName.isNotEmpty)
        'customerName': customerName,
      'activeBookingId': bookingId,
      'title': title,
      'subtitle': subtitle,
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCounts': {customerId: 0, ownerId: 0},
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      if (bookingSnapshot != null) 'bookingSnapshot': bookingSnapshot.toMap(),
    });
    return ref.id;
  }

  /// Entry point from the Arena Details screen: opens the single pair chat
  /// with the arena's owner, no booking required. Adopts a legacy
  /// per-booking chat (found via the customer's bookings with this arena)
  /// before creating anything new, so history is never split.
  Future<String> getOrCreateArenaChat({
    required String arenaId,
    required String customerId,
    required String ownerId,
    required String title,
    required String requesterUid,
    String? customerName,
  }) async {
    final pairKey = '${arenaId}_$customerId';

    final byPair = await _chats
        .where('participants', arrayContains: requesterUid)
        .where('pairKey', isEqualTo: pairKey)
        .limit(1)
        .get();
    if (byPair.docs.isNotEmpty) return byPair.docs.first.id;

    // No pair chat yet — a legacy chat may exist under one of the pair's
    // booking ids. whereIn caps at 10; recent bookings are checked first.
    final bookings = await _db
        .collection('bookings')
        .where('arenaId', isEqualTo: arenaId)
        .where('customerId', isEqualTo: customerId)
        .limit(10)
        .get();
    final bookingIds = bookings.docs.map((d) => d.id).toList();
    if (bookingIds.isNotEmpty) {
      final legacy = await _chats
          .where('participants', arrayContains: requesterUid)
          .where('bookingId', whereIn: bookingIds)
          .limit(1)
          .get();
      if (legacy.docs.isNotEmpty) {
        await legacy.docs.first.reference.set({
          'pairKey': pairKey,
          'arenaId': arenaId,
          'customerId': customerId,
        }, SetOptions(merge: true));
        return legacy.docs.first.id;
      }
    }

    final ref = _chats.doc();
    await ref.set({
      'type': 'booking',
      'participants': [customerId, ownerId],
      'pairKey': pairKey,
      'arenaId': arenaId,
      'customerId': customerId,
      if (customerName != null && customerName.isNotEmpty)
        'customerName': customerName,
      'title': title,
      'subtitle': 'Arena chat',
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCounts': {customerId: 0, ownerId: 0},
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Upgrades a legacy per-booking chat to a pair chat by resolving the
  /// pair from its booking document. No-op for chats that already have a
  /// pairKey (or aren't booking chats). Called when a chat is opened, so
  /// old conversations gain the live banner without a batch migration.
  Future<void> upgradeLegacyChat(String chatId) async {
    final doc = await _chats.doc(chatId).get();
    final data = doc.data();
    if (data == null ||
        data['pairKey'] != null ||
        data['type'] != 'booking' ||
        data['bookingId'] == null) {
      return;
    }
    final booking =
        await _db.collection('bookings').doc(data['bookingId']).get();
    final b = booking.data();
    final arenaId = b?['arenaId'];
    final customerId = b?['customerId'];
    if (arenaId == null || customerId == null) return;
    await _chats.doc(chatId).set({
      'pairKey': '${arenaId}_$customerId',
      'arenaId': arenaId,
      'customerId': customerId,
      'activeBookingId': data['bookingId'],
    }, SetOptions(merge: true));
  }

  /// Pins a booking as the chat's active context (banner default for both
  /// parties). Written by either participant.
  Future<void> setActiveBooking(String chatId, String bookingId) =>
      _chats.doc(chatId).update({'activeBookingId': bookingId});

  Future<String> getOrCreateSupportChat({
    required String uid,
    required String role,
    required String displayName,
  }) async {
    final typeKey = role == 'owner' ? 'owner_support' : 'customer_support';
    final existing = await _chats
        .where('participants', arrayContains: uid)
        .where('type', isEqualTo: typeKey)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return existing.docs.first.id;

    final ref = _chats.doc();
    await ref.set({
      'type': typeKey,
      'participants': [uid],
      'title': 'MyArena Support',
      'subtitle': '$displayName · $role',
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCounts': {uid: 0},
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // ── Streams ──────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> userChats(String uid) => _chats
      .where('participants', arrayContains: uid)
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => {...d.data(), 'id': d.id}).toList());

  /// Returns booking chats for arenas assigned to a staff member. Used instead
  /// of [userChats] for arena staff because they are not in the participants
  /// list of customer-owner chats.
  Stream<List<Map<String, dynamic>>> staffArenaChats(List<String> arenaIds) {
    if (arenaIds.isEmpty) {
      return Stream.value([]);
    }
    final ids = arenaIds.take(10).toList(); // Firestore whereIn cap
    return _chats
        .where('arenaId', whereIn: ids)
        .where('type', isEqualTo: 'booking')
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  Stream<List<Map<String, dynamic>>> allChats() => _chats
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => {...d.data(), 'id': d.id}).toList());

  Stream<List<MessageModel>> messages(String chatId) => _chats
      .doc(chatId)
      .collection('messages')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs
          .map((d) => MessageModel.fromMap({...d.data(), 'id': d.id}))
          .toList());

  // ── Send messages ────────────────────────────────────────────────────

  Future<void> sendText({
    required String chatId,
    required String senderId,
    required String senderRole,
    String? senderName,
    required String text,
    required List<String> participants,
    Map<String, dynamic>? bookingRef,
    Map<String, dynamic>? ticketRef,
  }) async {
    final msgRef = _chats.doc(chatId).collection('messages').doc();
    final batch = _db.batch();

    batch.set(msgRef, {
      'senderId': senderId,
      'senderRole': senderRole,
      if (senderName != null) 'senderName': senderName,
      'type': 'text',
      'content': text,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'bookingRef': ?bookingRef,
      'ticketRef': ?ticketRef,
    });

    final increments = <String, dynamic>{
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    };
    for (final uid in participants) {
      if (uid != senderId) {
        increments['unreadCounts.$uid'] = FieldValue.increment(1);
      }
    }
    batch.update(_chats.doc(chatId), increments);
    await batch.commit();
  }

  Future<void> sendImage({
    required String chatId,
    required String senderId,
    required String senderRole,
    String? senderName,
    required XFile file,
    required List<String> participants,
    Map<String, dynamic>? bookingRef,
  }) async {
    final ext = file.name.split('.').last;
    final ref = _storage.ref(
        'chats/$chatId/${DateTime.now().millisecondsSinceEpoch}.$ext');
    await ref.putData(await file.readAsBytes());
    final url = await ref.getDownloadURL();

    final msgRef = _chats.doc(chatId).collection('messages').doc();
    final batch = _db.batch();
    batch.set(msgRef, {
      'senderId': senderId,
      'senderRole': senderRole,
      if (senderName != null) 'senderName': senderName,
      'type': 'image',
      'content': url,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'bookingRef': ?bookingRef,
    });

    final updates = <String, dynamic>{
      'lastMessage': '📷 Photo',
      'lastMessageAt': FieldValue.serverTimestamp(),
    };
    for (final uid in participants) {
      if (uid != senderId) {
        updates['unreadCounts.$uid'] = FieldValue.increment(1);
      }
    }
    batch.update(_chats.doc(chatId), updates);
    await batch.commit();
  }

  Future<void> markRead(String chatId, String uid) =>
      _chats.doc(chatId).update({'unreadCounts.$uid': 0});

  Future<void> addParticipant(String chatId, String uid) => _chats
      .doc(chatId)
      .update({'participants': FieldValue.arrayUnion([uid])});
}
