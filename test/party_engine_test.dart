import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/party_engine.dart';

void main() {
  test('vote toggles and keeps one vote per user', () {
    final engine = PartyEngine();
    addTearDown(engine.dispose);

    final create = engine.createRoom(
      hostName: 'Host',
      hostAvatar: 'A',
      spotifyConnected: true,
      roomName: 'Testparty',
      roomPassword: '1234',
      inviteOnly: true,
      initialSettings: const RoomSettings(),
    );
    expect(create.success, isTrue);

    final songs = engine.trendingSongs.take(2).toList(growable: false);
    expect(engine.addSong(songs[0]).success, isTrue);
    expect(engine.addSong(songs[1]).success, isTrue);

    final queued = engine.orderedQueue.first;
    expect(
      engine.voteOnSong(queueItemId: queued.id, vote: VoteType.like).success,
      isTrue,
    );
    expect(queued.likes, 1);
    expect(queued.dislikes, 0);

    expect(
      engine.voteOnSong(queueItemId: queued.id, vote: VoteType.like).success,
      isTrue,
    );
    expect(queued.likes, 0);
    expect(queued.dislikes, 0);
  });

  test('duplicate prevention and cooldown work', () {
    final engine = PartyEngine();
    addTearDown(engine.dispose);

    engine.createRoom(
      hostName: 'Host',
      hostAvatar: 'A',
      spotifyConnected: true,
      roomName: 'Testparty',
      roomPassword: '1234',
      inviteOnly: true,
      initialSettings: const RoomSettings(),
    );
    final song = engine.trendingSongs.first;

    expect(engine.addSong(song).success, isTrue);
    expect(engine.addSong(song).success, isFalse);

    expect(engine.skipNowPlaying().success, isTrue);
    expect(engine.addSong(song).success, isFalse);

    final room = engine.currentRoom!;
    room.cooldownUntilBySongId[song.id] = DateTime.now().subtract(
      const Duration(minutes: 1),
    );
    expect(engine.addSong(song).success, isTrue);
  });

  test('suggestions mode stores guest songs as suggestions', () {
    final engine = PartyEngine();
    addTearDown(engine.dispose);

    engine.createRoom(
      hostName: 'Host',
      hostAvatar: 'A',
      spotifyConnected: true,
      roomName: 'Vorschlagsparty',
      roomPassword: '1234',
      inviteOnly: true,
      initialSettings: const RoomSettings(mode: RoomMode.suggestionsOnly),
    );

    final roomCode = engine.currentRoom!.code;
    final joined = engine.joinRoom(
      guestName: 'Guest',
      guestAvatar: 'B',
      joinInput: roomCode,
      roomPassword: '1234',
    );
    expect(joined.success, isTrue);

    final song = engine.trendingSongs.first;
    expect(engine.addSong(song).success, isTrue);
    expect(engine.currentRoom!.suggestions.length, 1);
    expect(engine.currentRoom!.queue.length, 0);
  });

  test('debug guest test access joins without room code and password', () {
    final engine = PartyEngine();
    addTearDown(engine.dispose);

    final join = engine.joinAsGuestForTesting(guestName: '', guestAvatar: 'B');
    expect(join.success, isTrue);
    expect(engine.currentRoom, isNotNull);
    expect(engine.currentUser?.role, PartyRole.guest);
    expect(engine.currentUser?.name, 'Gast');
    expect(engine.currentRoom!.roomPassword, isEmpty);
    expect(engine.currentRoom!.participants.length, 2);
  });

  test('empty join input uses single active local room', () {
    final engine = PartyEngine();
    addTearDown(engine.dispose);

    final create = engine.createRoom(
      hostName: 'Host',
      hostAvatar: 'A',
      spotifyConnected: true,
      roomName: 'Solo Party',
      roomPassword: '1234',
      inviteOnly: true,
      initialSettings: const RoomSettings(),
    );
    expect(create.success, isTrue);

    final verify = engine.verifyJoinAccess(joinInput: '', roomPassword: '1234');
    expect(verify.success, isTrue);

    final join = engine.joinRoom(
      guestName: 'Gast',
      guestAvatar: 'B',
      joinInput: '',
      roomPassword: '1234',
    );
    expect(join.success, isTrue);
    expect(engine.currentUser?.role, PartyRole.guest);
  });

  test('empty join input fails when multiple active local rooms exist', () {
    final engine = PartyEngine();
    addTearDown(engine.dispose);

    final first = engine.createRoom(
      hostName: 'Host One',
      hostAvatar: 'A',
      spotifyConnected: true,
      roomName: 'Party One',
      roomPassword: '1234',
      inviteOnly: true,
      initialSettings: const RoomSettings(),
    );
    expect(first.success, isTrue);

    final second = engine.createRoom(
      hostName: 'Host Two',
      hostAvatar: 'A',
      spotifyConnected: true,
      roomName: 'Party Two',
      roomPassword: '1234',
      inviteOnly: true,
      initialSettings: const RoomSettings(),
    );
    expect(second.success, isTrue);

    final verify = engine.verifyJoinAccess(joinInput: '', roomPassword: '1234');
    expect(verify.success, isFalse);
    expect(verify.message, contains('Mehrere lokale Raeume'));
  });
}
