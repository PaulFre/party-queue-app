import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'join_input_parser.dart';
import 'party_codec.dart';
import 'realtime_sync.dart';

part 'party_queue_policy.dart';
part 'party_realtime_coordinator.dart';
part 'party_session_service.dart';

enum PartyRole { host, guest }

enum VoteType { like, dislike }

enum QueueSortMode { votesOnly, votesWithAgeBoost }

enum RoomMode { democratic, suggestionsOnly }

enum PlaybackConnectionState { connected, tokenExpired, deviceUnavailable }

class ActionResult {
  const ActionResult({
    required this.success,
    required this.message,
    this.code = PartyErrorCode.unknown,
  });

  final bool success;
  final String message;
  final String code;

  static ActionResult ok(String message, {String code = PartyErrorCode.ok}) =>
      ActionResult(success: true, message: message, code: code);

  static ActionResult fail(
    String message, {
    String code = PartyErrorCode.unknown,
  }) => ActionResult(success: false, message: message, code: code);
}

class AddEligibility {
  const AddEligibility({required this.allowed, required this.reason});

  final bool allowed;
  final String reason;

  static const AddEligibility allowedResult = AddEligibility(
    allowed: true,
    reason: '',
  );

  static AddEligibility denied(String reason) =>
      AddEligibility(allowed: false, reason: reason);
}

class PartyUser {
  const PartyUser({
    required this.id,
    required this.name,
    required this.avatar,
    required this.role,
  });

  final String id;
  final String name;
  final String avatar;
  final PartyRole role;

  PartyUser copyWith({String? name, String? avatar, PartyRole? role}) {
    return PartyUser(
      id: id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      role: role ?? this.role,
    );
  }
}

class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.explicit,
    required this.genres,
    required this.coverEmoji,
  });

  final String id;
  final String title;
  final String artist;
  final Duration duration;
  final bool explicit;
  final Set<String> genres;
  final String coverEmoji;
}

class QueueItem {
  QueueItem({
    required this.id,
    required this.song,
    required this.addedByUserId,
    required this.addedByName,
    required this.addedByAvatar,
    required this.addedAt,
    Map<String, VoteType>? votesByUser,
    this.pinned = false,
    this.pinnedAt,
  }) : votesByUser = votesByUser ?? <String, VoteType>{};

  final String id;
  final Song song;
  final String addedByUserId;
  final String addedByName;
  final String addedByAvatar;
  final DateTime addedAt;
  final Map<String, VoteType> votesByUser;
  bool pinned;
  DateTime? pinnedAt;

  int get likes =>
      votesByUser.values.where((vote) => vote == VoteType.like).length;

  int get dislikes =>
      votesByUser.values.where((vote) => vote == VoteType.dislike).length;

  int get score => likes - dislikes;
}

class RoomSettings {
  const RoomSettings({
    this.sortMode = QueueSortMode.votesOnly,
    this.cooldown = const Duration(minutes: 30),
    this.maxAddsPerWindow = 3,
    this.addWindow = const Duration(minutes: 10),
    this.fairnessMode = true,
    this.mode = RoomMode.democratic,
    this.blockExplicit = false,
    this.excludedGenres = const <String>{},
    this.votesPaused = false,
    this.hostOnlyAdds = false,
    this.lockRoom = false,
    this.freezeWindow = const Duration(seconds: 60),
  });

  final QueueSortMode sortMode;
  final Duration cooldown;
  final int maxAddsPerWindow;
  final Duration addWindow;
  final bool fairnessMode;
  final RoomMode mode;
  final bool blockExplicit;
  final Set<String> excludedGenres;
  final bool votesPaused;
  final bool hostOnlyAdds;
  final bool lockRoom;
  final Duration freezeWindow;

  RoomSettings copyWith({
    QueueSortMode? sortMode,
    Duration? cooldown,
    int? maxAddsPerWindow,
    Duration? addWindow,
    bool? fairnessMode,
    RoomMode? mode,
    bool? blockExplicit,
    Set<String>? excludedGenres,
    bool? votesPaused,
    bool? hostOnlyAdds,
    bool? lockRoom,
    Duration? freezeWindow,
  }) {
    return RoomSettings(
      sortMode: sortMode ?? this.sortMode,
      cooldown: cooldown ?? this.cooldown,
      maxAddsPerWindow: maxAddsPerWindow ?? this.maxAddsPerWindow,
      addWindow: addWindow ?? this.addWindow,
      fairnessMode: fairnessMode ?? this.fairnessMode,
      mode: mode ?? this.mode,
      blockExplicit: blockExplicit ?? this.blockExplicit,
      excludedGenres: excludedGenres ?? this.excludedGenres,
      votesPaused: votesPaused ?? this.votesPaused,
      hostOnlyAdds: hostOnlyAdds ?? this.hostOnlyAdds,
      lockRoom: lockRoom ?? this.lockRoom,
      freezeWindow: freezeWindow ?? this.freezeWindow,
    );
  }
}

class PartyRoom {
  PartyRoom({
    required this.code,
    required this.roomName,
    required this.roomPassword,
    required this.isPublic,
    required this.coreSettingsLocked,
    required this.inviteLink,
    required this.hostUserId,
    required this.createdAt,
    required Map<String, PartyUser> participants,
    this.settings = const RoomSettings(),
    this.connectionState = PlaybackConnectionState.connected,
  }) : participants = Map<String, PartyUser>.from(participants);

  final String code;
  final String roomName;
  final String roomPassword;
  final bool isPublic;
  final bool coreSettingsLocked;
  final String inviteLink;
  final String hostUserId;
  final DateTime createdAt;
  final Map<String, PartyUser> participants;
  RoomSettings settings;
  PlaybackConnectionState connectionState;
  final List<QueueItem> queue = <QueueItem>[];
  final List<QueueItem> suggestions = <QueueItem>[];
  final List<QueueItem> playedHistory = <QueueItem>[];
  final Map<String, DateTime> cooldownUntilBySongId = <String, DateTime>{};
  final Map<String, List<DateTime>> addHistoryByUserId =
      <String, List<DateTime>>{};
  QueueItem? nowPlaying;
  Duration nowPlayingPosition = Duration.zero;
  String? lockedNextSongId;
  String? lastPlayedByUserId;
  bool ended = false;
}

class RoomLookupResult {
  const RoomLookupResult._({
    required this.room,
    required this.resolvedCode,
    this.errorMessage,
    this.errorCode,
  });

  const RoomLookupResult.success({
    required PartyRoom room,
    required String resolvedCode,
  }) : this._(room: room, resolvedCode: resolvedCode);

  const RoomLookupResult.error({
    required String errorMessage,
    required String resolvedCode,
    String? errorCode,
  }) : this._(
         room: null,
         resolvedCode: resolvedCode,
         errorMessage: errorMessage,
         errorCode: errorCode,
       );

  final PartyRoom? room;
  final String resolvedCode;
  final String? errorMessage;
  final String? errorCode;

  bool get isSuccess => room != null && errorMessage == null;
}

class PlaylistExport {
  const PlaylistExport({required this.playlistName, required this.songs});

  final String playlistName;
  final List<Song> songs;
}

class MockSpotifyCatalogService {
  MockSpotifyCatalogService() : _songs = _seedSongs();

  final List<Song> _songs;

  static const List<String> allGenres = <String>[
    'dance',
    'electronic',
    'hiphop',
    'pop',
    'rock',
    'latin',
    'house',
    'indie',
    'afrobeats',
    'techno',
  ];

  List<Song> trending({int limit = 12}) {
    return _songs.take(limit).toList(growable: false);
  }

