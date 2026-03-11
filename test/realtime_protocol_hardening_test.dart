import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/party_codec.dart';
import 'package:party_queue_app/src/party_engine.dart';
import 'package:party_queue_app/src/realtime_sync.dart';

import 'support/in_memory_realtime_sync.dart';

Future<({
  PartyEngine host,
  PartyEngine guest,
  InMemoryRealtimeSync sync,
  String roomCode,
  String guestUserId,
})> _bootstrapRealtimeSession() async {
  final sync = InMemoryRealtimeSync();
  final host = PartyEngine(realtimeSync: sync);
  final guest = PartyEngine(realtimeSync: sync);

  final created = await host.createRoomRealtime(
    hostName: 'Host',
    hostAvatar: 'A',
    spotifyConnected: true,
    roomName: 'Protocol Party',
    roomPassword: '1234',
    inviteOnly: true,
    initialSettings: const RoomSettings(),
  );
  expect(created.success, isTrue);
  final roomCode = host.currentRoom!.code;

  final verified = await guest.verifyJoinAccessRealtime(
    joinInput: roomCode,
    roomPassword: '1234',
  );
  expect(verified.success, isTrue);

  final joined = await guest.joinRoomRealtime(
    guestName: 'Guest',
    guestAvatar: 'B',
    joinInput: roomCode,
    roomPassword: '1234',
  );
  expect(joined.success, isTrue);
  final guestUserId = guest.currentUser!.id;

  await waitForCondition(
    () => host.currentRoom!.participants.containsKey(guestUserId),
    label: 'host receives guest participant',
  );

  return (
    host: host,
    guest: guest,
    sync: sync,
    roomCode: roomCode,
    guestUserId: guestUserId,
  );
}

void main() {
  test('rejects malformed realtime command payload with explicit error code', () async {
    final ctx = await _bootstrapRealtimeSession();
    addTearDown(ctx.host.dispose);
    addTearDown(ctx.guest.dispose);
    addTearDown(ctx.sync.dispose);

    final malformed = await ctx.sync.injectPendingCommand(
      code: ctx.roomCode,
      type: RealtimeCommandType.voteSong,
      userId: ctx.guestUserId,
      payload: <String, dynamic>{
        'queueItemId': '',
        'vote': 'super_like',
        'unexpected': true,
      },
    );

    await waitForCondition(
      () => ctx.sync
          .commandsForRoom(ctx.roomCode)
          .any((command) => command.id == malformed.id && command.processed),
      label: 'malformed command processed',
    );

    final result = ctx.sync.commandResultFor(malformed.id);
    expect(result?['success'], isFalse);
    final telemetryCodes = ctx.host.recentTelemetry
        .map((event) => event.code)
        .toList(growable: false);
    expect(telemetryCodes, contains(PartyErrorCode.realtimeCommandInvalid));
  });

  test('rejects stale realtime command as replay-like event', () async {
    final ctx = await _bootstrapRealtimeSession();
    addTearDown(ctx.host.dispose);
    addTearDown(ctx.guest.dispose);
    addTearDown(ctx.sync.dispose);

    final song = ctx.guest.trendingSongs.first;
    final staleCommand = await ctx.sync.injectPendingCommand(
      code: ctx.roomCode,
      type: RealtimeCommandType.addSong,
      userId: ctx.guestUserId,
      createdAtMs: DateTime.now()
          .subtract(const Duration(hours: 2))
          .millisecondsSinceEpoch,
      payload: <String, dynamic>{
        'song': encodeSong(song),
        'actorName': 'Guest',
        'actorAvatar': 'B',
      },
    );

    await waitForCondition(
      () => ctx.sync
          .commandsForRoom(ctx.roomCode)
          .any((command) => command.id == staleCommand.id && command.processed),
      label: 'stale command processed',
    );

    final result = ctx.sync.commandResultFor(staleCommand.id);
    expect(result?['success'], isFalse);
    final telemetryCodes = ctx.host.recentTelemetry
        .map((event) => event.code)
        .toList(growable: false);
    expect(telemetryCodes, contains(PartyErrorCode.realtimeCommandReplay));
  });
}
