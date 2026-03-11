import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/party_engine.dart';

import 'support/in_memory_realtime_sync.dart';

void main() {
  test(
    'realtime happy path: host create, guest join, guest add song',
    () async {
      final sync = InMemoryRealtimeSync();
      addTearDown(sync.dispose);

      final hostEngine = PartyEngine(realtimeSync: sync);
      final guestEngine = PartyEngine(realtimeSync: sync);
      addTearDown(hostEngine.dispose);
      addTearDown(guestEngine.dispose);

      final created = await hostEngine.createRoomRealtime(
        hostName: 'Host',
        hostAvatar: 'A',
        spotifyConnected: true,
        roomName: 'Realtime Party',
        roomPassword: '1234',
        inviteOnly: true,
        initialSettings: const RoomSettings(),
      );
      expect(created.success, isTrue);
      final roomCode = hostEngine.currentRoom!.code;

      final verified = await guestEngine.verifyJoinAccessRealtime(
        joinInput: roomCode,
        roomPassword: '1234',
      );
      expect(verified.success, isTrue);

      final joined = await guestEngine.joinRoomRealtime(
        guestName: 'Guest',
        guestAvatar: 'B',
        joinInput: roomCode,
        roomPassword: '1234',
      );
      expect(joined.success, isTrue);
      final guestUserId = guestEngine.currentUser!.id;

      await waitForCondition(
        () => hostEngine.currentRoom!.participants.containsKey(guestUserId),
        label: 'host receives guest participant',
      );

      final song = guestEngine.trendingSongs.first;
      final addResult = guestEngine.addSong(song);
      expect(addResult.success, isTrue);

      await waitForCondition(
        () => sync.commandsForRoom(roomCode).isNotEmpty,
        label: 'guest command enqueued',
      );
      await waitForCondition(
        () => sync.commandsForRoom(roomCode).every((command) => command.processed),
        label: 'host processed guest command',
      );

      final commandResults = sync.commandsForRoom(roomCode)
          .map((command) => sync.commandResultFor(command.id))
          .whereType<Map<String, Object?>>()
          .toList(growable: false);
      expect(commandResults.every((result) => result['success'] == true), isTrue);
      final successMessages = commandResults
          .map((result) => (result['message'] ?? '').toString())
          .toList(growable: false);
      expect(successMessages.any((message) => message.contains('Song')), isTrue);
      expect(hostEngine.lastSyncError, isNull);
      expect(guestEngine.lastSyncError, isNull);
    },
  );
}
