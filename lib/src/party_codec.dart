import 'party_engine.dart';

Map<String, dynamic> encodePartyUser(PartyUser user) {
  return <String, dynamic>{
    'id': user.id,
    'name': user.name,
    'avatar': user.avatar,
    'role': user.role.name,
  };
}

PartyUser decodePartyUser(Map<String, dynamic> map) {
  return PartyUser(
    id: (map['id'] ?? '') as String,
    name: (map['name'] ?? 'Gast') as String,
    avatar: (map['avatar'] ?? '😀') as String,
    role: PartyRole.values.firstWhere(
      (value) => value.name == map['role'],
      orElse: () => PartyRole.guest,
    ),
  );
}

Map<String, dynamic> encodeSong(Song song) {
  return <String, dynamic>{
    'id': song.id,
    'title': song.title,
    'artist': song.artist,
    'durationMs': song.duration.inMilliseconds,
    'explicit': song.explicit,
    'genres': song.genres.toList(growable: false),
    'coverEmoji': song.coverEmoji,
  };
}

Song decodeSong(Map<String, dynamic> map) {
  final rawGenres = map['genres'];
  final genres = <String>{};
  if (rawGenres is Iterable) {
    for (final genre in rawGenres) {
      genres.add(genre.toString());
    }
  }
  return Song(
    id: (map['id'] ?? '') as String,
    title: (map['title'] ?? 'Unknown') as String,
    artist: (map['artist'] ?? 'Unknown') as String,
    duration: Duration(milliseconds: ((map['durationMs'] ?? 0) as num).toInt()),
    explicit: (map['explicit'] ?? false) as bool,
    genres: genres,
    coverEmoji: (map['coverEmoji'] ?? '🎵') as String,
  );
}

Map<String, dynamic> encodeQueueItem(QueueItem item) {
  return <String, dynamic>{
    'id': item.id,
    'song': encodeSong(item.song),
    'addedByUserId': item.addedByUserId,
    'addedByName': item.addedByName,
    'addedByAvatar': item.addedByAvatar,
    'addedAtMs': item.addedAt.millisecondsSinceEpoch,
    'votesByUser': item.votesByUser.map(
      (key, value) => MapEntry(key, value.name),
    ),
    'pinned': item.pinned,
    'pinnedAtMs': item.pinnedAt?.millisecondsSinceEpoch,
  };
}

QueueItem decodeQueueItem(Map<String, dynamic> map) {
  final rawVotes = map['votesByUser'];
  final votes = <String, VoteType>{};
  if (rawVotes is Map) {
    rawVotes.forEach((key, value) {
      votes[key.toString()] = VoteType.values.firstWhere(
        (candidate) => candidate.name == value.toString(),
        orElse: () => VoteType.like,
      );
    });
  }
  final pinnedAtMs = map['pinnedAtMs'];
  return QueueItem(
    id: (map['id'] ?? '') as String,
    song: decodeSong(Map<String, dynamic>.from(map['song'] as Map? ?? {})),
    addedByUserId: (map['addedByUserId'] ?? '') as String,
    addedByName: (map['addedByName'] ?? 'Gast') as String,
    addedByAvatar: (map['addedByAvatar'] ?? '😀') as String,
    addedAt: DateTime.fromMillisecondsSinceEpoch(
      ((map['addedAtMs'] ?? 0) as num).toInt(),
    ),
    votesByUser: votes,
    pinned: (map['pinned'] ?? false) as bool,
    pinnedAt: pinnedAtMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch((pinnedAtMs as num).toInt()),
  );
}

Map<String, dynamic> encodeRoomSettings(RoomSettings settings) {
  return <String, dynamic>{
    'sortMode': settings.sortMode.name,
    'cooldownMs': settings.cooldown.inMilliseconds,
    'maxAddsPerWindow': settings.maxAddsPerWindow,
    'addWindowMs': settings.addWindow.inMilliseconds,
    'fairnessMode': settings.fairnessMode,
    'mode': settings.mode.name,
    'blockExplicit': settings.blockExplicit,
    'excludedGenres': settings.excludedGenres.toList(growable: false),
    'votesPaused': settings.votesPaused,
    'hostOnlyAdds': settings.hostOnlyAdds,
    'lockRoom': settings.lockRoom,
    'freezeWindowMs': settings.freezeWindow.inMilliseconds,
  };
}

RoomSettings decodeRoomSettings(Map<String, dynamic> map) {
  final rawGenres = map['excludedGenres'];
  final genres = <String>{};
  if (rawGenres is Iterable) {
    for (final genre in rawGenres) {
      genres.add(genre.toString());
    }
  }
  return RoomSettings(
    sortMode: QueueSortMode.values.firstWhere(
      (value) => value.name == map['sortMode'],
      orElse: () => QueueSortMode.votesOnly,
    ),
    cooldown: Duration(
      milliseconds: ((map['cooldownMs'] ?? 30 * 60 * 1000) as num).toInt(),
    ),
    maxAddsPerWindow: ((map['maxAddsPerWindow'] ?? 3) as num).toInt(),
    addWindow: Duration(
      milliseconds: ((map['addWindowMs'] ?? 10 * 60 * 1000) as num).toInt(),
    ),
    fairnessMode: (map['fairnessMode'] ?? true) as bool,
    mode: RoomMode.values.firstWhere(
      (value) => value.name == map['mode'],
      orElse: () => RoomMode.democratic,
    ),
    blockExplicit: (map['blockExplicit'] ?? false) as bool,
    excludedGenres: genres,
    votesPaused: (map['votesPaused'] ?? false) as bool,
    hostOnlyAdds: (map['hostOnlyAdds'] ?? false) as bool,
    lockRoom: (map['lockRoom'] ?? false) as bool,
    freezeWindow: Duration(
      milliseconds: ((map['freezeWindowMs'] ?? 60 * 1000) as num).toInt(),
    ),
  );
}

