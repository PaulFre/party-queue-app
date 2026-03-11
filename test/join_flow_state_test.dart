import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/app_shell.dart';
import 'package:party_queue_app/src/party_engine.dart';

void main() {
  testWidgets('join flow exposes retry CTA on access verification errors', (
    WidgetTester tester,
  ) async {
    final engine = PartyEngine();
    final created = engine.createRoom(
      hostName: 'Host',
      hostAvatar: 'A',
      spotifyConnected: true,
      roomName: 'Join Retry Party',
      roomPassword: '1234',
      inviteOnly: true,
      initialSettings: const RoomSettings(),
    );
    expect(created.success, isTrue);

    await tester.pumpWidget(PartyQueueApp(engine: engine));
    await tester.tap(find.text('Gast'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();

    expect(find.text('Erneut versuchen'), findsOneWidget);
    expect(find.textContaining('Fehlercode:'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    engine.dispose();
  });

  testWidgets('join flow transitions to profile step after successful verify', (
    WidgetTester tester,
  ) async {
    final engine = PartyEngine();
    final created = engine.createRoom(
      hostName: 'Host',
      hostAvatar: 'A',
      spotifyConnected: true,
      roomName: 'Join Success Party',
      roomPassword: '1234',
      inviteOnly: true,
      initialSettings: const RoomSettings(),
    );
    expect(created.success, isTrue);

    await tester.pumpWidget(PartyQueueApp(engine: engine));
    await tester.tap(find.text('Gast'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), '1234');
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();

    expect(find.text('Dein Name'), findsOneWidget);
    expect(find.text('Beitreten'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    engine.dispose();
  });
}
