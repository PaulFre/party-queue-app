import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/realtime_sync.dart';

class InMemoryRealtimeSync implements PartyRealtimeSyncApi {
  final Map<String, Map<String, dynamic>> _roomStateByCode =
      <String, Map<String, dynamic>>{};
  final Map<String, StreamController<Map<String, dynamic>?>> _roomControllers =
      <String, StreamController<Map<String, dynamic>?>>{};
  final Map<String, List<RealtimeCommand>> _commandsByCode =
      <String, List<RealtimeCommand>>{};
  final Map<String, Map<String, Object?>> _commandResultsById =
      <String, Map<String, Object?>>{};
  final Map<String, StreamController<List<RealtimeCommand>>> _commandControllers =
      <String, StreamController<List<RealtimeCommand>>>{};
  int _commandCounter = 0;
  int _authCounter = 0;

  void dispose() {
    for (final controller in _roomControllers.values) {
      controller.close();
    }
    for (final controller in _commandControllers.values) {
      controller.close();
    }
  }

  @override
  Future<RealtimeResult> ensureSignedInAnonymously() async {
    return RealtimeResult.ok(
      'In-memory auth ok.',
      userId: 'test_user_${++_authCounter}',
    );
  }

  @override
  Future<RealtimeResult> createRoomState({
    required String code,
    required String hostUserId,
    required Map<String, dynamic> roomState,
  }) async {
    if (_roomStateByCode.containsKey(code)) {
      return RealtimeResult.fail('Room-Code bereits vergeben.');
    }
    _roomStateByCode[code] = _cloneMap(roomState);
    _emitRoomState(code);
    return RealtimeResult.ok('Realtime room erstellt.');
  }

  @override
  Future<Map<String, dynamic>?> fetchRoomState(String code) async {
    final state = _roomStateByCode[code];
    if (state == null) {
      return null;
    }
    return _cloneMap(state);
  }

