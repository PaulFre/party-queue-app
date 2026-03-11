import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/app_shell.dart';
import 'package:party_queue_app/src/party_engine.dart';

void main() {
  testWidgets('landing screen renders host and join actions', (
    WidgetTester tester,
  ) async {
    final engine = PartyEngine();

    await tester.pumpWidget(PartyQueueApp(engine: engine));

    expect(find.text('Party Queue'), findsOneWidget);
    expect(find.text('Host'), findsOneWidget);
    expect(find.text('Gast'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    engine.dispose();
  });
}
