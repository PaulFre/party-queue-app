import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'party_engine.dart';
import 'ui_common.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.engine});

  final PartyEngine engine;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.engine,
      builder: (context, _) {
        final room = widget.engine.currentRoom;
        final user = widget.engine.currentUser;
        if (room == null || user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Party')),
            body: const Center(child: Text('Kein aktiver Raum.')),
          );
        }
        final isHost = room.hostUserId == user.id;
        final hostName = room.participants[room.hostUserId]?.name ?? 'Host';
        final queue = widget.engine.orderedQueue;
        final searchResults = widget.engine.searchSongs(_searchController.text);
        final recommendations = widget.engine.recommendedSongsForCurrentQueue(
          limit: 5,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text('${room.roomName} von $hostName'),
            actions: [
              IconButton(
                tooltip: 'Raum verlassen',
                onPressed: () {
                  widget.engine.leaveRoom();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.exit_to_app),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _buildNowNextCard(room, isHost),
              _buildLiveQueueCard(room, user, isHost, queue),
              _buildSearchCard(room, isHost, searchResults, recommendations),
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _bottomAction(
                      icon: Icons.link_outlined,
                      label: 'Join',
                      onTap: () => _openJoinOptionsSheet(room),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _bottomAction(
                      icon: Icons.group_outlined,
                      label: 'Gaeste',
                      onTap: () => _openGuestsSheet(isHost),
                    ),
                  ),
                  if (isHost) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _bottomAction(
                        icon: Icons.tune,
                        label: 'Einstellungen',
                        onTap: _openHostSettingsSheet,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNowNextCard(PartyRoom room, bool isHost) {
    final now = room.nowPlaying;
    final next = widget.engine.nextSong;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jetzt laeuft',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(now == null ? 'Kein Song' : now.song.title),
              subtitle: Text(now == null ? '-' : now.song.artist),
              trailing: isHost && now != null
                  ? IconButton(
                      onPressed: () =>
                          _handleAction(widget.engine.skipNowPlaying()),
                      icon: const Icon(Icons.skip_next),
                    )
                  : null,
            ),
            const Divider(),
            Text(
              'Als naechstes: ${next == null ? 'Noch leer' : next.song.title}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveQueueCard(
    PartyRoom room,
    PartyUser user,
    bool isHost,
    List<QueueItem> queue,
  ) {
    final topTen = queue.take(10).toList(growable: false);
    final canVote = !room.settings.votesPaused || isHost;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Live-Warteschlange',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: queue.isEmpty ? null : _openFullQueueSheet,
                  child: const Text('Voll anzeigen'),
                ),
              ],
            ),
            Text(
              '${queue.length} Song(s) · Laufzeit ${formatDuration(_queueDuration(queue))}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (topTen.isEmpty)
              const Text('Noch keine Songs.')
            else
              ...topTen.asMap().entries.map((entry) {
                final pos = entry.key + 1;
                final item = entry.value;
                final currentVote = item.votesByUser[user.id];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('$pos. ${item.song.title}'),
                          subtitle: Text(item.song.artist),
                          trailing: Text('Score ${item.score}'),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: canVote
                                  ? () => _handleAction(
                                      widget.engine.voteOnSong(
                                        queueItemId: item.id,
                                        vote: VoteType.like,
                                      ),
                                      showSuccess: false,
                                    )
                                  : null,
                              icon: Icon(
                                Icons.thumb_up_alt_outlined,
                                color: currentVote == VoteType.like
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                            Text('Like ${item.likes}'),
                            const SizedBox(width: 10),
                            IconButton(
                              onPressed: canVote
                                  ? () => _handleAction(
                                      widget.engine.voteOnSong(
                                        queueItemId: item.id,
                                        vote: VoteType.dislike,
                                      ),
                                      showSuccess: false,
                                    )
                                  : null,
                              icon: Icon(
                                Icons.thumb_down_alt_outlined,
                                color: currentVote == VoteType.dislike
                                    ? Theme.of(context).colorScheme.error
                                    : null,
                              ),
                            ),
                            Text('Dislike ${item.dislikes}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard(
    PartyRoom room,
    bool isHost,
    List<Song> searchResults,
    List<Song> recommendations,
  ) {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spotify-Suche',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Song oder Artist suchen',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            if (hasQuery) ...[
              const SizedBox(height: 8),
              ...searchResults.take(5).map((song) {
                return _songTile(room, isHost, song);
              }),
            ],
            const SizedBox(height: 8),
            Text(
              'Empfohlen (5)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            ...recommendations.map((song) => _songTile(room, isHost, song)),
          ],
        ),
      ),
    );
  }

  Widget _songTile(PartyRoom room, bool isHost, Song song) {
    final eligibility = widget.engine.canAddSong(song);
    final label = room.settings.mode == RoomMode.suggestionsOnly && !isHost
        ? 'Vorschlagen'
        : 'Hinzufuegen';
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(song.title),
      subtitle: Text(song.artist),
      trailing: FilledButton(
        onPressed: eligibility.allowed
            ? () => _handleAction(widget.engine.addSong(song))
            : null,
        child: Text(label),
      ),
    );
  }

  Widget _bottomAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 74,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  void _openJoinOptionsSheet(PartyRoom room) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Join-Optionen',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              SelectableText('Raumname: ${room.roomName}'),
              SelectableText('Raumcode: ${room.code}'),
              SelectableText('Raumpasswort: ${room.roomPassword}'),
              Row(
                children: [
                  Expanded(child: SelectableText('Link: ${room.inviteLink}')),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: room.inviteLink));
                      showActionSnackBar(
                        context,
                        ActionResult.ok('Invite-Link kopiert.'),
                      );
                    },
                    icon: const Icon(Icons.copy_outlined),
                  ),
                ],
              ),
              Text(
                room.isPublic
                    ? 'Sichtbarkeit: oeffentlich suchbar.'
                    : 'Sichtbarkeit: nur Invite/QR.',
              ),
              const SizedBox(height: 10),
              Center(child: QrImageView(data: room.inviteLink, size: 140)),
            ],
          ),
        );
      },
    );
  }

  void _openGuestsSheet(bool isHost) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return AnimatedBuilder(
          animation: widget.engine,
          builder: (context, _) {
            final room = widget.engine.currentRoom;
            if (room == null) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Kein aktiver Raum.'),
              );
            }
            final participants = widget.engine.participants;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Gaeste (${participants.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ...participants.map((p) {
                  final isParticipantHost = p.id == room.hostUserId;
                  return ListTile(
                    leading: Text(p.avatar),
                    title: Text(p.name),
                    subtitle: Text(isParticipantHost ? 'Host' : 'Gast'),
                    trailing: isHost && !isParticipantHost
                        ? IconButton(
                            onPressed: () => _handleAction(
                              widget.engine.kickParticipant(p.id),
                            ),
                            icon: const Icon(Icons.person_remove_outlined),
                          )
                        : null,
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  void _openHostSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return AnimatedBuilder(
          animation: widget.engine,
          builder: (context, _) {
            final room = widget.engine.currentRoom;
            if (room == null) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Kein aktiver Raum.'),
              );
            }
            final coreLocked = room.coreSettingsLocked;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Host-Einstellungen',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (coreLocked)
                  const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(
                      'Raum-Modus, Sortierlogik, Fairness, Cooldown und Freeze sind fixiert.',
                    ),
                  ),
                DropdownButtonFormField<RoomMode>(
                  initialValue: room.settings.mode,
                  decoration: const InputDecoration(
                    labelText: 'Raum-Modus',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: RoomMode.democratic,
                      child: Text('Demokratisch'),
                    ),
                    DropdownMenuItem(
                      value: RoomMode.suggestionsOnly,
                      child: Text('Nur Vorschlaege'),
                    ),
                  ],
                  onChanged: coreLocked
                      ? null
                      : (value) {
                          if (value != null) {
                            _handleAction(widget.engine.setRoomMode(value));
                          }
                        },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<QueueSortMode>(
                  initialValue: room.settings.sortMode,
                  decoration: const InputDecoration(
                    labelText: 'Sortierlogik',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: QueueSortMode.votesOnly,
                      child: Text('Likes - Dislikes'),
                    ),
                    DropdownMenuItem(
                      value: QueueSortMode.votesWithAgeBoost,
                      child: Text('Likes - Dislikes + Altersbonus'),
                    ),
                  ],
                  onChanged: coreLocked
                      ? null
                      : (value) {
                          if (value != null) {
                            _handleAction(widget.engine.setSortMode(value));
                          }
                        },
                ),
                SwitchListTile(
                  value: room.settings.fairnessMode,
                  onChanged: coreLocked
                      ? null
                      : (value) => _handleAction(
                          widget.engine.setFairnessMode(value),
                          showSuccess: false,
                        ),
                  title: const Text('Fairness-Modus'),
                ),
                SwitchListTile(
                  value: room.settings.blockExplicit,
                  onChanged: (value) => _handleAction(
                    widget.engine.setBlockExplicit(value),
                    showSuccess: false,
                  ),
                  title: const Text('Explizite Inhalte blockieren'),
                ),
                SwitchListTile(
                  value: room.settings.votesPaused,
                  onChanged: (value) => _handleAction(
                    widget.engine.setVotesPaused(value),
                    showSuccess: false,
                  ),
                  title: const Text('Votes pausieren'),
                ),
                SwitchListTile(
                  value: room.settings.hostOnlyAdds,
                  onChanged: (value) => _handleAction(
                    widget.engine.setHostOnlyAdds(value),
                    showSuccess: false,
                  ),
                  title: const Text('Nur Host darf Songs adden'),
                ),
                SwitchListTile(
                  value: room.settings.lockRoom,
                  onChanged: (value) => _handleAction(
                    widget.engine.setRoomLocked(value),
                    showSuccess: false,
                  ),
                  title: const Text('Raum sperren'),
                ),
                const SizedBox(height: 8),
                Text('Cooldown: ${room.settings.cooldown.inMinutes} min'),
                Slider(
                  min: 5,
                  max: 120,
                  divisions: 23,
                  value: room.settings.cooldown.inMinutes.toDouble(),
                  onChanged: coreLocked
                      ? null
                      : (value) => _handleAction(
                          widget.engine.setCooldownMinutes(value.round()),
                          showSuccess: false,
                        ),
                ),
                Text(
                  'Anti-Spam: max. ${room.settings.maxAddsPerWindow} Song(s) in '
                  '${room.settings.addWindow.inMinutes} min',
                ),
                Slider(
                  min: 1,
                  max: 10,
                  divisions: 9,
                  value: room.settings.maxAddsPerWindow.toDouble(),
                  onChanged: (value) => _handleAction(
                    widget.engine.setAntiSpamLimit(value.round()),
                    showSuccess: false,
                  ),
                ),
                Slider(
                  min: 5,
                  max: 30,
                  divisions: 25,
                  value: room.settings.addWindow.inMinutes.toDouble(),
                  label: '${room.settings.addWindow.inMinutes} min',
                  onChanged: (value) => _handleAction(
                    widget.engine.setAntiSpamWindowMinutes(value.round()),
                    showSuccess: false,
                  ),
                ),
                Text(
                  'Freeze-Fenster: ${room.settings.freezeWindow.inSeconds} sek',
                ),
                Slider(
                  min: 15,
                  max: 120,
                  divisions: 21,
                  value: room.settings.freezeWindow.inSeconds.toDouble(),
                  onChanged: coreLocked
                      ? null
                      : (value) => _handleAction(
                          widget.engine.setFreezeWindowSeconds(value.round()),
                          showSuccess: false,
                        ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Genres ausschliessen',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.engine.availableGenres
                      .map((genre) {
                        final excluded = room.settings.excludedGenres.contains(
                          genre,
                        );
                        return FilterChip(
                          label: Text(genre),
                          selected: excluded,
                          onSelected: (value) => _handleAction(
                            widget.engine.setGenreExcluded(genre, value),
                            showSuccess: false,
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          _handleAction(widget.engine.simulateTokenExpired()),
                      icon: const Icon(Icons.key_off),
                      label: const Text('Token ablaufen lassen'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _handleAction(widget.engine.simulateDeviceLost()),
                      icon: const Icon(Icons.speaker_notes_off),
                      label: const Text('Device verlieren'),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        final export = widget.engine
                            .endPartyAndGeneratePlaylist();
                        if (export == null) {
                          _handleAction(
                            ActionResult.fail(
                              'Playlist konnte nicht erzeugt werden.',
                            ),
                          );
                          return;
                        }
                        _showPlaylistDialog(export);
                      },
                      icon: const Icon(Icons.playlist_add_check),
                      label: const Text('Party beenden + Playlist'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openFullQueueSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return AnimatedBuilder(
          animation: widget.engine,
          builder: (context, _) {
            final room = widget.engine.currentRoom;
            final user = widget.engine.currentUser;
            final queue = widget.engine.orderedQueue;
            if (room == null || user == null) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Kein aktiver Raum.'),
              );
            }
            final isHost = room.hostUserId == user.id;
            final canVote = !room.settings.votesPaused || isHost;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Vollstaendige Warteliste',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ...queue.map((item) {
                  final currentVote = item.votesByUser[user.id];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.song.title),
                    subtitle: Text(item.song.artist),
                    trailing: Wrap(
                      spacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          onPressed: canVote
                              ? () => _handleAction(
                                  widget.engine.voteOnSong(
                                    queueItemId: item.id,
                                    vote: VoteType.like,
                                  ),
                                  showSuccess: false,
                                )
                              : null,
                          icon: Icon(
                            Icons.thumb_up_alt_outlined,
                            color: currentVote == VoteType.like
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                        IconButton(
                          onPressed: canVote
                              ? () => _handleAction(
                                  widget.engine.voteOnSong(
                                    queueItemId: item.id,
                                    vote: VoteType.dislike,
                                  ),
                                  showSuccess: false,
                                )
                              : null,
                          icon: Icon(
                            Icons.thumb_down_alt_outlined,
                            color: currentVote == VoteType.dislike
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                        ),
                        Text('Score ${item.score}'),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  Duration _queueDuration(List<QueueItem> queue) {
    var duration = Duration.zero;
    for (final item in queue) {
      duration += item.song.duration;
    }
    return duration;
  }

  void _showPlaylistDialog(PlaylistExport export) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(export.playlistName),
          content: SizedBox(
            width: 360,
            child: export.songs.isEmpty
                ? const Text('Noch keine gespielten Songs.')
                : ListView(
                    shrinkWrap: true,
                    children: export.songs
                        .map((song) {
                          return ListTile(
                            dense: true,
                            title: Text(song.title),
                            subtitle: Text(song.artist),
                          );
                        })
                        .toList(growable: false),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Schliessen'),
            ),
          ],
        );
      },
    );
  }

  void _handleAction(ActionResult result, {bool showSuccess = true}) {
    if (!mounted) {
      return;
    }
    if (!result.success || showSuccess) {
      showActionSnackBar(context, result);
    }
    setState(() {});
  }
}
