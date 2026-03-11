import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'party_engine.dart';
import 'room_screen.dart';
import 'ui_common.dart';

class PartyQueueApp extends StatelessWidget {
  const PartyQueueApp({super.key, required this.engine});

  final PartyEngine engine;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Party Queue',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0C8E7E),
          brightness: Brightness.light,
        ),
      ),
      home: LandingScreen(engine: engine),
    );
  }
}

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key, required this.engine});

  final PartyEngine engine;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: engine,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF07090F),
          body: SafeArea(
            child: Stack(
              children: [
                const Positioned(
                  top: -120,
                  right: -80,
                  child: _GlowOrb(size: 300),
                ),
                const Positioned(
                  bottom: -140,
                  left: -120,
                  child: _GlowOrb(size: 320),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F4FF),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFF7A3DF3),
                              width: 4,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x557A3DF3),
                                blurRadius: 26,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Logo',
                            style: TextStyle(
                              color: Color(0xFF13151B),
                              fontWeight: FontWeight.w800,
                              fontSize: 28,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Party Queue',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Host erstellt einen Raum. Gaeste joinen in Sekunden.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFB9BCD0),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _PrimaryActionBar(
                        label: 'Host',
                        icon: Icons.home_work_outlined,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => HostSetupScreen(engine: engine),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _PrimaryActionBar(
                        label: 'Gast',
                        icon: Icons.group_add_outlined,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => JoinSetupScreen(engine: engine),
                            ),
                          );
                        },
                      ),
                      if (engine.canSmartRejoin) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            final result = engine.smartRejoin();
                            showActionSnackBar(context, result);
                            if (result.success) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RoomScreen(engine: engine),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text(
                            'Letzte Session wiederherstellen',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xAA111528),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x337A3DF3)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              engine.realtimeAvailable
                                  ? Icons.cloud_done_outlined
                                  : Icons.cloud_off_outlined,
                              color: engine.realtimeAvailable
                                  ? const Color(0xFF6EE7B7)
                                  : const Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                engine.realtimeAvailable
                                    ? 'Realtime Sync aktiv'
                                    : 'Lokalmodus aktiv',
                                style: const TextStyle(
                                  color: Color(0xFFE7E9F4),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [Color(0x447A3DF3), Color(0x117A3DF3), Color(0x007A3DF3)],
          ),
        ),
      ),
    );
  }
}

class _PrimaryActionBar extends StatelessWidget {
  const _PrimaryActionBar({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF5B2CD4), Color(0xFF7A3DF3)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x4D7A3DF3),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: SizedBox(
            height: 58,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HostSetupScreen extends StatefulWidget {
  const HostSetupScreen({super.key, required this.engine});

  final PartyEngine engine;

  @override
  State<HostSetupScreen> createState() => _HostSetupScreenState();
}

class _HostSetupScreenState extends State<HostSetupScreen> {
  static const String _rememberSpotifyCredentialsKey =
      'remember_spotify_credentials';
  static const String _spotifyUsernameKey = 'spotify_username';
  static const String _spotifyPasswordKey = 'spotify_password';

  final TextEditingController _spotifyUserController = TextEditingController();
  final TextEditingController _spotifyPasswordController =
      TextEditingController();
  final TextEditingController _roomNameController = TextEditingController(
    text: 'Meine Party',
  );
  final TextEditingController _roomPasswordController = TextEditingController();
  bool _spotifyConnected = false;
  bool _inviteOnly = true;
  RoomMode _initialRoomMode = RoomMode.democratic;
  QueueSortMode _initialSortMode = QueueSortMode.votesOnly;
  bool _initialFairnessMode = true;
  double _initialCooldownMinutes = 30;
  double _initialFreezeSeconds = 60;
  bool _rememberSpotifyCredentials = false;
  bool _loadingSavedSpotifyCredentials = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadSavedSpotifyCredentials();
  }

  @override
  void dispose() {
    _spotifyUserController.dispose();
    _spotifyPasswordController.dispose();
    _roomNameController.dispose();
    _roomPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSpotifyCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_rememberSpotifyCredentialsKey) ?? false;
    final username = prefs.getString(_spotifyUsernameKey) ?? '';
    final password = prefs.getString(_spotifyPasswordKey) ?? '';
    if (!mounted) {
      return;
    }
    setState(() {
      _rememberSpotifyCredentials = remember;
      _loadingSavedSpotifyCredentials = false;
      if (remember) {
        _spotifyUserController.text = username;
        _spotifyPasswordController.text = password;
      } else {
        _spotifyUserController.clear();
        _spotifyPasswordController.clear();
      }
    });
  }

