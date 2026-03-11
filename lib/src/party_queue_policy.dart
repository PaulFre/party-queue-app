part of 'party_engine.dart';

class QueuePolicyService {
  List<QueueItem> orderedQueue(PartyRoom room, {DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();
    final pinned = room.queue.where((item) => item.pinned).toList();
    final dynamicItems = room.queue.where((item) => !item.pinned).toList();

    pinned.sort((a, b) {
      final aPinnedAt = a.pinnedAt ?? a.addedAt;
      final bPinnedAt = b.pinnedAt ?? b.addedAt;
      final pinCompare = aPinnedAt.compareTo(bPinnedAt);
      if (pinCompare != 0) {
        return pinCompare;
      }
      return b.score.compareTo(a.score);
    });

    dynamicItems.sort((a, b) {
      final scoreCompare = _rankForOrdering(
        b,
        room,
        effectiveNow,
      ).compareTo(_rankForOrdering(a, room, effectiveNow));
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return a.addedAt.compareTo(b.addedAt);
    });

    final previousAdder = room.nowPlaying?.addedByUserId ?? room.lastPlayedByUserId;
    final fairItems = room.settings.fairnessMode
        ? _applyFairness(dynamicItems, previousAdder)
        : dynamicItems;

    final ordered = <QueueItem>[...pinned, ...fairItems];
    if (room.lockedNextSongId != null) {
      final lockIndex = ordered.indexWhere((item) => item.id == room.lockedNextSongId);
      if (lockIndex > 0) {
        final lockedItem = ordered.removeAt(lockIndex);
        ordered.insert(0, lockedItem);
      }
    }
    return ordered;
  }

  bool songExists({required PartyRoom room, required String songId}) {
    if (room.nowPlaying?.song.id == songId) {
      return true;
    }
    if (room.queue.any((item) => item.song.id == songId)) {
      return true;
    }
    if (room.suggestions.any((item) => item.song.id == songId)) {
      return true;
    }
    return false;
  }

  double _rankForOrdering(QueueItem item, PartyRoom room, DateTime now) {
    var score = item.score.toDouble();
    if (room.settings.sortMode == QueueSortMode.votesWithAgeBoost) {
      final ageSeconds = now.difference(item.addedAt).inSeconds;
      score += (ageSeconds / 120).clamp(0, 5);
    }
    return score;
  }

  List<QueueItem> _applyFairness(
    List<QueueItem> sorted,
    String? previousAdder,
  ) {
    if (sorted.length <= 1) {
      return sorted;
    }
    final pool = List<QueueItem>.from(sorted);
    final result = <QueueItem>[];
    var lastAdder = previousAdder;
    while (pool.isNotEmpty) {
      final nextIndex = pool.indexWhere((item) => item.addedByUserId != lastAdder);
      final indexToTake = nextIndex == -1 ? 0 : nextIndex;
      final next = pool.removeAt(indexToTake);
      result.add(next);
      lastAdder = next.addedByUserId;
    }
    return result;
  }
}