  @override
  Future<List<PublicRoomSearchHit>> searchPublicRoomsByName(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const <PublicRoomSearchHit>[];
    }
    final exact = <PublicRoomSearchHit>[];
    final partial = <PublicRoomSearchHit>[];
    _roomStateByCode.forEach((code, state) {
      final roomName = (state['roomName'] ?? '').toString().trim();
      if (roomName.isEmpty) {
        return;
      }
      if ((state['isPublic'] ?? false) != true) {
        return;
      }
      if ((state['ended'] ?? false) == true) {
        return;
      }
      final roomNameLower = (state['roomNameLower'] ?? roomName).toString().toLowerCase();
      final hit = PublicRoomSearchHit(code: code, roomName: roomName);
      if (roomNameLower == normalized) {
        exact.add(hit);
      } else if (roomNameLower.contains(normalized)) {
        partial.add(hit);
      }
    });
    return <PublicRoomSearchHit>[...exact, ...partial];
  }

  @override
  Stream<Map<String, dynamic>?> watchRoomState(String code) {
    final controller = _roomController(code);
    return Stream<Map<String, dynamic>?>.multi((multi) {
      final subscription = controller.stream.listen(
        multi.add,
        onError: multi.addError,
      );
      final current = _roomStateByCode[code];
      multi.add(current == null ? null : _cloneMap(current));
      multi.onCancel = () => subscription.cancel();
    });
  }

  @override
  Future<RealtimeResult> upsertParticipant({
    required String code,
    required String participantId,
    required Map<String, dynamic> participant,
  }) async {
    final state = _roomStateByCode[code];
    if (state == null) {
      return RealtimeResult.fail('Raum wurde nicht gefunden.');
    }
    final participants = Map<String, dynamic>.from(
      state['participants'] as Map? ?? <String, dynamic>{},
    );
    participants[participantId] = _cloneMap(participant);
    state['participants'] = participants;
    _emitRoomState(code);
    return RealtimeResult.ok('Teilnehmer synchronisiert.');
  }

  @override
  Future<RealtimeResult> updateRoomState({
    required String code,
    required Map<String, dynamic> roomState,
  }) async {
    if (!_roomStateByCode.containsKey(code)) {
      return RealtimeResult.fail('Room-Update fehlgeschlagen.');
    }
    _roomStateByCode[code] = _cloneMap(roomState);
    _emitRoomState(code);
    return RealtimeResult.ok('Raum aktualisiert.');
  }

  @override
  Future<RealtimeResult> enqueueCommand({
    required String code,
    required RealtimeCommandType type,
    required String userId,
    required Map<String, dynamic> payload,
  }) async {
    if (!_roomStateByCode.containsKey(code)) {
      return RealtimeResult.fail('Command konnte nicht gesendet werden.');
    }
    final command = RealtimeCommand(
      id: 'cmd_${++_commandCounter}',
      type: type,
      userId: userId,
      payload: _cloneMap(payload),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      processed: false,
    );
    _commandsByCode.putIfAbsent(code, () => <RealtimeCommand>[]).add(command);
    _emitPendingCommands(code);
    return RealtimeResult.ok('Command gesendet.');
  }

  Future<RealtimeCommand> injectPendingCommand({
    required String code,
    required RealtimeCommandType type,
    required String userId,
    required Map<String, dynamic> payload,
    int? createdAtMs,
    String? commandId,
  }) async {
    if (!_roomStateByCode.containsKey(code)) {
      throw StateError('Room not found: $code');
    }
    final command = RealtimeCommand(
      id: commandId ?? 'injected_${++_commandCounter}',
      type: type,
      userId: userId,
      payload: _cloneMap(payload),
      createdAtMs: createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
      processed: false,
    );
    _commandsByCode.putIfAbsent(code, () => <RealtimeCommand>[]).add(command);
    _emitPendingCommands(code);
    return command;
  }

  List<RealtimeCommand> commandsForRoom(String code) {
    return List<RealtimeCommand>.unmodifiable(
      _commandsByCode[code] ?? const <RealtimeCommand>[],
    );
  }

  Map<String, Object?>? commandResultFor(String commandId) {
    final result = _commandResultsById[commandId];
    if (result == null) {
      return null;
    }
    return Map<String, Object?>.from(result);
  }

  @override
  Stream<List<RealtimeCommand>> watchPendingCommands(String code) {
    final controller = _commandController(code);
    return Stream<List<RealtimeCommand>>.multi((multi) {
      final subscription = controller.stream.listen(
        multi.add,
        onError: multi.addError,
      );
      multi.add(_pendingCommands(code));
      multi.onCancel = () => subscription.cancel();
    });
  }

  @override
  Future<void> markCommandProcessed({
    required String code,
    required String commandId,
    required bool success,
    required String message,
  }) async {
    _commandResultsById[commandId] = <String, Object?>{
      'success': success,
      'message': message,
    };
    final commands = _commandsByCode[code];
    if (commands == null) {
      return;
    }
    final index = commands.indexWhere((command) => command.id == commandId);
    if (index == -1) {
      return;
    }
    final current = commands[index];
    commands[index] = RealtimeCommand(
      id: current.id,
      type: current.type,
      userId: current.userId,
      payload: current.payload,
      createdAtMs: current.createdAtMs,
      processed: true,
    );
    _emitPendingCommands(code);
  }

  StreamController<Map<String, dynamic>?> _roomController(String code) {
    return _roomControllers.putIfAbsent(
      code,
      () => StreamController<Map<String, dynamic>?>.broadcast(),
    );
  }

  StreamController<List<RealtimeCommand>> _commandController(String code) {
    return _commandControllers.putIfAbsent(
      code,
      () => StreamController<List<RealtimeCommand>>.broadcast(),
    );
  }

  void _emitRoomState(String code) {
    final state = _roomStateByCode[code];
    if (state == null) {
      return;
    }
    _roomController(code).add(_cloneMap(state));
  }

  void _emitPendingCommands(String code) {
    _commandController(code).add(_pendingCommands(code));
  }

  List<RealtimeCommand> _pendingCommands(String code) {
    final commands = _commandsByCode[code] ?? const <RealtimeCommand>[];
    final pending = commands.where((command) => !command.processed).toList(growable: false);
    pending.sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    return pending;
  }

  Map<String, dynamic> _cloneMap(Map<String, dynamic> source) {
    return Map<String, dynamic>.from(
      jsonDecode(jsonEncode(source)) as Map<String, dynamic>,
    );
  }
}

Future<void> waitForCondition(
  bool Function() condition, {
  required String label,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      fail('Timeout while waiting for: $label');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
