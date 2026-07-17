import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../data/models/chat_model.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');

  // ── Chat room creation ───────────────────────────────────────────────

  Future<String> getOrCreateBookingChat({
    required String bookingId,
    required String customerId,
    required String ownerId,
    required String title,
    required String subtitle,
    required String requesterUid,
  }) async {
    // Filtering by `participants` (arrayContains) — not just `bookingId` — lets
    // Firestore statically verify the query against the chats read rule
    // (`uid() in resource.data.participants`); without it the query is denied
    // outright since the rule can't be proven to hold for every possible match.
    final existing = await _chats
        .where('participants', arrayContains: requesterUid)
        .where('bookingId', isEqualTo: bookingId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return existing.docs.first.id;

    final ref = _chats.doc();
    await ref.set({
      'type': 'booking',
      'participants': [customerId, ownerId],
      'bookingId': bookingId,
      'title': title,
      'subtitle': subtitle,
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCounts': {customerId: 0, ownerId: 0},
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

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
    required String text,
    required List<String> participants,
  }) async {
    final msgRef = _chats.doc(chatId).collection('messages').doc();
    final batch = _db.batch();

    batch.set(msgRef, {
      'senderId': senderId,
      'senderRole': senderRole,
      'type': 'text',
      'content': text,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
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
    required File file,
    required List<String> participants,
  }) async {
    final ext = file.path.split('.').last;
    final ref = _storage.ref(
        'chats/$chatId/${DateTime.now().millisecondsSinceEpoch}.$ext');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    final msgRef = _chats.doc(chatId).collection('messages').doc();
    final batch = _db.batch();
    batch.set(msgRef, {
      'senderId': senderId,
      'senderRole': senderRole,
      'type': 'image',
      'content': url,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
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
