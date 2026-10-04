import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pawmate/features/pairing/pairing_api.dart';

void main() {
  test(
    'device login sends no existing token and receives no recovery secret',
    () async {
      final api = PairingApi(
        MockClient((request) async {
          expect(
            request.url.path,
            '/api/v1/pairing/devices/login-codes/redeem',
          );
          expect(request.headers.containsKey('authorization'), isFalse);
          expect(jsonDecode(request.body), {
            'code': 'single-use-code',
            'device_name': 'My tablet',
          });
          return http.Response(
            jsonEncode({
              'access_token': 'tablet-token',
              'pair_id': 'our-home',
              'role': 'inviter',
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);
      final credentials = await api.redeemDeviceLoginCode(
        'https://home.example.test',
        ' single-use-code ',
        ' My tablet ',
      );
      expect(credentials.accessToken, 'tablet-token');
      expect(credentials.pairID, 'our-home');
      expect(credentials.role, 'inviter');
    },
  );

  test('device operations authenticate with the installation token', () async {
    final requests = <http.Request>[];
    final api = PairingApi(
      MockClient((request) async {
        requests.add(request);
        expect(request.headers['authorization'], 'Bearer tablet-token');
        if (request.method == 'DELETE') return http.Response('', 204);
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'code': 'new-code',
              'expires_at': '2026-10-04T10:00:00Z',
            }),
            201,
          );
        }
        return http.Response(
          jsonEncode({
            'devices': [
              {
                'id': 'tablet-id',
                'name': 'My tablet',
                'current': true,
                'created_at': '2026-10-04T09:00:00Z',
              },
              {
                'id': 'phone-id',
                'name': 'Phone',
                'current': false,
                'created_at': '2026-10-03T09:00:00Z',
              },
            ],
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);
    final devices = await api.getDevices(
      'https://home.example.test',
      'tablet-token',
    );
    expect(devices.where((device) => device.current).single.id, 'tablet-id');
    final code = await api.createDeviceLoginCode(
      'https://home.example.test',
      'tablet-token',
    );
    expect(code.code, 'new-code');
    await api.revokeDevice(
      'https://home.example.test',
      'tablet-token',
      'phone-id',
    );
    expect(requests.last.url.path, '/api/v1/pairing/devices/phone-id');
  });

  test(
    'expired codes and revoked sessions preserve their HTTP error status',
    () async {
      final api = PairingApi(
        MockClient(
          (request) async => http.Response(
            jsonEncode({
              'error': request.method == 'POST'
                  ? 'invalid_device_code'
                  : 'invalid_session_token',
            }),
            401,
          ),
        ),
      );
      addTearDown(api.close);
      final isUnauthorized = isA<PairingApiException>().having(
        (error) => error.statusCode,
        'status',
        401,
      );
      await expectLater(
        api.redeemDeviceLoginCode(
          'https://home.example.test',
          'expired',
          'Tablet',
        ),
        throwsA(isUnauthorized),
      );
      await expectLater(
        api.getDevices('https://home.example.test', 'revoked'),
        throwsA(isUnauthorized),
      );
    },
  );
}
