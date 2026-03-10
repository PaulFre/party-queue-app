import 'package:flutter/material.dart';

import 'party_engine.dart';

const List<String> kAvatarOptions = <String>[
  '😀',
  '😎',
  '🦄',
  '🤖',
  '🦊',
  '🐼',
  '🐯',
  '🐸',
  '🐙',
  '🦁',
];

String formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

void showActionSnackBar(BuildContext context, ActionResult result) {
  final theme = Theme.of(context);
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(result.message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: result.success
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.errorContainer,
    ),
  );
}
