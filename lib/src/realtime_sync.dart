import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RealtimeResult {
  const RealtimeResult({
    required this.success,
    required this.message,
    this.userId,
  });

  final bool success;
  final String message;
  final String? userId;

  static RealtimeResult ok(String message, {String? userId}) =>
      RealtimeResult(success: true, message: message, userId: userId);

  static RealtimeResult fail(String message) =>
      RealtimeResult(success: false, message: message);
}

class PublicRoomSearchHit {
  const PublicRoomSearchHit({required this.code, required this.roomName});

  final String code;
  final String roomName;
}

enum RealtimeCommandType { addSong, voteSong, updateProfile }

class RealtimeCommand {
  const RealtimeCommand({
    required this.id,
    required this.type,
    required this.userId,
    required this.payload,
    required this.createdAtMs,
    required this.processed,
  });

  final String id;
  final RealtimeCommandType type;
  final String userId;
  final Map<String, dynamic> payload;
  final int createdAtMs;
  final bool processed;

  static RealtimeCommand? fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final typeRaw = data['type']?.toString();
    if (typeRaw == null) {
      return null;
    }
    final type = RealtimeCommandType.values.where(
      (value) => value.name == typeRaw,
    );
    if (type.isEmpty) {
      return null;
    }
    return RealtimeCommand(
      id: snapshot.id,
      type: type.first,
      userId: (data['userId'] ?? '') as String,
      payload: Map<String, dynamic>.from(data['payload'] as Map? ?? {}),
      createdAtMs: ((data['createdAtMs'] ?? 0) as num).toInt(),
      processed: (data['processed'] ?? false) as bool,
    );
  }
}

abstract class PartyRealtimeSyncApi {
  Future<RealtimeResult> ensureSignedInAnonymously();

  Future<RealtimeResult> createRoomState({
    required String code,
    required String hostUserId,
    required Map<String, dynamic> roomState,
  });

  Future<Map<String, dynamic>?> fetchRoomState(String code);

  Future<List<PublicRoomSearchHit>> searchPublicRoomsByName(String query);

  Stream<Map<String, dynamic>?> watchRoomState(String code);

  Future<RealtimeResult> upsertParticipant({
    required String code,
    required String participantId,
    required Map<String, dynamic> participant,
  });

  Future<RealtimeResult> updateRoomState({
    required String code,
    required Map<String, dynamic> roomState,
  });

  Future<RealtimeResult> enqueueCommand({
    required String code,
    required RealtimeCommandType type,
    required String userId,
    required Map<String, dynamic> payload,
  });

  Stream<List<RealtimeCommand>> watchPendingCommands(String code);

  Future<void> markCommandProcessed({
    required String code,
    required String commandId,
    required bool success,
    required String message,
  });
}