  Future<void> _persistSpotifyCredentials({
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      _rememberSpotifyCredentialsKey,
      _rememberSpotifyCredentials,
    );
    if (_rememberSpotifyCredentials) {
      await prefs.setString(_spotifyUsernameKey, username);
      await prefs.setString(_spotifyPasswordKey, password);
      return;
    }
    await prefs.remove(_spotifyUsernameKey);
    await prefs.remove(_spotifyPasswordKey);
  }

  Future<void> _connectSpotifyWithCredentials() async {
    final username = _spotifyUserController.text.trim();
    final password = _spotifyPasswordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      showActionSnackBar(
        context,
        ActionResult.fail(
          'Bitte Benutzername und Passwort fuer Spotify angeben.',
        ),
      );
      return;
    }
    await _persistSpotifyCredentials(username: username, password: password);
    if (!mounted) {
      return;
    }
    setState(() => _spotifyConnected = true);
    showActionSnackBar(
      context,
      ActionResult.ok('Spotify-Login fuer "$username" ist aktiv.'),
    );
  }

  void _connectSpotifyWithProvider(String provider) {
    setState(() => _spotifyConnected = true);
    showActionSnackBar(
      context,
      ActionResult.ok('Spotify-Login ueber $provider wurde gestartet (MVP).'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Party hosten')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spotify-Anmeldung',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sie benoetigen einen Spotify Premium Account, um eine Party hosten zu koennen.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ihre Daten werden nicht an Dritte weitergegeben und nur fuer die Anmeldung verwendet.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _spotifyUserController,
                    decoration: const InputDecoration(
                      labelText: 'Spotify Benutzername',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _spotifyPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Spotify Passwort',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _rememberSpotifyCredentials,
                    onChanged: _loadingSavedSpotifyCredentials
                        ? null
                        : (value) => setState(
                            () => _rememberSpotifyCredentials = value ?? false,
                          ),
                    title: const Text(
                      'Login-Daten fuer spaetere Nutzung speichern',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _connectSpotifyWithCredentials,
                          icon: const Icon(Icons.login),
                          label: const Text('Mit Spotify anmelden'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          _spotifyConnected
                              ? 'Premium verbunden'
                              : 'Nicht verbunden',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _connectSpotifyWithProvider('Google'),
                        icon: const Icon(Icons.g_mobiledata),
                        label: const Text('Google'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _connectSpotifyWithProvider('Apple'),
                        icon: const Icon(Icons.apple),
                        label: const Text('Apple'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _connectSpotifyWithProvider('Facebook'),
                        icon: const Icon(Icons.facebook),
                        label: const Text('Facebook'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Raumzugang',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _roomNameController,
                    decoration: const InputDecoration(
                      labelText: 'Raumname',
                      helperText:
                          'Gaeste koennen oeffentliche Parties ueber den Namen suchen.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _roomPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Raumpasswort',
                      helperText: 'Passwort wird immer zum Beitritt benoetigt.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  CheckboxListTile(
                    value: _inviteOnly,
                    onChanged: (value) =>
                        setState(() => _inviteOnly = value ?? true),
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Nur per Invite-Link / QR-Code beitretbar',
                    ),
                    subtitle: Text(
                      _inviteOnly
                          ? 'Party ist nicht ueber die Suche sichtbar.'
                          : 'Party ist oeffentlich suchbar. Passwort bleibt Pflicht.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Initiale Raum-Einstellungen',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Diese Einstellungen sind nach der Raum-Erstellung gesperrt.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<RoomMode>(
                    initialValue: _initialRoomMode,
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
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _initialRoomMode = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<QueueSortMode>(
                    initialValue: _initialSortMode,
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
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _initialSortMode = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: _initialFairnessMode,
                    onChanged: (value) =>
                        setState(() => _initialFairnessMode = value),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fairness-Modus'),
                    subtitle: const Text(
                      'Verhindert mehrere Songs in Folge vom selben Gast.',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cooldown der Songs: ${_initialCooldownMinutes.round()} min',
                  ),
                  Slider(
                    min: 5,
                    max: 120,
                    divisions: 23,
                    value: _initialCooldownMinutes,
                    onChanged: (value) =>
                        setState(() => _initialCooldownMinutes = value),
                  ),
                  Text('Freeze-Fenster: ${_initialFreezeSeconds.round()} sek'),
                  Slider(
                    min: 15,
                    max: 120,
                    divisions: 21,
                    value: _initialFreezeSeconds,
                    onChanged: (value) =>
                        setState(() => _initialFreezeSeconds = value),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: Icon(
                widget.engine.realtimeAvailable
                    ? Icons.sync
                    : Icons.sync_problem_outlined,
              ),
              title: const Text('Firebase Realtime Sync'),
              subtitle: Text(
                widget.engine.realtimeAvailable
                    ? 'Automatisch aktiv. Mehrgeraete-Sync wird immer verwendet.'
                    : 'Aktuell nicht verfuegbar. Es wird lokal gehostet.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSubmitting
                ? null
                : () async {
                    setState(() => _isSubmitting = true);
                    final initialSettings = RoomSettings(
                      mode: _initialRoomMode,
                      sortMode: _initialSortMode,
                      fairnessMode: _initialFairnessMode,
                      cooldown: Duration(
                        minutes: _initialCooldownMinutes.round(),
                      ),
                      freezeWindow: Duration(
                        seconds: _initialFreezeSeconds.round(),
                      ),
                    );
                    final result = widget.engine.realtimeAvailable
                        ? await widget.engine.createRoomRealtime(
                            hostName: 'Host',
                            hostAvatar: kAvatarOptions.first,
                            spotifyConnected: _spotifyConnected,
                            roomName: _roomNameController.text,
                            roomPassword: _roomPasswordController.text,
                            inviteOnly: _inviteOnly,
                            initialSettings: initialSettings,
                          )
                        : widget.engine.createRoom(
                            hostName: 'Host',
                            hostAvatar: kAvatarOptions.first,
                            spotifyConnected: _spotifyConnected,
                            roomName: _roomNameController.text,
                            roomPassword: _roomPasswordController.text,
                            inviteOnly: _inviteOnly,
                            initialSettings: initialSettings,
                          );
                    if (!context.mounted) {
                      return;
                    }
                    setState(() => _isSubmitting = false);
                    showActionSnackBar(context, result);
                    if (result.success) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) =>
                              HostProfileSetupScreen(engine: widget.engine),
                        ),
                      );
                    }
                  },
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.rocket_launch_outlined),
            label: Text(_isSubmitting ? 'Erstelle...' : 'Raum erstellen'),
          ),
        ],
      ),
    );
  }
}

class HostProfileSetupScreen extends StatefulWidget {
  const HostProfileSetupScreen({super.key, required this.engine});

  final PartyEngine engine;

  @override
  State<HostProfileSetupScreen> createState() => _HostProfileSetupScreenState();
}

class _HostProfileSetupScreenState extends State<HostProfileSetupScreen> {
  static const Map<String, String> _playlistPresetLabels = <String, String>{
    'party_hits': 'Party Hits',
    'dance_mix': 'Dance Mix',
    'urban_mix': 'Urban Mix',
    'chill_mix': 'Chill Mix',
  };

  final TextEditingController _nameController = TextEditingController(
    text: 'Host',
  );
  String _avatar = kAvatarOptions.first;
  bool _importSpotifyPlaylist = false;
  String _selectedPlaylistPreset = 'party_hits';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.engine.currentRoom;
    if (room == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Host-Profil')),
        body: const Center(child: Text('Kein aktiver Raum.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Host-Profil festlegen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Raum "${room.roomName}" wurde erstellt. '
                'Waehle jetzt deinen Host-Namen und Avatar.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Host-Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          AvatarPicker(
            selected: _avatar,
            onSelected: (avatar) => setState(() => _avatar = avatar),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _importSpotifyPlaylist,
            onChanged: (value) =>
                setState(() => _importSpotifyPlaylist = value),
            contentPadding: EdgeInsets.zero,
            title: const Text('Spotify-Playlist in die Start-Queue laden'),
            subtitle: const Text(
              'Waehle eine vorhandene Playlist aus deinem Spotify-Account (MVP-Auswahl).',
            ),
          ),
          if (_importSpotifyPlaylist) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedPlaylistPreset,
              decoration: const InputDecoration(
                labelText: 'Playlist',
                border: OutlineInputBorder(),
              ),
              items: _playlistPresetLabels.entries
                  .map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedPlaylistPreset = value);
                }
              },
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSubmitting
                ? null
                : () {
                    setState(() => _isSubmitting = true);
                    final result = widget.engine.updateCurrentProfile(
                      name: _nameController.text,
                      avatar: _avatar,
                    );
                    if (!mounted) {
                      return;
                    }
                    if (result.success && _importSpotifyPlaylist) {
                      final preloadResult = widget.engine.preloadQueueFromSongs(
                        _buildStarterPlaylistSongs(),
                      );
                      showActionSnackBar(context, preloadResult);
                    }
                    setState(() => _isSubmitting = false);
                    showActionSnackBar(context, result);
                    if (result.success) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => RoomScreen(engine: widget.engine),
                        ),
                      );
                    }
                  },
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.meeting_room_outlined),
            label: Text(_isSubmitting ? 'Speichere...' : 'Raum betreten'),
          ),
        ],
      ),
    );
  }

  List<Song> _buildStarterPlaylistSongs() {
    final byId = <String, Song>{};
    void addSongs(Iterable<Song> songs) {
      for (final song in songs) {
        byId.putIfAbsent(song.id, () => song);
      }
    }

    switch (_selectedPlaylistPreset) {
      case 'dance_mix':
        addSongs(widget.engine.searchSongs('dance'));
        addSongs(widget.engine.searchSongs('house'));
        addSongs(widget.engine.searchSongs('electronic'));
        break;
      case 'urban_mix':
        addSongs(widget.engine.searchSongs('hiphop'));
        addSongs(widget.engine.searchSongs('afrobeats'));
        addSongs(widget.engine.searchSongs('latin'));
        break;
      case 'chill_mix':
        addSongs(widget.engine.searchSongs('indie'));
        addSongs(widget.engine.searchSongs('pop'));
        break;
      case 'party_hits':
        addSongs(widget.engine.trendingSongs);
        addSongs(widget.engine.searchSongs('pop'));
        break;
    }
    addSongs(widget.engine.trendingSongs);
    return byId.values.take(20).toList(growable: false);
  }
}