  List<Song> search(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return trending(limit: 18);
    }
    return _songs
        .where(
          (song) =>
              song.title.toLowerCase().contains(trimmed) ||
              song.artist.toLowerCase().contains(trimmed) ||
              song.genres.any((genre) => genre.contains(trimmed)),
        )
        .take(40)
        .toList(growable: false);
  }

  static List<Song> _seedSongs() {
    Song song({
      required String id,
      required String title,
      required String artist,
      required int minutes,
      required int seconds,
      required bool explicit,
      required Set<String> genres,
      required String cover,
    }) {
      return Song(
        id: id,
        title: title,
        artist: artist,
        duration: Duration(minutes: minutes, seconds: seconds),
        explicit: explicit,
        genres: genres,
        coverEmoji: cover,
      );
    }

    return <Song>[
      song(
        id: 'sp001',
        title: 'Midnight Drive',
        artist: 'Neon Streets',
        minutes: 3,
        seconds: 12,
        explicit: false,
        genres: <String>{'electronic', 'dance'},
        cover: 'N1',
      ),
      song(
        id: 'sp002',
        title: 'Summer Roof',
        artist: 'Sky Highway',
        minutes: 2,
        seconds: 56,
        explicit: false,
        genres: <String>{'pop', 'dance'},
        cover: 'N1',
      ),
      song(
        id: 'sp003',
        title: 'Bassline Fever',
        artist: 'Kilo Volt',
        minutes: 3,
        seconds: 48,
        explicit: false,
        genres: <String>{'house', 'electronic'},
        cover: 'N1',
      ),
      song(
        id: 'sp004',
        title: 'City Pulse',
        artist: 'Metro Unit',
        minutes: 4,
        seconds: 10,
        explicit: false,
        genres: <String>{'techno', 'electronic'},
        cover: 'N1',
      ),
      song(
        id: 'sp005',
        title: 'Golden Hour',
        artist: 'Luna Vale',
        minutes: 3,
        seconds: 4,
        explicit: false,
        genres: <String>{'pop', 'indie'},
        cover: 'N1',
      ),
      song(
        id: 'sp006',
        title: 'No Sleep Tonight',
        artist: 'Afterclub',
        minutes: 3,
        seconds: 33,
        explicit: true,
        genres: <String>{'dance', 'house'},
        cover: 'N1',
      ),
      song(
        id: 'sp007',
        title: 'Fireline',
        artist: 'Riko Blaze',
        minutes: 2,
        seconds: 44,
        explicit: false,
        genres: <String>{'hiphop', 'pop'},
        cover: 'N1',
      ),
      song(
        id: 'sp008',
        title: 'Barrio Lights',
        artist: 'Sol Madre',
        minutes: 3,
        seconds: 18,
        explicit: false,
        genres: <String>{'latin', 'dance'},
        cover: 'N1',
      ),
      song(
        id: 'sp009',
        title: 'Wave Runner',
        artist: 'Coral Kid',
        minutes: 2,
        seconds: 59,
        explicit: false,
        genres: <String>{'indie', 'pop'},
        cover: 'N1',
      ),
      song(
        id: 'sp010',
        title: 'Turn It Louder',
        artist: 'Bricklane',
        minutes: 3,
        seconds: 41,
        explicit: false,
        genres: <String>{'rock', 'dance'},
        cover: 'N1',
      ),
      song(
        id: 'sp011',
        title: 'Afro Motion',
        artist: 'Keta Sound',
        minutes: 3,
        seconds: 39,
        explicit: false,
        genres: <String>{'afrobeats', 'dance'},
        cover: 'N1',
      ),
      song(
        id: 'sp012',
        title: 'Main Stage',
        artist: 'Vortex 99',
        minutes: 4,
        seconds: 2,
        explicit: false,
        genres: <String>{'techno', 'house'},
        cover: 'N1',
      ),
      song(
        id: 'sp013',
        title: 'Hands Up Again',
        artist: 'Party Signal',
        minutes: 3,
        seconds: 14,
        explicit: false,
        genres: <String>{'dance', 'pop'},
        cover: 'N1',
      ),
      song(
        id: 'sp014',
        title: 'Diamond Riddim',
        artist: 'Nova K',
        minutes: 2,
        seconds: 49,
        explicit: true,
        genres: <String>{'hiphop', 'afrobeats'},
        cover: 'N1',
      ),
      song(
        id: 'sp015',
        title: 'Echo de la Noche',
        artist: 'Luna Roja',
        minutes: 3,
        seconds: 23,
        explicit: false,
        genres: <String>{'latin', 'house'},
        cover: 'N1',
      ),
      song(
        id: 'sp016',
        title: 'Night Ferry',
        artist: 'South Harbor',
        minutes: 3,
        seconds: 31,
        explicit: false,
        genres: <String>{'indie', 'electronic'},
        cover: 'N1',
      ),
      song(
        id: 'sp017',
        title: 'Rio Skyline',
        artist: 'Azul Norte',
        minutes: 3,
        seconds: 5,
        explicit: false,
        genres: <String>{'latin', 'pop'},
        cover: 'N1',
      ),
      song(
        id: 'sp018',
        title: 'After Midnight Call',
        artist: 'Static Moon',
        minutes: 2,
        seconds: 57,
        explicit: false,
        genres: <String>{'house', 'dance'},
        cover: 'N1',
      ),
      song(
        id: 'sp019',
        title: 'Chrome Hearts',
        artist: 'Nova June',
        minutes: 3,
        seconds: 26,
        explicit: true,
        genres: <String>{'hiphop', 'pop'},
        cover: 'N1',
      ),
      song(
        id: 'sp020',
        title: 'Sunset Protocol',
        artist: 'Binary Kids',
        minutes: 4,
        seconds: 4,
        explicit: false,
        genres: <String>{'techno', 'electronic'},
        cover: 'N1',
      ),
      song(
        id: 'sp021',
        title: 'Palms and Neon',
        artist: 'Tropical Avenue',
        minutes: 3,
        seconds: 8,
        explicit: false,
        genres: <String>{'afrobeats', 'dance'},
        cover: 'N1',
      ),
      song(
        id: 'sp022',
        title: 'Street Drums',
        artist: 'Kairo One',
        minutes: 3,
        seconds: 11,
        explicit: false,
        genres: <String>{'hiphop', 'afrobeats'},
        cover: 'N1',
      ),
      song(
        id: 'sp023',
        title: 'Satellite Glow',
        artist: 'Eighty Miles',
        minutes: 3,
        seconds: 37,
        explicit: false,
        genres: <String>{'indie', 'pop'},
        cover: 'N1',
      ),
      song(
        id: 'sp024',
        title: 'Dancing Signals',
        artist: 'Metroline',
        minutes: 2,
        seconds: 53,
        explicit: false,
        genres: <String>{'dance', 'electronic'},
        cover: 'N1',
      ),
      song(
        id: 'sp025',
        title: 'Concrete Paradise',
        artist: 'Vault Club',
        minutes: 3,
        seconds: 43,
        explicit: false,
        genres: <String>{'house', 'techno'},
        cover: 'N1',
      ),
      song(
        id: 'sp026',
        title: 'Warm Lights',
        artist: 'Ivy Harbour',
        minutes: 3,
        seconds: 2,
        explicit: false,
        genres: <String>{'indie', 'rock'},
        cover: 'N1',
      ),
      song(
        id: 'sp027',
        title: 'Firework Taxi',
        artist: 'Loud Avenue',
        minutes: 3,
        seconds: 29,
        explicit: false,
        genres: <String>{'rock', 'dance'},
        cover: 'N1',
      ),
      song(
        id: 'sp028',
        title: 'Golden Tropic',
        artist: 'Sol Bay',
        minutes: 3,
        seconds: 15,
        explicit: false,
        genres: <String>{'latin', 'afrobeats'},
        cover: 'N1',
      ),
      song(
        id: 'sp029',
        title: 'Backseat Frequency',
        artist: 'Delta Bloom',
        minutes: 2,
        seconds: 58,
        explicit: false,
        genres: <String>{'electronic', 'pop'},
        cover: 'N1',
      ),
      song(
        id: 'sp030',
        title: 'Night Garden',
        artist: 'Echo Vale',
        minutes: 3,
        seconds: 34,
        explicit: false,
        genres: <String>{'house', 'indie'},
        cover: 'N1',
      ),
    ];
  }
}