class PartyRealtimeSync implements PartyRealtimeSyncApi {
  PartyRealtimeSync({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _firestore.collection('party_rooms');

  CollectionReference<Map<String, dynamic>> _commands(String code) =>
      _rooms.doc(code).collection('commands');

  @override
  Future<RealtimeResult> ensureSignedInAnonymously() async {
    try {
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }
      return RealtimeResult.ok(
        'Realtime auth verbunden.',
        userId: _auth.currentUser?.uid,
      );
    } catch (_) {
      return RealtimeResult.fail(
        'Firebase Auth fehlgeschlagen. Bitte Firebase Projekt prüfen.',
      );
    }
  }

  @override
  Future<RealtimeResult> createRoomState({
    required String code,
    required String hostUserId,
    required Map<String, dynamic> roomState,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final roomRef = _rooms.doc(code);
        final snapshot = await transaction.get(roomRef);
        if (snapshot.exists) {
          throw StateError('Room exists');
        }
        transaction.set(roomRef, <String, dynamic>{
          'hostUserId': hostUserId,
          'hostAuthUid': _auth.currentUser?.uid,
          'createdAtMs': DateTime.now().millisecondsSinceEpoch,
          'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
          'state': roomState,
        });
      });
      return RealtimeResult.ok('Realtime room erstellt.');
    } on StateError {
      return RealtimeResult.fail('Room-Code bereits vergeben.');
    } catch (_) {
      return RealtimeResult.fail('Room konnte nicht erstellt werden.');
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchRoomState(String code) async {
    final snapshot = await _rooms.doc(code).get();
    if (!snapshot.exists) {
      return null;
    }
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    return Map<String, dynamic>.from(data['state'] as Map? ?? {});
  }

  @override
  Future<List<PublicRoomSearchHit>> searchPublicRoomsByName(
    String query,
  ) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const <PublicRoomSearchHit>[];
    }
    try {
      final snapshot = await _rooms.get();
      final exact = <PublicRoomSearchHit>[];
      final partial = <PublicRoomSearchHit>[];
      for (final doc in snapshot.docs) {
        final state = Map<String, dynamic>.from(
          doc.data()['state'] as Map? ?? <String, dynamic>{},
        );
        final roomName = (state['roomName'] ?? '').toString().trim();
        if (roomName.isEmpty) {
          continue;
        }
        if ((state['isPublic'] ?? false) != true) {
          continue;
        }
        if ((state['ended'] ?? false) == true) {
          continue;
        }
        final roomNameLower = (state['roomNameLower'] ?? roomName)
            .toString()
            .toLowerCase();
        final hit = PublicRoomSearchHit(code: doc.id, roomName: roomName);
        if (roomNameLower == normalized) {
          exact.add(hit);
        } else if (roomNameLower.contains(normalized)) {
          partial.add(hit);
        }
      }
      return <PublicRoomSearchHit>[...exact, ...partial];
    } catch (_) {
      return const <PublicRoomSearchHit>[];
    }
  }

  @override
  Stream<Map<String, dynamic>?> watchRoomState(String code) {
    return _rooms.doc(code).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      final data = snapshot.data();
      if (data == null) {
        return null;
      }
      return Map<String, dynamic>.from(data['state'] as Map? ?? {});
    });
  }

  @override
  Future<RealtimeResult> upsertParticipant({
    required String code,
    required String participantId,
    required Map<String, dynamic> participant,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final roomRef = _rooms.doc(code);
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) {
          throw StateError('Room not found');
        }
        final data = snapshot.data() ?? <String, dynamic>{};
        final state = Map<String, dynamic>.from(data['state'] as Map? ?? {});
        final participants = Map<String, dynamic>.from(
          state['participants'] as Map? ?? <String, dynamic>{},
        );
        participants[participantId] = participant;
        state['participants'] = participants;
        transaction.update(roomRef, <String, dynamic>{
          'state': state,
          'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        });
      });
      return RealtimeResult.ok('Teilnehmer synchronisiert.');
    } on StateError {
      return RealtimeResult.fail('Raum wurde nicht gefunden.');
    } catch (_) {
      return RealtimeResult.fail(
        'Teilnehmer konnte nicht synchronisiert werden.',
      );
    }
  }

  @override
  Future<RealtimeResult> updateRoomState({
    required String code,
    required Map<String, dynamic> roomState,
  }) async {
    try {
      await _rooms.doc(code).update(<String, dynamic>{
        'state': roomState,
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      });
      return RealtimeResult.ok('Raum aktualisiert.');
    } catch (_) {
      return RealtimeResult.fail('Room-Update fehlgeschlagen.');
    }
  }

  @override
  Future<RealtimeResult> enqueueCommand({
    required String code,
    required RealtimeCommandType type,
    required String userId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await _commands(code).add(<String, dynamic>{
        'type': type.name,
        'userId': userId,
        'payload': payload,
        'createdAtMs': DateTime.now().millisecondsSinceEpoch,
        'processed': false,
      });
      return RealtimeResult.ok('Command gesendet.');
    } catch (_) {
      return RealtimeResult.fail('Command konnte nicht gesendet werden.');
    }
  }

  @override
  Stream<List<RealtimeCommand>> watchPendingCommands(String code) {
    return _commands(code)
        .where('processed', isEqualTo: false)
        .orderBy('createdAtMs')
        .snapshots()
        .map((snapshot) {
          final commands = <RealtimeCommand>[];
          for (final document in snapshot.docs) {
            final parsed = RealtimeCommand.fromSnapshot(document);
            if (parsed != null && !parsed.processed) {
              commands.add(parsed);
            }
          }
          return commands;
        });
  }

  @override
  Future<void> markCommandProcessed({
    required String code,
    required String commandId,
    required bool success,
    required String message,
  }) async {
    await _commands(code).doc(commandId).update(<String, dynamic>{
      'processed': true,
      'processedAtMs': DateTime.now().millisecondsSinceEpoch,
      'resultSuccess': success,
      'resultMessage': message,
    });
  }
}