enum _JoinStage { access, profile }

enum _JoinAsyncState { idle, loading, error }

enum _JoinAction { verifyAccess, joinRoom }

class JoinSetupScreen extends StatefulWidget {
  const JoinSetupScreen({super.key, required this.engine});

  final PartyEngine engine;

  @override
  State<JoinSetupScreen> createState() => _JoinSetupScreenState();
}

class _JoinSetupScreenState extends State<JoinSetupScreen> {
  final TextEditingController _joinController = TextEditingController();
  final TextEditingController _roomPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController(
    text: 'Gast',
  );
  String _avatar = kAvatarOptions[1];
  _JoinStage _stage = _JoinStage.access;
  _JoinAsyncState _asyncState = _JoinAsyncState.idle;
  _JoinAction _lastAction = _JoinAction.verifyAccess;
  ActionResult? _lastJoinError;
  String? _roomLookupMessage;

  bool get _isSubmitting => _asyncState == _JoinAsyncState.loading;
  bool get _showProfileStep => _stage == _JoinStage.profile;

  @override
  void dispose() {
    _joinController.dispose();
    _roomPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Party beitreten')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_showProfileStep) ...[
            TextField(
              controller: _joinController,
              decoration: const InputDecoration(
                labelText: 'Code, Invite-Link oder Party-Name',
                helperText:
                    'Nach oeffentlichen Raeumen kannst du ueber den Namen suchen. '
                    'Wenn lokal genau ein Raum aktiv ist, kannst du das Feld leer lassen.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _roomPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Raumpasswort',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Card(
            child: ListTile(
              leading: Icon(
                widget.engine.realtimeAvailable
                    ? Icons.sync
                    : Icons.sync_problem_outlined,
              ),
              title: const Text('Firebase Realtime Sync'),
              subtitle: Text(
                widget.engine.realtimeAvailable
                    ? 'Automatisch aktiv. Beitritt erfolgt immer als Live-Session.'
                    : 'Aktuell nicht verfuegbar. Beitritt erfolgt lokal.',
              ),
            ),
          ),
          if (_lastJoinError != null && _asyncState == _JoinAsyncState.error) ...[
            const SizedBox(height: 10),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: Text(_lastJoinError!.message),
                subtitle: Text('Fehlercode: ${_lastJoinError!.code}'),
                trailing: TextButton(
                  onPressed: _isSubmitting ? null : _retryLastAction,
                  child: const Text('Erneut versuchen'),
                ),
              ),
            ),
          ],
          if (_isSubmitting) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          if (_showProfileStep) ...[
            const SizedBox(height: 10),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(_roomLookupMessage ?? 'Raum gefunden.'),
                subtitle: const Text(
                  'Waehle jetzt deinen Namen und Avatar fuer den Beitritt.',
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Dein Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            AvatarPicker(
              selected: _avatar,
              onSelected: (avatar) => setState(() => _avatar = avatar),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _isSubmitting
                      ? null
                      : (_showProfileStep ? _joinNow : _verifyRoomAccess),
                  child: Text(
                    _isSubmitting
                        ? (_showProfileStep ? 'Verbinde...' : 'Pruefe...')
                        : (_showProfileStep ? 'Beitreten' : 'Weiter'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : _showProfileStep
                    ? () => setState(() {
                        _stage = _JoinStage.access;
                        _asyncState = _JoinAsyncState.idle;
                        _lastJoinError = null;
                      })
                    : () async {
                        final raw = await Navigator.of(context).push<String>(
                          MaterialPageRoute(
                            builder: (_) => const QrJoinScannerScreen(),
                          ),
                        );
                        if (raw != null && raw.isNotEmpty) {
                          _joinController.text = raw;
                          if (context.mounted) {
                            await _verifyRoomAccess();
                          }
                        }
                      },
                icon: Icon(
                  _showProfileStep ? Icons.arrow_back : Icons.qr_code_scanner,
                ),
                label: Text(_showProfileStep ? 'Zurueck' : 'QR'),
              ),
            ],
          ),
          if (!_showProfileStep && kDebugMode) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isSubmitting ? null : _joinAsGuestForTesting,
                icon: const Icon(Icons.science_outlined),
                label: const Text('Gast-Testzugang ohne Raumcode'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _verifyRoomAccess() async {
    setState(() {
      _asyncState = _JoinAsyncState.loading;
      _lastAction = _JoinAction.verifyAccess;
      _lastJoinError = null;
    });
    final result = widget.engine.realtimeAvailable
        ? await widget.engine.verifyJoinAccessRealtime(
            joinInput: _joinController.text,
            roomPassword: _roomPasswordController.text,
          )
        : widget.engine.verifyJoinAccess(
            joinInput: _joinController.text,
            roomPassword: _roomPasswordController.text,
          );
    if (!mounted) {
      return;
    }
    if (!result.success) {
      final mappedError = _mapJoinError(result);
      setState(() {
        _asyncState = _JoinAsyncState.error;
        _lastJoinError = mappedError;
      });
      showActionSnackBar(context, mappedError);
      return;
    }
    setState(() => _asyncState = _JoinAsyncState.idle);
    showActionSnackBar(context, result);
    if (result.success) {
      setState(() {
        _roomLookupMessage = result.message;
        _stage = _JoinStage.profile;
      });
    }
  }

  Future<void> _joinNow() async {
    setState(() {
      _asyncState = _JoinAsyncState.loading;
      _lastAction = _JoinAction.joinRoom;
      _lastJoinError = null;
    });
    final result = widget.engine.realtimeAvailable
        ? await widget.engine.joinRoomRealtime(
            guestName: _nameController.text,
            guestAvatar: _avatar,
            joinInput: _joinController.text,
            roomPassword: _roomPasswordController.text,
          )
        : widget.engine.joinRoom(
            guestName: _nameController.text,
            guestAvatar: _avatar,
            joinInput: _joinController.text,
            roomPassword: _roomPasswordController.text,
          );
    if (!mounted) {
      return;
    }
    if (!result.success) {
      final mappedError = _mapJoinError(result);
      setState(() {
        _asyncState = _JoinAsyncState.error;
        _lastJoinError = mappedError;
      });
      showActionSnackBar(context, mappedError);
      return;
    }
    setState(() => _asyncState = _JoinAsyncState.idle);
    showActionSnackBar(context, result);
    if (result.success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => RoomScreen(engine: widget.engine)),
      );
    }
  }

  void _joinAsGuestForTesting() {
    setState(() {
      _asyncState = _JoinAsyncState.loading;
      _lastJoinError = null;
    });
    final result = widget.engine.joinAsGuestForTesting(
      guestName: _nameController.text,
      guestAvatar: _avatar,
    );
    if (!mounted) {
      return;
    }
    setState(() => _asyncState = _JoinAsyncState.idle);
    showActionSnackBar(context, result);
    if (result.success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => RoomScreen(engine: widget.engine)),
      );
    }
  }

