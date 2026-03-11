part of 'party_engine.dart';

class PartyErrorCode {
  static const String ok = 'ok';
  static const String unknown = 'error_unknown';

  static const String roomPasswordRequired = 'room_password_required';
  static const String roomPasswordInvalid = 'room_password_invalid';
  static const String roomEnded = 'room_ended';
  static const String roomLocked = 'room_locked';
  static const String roomLookupNoActive = 'room_lookup_no_active';
  static const String roomLookupMultipleActive = 'room_lookup_multiple_active';
  static const String roomLookupNotFound = 'room_lookup_not_found';
  static const String roomLookupAmbiguous = 'room_lookup_ambiguous';

  static const String realtimeUnavailable = 'realtime_unavailable';
  static const String realtimeAuthFailed = 'realtime_auth_failed';
  static const String realtimeAuthMissingUserId = 'realtime_auth_missing_user_id';
  static const String realtimeListenerInterrupted = 'realtime_listener_interrupted';
  static const String realtimeCommandListenerInterrupted =
      'realtime_command_listener_interrupted';
  static const String realtimeGuestCommandEnqueueFailed =
      'realtime_guest_command_enqueue_failed';
  static const String realtimeCommandInvalid = 'realtime_command_invalid';
  static const String realtimeCommandReplay = 'realtime_command_replay';
  static const String realtimeCommandActorMissing = 'realtime_command_actor_missing';
  static const String realtimeCommandAckFailed = 'realtime_command_ack_failed';
}

class TelemetryEvent {
  const TelemetryEvent({
    required this.timestamp,
    required this.category,
    required this.action,
    required this.success,
    required this.code,
    required this.message,
    this.role,
    this.roomCode,
    this.metadata = const <String, Object?>{},
  });

  final DateTime timestamp;
  final String category;
  final String action;
  final bool success;
  final String code;
  final String message;
  final String? role;
  final String? roomCode;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'timestamp': timestamp.toIso8601String(),
      'category': category,
      'action': action,
      'success': success,
      'code': code,
      'message': message,
      if (role != null) 'role': role,
      if (roomCode != null) 'roomCode': roomCode,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}

class RealtimeCommandValidationResult {
  const RealtimeCommandValidationResult._({
    required this.isValid,
    this.code,
    this.message,
  });

  const RealtimeCommandValidationResult.valid()
      : this._(isValid: true, code: null, message: null);

  const RealtimeCommandValidationResult.invalid({
    required String code,
    required String message,
  }) : this._(isValid: false, code: code, message: message);

  final bool isValid;
  final String? code;
  final String? message;
}

class RealtimeCommandContract {
  static const Duration staleAfter = Duration(minutes: 30);
  static const Duration futureSkew = Duration(minutes: 1);

  RealtimeCommandValidationResult validateIncomingCommand(
    RealtimeCommand command, {
    required DateTime now,
  }) {
    if (command.id.trim().isEmpty || command.id.length > 120) {
      return const RealtimeCommandValidationResult.invalid(
        code: PartyErrorCode.realtimeCommandInvalid,
        message: 'Command-ID ist ungueltig.',
      );
    }
    if (command.userId.trim().isEmpty || command.userId.length > 128) {
      return const RealtimeCommandValidationResult.invalid(
        code: PartyErrorCode.realtimeCommandInvalid,
        message: 'Command-User ist ungueltig.',
      );
    }
    final createdAt = DateTime.fromMillisecondsSinceEpoch(command.createdAtMs);
    if (createdAt.isAfter(now.add(futureSkew))) {
      return const RealtimeCommandValidationResult.invalid(
        code: PartyErrorCode.realtimeCommandInvalid,
        message: 'Command-Timestamp liegt in der Zukunft.',
      );
    }
    if (now.difference(createdAt) > staleAfter) {
      return const RealtimeCommandValidationResult.invalid(
        code: PartyErrorCode.realtimeCommandReplay,
        message: 'Command ist veraltet und wurde verworfen.',
      );
    }
    return validateOutgoingPayload(command.type, command.payload);
  }