class PartyEngine extends ChangeNotifier {
  PartyEngine({
    MockSpotifyCatalogService? catalog,
    PartyRealtimeSyncApi? realtimeSync,
    bool verboseTelemetryLogs = false,
  }) : _catalog = catalog ?? MockSpotifyCatalogService(),
       _realtimeSync = realtimeSync,
       _verboseTelemetryLogs = verboseTelemetryLogs {
    _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  final MockSpotifyCatalogService _catalog;
  final PartyRealtimeSyncApi? _realtimeSync;
  final bool _verboseTelemetryLogs;
  final QueuePolicyService _queuePolicy = QueuePolicyService();
  final SessionService _sessionService = SessionService();
  final RealtimeCoordinator _realtimeCoordinator = RealtimeCoordinator();
  final RealtimeCommandContract _commandContract = RealtimeCommandContract();
  final List<TelemetryEvent> _telemetryEvents = <TelemetryEvent>[];
  final Map<String, PartyRoom> _roomsByCode = <String, PartyRoom>{};
  final Uuid _uuid = const Uuid();
  final Random _random = Random();
  Timer? _ticker;
  StreamSubscription<Map<String, dynamic>?>? _roomRealtimeSubscription;
  StreamSubscription<List<RealtimeCommand>>? _commandSubscription;

  PartyRoom? _currentRoom;
  PartyUser? _currentUser;
  bool _isRealtimeSession = false;
  bool _isRealtimeHostAuthority = false;
  bool _isApplyingRemoteState = false;
  bool _isHandlingRemoteCommand = false;
  bool _isPublishingState = false;
  bool _queuedStatePublish = false;
  String? _lastSyncError;

  PartyRoom? get currentRoom => _currentRoom;
  PartyUser? get currentUser => _currentUser;
  bool get realtimeAvailable => _realtimeSync != null;
  bool get isRealtimeSession => _isRealtimeSession;
  String? get lastSyncError => _lastSyncError;
  List<TelemetryEvent> get recentTelemetry =>
      List<TelemetryEvent>.unmodifiable(_telemetryEvents);

  bool get isHost =>
      _currentRoom != null &&
      _currentUser != null &&
      _currentRoom!.hostUserId == _currentUser!.id;

  bool get _isRealtimeGuest =>
      _isRealtimeSession &&
      !_isRealtimeHostAuthority &&
      !_isHandlingRemoteCommand;

  bool get canSmartRejoin =>
      _sessionService.hasValidSnapshot(_roomsByCode);

  List<String> get availableGenres => MockSpotifyCatalogService.allGenres;

  List<QueueItem> get orderedQueue {
    final room = _currentRoom;
    if (room == null) {
      return const <QueueItem>[];
    }
    return List<QueueItem>.unmodifiable(_queuePolicy.orderedQueue(room));
  }

  List<QueueItem> get topVoted {
    final room = _currentRoom;
    if (room == null) {
      return const <QueueItem>[];
    }
    final top = List<QueueItem>.from(room.queue);
    top.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return a.addedAt.compareTo(b.addedAt);
    });
    return top.take(3).toList(growable: false);
  }

  QueueItem? get nextSong {
    final queue = orderedQueue;
    if (queue.isEmpty) {
      return null;
    }
    return queue.first;
  }

  Duration get nowPlayingRemaining {
    final room = _currentRoom;
    if (room == null || room.nowPlaying == null) {
      return Duration.zero;
    }
    final remaining = room.nowPlaying!.song.duration - room.nowPlayingPosition;
    if (remaining.isNegative) {
      return Duration.zero;
    }
    return remaining;
  }

  List<PartyUser> get participants {
    final room = _currentRoom;
    if (room == null) {
      return const <PartyUser>[];
    }
    final list = room.participants.values.toList();
    list.sort((a, b) {
      if (a.id == room.hostUserId) {
        return -1;
      }
      if (b.id == room.hostUserId) {
        return 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  List<Song> get trendingSongs =>
      _filterSongsForCurrentRoom(_catalog.trending());

  List<Song> recommendedSongsForCurrentQueue({int limit = 5}) {
    final safeLimit = limit.clamp(1, 20).toInt();
    final room = _currentRoom;
    final candidates = _filterSongsForCurrentRoom(_catalog.trending(limit: 60));
    if (room == null) {
      return candidates.take(safeLimit).toList(growable: false);
    }

    final genreWeights = <String, int>{};
    final topTen = orderedQueue.take(10).toList(growable: false);
    for (final item in topTen) {
      for (final genre in item.song.genres) {
        genreWeights.update(genre, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    final blockedSongIds = <String>{
      if (room.nowPlaying != null) room.nowPlaying!.song.id,
      ...room.queue.map((item) => item.song.id),
      ...room.suggestions.map((item) => item.song.id),
    };

    final scored = candidates
        .where((song) => !blockedSongIds.contains(song.id))
        .map((song) {
          var score = 0;
          for (final genre in song.genres) {
            score += genreWeights[genre] ?? 0;
          }
          return (song: song, score: score);
        })
        .toList(growable: false);

    scored.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      if (a.song.explicit != b.song.explicit) {
        return a.song.explicit ? 1 : -1;
      }
      return a.song.title.toLowerCase().compareTo(b.song.title.toLowerCase());
    });

    final recommended = <Song>[];
    final selectedIds = <String>{};
    for (final entry in scored) {
      if (recommended.length >= safeLimit) {
        break;
      }
      recommended.add(entry.song);
      selectedIds.add(entry.song.id);
    }

    if (recommended.length < safeLimit) {
      final fallback = _filterSongsForCurrentRoom(_catalog.search(''));
      for (final song in fallback) {
        if (recommended.length >= safeLimit) {
          break;
        }
        if (blockedSongIds.contains(song.id) || selectedIds.contains(song.id)) {
          continue;
        }
        recommended.add(song);
        selectedIds.add(song.id);
      }
    }

    return recommended.toList(growable: false);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _roomRealtimeSubscription?.cancel();
    _commandSubscription?.cancel();
    super.dispose();
  }

  ActionResult createRoom({
    required String hostName,
    required String hostAvatar,
    required bool spotifyConnected,
    required String roomName,
    required String roomPassword,
    required bool inviteOnly,
    required RoomSettings initialSettings,
    String? hostUserId,
  }) {
    _detachRealtimeSession();
    ActionResult result;
    if (!spotifyConnected) {
      result = ActionResult.fail(
        'Host muss zuerst Spotify Premium verbinden, bevor ein Raum erstellt wird.',
        code: 'host_spotify_required',
      );
      _logTelemetry(
        category: 'host',
        action: 'create_room',
        result: result,
      );
      return result;
    }
    final safeName = hostName.trim().isEmpty ? 'Host' : hostName.trim();
    final safeRoomName = roomName.trim();
    if (safeRoomName.isEmpty) {
      result = ActionResult.fail(
        'Bitte gib einen Raumnamen ein.',
        code: 'room_name_required',
      );
      _logTelemetry(
        category: 'host',
        action: 'create_room',
        result: result,
      );
      return result;
    }
    final safeRoomPassword = roomPassword.trim();
    if (safeRoomPassword.length < 4) {
      result = ActionResult.fail(
        'Bitte gib ein Raumpasswort mit mindestens 4 Zeichen ein.',
        code: 'room_password_too_short',
      );
      _logTelemetry(
        category: 'host',
        action: 'create_room',
        result: result,
      );
      return result;
    }
    final host = PartyUser(
      id: hostUserId ?? _uuid.v4(),
      name: safeName,
      avatar: hostAvatar,
      role: PartyRole.host,
    );
    final roomCode = _generateRoomCode();
    final room = PartyRoom(
      code: roomCode,
      roomName: safeRoomName,
      roomPassword: safeRoomPassword,
      isPublic: !inviteOnly,
      coreSettingsLocked: true,
      inviteLink: 'https://partyqueue.app/join/$roomCode',
      hostUserId: host.id,
      createdAt: DateTime.now(),
      participants: <String, PartyUser>{host.id: host},
      settings: initialSettings,
      connectionState: PlaybackConnectionState.connected,
    );
    _roomsByCode[roomCode] = room;
    _currentRoom = room;
    _currentUser = host;
    _rememberSession(room: room, user: host);
    _emitStateChanged();
    result = ActionResult.ok(
      'Party "$safeRoomName" ($roomCode) wurde erstellt.',
      code: 'host_room_created',
    );
    _logTelemetry(
      category: 'host',
      action: 'create_room',
      result: result,
      role: PartyRole.host,
      room: room,
    );
    return result;
  }

  Future<ActionResult> createRoomRealtime({
    required String hostName,
    required String hostAvatar,
    required bool spotifyConnected,
    required String roomName,
    required String roomPassword,
    required bool inviteOnly,
    required RoomSettings initialSettings,
  }) async {
    final realtimeSync = _realtimeSync;
    if (realtimeSync == null) {
      final result = ActionResult.fail(
        'Firebase Realtime ist nicht verfuegbar. Bitte lokal hosten oder Firebase konfigurieren.',
        code: PartyErrorCode.realtimeUnavailable,
      );
      _logTelemetry(
        category: 'realtime',
        action: 'host_create_room',
        result: result,
        role: PartyRole.host,
      );
      return result;
    }
    final authResult = await realtimeSync.ensureSignedInAnonymously();
    if (!authResult.success) {
      final result = ActionResult.fail(
        authResult.message,
        code: PartyErrorCode.realtimeAuthFailed,
      );
      _logTelemetry(
        category: 'realtime',
        action: 'host_create_room',
        result: result,
        role: PartyRole.host,
      );
      return result;
    }
    final authUserId = authResult.userId;
    if (authUserId == null || authUserId.isEmpty) {
      final result = ActionResult.fail(
        'Realtime Auth-ID konnte nicht bestimmt werden.',
        code: PartyErrorCode.realtimeAuthMissingUserId,
      );
      _logTelemetry(
        category: 'realtime',
        action: 'host_create_room',
        result: result,
        role: PartyRole.host,
      );
      return result;
    }
    final localResult = createRoom(
      hostName: hostName,
      hostAvatar: hostAvatar,
      spotifyConnected: spotifyConnected,
      roomName: roomName,
      roomPassword: roomPassword,
      inviteOnly: inviteOnly,
      initialSettings: initialSettings,
      hostUserId: authUserId,
    );
    if (!localResult.success) {
      return localResult;
    }
    final room = _currentRoom!;
    final createResult = await realtimeSync.createRoomState(
      code: room.code,
      hostUserId: room.hostUserId,
      roomState: encodePartyRoom(room),
    );
    if (!createResult.success) {
      final result = ActionResult.fail(
        createResult.message,
        code: 'realtime_room_create_failed',
      );
      _logTelemetry(
        category: 'realtime',
        action: 'host_create_room',
        result: result,
        role: PartyRole.host,
        room: room,
      );
      return result;
    }
    _isRealtimeSession = true;
    _isRealtimeHostAuthority = true;
    _rememberSession(room: room, user: _currentUser!);
    await _attachRealtimeRoomSubscription(room.code);
    _attachHostCommandListener(room.code);
    final result = ActionResult.ok(
      '${localResult.message} Realtime-Sync aktiv.',
      code: 'realtime_room_created',
    );
    _logTelemetry(
      category: 'realtime',
      action: 'host_create_room',
      result: result,
      role: PartyRole.host,
      room: room,
    );
    return result;
  }

  ActionResult joinAsGuestForTesting({
    required String guestName,
    required String guestAvatar,
  }) {
    if (!kDebugMode) {
      return ActionResult.fail(
        'Gast-Testzugang ist nur im Debug-Modus verfuegbar.',
      );
    }
    _detachRealtimeSession();
    final safeName = guestName.trim().isEmpty ? 'Gast' : guestName.trim();
    final host = PartyUser(
      id: _uuid.v4(),
      name: 'Test Host',
      avatar: 'A',
      role: PartyRole.host,
    );
    final guest = PartyUser(
      id: _uuid.v4(),
      name: safeName,
      avatar: guestAvatar,
      role: PartyRole.guest,
    );
    final roomCode = _generateRoomCode();
    final room = PartyRoom(
      code: roomCode,
      roomName: 'Gast-Testparty',
      roomPassword: '',
      isPublic: false,
      coreSettingsLocked: true,
      inviteLink: 'https://partyqueue.app/join/$roomCode',
      hostUserId: host.id,
      createdAt: DateTime.now(),
      participants: <String, PartyUser>{host.id: host, guest.id: guest},
      settings: const RoomSettings(),
      connectionState: PlaybackConnectionState.connected,
    );
    _roomsByCode[roomCode] = room;
    _currentRoom = room;
    _currentUser = guest;
    _rememberSession(room: room, user: guest);
    _emitStateChanged();
    return ActionResult.ok(
      'Gast-Testzugang aktiv: Du bist der Party ${room.roomName} ($roomCode) beigetreten.',
    );
  }

  ActionResult verifyJoinAccess({
    required String joinInput,
    required String roomPassword,
  }) {
    final lookup = _lookupLocalJoinRoom(joinInput);
    if (!lookup.isSuccess) {
      final result = ActionResult.fail(
        lookup.errorMessage!,
        code: lookup.errorCode ?? PartyErrorCode.roomLookupNotFound,
      );
      _logTelemetry(
        category: 'guest',
        action: 'verify_join_access_local',
        result: result,
        role: PartyRole.guest,
      );
      return result;
    }
    final room = lookup.room!;
    final accessResult = _validateJoinAccess(
      room: room,
      roomPassword: roomPassword,
    );
    if (!accessResult.success) {
      _logTelemetry(
        category: 'guest',
        action: 'verify_join_access_local',
        result: accessResult,
        role: PartyRole.guest,
        room: room,
      );
      return accessResult;
    }
    final result = ActionResult.ok(
      'Raum ${room.roomName} (${lookup.resolvedCode}) gefunden. Jetzt Name und Avatar waehlen.',
      code: 'join_access_verified',
    );
    _logTelemetry(
      category: 'guest',
      action: 'verify_join_access_local',
      result: result,
      role: PartyRole.guest,
      room: room,
    );
    return result;
  }

  Future<ActionResult> verifyJoinAccessRealtime({
    required String joinInput,
    required String roomPassword,
  }) async {
    final realtimeSync = _realtimeSync;
    if (realtimeSync == null) {
      final result = ActionResult.fail(
        'Firebase Realtime ist nicht verfuegbar. Bitte lokal beitreten oder Firebase konfigurieren.',
        code: PartyErrorCode.realtimeUnavailable,
      );
      _logTelemetry(
        category: 'realtime',
        action: 'verify_join_access',
        result: result,
        role: PartyRole.guest,
      );
      return result;
    }
    final authResult = await realtimeSync.ensureSignedInAnonymously();
    if (!authResult.success) {
      final result = ActionResult.fail(
        authResult.message,
        code: PartyErrorCode.realtimeAuthFailed,
      );
      _logTelemetry(
        category: 'realtime',
        action: 'verify_join_access',
        result: result,
        role: PartyRole.guest,
      );
      return result;
    }
    final normalizedJoinInput = _normalizeJoinInputForRealtime(joinInput);
    if (normalizedJoinInput.isEmpty) {
      final result = ActionResult.fail(
        'Kein aktiver Raum gefunden. Erstelle zuerst eine Party oder gib Code/Link ein.',
        code: PartyErrorCode.roomLookupNoActive,
      );
      _logTelemetry(
        category: 'guest',
        action: 'verify_join_access_realtime',
        result: result,
        role: PartyRole.guest,
      );
      return result;
    }
    final lookup = await _lookupRealtimeJoinRoom(
      realtimeSync: realtimeSync,
      joinInput: normalizedJoinInput,
    );
    if (!lookup.isSuccess) {
      final result = ActionResult.fail(
        lookup.errorMessage!,
        code: lookup.errorCode ?? PartyErrorCode.roomLookupNotFound,
      );
      _logTelemetry(
        category: 'guest',
        action: 'verify_join_access_realtime',
        result: result,
        role: PartyRole.guest,
      );
      return result;
    }
    final room = lookup.room!;
    final accessResult = _validateJoinAccess(
      room: room,
      roomPassword: roomPassword,
    );
    if (!accessResult.success) {
      _logTelemetry(
        category: 'guest',
        action: 'verify_join_access_realtime',
        result: accessResult,
        role: PartyRole.guest,
        room: room,
      );
      return accessResult;
    }
    final result = ActionResult.ok(
      'Raum ${room.roomName} (${lookup.resolvedCode}) gefunden. Jetzt Name und Avatar waehlen.',
      code: 'join_access_verified',
    );
    _logTelemetry(
      category: 'guest',
      action: 'verify_join_access_realtime',
      result: result,
      role: PartyRole.guest,
      room: room,
    );
    return result;
  }

  ActionResult joinRoom({
    required String guestName,
    required String guestAvatar,
    required String joinInput,
    required String roomPassword,
    String? guestUserId,
  }) {
    _detachRealtimeSession();
    final lookup = _lookupLocalJoinRoom(joinInput);
    if (!lookup.isSuccess) {
      final result = ActionResult.fail(
        lookup.errorMessage!,
        code: lookup.errorCode ?? PartyErrorCode.roomLookupNotFound,
      );
      _logTelemetry(
        category: 'guest',
        action: 'join_room_local',
        result: result,
        role: PartyRole.guest,
      );
      return result;
    }
    final room = lookup.room!;
    final accessResult = _validateJoinAccess(
      room: room,
      roomPassword: roomPassword,
    );
    if (!accessResult.success) {
      _logTelemetry(
        category: 'guest',
        action: 'join_room_local',
        result: accessResult,
        role: PartyRole.guest,
        room: room,
      );
      return accessResult;
    }
    final safeName = guestName.trim().isEmpty ? 'Gast' : guestName.trim();
    final guest = PartyUser(
      id: guestUserId ?? _uuid.v4(),
      name: safeName,
      avatar: guestAvatar,
      role: PartyRole.guest,
    );
    room.participants[guest.id] = guest;
    _currentRoom = room;
    _currentUser = guest;
    _rememberSession(room: room, user: guest);
    _emitStateChanged();
    final result = ActionResult.ok(
      'Du bist der Party ${room.roomName} (${lookup.resolvedCode}) beigetreten.',
      code: 'join_room_success',
    );
    _logTelemetry(
      category: 'guest',
      action: 'join_room_local',
      result: result,
      role: PartyRole.guest,
      room: room,
    );
    return result;
  }

  Future<ActionResult> joinRoomRealtime({
    required String guestName,
    required String guestAvatar,
    required String joinInput,
    required String roomPassword,
  }) async {
    final realtimeSync = _realtimeSync;
    if (realtimeSync == null) {
      final result = ActionResult.fail(
        'Firebase Realtime ist nicht verfuegbar. Bitte lokal beitreten oder Firebase konfigurieren.',
        code: PartyErrorCode.realtimeUnavailable,
      );
      _logTelemetry(
        category: 'realtime',
        action: 'join_room_realtime',
        result: result,
        role: PartyRole.guest,
      );
      return result;
    }
    final authResult = await realtimeSync.ensureSignedInAnonymously();
    if (!authResult.success) {
      final result = ActionResult.fail(
        authResult.message,
        code: PartyErrorCode.realtimeAuthFailed,
      );
      _logTelemetry(
        category: 'realtime',
        action: 'join_room_realtime',
        result: result,
        role: PartyRole.guest,
      );
      return result;
    }
    final authUserId = authResult.userId;
    if (authUserId == null || authUserId.isEmpty) {
      final result = ActionResult.fail(
        'Realtime Auth-ID konnte nicht bestimmt werden.',
        code: PartyErrorCode.realtimeAuthMissingUserId,
      );
      _logTelemetry(
        category: 'realtime',
        action: 'join_room_realtime',
        result: result,
        role: PartyRole.guest,
      );
      return result;
    }
    final normalizedJoinInput = _normalizeJoinInputForRealtime(joinInput);
    if (normalizedJoinInput.isEmpty) {
      final result = ActionResult.fail(
        'Kein aktiver Raum gefunden. Erstelle zuerst eine Party oder gib Code/Link ein.',
        code: PartyErrorCode.roomLookupNoActive,
      );
      _logTelemetry(
        category: 'guest',
        action: 'join_room_realtime',
        result: result,
        role: PartyRole.guest,
      );
      return result;
    }
    final lookup = await _lookupRealtimeJoinRoom(
      realtimeSync: realtimeSync,
      joinInput: normalizedJoinInput,
    );
    if (!lookup.isSuccess) {
      final result = ActionResult.fail(
        lookup.errorMessage!,
        code: lookup.errorCode ?? PartyErrorCode.roomLookupNotFound,
      );
      _logTelemetry(
        category: 'guest',
        action: 'join_room_realtime',
        result: result,
        role: PartyRole.guest,
      );
      return result;
    }
    final remoteRoom = lookup.room!;
    final accessResult = _validateJoinAccess(
      room: remoteRoom,
      roomPassword: roomPassword,
    );
    if (!accessResult.success) {
      _logTelemetry(
        category: 'guest',
        action: 'join_room_realtime',
        result: accessResult,
        role: PartyRole.guest,
        room: remoteRoom,
      );
      return accessResult;
    }
    final safeName = guestName.trim().isEmpty ? 'Gast' : guestName.trim();
    final guest = PartyUser(
      id: authUserId,
      name: safeName,
      avatar: guestAvatar,
      role: PartyRole.guest,
    );
    remoteRoom.participants[guest.id] = guest;
    _currentRoom = remoteRoom;
    _currentUser = guest;
    _roomsByCode[remoteRoom.code] = remoteRoom;
    _isRealtimeSession = true;
    _isRealtimeHostAuthority = false;
    _rememberSession(room: remoteRoom, user: guest);

    await _attachRealtimeRoomSubscription(remoteRoom.code);
    _queueGuestCommand(RealtimeCommandType.updateProfile, <String, dynamic>{
      'name': guest.name,
      'avatar': guest.avatar,
    });
    _emitStateChanged();
    final result = ActionResult.ok(
      'Du bist der Realtime-Party ${remoteRoom.roomName} (${lookup.resolvedCode}) beigetreten.',
      code: 'join_room_success',
    );
    _logTelemetry(
      category: 'realtime',
      action: 'join_room_realtime',
      result: result,
      role: PartyRole.guest,
      room: remoteRoom,
    );
    return result;
  }

  ActionResult smartRejoin() {
    final snapshot = _sessionService.snapshot;
    if (!canSmartRejoin || snapshot == null) {
      return ActionResult.fail(
        'Es gibt keine letzte Session zum Wiederverbinden.',
        code: 'session_rejoin_unavailable',
      );
    }
    final code = snapshot.roomCode;
    final room = _roomsByCode[code];
    if (room == null || room.ended) {
      return ActionResult.fail(
        'Die letzte Session ist nicht mehr verfuegbar.',
        code: 'session_room_unavailable',
      );
    }
    final user = snapshot.user;
    room.participants[user.id] = user;
    _currentRoom = room;
    _currentUser = user;
    if (snapshot.wasRealtime && _realtimeSync != null) {
      _isRealtimeSession = true;
      _isRealtimeHostAuthority = snapshot.wasHostAuthority;
      unawaited(_attachRealtimeRoomSubscription(room.code));
      if (_isRealtimeHostAuthority) {
        _attachHostCommandListener(room.code);
      }
    }
    _emitStateChanged();
    final result = ActionResult.ok(
      'Letzte Session erfolgreich wieder verbunden.',
      code: 'session_rejoin_success',
    );
    _logTelemetry(
      category: 'session',
      action: 'smart_rejoin',
      result: result,
      role: _currentUser?.role,
      room: room,
    );
    return result;
  }

  void leaveRoom() {
    _detachRealtimeSession();
    _currentRoom = null;
    _currentUser = null;
    _emitStateChanged();
  }

  ActionResult updateCurrentProfile({
    required String name,
    required String avatar,
  }) {
    final room = _currentRoom;
    final user = _currentUser;
    if (room == null || user == null) {
      return ActionResult.fail('Kein aktiver Raum.');
    }
    final safeName = name.trim().isEmpty ? user.name : name.trim();
    final updated = user.copyWith(name: safeName, avatar: avatar);
    room.participants[user.id] = updated;
    _currentUser = updated;
    _sessionService.updateRememberedUser(updated);
    _reorderQueue(room);
    _emitStateChanged();
    if (_isRealtimeSession) {
      if (isHost) {
        _publishRealtimeState();
      } else if (!_isHandlingRemoteCommand) {
        _queueGuestCommand(RealtimeCommandType.updateProfile, <String, dynamic>{
          'name': updated.name,
          'avatar': updated.avatar,
        });
      }
    }
    return ActionResult.ok('Profil aktualisiert.');
  }

  ActionResult preloadQueueFromSongs(List<Song> songs) {
    final room = _currentRoom;
    final user = _currentUser;
    if (room == null || user == null) {
      return ActionResult.fail('Kein aktiver Raum.');
    }
    if (user.id != room.hostUserId) {
      return ActionResult.fail('Nur der Host kann eine Start-Playlist laden.');
    }
    if (room.ended) {
      return ActionResult.fail('Die Party wurde bereits beendet.');
    }
    final filteredSongs = _filterSongsForCurrentRoom(songs);
    var added = 0;
    for (final song in filteredSongs) {
      if (_queuePolicy.songExists(room: room, songId: song.id)) {
        continue;
      }
      room.queue.add(
        QueueItem(
          id: _uuid.v4(),
          song: song,
          addedByUserId: user.id,
          addedByName: user.name,
          addedByAvatar: user.avatar,
          addedAt: DateTime.now(),
        ),
      );
      added++;
    }
    if (added == 0) {
      return ActionResult.fail(
        'Keine neuen Songs aus der ausgewaehlten Playlist verfuegbar.',
      );
    }
    _reorderQueue(room);
    _emitStateChanged();
    return ActionResult.ok('$added Song(s) aus Playlist in die Queue geladen.');
  }

  ActionResult kickParticipant(String participantId) {
    final room = _currentRoom;
    final user = _currentUser;
    if (room == null || user == null) {
      return ActionResult.fail('Kein aktiver Raum.');
    }
    if (user.id != room.hostUserId) {
      return ActionResult.fail('Nur der Host kann Gaeste entfernen.');
    }
    if (participantId == room.hostUserId) {
      return ActionResult.fail('Der Host kann nicht entfernt werden.');
    }
    final removed = room.participants.remove(participantId);
    if (removed == null) {
      return ActionResult.fail('Gast wurde nicht gefunden.');
    }
    room.addHistoryByUserId.remove(participantId);
    if (room.lastPlayedByUserId == participantId) {
      room.lastPlayedByUserId = null;
    }
    _emitStateChanged();
    return ActionResult.ok('${removed.name} wurde aus dem Raum entfernt.');
  }

  List<Song> searchSongs(String query) {
    return _filterSongsForCurrentRoom(_catalog.search(query));
  }

  AddEligibility canAddSong(Song song) {
    final room = _currentRoom;
    final user = _currentUser;
    if (room == null || user == null) {
      return AddEligibility.denied('Kein aktiver Raum.');
    }
    return _checkAddEligibility(
      room: room,
      user: user,
      song: song,
      mutateAddHistory: false,
    );
  }

  ActionResult addSong(Song song) {
    final room = _currentRoom;
    final user = _currentUser;
    if (room == null || user == null) {
      return ActionResult.fail('Kein aktiver Raum.');
    }
    if (_isRealtimeGuest) {
      _queueGuestCommand(RealtimeCommandType.addSong, <String, dynamic>{
        'song': encodeSong(song),
        'actorName': user.name,
        'actorAvatar': user.avatar,
      });
      return ActionResult.ok('Song-Add an Host gesendet.');
    }
    if (room.ended) {
      return ActionResult.fail('Die Party wurde bereits beendet.');
    }
    final eligibility = _checkAddEligibility(
      room: room,
      user: user,
      song: song,
      mutateAddHistory: true,
    );
    if (!eligibility.allowed) {
      return ActionResult.fail(eligibility.reason);
    }

    final item = QueueItem(
      id: _uuid.v4(),
      song: song,
      addedByUserId: user.id,
      addedByName: user.name,
      addedByAvatar: user.avatar,
      addedAt: DateTime.now(),
    );

    if (room.settings.mode == RoomMode.suggestionsOnly &&
        user.id != room.hostUserId) {
      room.suggestions.add(item);
      _emitStateChanged();
      return ActionResult.ok('Song wurde als Vorschlag eingereicht.');
    }

    room.queue.add(item);
    _reorderQueue(room);
    _emitStateChanged();
    return ActionResult.ok('Song wurde zur Live-Warteschlange hinzugefuegt.');
  }

  ActionResult voteOnSong({
    required String queueItemId,
    required VoteType vote,
  }) {
    final room = _currentRoom;
    final user = _currentUser;
    if (room == null || user == null) {
      return ActionResult.fail('Kein aktiver Raum.');
    }
    if (_isRealtimeGuest) {
      _queueGuestCommand(RealtimeCommandType.voteSong, <String, dynamic>{
        'queueItemId': queueItemId,
        'vote': vote.name,
        'actorName': user.name,
        'actorAvatar': user.avatar,
      });
      return ActionResult.ok('Vote an Host gesendet.');
    }
    if (room.settings.votesPaused && user.id != room.hostUserId) {
      return ActionResult.fail('Voting wurde vom Host pausiert.');
    }
    final index = room.queue.indexWhere((item) => item.id == queueItemId);
    if (index == -1) {
      return ActionResult.fail(
        'Der Song liegt nicht mehr in der Warteschlange.',
      );
    }
    final item = room.queue[index];
    final existing = item.votesByUser[user.id];
    if (existing == vote) {
      item.votesByUser.remove(user.id);
    } else {
      item.votesByUser[user.id] = vote;
    }
    _reorderQueue(room);
    _emitStateChanged();
    return ActionResult.ok('Vote gespeichert.');
  }

  ActionResult approveSuggestion(String queueItemId) {
    final room = _currentRoom;
    final user = _currentUser;
    if (room == null || user == null) {
      return ActionResult.fail('Kein aktiver Raum.');
    }
    if (user.id != room.hostUserId) {
      return ActionResult.fail('Nur der Host kann Vorschlaege freigeben.');
    }
    final index = room.suggestions.indexWhere((item) => item.id == queueItemId);
    if (index == -1) {
      return ActionResult.fail('Vorschlag nicht gefunden.');
    }
    final item = room.suggestions.removeAt(index);
    if (_queuePolicy.songExists(room: room, songId: item.song.id)) {
      return ActionResult.fail(
        'Song ist bereits in Queue, Vorschlag verworfen.',
      );
    }
    room.queue.add(item);
    _reorderQueue(room);
    _emitStateChanged();
    return ActionResult.ok('Vorschlag uebernommen.');
  }

  ActionResult rejectSuggestion(String queueItemId) {
    final room = _currentRoom;
    final user = _currentUser;
    if (room == null || user == null) {
      return ActionResult.fail('Kein aktiver Raum.');
    }
    if (user.id != room.hostUserId) {
      return ActionResult.fail('Nur der Host kann Vorschlaege ablehnen.');
    }
    room.suggestions.removeWhere((item) => item.id == queueItemId);
    _emitStateChanged();
    return ActionResult.ok('Vorschlag entfernt.');
  }

  ActionResult togglePin(String queueItemId) {
    final room = _currentRoom;
    final user = _currentUser;
    if (room == null || user == null) {
      return ActionResult.fail('Kein aktiver Raum.');
    }
    if (user.id != room.hostUserId) {
      return ActionResult.fail('Nur der Host kann Songs fixieren.');
    }
    final index = room.queue.indexWhere((item) => item.id == queueItemId);
    if (index == -1) {
      return ActionResult.fail('Song nicht in der Queue gefunden.');
    }
    final item = room.queue[index];
    item.pinned = !item.pinned;
    item.pinnedAt = item.pinned ? DateTime.now() : null;
    _reorderQueue(room);
    _emitStateChanged();
    return ActionResult.ok(
      item.pinned ? 'Song fixiert.' : 'Fixierung entfernt.',
    );
  }

  ActionResult removeQueueItem(String queueItemId) {
    final room = _currentRoom;
    final user = _currentUser;
    if (room == null || user == null) {
      return ActionResult.fail('Kein aktiver Raum.');
    }
    if (user.id != room.hostUserId) {
      return ActionResult.fail('Nur der Host kann Songs entfernen.');
    }
    final before = room.queue.length;
    room.queue.removeWhere((item) => item.id == queueItemId);
    if (room.queue.length == before) {
      return ActionResult.fail('Song nicht gefunden.');
    }
    _reorderQueue(room);
    _emitStateChanged();
    return ActionResult.ok('Song aus der Queue entfernt.');
  }

  ActionResult skipNowPlaying() {
    final room = _currentRoom;
    final user = _currentUser;
    if (room == null || user == null) {
      return ActionResult.fail('Kein aktiver Raum.');
    }
    if (user.id != room.hostUserId) {
      return ActionResult.fail('Nur der Host kann skippen.');
    }
    if (room.nowPlaying == null) {
      return ActionResult.fail('Aktuell laeuft kein Song.');
    }
    _finishCurrentSong(room);
    _emitStateChanged();
    return ActionResult.ok('Song wurde geskippt.');
  }

  ActionResult setSortMode(QueueSortMode mode) {
    return _updateSettings(
      update: (current) => current.copyWith(sortMode: mode),
      successMessage: mode == QueueSortMode.votesOnly
          ? 'Sortierung: Likes - Dislikes.'
          : 'Sortierung: Votes + Altersbonus.',
      blockWhenCoreSettingsLocked: true,
    );
  }

  ActionResult setFairnessMode(bool value) {
    return _updateSettings(
      update: (current) => current.copyWith(fairnessMode: value),
      successMessage: value
          ? 'Fairness-Modus aktiviert.'
          : 'Fairness-Modus deaktiviert.',
      blockWhenCoreSettingsLocked: true,
    );
  }

  ActionResult setCooldownMinutes(int minutes) {
    final safe = minutes.clamp(5, 180).toInt();
    return _updateSettings(
      update: (current) => current.copyWith(cooldown: Duration(minutes: safe)),
      successMessage: 'Cooldown auf $safe Minuten gesetzt.',
      blockWhenCoreSettingsLocked: true,
    );
  }

  ActionResult setAntiSpamLimit(int maxAdds) {
    final safe = maxAdds.clamp(1, 12).toInt();
    return _updateSettings(
      update: (current) => current.copyWith(maxAddsPerWindow: safe),
      successMessage: 'Anti-Spam: max. $safe Songs im Zeitfenster.',
    );
  }

  ActionResult setAntiSpamWindowMinutes(int minutes) {
    final safe = minutes.clamp(5, 60).toInt();
    return _updateSettings(
      update: (current) => current.copyWith(addWindow: Duration(minutes: safe)),
      successMessage: 'Anti-Spam-Zeitfenster auf $safe Minuten gesetzt.',
    );
  }

  ActionResult setRoomMode(RoomMode mode) {
    return _updateSettings(
      update: (current) => current.copyWith(mode: mode),
      successMessage: mode == RoomMode.democratic
          ? 'Modus: Demokratisch.'
          : 'Modus: Nur Vorschlaege.',
      blockWhenCoreSettingsLocked: true,
    );
  }

  ActionResult setBlockExplicit(bool value) {
    return _updateSettings(
      update: (current) => current.copyWith(blockExplicit: value),
      successMessage: value
          ? 'Explizite Inhalte werden blockiert.'
          : 'Explizite Inhalte sind erlaubt.',
    );
  }

  ActionResult setVotesPaused(bool value) {
    return _updateSettings(
      update: (current) => current.copyWith(votesPaused: value),
      successMessage: value ? 'Votes pausiert.' : 'Votes wieder freigegeben.',
    );
  }

  ActionResult setHostOnlyAdds(bool value) {
    return _updateSettings(
      update: (current) => current.copyWith(hostOnlyAdds: value),
      successMessage: value
          ? 'Nur Host darf Songs hinzufuegen.'
          : 'Alle duerfen Songs hinzufuegen.',
    );
  }

  ActionResult setRoomLocked(bool value) {
    return _updateSettings(
      update: (current) => current.copyWith(lockRoom: value),
      successMessage: value ? 'Raum ist gesperrt.' : 'Raum ist wieder offen.',
    );
  }

  ActionResult setFreezeWindowSeconds(int seconds) {
    final safe = seconds.clamp(15, 180).toInt();
    return _updateSettings(
      update: (current) =>
          current.copyWith(freezeWindow: Duration(seconds: safe)),
      successMessage: 'Freeze-Fenster auf $safe Sekunden gesetzt.',
      blockWhenCoreSettingsLocked: true,
    );
  }

  ActionResult setGenreExcluded(String genre, bool excluded) {
    return _updateSettings(
      update: (current) {
        final genres = Set<String>.from(current.excludedGenres);
        if (excluded) {
          genres.add(genre);
        } else {
          genres.remove(genre);
        }
        return current.copyWith(excludedGenres: genres);
      },
      successMessage: excluded
          ? 'Genre $genre ausgeschlossen.'
          : 'Genre $genre wieder erlaubt.',
    );
  }

  ActionResult simulateTokenExpired() {
    return _updateConnectionState(
      PlaybackConnectionState.tokenExpired,
      'Spotify-Token ist abgelaufen (simuliert).',
    );
  }

  ActionResult simulateDeviceLost() {
    return _updateConnectionState(
      PlaybackConnectionState.deviceUnavailable,
      'Spotify-Wiedergabegeraet verloren (simuliert).',
    );
  }

  ActionResult reconnectPlayback() {
    return _updateConnectionState(
      PlaybackConnectionState.connected,
      'Spotify-Verbindung wiederhergestellt.',
    );
  }

  PlaylistExport? endPartyAndGeneratePlaylist() {
    final room = _currentRoom;
    final user = _currentUser;
    if (room == null || user == null || user.id != room.hostUserId) {
      return null;
    }
    room.ended = true;
    final playCounts = <String, int>{};
    final songsById = <String, Song>{};
    for (final item in room.playedHistory) {
      playCounts.update(item.song.id, (value) => value + 1, ifAbsent: () => 1);
      songsById[item.song.id] = item.song;
    }
    final ids = playCounts.keys.toList()
      ..sort((a, b) {
        final countCompare = playCounts[b]!.compareTo(playCounts[a]!);
        if (countCompare != 0) {
          return countCompare;
        }
        return songsById[a]!.title.compareTo(songsById[b]!.title);
      });
    final songs = ids.map((id) => songsById[id]!).toList(growable: false);
    _emitStateChanged();
    return PlaylistExport(
      playlistName: 'Party ${room.code} Highlights',
      songs: songs,
    );
  }

  void _onTick(Timer _) {
    final room = _currentRoom;
    if (room == null || room.ended) {
      return;
    }
    if (_isRealtimeSession && !isHost) {
      return;
    }
    _pruneCooldown(room);
    if (room.connectionState != PlaybackConnectionState.connected) {
      return;
    }

    var changed = false;
    if (room.nowPlaying == null && room.queue.isNotEmpty) {
      _ensurePlaybackStarted(room);
      changed = true;
    }

    final current = room.nowPlaying;
    if (current == null) {
      if (changed) {
        _emitStateChanged();
      }
      return;
    }

    room.nowPlayingPosition += const Duration(seconds: 1);
    changed = true;

    final remaining = current.song.duration - room.nowPlayingPosition;
    if (!remaining.isNegative &&
        remaining <= room.settings.freezeWindow &&
        room.lockedNextSongId == null &&
        room.queue.isNotEmpty) {
      room.lockedNextSongId = _queuePolicy.orderedQueue(room).first.id;
    }

    if (room.nowPlayingPosition >= current.song.duration) {
      _finishCurrentSong(room);
    }

    if (changed) {
      _emitStateChanged();
    }
  }

  void _pruneCooldown(PartyRoom room) {
    final now = DateTime.now();
    room.cooldownUntilBySongId.removeWhere(
      (_, expiresAt) => !expiresAt.isAfter(now),
    );
  }

  void _finishCurrentSong(PartyRoom room) {
    final current = room.nowPlaying;
    if (current == null) {
      return;
    }
    room.playedHistory.add(current);
    room.lastPlayedByUserId = current.addedByUserId;
    room.cooldownUntilBySongId[current.song.id] = DateTime.now().add(
      room.settings.cooldown,
    );
    room.nowPlaying = null;
    room.nowPlayingPosition = Duration.zero;
    room.lockedNextSongId = null;
    _pruneCooldown(room);
    _ensurePlaybackStarted(room);
  }

  void _ensurePlaybackStarted(PartyRoom room) {
    if (room.nowPlaying != null || room.queue.isEmpty) {
      return;
    }
    final ordered = _queuePolicy.orderedQueue(room);
    if (ordered.isEmpty) {
      return;
    }
    final next = ordered.first;
    room.queue.removeWhere((item) => item.id == next.id);
    room.nowPlaying = next;
    room.nowPlayingPosition = Duration.zero;
  }

  void _reorderQueue(PartyRoom room) {
    if (room.queue.isNotEmpty) {
      final sorted = _queuePolicy.orderedQueue(room);
      room.queue
        ..clear()
        ..addAll(sorted);
    }
    if (room.nowPlaying == null) {
      _ensurePlaybackStarted(room);
    }
  }

  AddEligibility _checkAddEligibility({
    required PartyRoom room,
    required PartyUser user,
    required Song song,
    required bool mutateAddHistory,
  }) {
    if (room.ended) {
      return AddEligibility.denied('Die Party ist bereits beendet.');
    }
    if (room.settings.hostOnlyAdds && user.id != room.hostUserId) {
      return AddEligibility.denied(
        'Nur der Host darf aktuell Songs hinzufuegen.',
      );
    }
    if (room.settings.blockExplicit && song.explicit) {
      return AddEligibility.denied(
        'Explizite Inhalte sind vom Host blockiert.',
      );
    }
    final intersectsExcludedGenre = song.genres.any(
      room.settings.excludedGenres.contains,
    );
    if (intersectsExcludedGenre) {
      return AddEligibility.denied(
        'Dieser Song faellt in ein vom Host ausgeschlossenes Genre.',
      );
    }
    if (_queuePolicy.songExists(room: room, songId: song.id)) {
      return AddEligibility.denied(
        'Song ist bereits in der Live-Queue oder laeuft schon.',
      );
    }

    final now = DateTime.now();
    final cooldownUntil = room.cooldownUntilBySongId[song.id];
    if (cooldownUntil != null && cooldownUntil.isAfter(now)) {
      final remaining = cooldownUntil.difference(now);
      final minutesLeft = remaining.inMinutes + 1;
      return AddEligibility.denied(
        'Song im Cooldown. Bitte in ca. $minutesLeft Minute(n) erneut versuchen.',
      );
    }

    final history = List<DateTime>.from(
      room.addHistoryByUserId[user.id] ?? <DateTime>[],
    );
    history.removeWhere(
      (stamp) => now.difference(stamp) > room.settings.addWindow,
    );
    if (mutateAddHistory) {
      room.addHistoryByUserId[user.id] = history;
    }
    if (history.length >= room.settings.maxAddsPerWindow) {
      return AddEligibility.denied(
        'Anti-Spam aktiv: max. ${room.settings.maxAddsPerWindow} Songs in ${room.settings.addWindow.inMinutes} Minuten.',
      );
    }
    if (mutateAddHistory) {
      history.add(now);
      room.addHistoryByUserId[user.id] = history;
    }
    return AddEligibility.allowedResult;
  }

  ActionResult _updateSettings({
    required RoomSettings Function(RoomSettings current) update,
    required String successMessage,
    bool blockWhenCoreSettingsLocked = false,
  }) {
    final room = _currentRoom;
    final user = _currentUser;
    if (room == null || user == null) {
      return ActionResult.fail('Kein aktiver Raum.');
    }
    if (user.id != room.hostUserId) {
      return ActionResult.fail('Nur der Host kann Einstellungen aendern.');
    }
    if (blockWhenCoreSettingsLocked && room.coreSettingsLocked) {
      return ActionResult.fail(
        'Diese Einstellung wurde beim Erstellen festgelegt und kann spaeter nicht mehr geaendert werden.',
      );
    }
    room.settings = update(room.settings);
    _reorderQueue(room);
    _emitStateChanged();
    return ActionResult.ok(successMessage);
  }

  ActionResult _updateConnectionState(
    PlaybackConnectionState state,
    String successMessage,
  ) {
    final room = _currentRoom;
    final user = _currentUser;
    if (room == null || user == null) {
      return ActionResult.fail('Kein aktiver Raum.');
    }
    if (user.id != room.hostUserId) {
      return ActionResult.fail('Nur der Host kann Spotify neu verbinden.');
    }
    room.connectionState = state;
    if (state == PlaybackConnectionState.connected) {
      _ensurePlaybackStarted(room);
    }
    _emitStateChanged();
    return ActionResult.ok(successMessage);
  }

  void _emitStateChanged() {
    super.notifyListeners();
    if (_isRealtimeSession &&
        _isRealtimeHostAuthority &&
        !_isApplyingRemoteState) {
      _publishRealtimeState();
    }
  }

  Future<void> _attachRealtimeRoomSubscription(String roomCode) async {
    await _roomRealtimeSubscription?.cancel();
    _roomRealtimeSubscription = _realtimeSync
        ?.watchRoomState(roomCode)
        .listen(
          (roomState) {
            if (roomState == null) {
              return;
            }
            final remoteRoom = decodePartyRoom(roomState);
            _roomsByCode[remoteRoom.code] = remoteRoom;
            final currentUserId = _currentUser?.id;
            if (currentUserId != null) {
              final syncedUser = remoteRoom.participants[currentUserId];
              if (syncedUser == null) {
                if (_isRealtimeSession && !_isRealtimeHostAuthority) {
                  final pendingLocalUser = _currentUser;
                  if (pendingLocalUser != null) {
                    remoteRoom.participants[pendingLocalUser.id] =
                        pendingLocalUser;
                    _currentRoom = remoteRoom;
                    _lastSyncError = null;
                    _isApplyingRemoteState = true;
                    super.notifyListeners();
                    _isApplyingRemoteState = false;
                    return;
                  }
                }
                _detachRealtimeSession();
                _lastSyncError = 'Du wurdest aus dem Raum entfernt.';
                _currentRoom = null;
                _currentUser = null;
                super.notifyListeners();
                return;
              }
              _currentUser = syncedUser;
            }
            _currentRoom = remoteRoom;
            _lastSyncError = null;
            _isApplyingRemoteState = true;
            super.notifyListeners();
            _isApplyingRemoteState = false;
          },
          onError: (_) {
            _lastSyncError = 'Realtime-Listener unterbrochen.';
            _logTelemetry(
              category: 'realtime',
              action: 'room_listener_error',
              result: ActionResult.fail(
                _lastSyncError!,
                code: PartyErrorCode.realtimeListenerInterrupted,
              ),
              role: _currentUser?.role,
              room: _currentRoom,
            );
            super.notifyListeners();
          },
        );
  }

  void _attachHostCommandListener(String roomCode) {
    final realtimeSync = _realtimeSync;
    if (!_isRealtimeSession ||
        !_isRealtimeHostAuthority ||
        realtimeSync == null) {
      return;
    }
    _commandSubscription?.cancel();
    _commandSubscription = realtimeSync
        .watchPendingCommands(roomCode)
        .listen(
          (commands) {
            for (final command in commands) {
              final started = _realtimeCoordinator.tryStartProcessing(
                roomCode: roomCode,
                commandId: command.id,
                now: DateTime.now(),
              );
              if (!started) {
                continue;
              }
              unawaited(
                _processRealtimeCommand(command)
                    .then((rememberAsProcessed) {
                      _realtimeCoordinator.finishProcessing(
                        roomCode: roomCode,
                        commandId: command.id,
                        now: DateTime.now(),
                        rememberAsProcessed: rememberAsProcessed,
                      );
                    })
                    .catchError((_) {
                      _realtimeCoordinator.finishProcessing(
                        roomCode: roomCode,
                        commandId: command.id,
                        now: DateTime.now(),
                        rememberAsProcessed: false,
                      );
                    }),
              );
            }
          },
          onError: (_) {
            _lastSyncError = 'Command-Listener unterbrochen.';
            _logTelemetry(
              category: 'realtime',
              action: 'command_listener_error',
              result: ActionResult.fail(
                _lastSyncError!,
                code: PartyErrorCode.realtimeCommandListenerInterrupted,
              ),
              role: _currentUser?.role,
              room: _currentRoom,
            );
            super.notifyListeners();
          },
        );
  }

  Future<bool> _processRealtimeCommand(RealtimeCommand command) async {
    final room = _currentRoom;
    if (room == null || !_isRealtimeSession || !_isRealtimeHostAuthority) {
      return false;
    }
    final validation = _commandContract.validateIncomingCommand(
      command,
      now: DateTime.now(),
    );
    if (!validation.isValid) {
      final invalidResult = ActionResult.fail(
        validation.message ?? 'Command-Payload ungueltig.',
        code: validation.code ?? PartyErrorCode.realtimeCommandInvalid,
      );
      await _ackRealtimeCommand(
        roomCode: room.code,
        commandId: command.id,
        result: invalidResult,
      );
      _logTelemetry(
        category: 'realtime',
        action: 'process_command_${command.type.name}',
        result: invalidResult,
        role: _currentUser?.role,
        room: room,
        metadata: <String, Object?>{
          'commandId': command.id,
          'userId': command.userId,
        },
      );
      return true;
    }
    final actor = _resolveActorForCommand(room: room, command: command);
    ActionResult result;
    if (actor == null) {
      result = ActionResult.fail(
        'User nicht im Raum.',
        code: PartyErrorCode.realtimeCommandActorMissing,
      );
    } else {
      final previousUser = _currentUser;
      _currentUser = actor;
      _isHandlingRemoteCommand = true;
      try {
        switch (command.type) {
          case RealtimeCommandType.addSong:
            final songMap = Map<String, dynamic>.from(
              command.payload['song'] as Map? ?? <String, dynamic>{},
            );
            result = addSong(decodeSong(songMap));
            break;
          case RealtimeCommandType.voteSong:
            final queueItemId =
                (command.payload['queueItemId'] ?? '') as String;
            final voteName =
                (command.payload['vote'] ?? VoteType.like.name) as String;
            final vote = VoteType.values.firstWhere(
              (value) => value.name == voteName,
              orElse: () => VoteType.like,
            );
            result = voteOnSong(queueItemId: queueItemId, vote: vote);
            break;
          case RealtimeCommandType.updateProfile:
            final name = (command.payload['name'] ?? actor.name) as String;
            final avatar =
                (command.payload['avatar'] ?? actor.avatar) as String;
            result = updateCurrentProfile(name: name, avatar: avatar);
            break;
        }
      } finally {
        _isHandlingRemoteCommand = false;
        _currentUser = previousUser;
      }
    }
    if (_isRealtimeSession && _isRealtimeHostAuthority) {
      _publishRealtimeState();
    }
    _logTelemetry(
      category: 'realtime',
      action: 'process_command_${command.type.name}',
      result: result,
      role: actor?.role,
      room: room,
      metadata: <String, Object?>{
        'commandId': command.id,
        'userId': command.userId,
      },
    );
    return _ackRealtimeCommand(
      roomCode: room.code,
      commandId: command.id,
      result: result,
    );
  }

  PartyUser? _resolveActorForCommand({
    required PartyRoom room,
    required RealtimeCommand command,
  }) {
    final existingActor = room.participants[command.userId];
    if (existingActor != null) {
      return existingActor;
    }
    final rawName =
        (command.payload['name'] ?? command.payload['actorName'] ?? '')
            .toString()
            .trim();
    final rawAvatar =
        (command.payload['avatar'] ?? command.payload['actorAvatar'] ?? '')
            .toString()
            .trim();
    if (rawName.isEmpty && rawAvatar.isEmpty) {
      return null;
    }
    final createdActor = PartyUser(
      id: command.userId,
      name: rawName.isEmpty ? 'Gast' : rawName,
      avatar: rawAvatar.isEmpty ? 'A' : rawAvatar,
      role: PartyRole.guest,
    );
    room.participants[createdActor.id] = createdActor;
    return createdActor;
  }

  void _queueGuestCommand(
    RealtimeCommandType type,
    Map<String, dynamic> payload,
  ) {
    final room = _currentRoom;
    final user = _currentUser;
    final sync = _realtimeSync;
    if (room == null || user == null || sync == null) {
      return;
    }
    final validation = _commandContract.validateOutgoingPayload(type, payload);
    if (!validation.isValid) {
      final failure = ActionResult.fail(
        validation.message ?? 'Command konnte lokal nicht validiert werden.',
        code: validation.code ?? PartyErrorCode.realtimeCommandInvalid,
      );
      _lastSyncError = failure.message;
      _logTelemetry(
        category: 'realtime',
        action: 'queue_guest_command_${type.name}',
        result: failure,
        role: user.role,
        room: room,
      );
      super.notifyListeners();
      return;
    }
    unawaited(
      sync
          .enqueueCommand(
            code: room.code,
            type: type,
            userId: user.id,
            payload: payload,
          )
          .then((result) {
            if (!result.success) {
              _lastSyncError = result.message;
              _logTelemetry(
                category: 'realtime',
                action: 'queue_guest_command_${type.name}',
                result: ActionResult.fail(
                  result.message,
                  code: PartyErrorCode.realtimeGuestCommandEnqueueFailed,
                ),
                role: user.role,
                room: room,
              );
              super.notifyListeners();
              return;
            }
            _logTelemetry(
              category: 'realtime',
              action: 'queue_guest_command_${type.name}',
              result: ActionResult.ok(
                result.message,
                code: 'realtime_guest_command_enqueued',
              ),
              role: user.role,
              room: room,
            );
          }),
    );
  }

  void _publishRealtimeState() {
    if (_isPublishingState) {
      _queuedStatePublish = true;
      return;
    }
    final room = _currentRoom;
    final sync = _realtimeSync;
    if (room == null || sync == null || !_isRealtimeSession) {
      return;
    }
    _isPublishingState = true;
    unawaited(
      sync
          .updateRoomState(code: room.code, roomState: encodePartyRoom(room))
          .then((result) {
            if (!result.success) {
              _lastSyncError = result.message;
              super.notifyListeners();
            }
          })
          .whenComplete(() {
            _isPublishingState = false;
            if (_queuedStatePublish) {
              _queuedStatePublish = false;
              _publishRealtimeState();
            }
          }),
    );
  }

  void _detachRealtimeSession() {
    _roomRealtimeSubscription?.cancel();
    _roomRealtimeSubscription = null;
    _commandSubscription?.cancel();
    _commandSubscription = null;
    _realtimeCoordinator.reset();
    _isRealtimeSession = false;
    _isRealtimeHostAuthority = false;
    _isApplyingRemoteState = false;
    _isHandlingRemoteCommand = false;
    _isPublishingState = false;
    _queuedStatePublish = false;
    _lastSyncError = null;
  }

  Future<bool> _ackRealtimeCommand({
    required String roomCode,
    required String commandId,
    required ActionResult result,
  }) async {
    try {
      await _realtimeSync?.markCommandProcessed(
        code: roomCode,
        commandId: commandId,
        success: result.success,
        message: result.message,
      );
      return true;
    } catch (_) {
      _lastSyncError = 'Command-Status konnte nicht bestaetigt werden.';
      _logTelemetry(
        category: 'realtime',
        action: 'command_ack',
        result: ActionResult.fail(
          _lastSyncError!,
          code: PartyErrorCode.realtimeCommandAckFailed,
        ),
        role: _currentUser?.role,
        room: _currentRoom,
        metadata: <String, Object?>{
          'commandId': commandId,
          'resultCode': result.code,
        },
      );
      super.notifyListeners();
      return false;
    }
  }

  List<Song> _filterSongsForCurrentRoom(List<Song> songs) {
    final room = _currentRoom;
    if (room == null) {
      return songs;
    }
    return songs
        .where((song) {
          if (room.settings.blockExplicit && song.explicit) {
            return false;
          }
          if (room.settings.excludedGenres.isNotEmpty &&
              song.genres.any(room.settings.excludedGenres.contains)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  ActionResult _validateJoinAccess({
    required PartyRoom room,
    required String roomPassword,
  }) {
    final safePassword = roomPassword.trim();
    if (safePassword.isEmpty) {
      return ActionResult.fail(
        'Bitte gib das Raumpasswort ein.',
        code: PartyErrorCode.roomPasswordRequired,
      );
    }
    if (room.ended) {
      return ActionResult.fail(
        'Diese Party ist bereits beendet.',
        code: PartyErrorCode.roomEnded,
      );
    }
    if (room.settings.lockRoom) {
      return ActionResult.fail(
        'Der Host hat den Raum aktuell gesperrt.',
        code: PartyErrorCode.roomLocked,
      );
    }
    if (room.roomPassword != safePassword) {
      return ActionResult.fail(
        'Das Raumpasswort ist falsch.',
        code: PartyErrorCode.roomPasswordInvalid,
      );
    }
    return ActionResult.ok('Raumzugriff erlaubt.');
  }

  RoomLookupResult _lookupLocalJoinRoom(String joinInput) {
    final trimmedInput = joinInput.trim();
    if (trimmedInput.isEmpty) {
      final activeRooms = _roomsByCode.values
          .where((room) => !room.ended)
          .toList(growable: false);
      if (activeRooms.isEmpty) {
        return const RoomLookupResult.error(
          errorMessage:
              'Kein aktiver lokaler Raum gefunden. Erstelle zuerst eine Party als Host.',
          resolvedCode: '',
          errorCode: PartyErrorCode.roomLookupNoActive,
        );
      }
      if (activeRooms.length > 1) {
        return const RoomLookupResult.error(
          errorMessage:
              'Mehrere lokale Raeume sind aktiv. Bitte Code, Invite-Link oder Party-Name eingeben.',
          resolvedCode: '',
          errorCode: PartyErrorCode.roomLookupMultipleActive,
        );
      }
      final room = activeRooms.first;
      return RoomLookupResult.success(room: room, resolvedCode: room.code);
    }

    final code = _extractRoomCode(joinInput);
    var resolvedCode = code;
    PartyRoom? room;
    if (code.isNotEmpty) {
      room = _roomsByCode[code];
    }
    if (room == null) {
      final matches = _findPublicRoomsByName(joinInput);
      if (matches.isEmpty) {
        if (code.isNotEmpty) {
          return RoomLookupResult.error(
            errorMessage:
                'Kein aktiver Raum mit dem Code $resolvedCode gefunden.',
            resolvedCode: resolvedCode,
            errorCode: PartyErrorCode.roomLookupNotFound,
          );
        }
        return const RoomLookupResult.error(
          errorMessage: 'Kein oeffentlicher Raum mit diesem Namen gefunden.',
          resolvedCode: '',
          errorCode: PartyErrorCode.roomLookupNotFound,
        );
      }
      if (matches.length > 1) {
        return const RoomLookupResult.error(
          errorMessage:
              'Mehrere oeffentliche Raeume passen auf den Namen. Bitte nutze Code oder Invite-Link.',
          resolvedCode: '',
          errorCode: PartyErrorCode.roomLookupAmbiguous,
        );
      }
      room = matches.first;
      resolvedCode = room.code;
    }
    return RoomLookupResult.success(room: room, resolvedCode: resolvedCode);
  }

  Future<RoomLookupResult> _lookupRealtimeJoinRoom({
    required PartyRealtimeSyncApi realtimeSync,
    required String joinInput,
  }) async {
    var code = _extractRoomCode(joinInput);
    if (code.isEmpty) {
      final matches = await realtimeSync.searchPublicRoomsByName(joinInput);
      if (matches.isEmpty) {
        return const RoomLookupResult.error(
          errorMessage:
              'Kein oeffentlicher Realtime-Raum mit diesem Namen gefunden.',
          resolvedCode: '',
          errorCode: PartyErrorCode.roomLookupNotFound,
        );
      }
      if (matches.length > 1) {
        return const RoomLookupResult.error(
          errorMessage:
              'Mehrere oeffentliche Realtime-Raeume passen auf den Namen. Bitte nutze Code oder Invite-Link.',
          resolvedCode: '',
          errorCode: PartyErrorCode.roomLookupAmbiguous,
        );
      }
      code = matches.first.code;
    }
    var roomState = await realtimeSync.fetchRoomState(code);
    if (roomState == null && code.isNotEmpty) {
      final matches = await realtimeSync.searchPublicRoomsByName(joinInput);
      if (matches.length == 1) {
        code = matches.first.code;
        roomState = await realtimeSync.fetchRoomState(code);
      }
    }
    if (roomState == null) {
      return RoomLookupResult.error(
        errorMessage: 'Kein aktiver Realtime-Raum mit Code $code.',
        resolvedCode: code,
        errorCode: PartyErrorCode.roomLookupNotFound,
      );
    }
    final room = decodePartyRoom(roomState);
    return RoomLookupResult.success(room: room, resolvedCode: code);
  }

  List<PartyRoom> _findPublicRoomsByName(String input) {
    final query = input.trim().toLowerCase();
    if (query.isEmpty) {
      return const <PartyRoom>[];
    }
    final publicRooms = _roomsByCode.values
        .where((room) => room.isPublic && !room.ended)
        .toList(growable: false);
    final exactMatches = publicRooms
        .where((room) => room.roomName.toLowerCase() == query)
        .toList(growable: false);
    if (exactMatches.isNotEmpty) {
      return exactMatches;
    }
    return publicRooms
        .where((room) => room.roomName.toLowerCase().contains(query))
        .toList(growable: false);
  }

  String _normalizeJoinInputForRealtime(String joinInput) {
    final trimmed = joinInput.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    final localLookup = _lookupLocalJoinRoom(trimmed);
    if (!localLookup.isSuccess) {
      return '';
    }
    return localLookup.resolvedCode;
  }

  String _extractRoomCode(String input) {
    return extractRoomCode(input);
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    while (true) {
      final buffer = StringBuffer();
      for (var i = 0; i < 6; i++) {
        buffer.write(chars[_random.nextInt(chars.length)]);
      }
      final code = buffer.toString();
      if (!_roomsByCode.containsKey(code)) {
        return code;
      }
    }
  }

  void _rememberSession({required PartyRoom room, required PartyUser user}) {
    _sessionService.remember(
      room: room,
      user: user,
      isRealtime: _isRealtimeSession,
      isRealtimeHostAuthority: _isRealtimeHostAuthority,
    );
  }

  void _logTelemetry({
    required String category,
    required String action,
    required ActionResult result,
    PartyRole? role,
    PartyRoom? room,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    final event = TelemetryEvent(
      timestamp: DateTime.now(),
      category: category,
      action: action,
      success: result.success,
      code: result.code,
      message: result.message,
      role: role?.name,
      roomCode: room?.code,
      metadata: metadata,
    );
    _telemetryEvents.add(event);
    const maxEvents = 300;
    if (_telemetryEvents.length > maxEvents) {
      _telemetryEvents.removeRange(0, _telemetryEvents.length - maxEvents);
    }
    if (_verboseTelemetryLogs && kDebugMode) {
      debugPrint('telemetry ${jsonEncode(event.toJson())}');
    }
  }
}