  Future<void> _retryLastAction() async {
    if (_lastAction == _JoinAction.joinRoom) {
      await _joinNow();
      return;
    }
    await _verifyRoomAccess();
  }

  ActionResult _mapJoinError(ActionResult result) {
    switch (result.code) {
      case PartyErrorCode.roomPasswordRequired:
        return ActionResult.fail(
          'Bitte gib zuerst das Raumpasswort ein.',
          code: result.code,
        );
      case PartyErrorCode.roomPasswordInvalid:
        return ActionResult.fail(
          'Das Raumpasswort ist falsch. Bitte pruefe die Eingabe.',
          code: result.code,
        );
      case PartyErrorCode.roomLocked:
        return ActionResult.fail(
          'Der Raum ist aktuell gesperrt. Bitte spaeter erneut versuchen.',
          code: result.code,
        );
      case PartyErrorCode.roomEnded:
        return ActionResult.fail(
          'Diese Party ist bereits beendet. Bitte einem aktiven Raum beitreten.',
          code: result.code,
        );
      case PartyErrorCode.roomLookupNoActive:
        return ActionResult.fail(
          'Kein aktiver Raum gefunden. Bitte Code/Link eingeben oder zuerst als Host starten.',
          code: result.code,
        );
      case PartyErrorCode.roomLookupMultipleActive:
        return ActionResult.fail(
          'Mehrere Raeume gefunden. Bitte verwende den exakten Code oder Invite-Link.',
          code: result.code,
        );
      case PartyErrorCode.roomLookupAmbiguous:
        return ActionResult.fail(
          'Mehrere Treffer gefunden. Bitte mit Raumcode oder Invite-Link fortfahren.',
          code: result.code,
        );
      case PartyErrorCode.realtimeUnavailable:
        return ActionResult.fail(
          'Realtime ist aktuell nicht verfuegbar. Bitte lokal beitreten.',
          code: result.code,
        );
      case PartyErrorCode.realtimeAuthFailed:
      case PartyErrorCode.realtimeAuthMissingUserId:
        return ActionResult.fail(
          'Realtime-Anmeldung fehlgeschlagen. Bitte kurz warten und erneut versuchen.',
          code: result.code,
        );
    }
    return result;
  }
}

class QrJoinScannerScreen extends StatefulWidget {
  const QrJoinScannerScreen({super.key});

  @override
  State<QrJoinScannerScreen> createState() => _QrJoinScannerScreenState();
}

class _QrJoinScannerScreenState extends State<QrJoinScannerScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR-Code scannen')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_handled) {
            return;
          }
          for (final code in capture.barcodes) {
            final raw = code.rawValue;
            if (raw != null && raw.isNotEmpty) {
              _handled = true;
              Navigator.of(context).pop(raw);
              return;
            }
          }
        },
      ),
    );
  }
}

class AvatarPicker extends StatelessWidget {
  const AvatarPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kAvatarOptions
          .map((avatar) {
            final isSelected = avatar == selected;
            return ChoiceChip(
              label: Text(avatar, style: const TextStyle(fontSize: 20)),
              selected: isSelected,
              onSelected: (_) => onSelected(avatar),
            );
          })
          .toList(growable: false),
    );
  }
}
