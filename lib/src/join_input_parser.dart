String extractRoomCode(String input) {
  final raw = input.trim();
  if (raw.isEmpty) {
    return '';
  }
  final uri = Uri.tryParse(raw);
  if (uri != null && uri.pathSegments.isNotEmpty) {
    final candidate = uri.pathSegments.last.toUpperCase();
    if (_roomCodePattern.hasMatch(candidate)) {
      return candidate;
    }
  }
  final upper = raw.toUpperCase();
  if (_roomCodePattern.hasMatch(upper)) {
    return upper;
  }
  final tokenMatch = _embeddedRoomCodePattern.firstMatch(raw);
  if (tokenMatch != null) {
    return tokenMatch.group(1)!.toUpperCase();
  }
  return '';
}

final RegExp _roomCodePattern = RegExp(r'^[A-Z0-9]{6}$');
final RegExp _embeddedRoomCodePattern = RegExp(r'\b([A-Za-z0-9]{6})\b');
