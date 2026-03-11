import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/join_input_parser.dart';

void main() {
  group('extractRoomCode', () {
    test('returns empty string for blank input', () {
      expect(extractRoomCode('   '), isEmpty);
    });

    test('extracts direct room code', () {
      expect(extractRoomCode('ab12cd'), 'AB12CD');
    });

    test('extracts room code from invite link', () {
      expect(
        extractRoomCode('https://partyqueue.app/join/xy34zz'),
        'XY34ZZ',
      );
    });

    test('extracts embedded token from sentence', () {
      expect(extractRoomCode('Join with code q1w2e3 please'), 'Q1W2E3');
    });

    test('ignores invalid code length', () {
      expect(extractRoomCode('ABCDE'), isEmpty);
      expect(extractRoomCode('ABCDEFG'), isEmpty);
    });
  });
}
