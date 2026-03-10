import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'src/app_shell.dart';
import 'src/party_engine.dart';
import 'src/realtime_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PartyRealtimeSync? realtimeSync;
  try {
    await Firebase.initializeApp();
    realtimeSync = PartyRealtimeSync();
  } catch (_) {
    realtimeSync = null;
  }
  runApp(PartyQueueApp(engine: PartyEngine(realtimeSync: realtimeSync)));
}