Map<String, dynamic> encodePartyRoom(PartyRoom room) {
  return <String, dynamic>{
    'code': room.code,
    'roomName': room.roomName,
    'roomNameLower': room.roomName.toLowerCase(),
    'roomPassword': room.roomPassword,
    'isPublic': room.isPublic,
    'coreSettingsLocked': room.coreSettingsLocked,
    'inviteLink': room.inviteLink,
    'hostUserId': room.hostUserId,
    'createdAtMs': room.createdAt.millisecondsSinceEpoch,
    'participants': room.participants.map(
      (key, value) => MapEntry(key, encodePartyUser(value)),
    ),
    'settings': encodeRoomSettings(room.settings),
    'connectionState': room.connectionState.name,
    'queue': room.queue.map(encodeQueueItem).toList(growable: false),
    'suggestions': room.suggestions
        .map(encodeQueueItem)
        .toList(growable: false),
    'playedHistory': room.playedHistory
        .map(encodeQueueItem)
        .toList(growable: false),
    'cooldownUntilBySongId': room.cooldownUntilBySongId.map(
      (key, value) => MapEntry(key, value.millisecondsSinceEpoch),
    ),
    'addHistoryByUserId': room.addHistoryByUserId.map(
      (key, value) => MapEntry(
        key,
        value
            .map((entry) => entry.millisecondsSinceEpoch)
            .toList(growable: false),
      ),
    ),
    'nowPlaying': room.nowPlaying == null
        ? null
        : encodeQueueItem(room.nowPlaying!),
    'nowPlayingPositionMs': room.nowPlayingPosition.inMilliseconds,
    'lockedNextSongId': room.lockedNextSongId,
    'lastPlayedByUserId': room.lastPlayedByUserId,
    'ended': room.ended,
  };
}

PartyRoom decodePartyRoom(Map<String, dynamic> map) {
  final code = (map['code'] ?? '') as String;
  final rawRoomName = (map['roomName'] ?? '').toString().trim();
  final rawParticipants = Map<String, dynamic>.from(
    map['participants'] as Map? ?? <String, dynamic>{},
  );
  final participants = <String, PartyUser>{};
  rawParticipants.forEach((key, value) {
    participants[key] = decodePartyUser(
      Map<String, dynamic>.from(value as Map),
    );
  });

  final room = PartyRoom(
    code: code,
    roomName: rawRoomName.isEmpty ? 'Party $code' : rawRoomName,
    roomPassword: (map['roomPassword'] ?? '') as String,
    isPublic: (map['isPublic'] ?? false) as bool,
    coreSettingsLocked: (map['coreSettingsLocked'] ?? false) as bool,
    inviteLink: (map['inviteLink'] ?? '') as String,
    hostUserId: (map['hostUserId'] ?? '') as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      ((map['createdAtMs'] ?? 0) as num).toInt(),
    ),
    participants: participants,
    settings: decodeRoomSettings(
      Map<String, dynamic>.from(map['settings'] as Map? ?? {}),
    ),
    connectionState: PlaybackConnectionState.values.firstWhere(
      (value) => value.name == map['connectionState'],
      orElse: () => PlaybackConnectionState.connected,
    ),
  );

  final rawQueue = map['queue'];
  if (rawQueue is Iterable) {
    room.queue.addAll(
      rawQueue.map(
        (entry) => decodeQueueItem(Map<String, dynamic>.from(entry as Map)),
      ),
    );
  }

  final rawSuggestions = map['suggestions'];
  if (rawSuggestions is Iterable) {
    room.suggestions.addAll(
      rawSuggestions.map(
        (entry) => decodeQueueItem(Map<String, dynamic>.from(entry as Map)),
      ),
    );
  }

  final rawHistory = map['playedHistory'];
  if (rawHistory is Iterable) {
    room.playedHistory.addAll(
      rawHistory.map(
        (entry) => decodeQueueItem(Map<String, dynamic>.from(entry as Map)),
      ),
    );
  }

  final rawCooldown = map['cooldownUntilBySongId'];
  if (rawCooldown is Map) {
    rawCooldown.forEach((key, value) {
      room.cooldownUntilBySongId[key.toString()] =
          DateTime.fromMillisecondsSinceEpoch((value as num).toInt());
    });
  }

  final rawAddHistory = map['addHistoryByUserId'];
  if (rawAddHistory is Map) {
    rawAddHistory.forEach((key, value) {
      final history = <DateTime>[];
      if (value is Iterable) {
        for (final stamp in value) {
          history.add(
            DateTime.fromMillisecondsSinceEpoch((stamp as num).toInt()),
          );
        }
      }
      room.addHistoryByUserId[key.toString()] = history;
    });
  }

  final nowPlayingRaw = map['nowPlaying'];
  if (nowPlayingRaw is Map) {
    room.nowPlaying = decodeQueueItem(Map<String, dynamic>.from(nowPlayingRaw));
  }
  room.nowPlayingPosition = Duration(
    milliseconds: ((map['nowPlayingPositionMs'] ?? 0) as num).toInt(),
  );
  room.lockedNextSongId = map['lockedNextSongId'] as String?;
  room.lastPlayedByUserId = map['lastPlayedByUserId'] as String?;
  room.ended = (map['ended'] ?? false) as bool;
  return room;
}