  RealtimeCommandValidationResult validateOutgoingPayload(
    RealtimeCommandType type,
    Map<String, dynamic> payload,
  ) {
    if (payload.length > 12) {
      return const RealtimeCommandValidationResult.invalid(
        code: PartyErrorCode.realtimeCommandInvalid,
        message: 'Command-Payload ist zu gross.',
      );
    }
    switch (type) {
      case RealtimeCommandType.addSong:
        return _validateAddSongPayload(payload);
      case RealtimeCommandType.voteSong:
        return _validateVotePayload(payload);
      case RealtimeCommandType.updateProfile:
        return _validateUpdateProfilePayload(payload);
    }
  }

  RealtimeCommandValidationResult _validateAddSongPayload(
    Map<String, dynamic> payload,
  ) {
    if (!_hasOnlyKeys(payload, const <String>{'song', 'actorName', 'actorAvatar'})) {
      return const RealtimeCommandValidationResult.invalid(
        code: PartyErrorCode.realtimeCommandInvalid,
        message: 'AddSong-Payload enthaelt ungueltige Felder.',
      );
    }
    final song = payload['song'];
    if (song is! Map) {
      return const RealtimeCommandValidationResult.invalid(
        code: PartyErrorCode.realtimeCommandInvalid,
        message: 'Song-Payload fehlt.',
      );
    }
    final songMap = Map<String, dynamic>.from(song);
    final id = songMap['id']?.toString().trim() ?? '';
    final title = songMap['title']?.toString().trim() ?? '';
    final artist = songMap['artist']?.toString().trim() ?? '';
    final rawDuration = songMap['durationMs'];
    final durationMs = rawDuration is num ? rawDuration.toInt() : -1;
    final rawExplicit = songMap['explicit'];
    final rawGenres = songMap['genres'];
    final coverEmoji = songMap['coverEmoji']?.toString() ?? '';

    if (id.isEmpty || id.length > 80) {
      return const RealtimeCommandValidationResult.invalid(
        code: PartyErrorCode.realtimeCommandInvalid,
        message: 'Song-ID ist ungueltig.',
      );
    }
    if (title.isEmpty || title.length > 200 || artist.isEmpty || artist.length > 200) {
      return const RealtimeCommandValidationResult.invalid(
        code: PartyErrorCode.realtimeCommandInvalid,
        message: 'Song-Metadaten sind ungueltig.',
      );
    }
    if (durationMs <= 0 || durationMs > const Duration(minutes: 15).inMilliseconds) {
      return const RealtimeCommandValidationResult.invalid(
        code: PartyErrorCode.realtimeCommandInvalid,
        message: 'Song-Dauer ist ungueltig.',
      );
    }
    if (rawExplicit is! bool) {
      return const RealtimeCommandValidationResult.invalid(
        code: PartyErrorCode.realtimeCommandInvalid,
        message: 'Song-Explicit-Flag ist ungueltig.',
      );
    }
    if (rawGenres is! Iterable || rawGenres.length > 12) {
      return const RealtimeCommandValidationResult.invalid(
        code: PartyErrorCode.realtimeCommandInvalid,
        message: 'Song-Genres sind ungueltig.',
      );
    }
    for (final genre in rawGenres) {
      final genreName = genre.toString().trim();
      if (genreName.isEmpty || genreName.length > 40) {
        return const RealtimeCommandValidationResult.invalid(
          code: PartyErrorCode.realtimeCommandInvalid,
          message: 'Song-Genres enthalten ungueltige Werte.',
        );
      }
    }
    if (coverEmoji.isEmpty || coverEmoji.length > 16) {
      return const RealtimeCommandValidationResult.invalid(
        code: PartyErrorCode.realtimeCommandInvalid,
        message: 'Song-Cover ist ungueltig.',
      );
    }
    if (!_isValidOptionalActor(payload)) {
      return const RealtimeCommandValidationResult.invalid(
        code: PartyErrorCode.realtimeCommandInvalid,
        message: 'Actor-Daten sind ungueltig.',
      );
    }
    return const RealtimeCommandValidationResult.valid();
  }

