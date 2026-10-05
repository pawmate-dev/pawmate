import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate/features/pairing/pairing_api.dart';

void main() {
  test('development builds accept HTTP private instance URLs', () {
    expect(
      PairingApi.parseServerURL(' http://100.64.0.1:8080/ ').toString(),
      'http://100.64.0.1:8080',
    );
  });

  test('HTTPS and instance path prefixes remain supported', () {
    expect(
      PairingApi.parseServerURL(
        'https://home.example.test/pawmate/',
      ).toString(),
      'https://home.example.test/pawmate',
    );
  });

  test('unsafe or unsupported instance URLs remain rejected', () {
    for (final value in [
      '',
      'home.example.test',
      'ftp://home.example.test',
      'http://user:secret@home.example.test',
      'http://home.example.test?token=secret',
      'http://home.example.test#secret',
    ]) {
      expect(
        () => PairingApi.parseServerURL(value),
        throwsA(isA<PairingApiException>()),
        reason: value,
      );
    }
  });
}
