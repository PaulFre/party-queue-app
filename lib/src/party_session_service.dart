part of 'party_engine.dart';

class SessionSnapshot {
  const SessionSnapshot({
    required this.roomCode,
    required this.user,
    required this.wasRealtime,
    required this.wasHostAuthority,
  });

  final String roomCode;
  final PartyUser user;
  final bool wasRealtime;
  final bool wasHostAuthority;

  SessionSnapshot copyWith({
    String? roomCode,
    PartyUser? user,
    bool? wasRealtime,
    bool? wasHostAuthority,
  }) {
    return SessionSnapshot(
      roomCode: roomCode ?? this.roomCode,
      user: user ?? this.user,
      wasRealtime: wasRealtime ?? this.wasRealtime,
      wasHostAuthority: wasHostAuthority ?? this.wasHostAuthority,
    );
  }
}

class SessionService {
  SessionSnapshot? _snapshot;

  SessionSnapshot? get snapshot => _snapshot;

  bool hasValidSnapshot(Map<String, PartyRoom> roomsByCode) {
    final current = _snapshot;
    if (current == null) {
      return false;
    }
    return roomsByCode.containsKey(current.roomCode);
  }

  void remember({
    required PartyRoom room,
    required PartyUser user,
    required bool isRealtime,
    required bool isRealtimeHostAuthority,
  }) {
    _snapshot = SessionSnapshot(
      roomCode: room.code,
      user: user,
      wasRealtime: isRealtime,
      wasHostAuthority: isRealtimeHostAuthority,
    );
  }

  void updateRememberedUser(PartyUser updatedUser) {
    final current = _snapshot;
    if (current == null || current.user.id != updatedUser.id) {
      return;
    }
    _snapshot = current.copyWith(user: updatedUser);
  }
}