  RealtimeCommandValidationResult _validateVotePayload(
    Map<String, dynamic> payload,
  ) {
    if (!_hasOnlyKeys(
      payload,
      const <String>{'queueItemId', 'vote', 'actorName', 'actorAvatar'},
    )) {
      return const RealtimeCommandValidationResult.invalid(
        code: PartyErrorCode.realtimeCommandInvalid,
        message: 'Vote-Payload enthaelt ungueltige Felder.',
      );
    }
    final queueItemId = payload['queueItemId']?.toString().trim() ?? '';
    final vote = payload['vote']?.toString().trim() ?? '';
    if (queueItemId.isEmpty || queueItemId.length > 120) {
      return const RealtimeCommandValidationResult.invalid(
        code: PartyErrorCode.realtimeCommandInvalid,
        message: 'Queue-Item-ID ist ungueltig.',
      );
    }
    if (!VoteType.values.any((value) => value.name == vote)) {
      return const RealtimeCommandValidationResult.invalid(
        code: PartyErrorCode.realtimeCommandInvalid,
        message: 'Vote-Typ ist ungueltig.',
      );
    }
    if (!_isValidOptionalActor(payload)) {
      return const RealtimeCommandValidationResult.invalid(
        code: PartyErrorCode.realtimeCommandInvalid,
        message: 'Actor-Daten sind ungueltig.',
      );
    }
    return const RealtimeCommandValidationResult.valid();
  }

  RealtimeCommandValidationResult _validateUpdateProfilePayload(
    Map<String, dynamic> payload,
  ) {
    if (!_hasOnlyKeys(payload, const <String>{'name', 'avatar'})) {
      return const RealtimeCommandValidationResult.invalid(
        code: PartyErrorCode.realtimeCommandInvalid,
        message: 'Profil-Payload enthaelt ungueltige Felder.',
      );
    }
    final name = payload['name']?.toString().trim() ?? '';
    final avatar = payload['avatar']?.toString().trim() ?? '';
    if (name.isEmpty || name.length > 40) {
      return const RealtimeCommandValidationResult.invalid(
        code: PartyErrorCode.realtimeCommandInvalid,
        message: 'Profilname ist ungueltig.',
      );
    }
    if (avatar.isEmpty || avatar.length > 16) {
      return const RealtimeCommandValidationResult.invalid(
        code: PartyErrorCode.realtimeCommandInvalid,
        message: 'Avatar ist ungueltig.',
      );
    }
    return const RealtimeCommandValidationResult.valid();
  }

  bool _isValidOptionalActor(Map<String, dynamic> payload) {
    final actorName = payload['actorName'];
    if (actorName != null) {
      final normalized = actorName.toString().trim();
      if (normalized.isEmpty || normalized.length > 40) {
        return false;
      }
    }
    final actorAvatar = payload['actorAvatar'];
    if (actorAvatar != null) {
      final normalized = actorAvatar.toString().trim();
      if (normalized.isEmpty || normalized.length > 16) {
        return false;
      }
    }
    return true;
  }

  bool _hasOnlyKeys(Map<String, dynamic> payload, Set<String> allowed) {
    return payload.keys.every(allowed.contains);
  }
}

class RealtimeCoordinator {
  RealtimeCoordinator({this.processedRetention = const Duration(hours: 1)});

  final Duration processedRetention;
  final Map<String, DateTime> _inFlight = <String, DateTime>{};
  final Map<String, DateTime> _processed = <String, DateTime>{};

  bool tryStartProcessing({
    required String roomCode,
    required String commandId,
    required DateTime now,
  }) {
    _prune(now);
    final key = '$roomCode::$commandId';
    if (_inFlight.containsKey(key) || _processed.containsKey(key)) {
      return false;
    }
    _inFlight[key] = now;
    return true;
  }

  void finishProcessing({
    required String roomCode,
    required String commandId,
    required DateTime now,
    required bool rememberAsProcessed,
  }) {
    final key = '$roomCode::$commandId';
    _inFlight.remove(key);
    if (rememberAsProcessed) {
      _processed[key] = now;
    }
    _prune(now);
  }

  void reset() {
    _inFlight.clear();
    _processed.clear();
  }

  void _prune(DateTime now) {
    _inFlight.removeWhere(
      (_, startedAt) => now.difference(startedAt) > const Duration(minutes: 5),
    );
    _processed.removeWhere(
      (_, processedAt) => now.difference(processedAt) > processedRetention,
    );
  }
}
