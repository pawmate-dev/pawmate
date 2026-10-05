import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pawmate/design/components/crayon_avatar_button.dart';
import 'package:pawmate/design/theme/pawmate_theme.dart';
import 'package:pawmate/features/pairing/member_profile.dart';
import 'package:pawmate/features/pairing/pairing_api.dart';
import 'package:pawmate/features/pairing/widgets/member_profile_editor.dart';
import 'package:pawmate/l10n/generated/app_localizations.dart';

Widget localized(Widget child, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      theme: buildPawmateTheme(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

Future<Uint8List> imageFixture() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.pink, BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(64, 32);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  testWidgets(
    'requires avatar and nickname and retains an image when selection is cancelled',
    (tester) async {
      final bytes = (await tester.runAsync(imageFixture))!;
      final form = GlobalKey<FormState>();
      final editor = GlobalKey<MemberProfileEditorState>();
      var cancel = false;
      await tester.pumpWidget(
        localized(
          Form(
            key: form,
            child: MemberProfileEditor(
              key: editor,
              selectImage: () async => cancel
                  ? null
                  : XFile.fromData(
                      bytes,
                      name: 'portrait.png',
                      mimeType: 'image/png',
                    ),
            ),
          ),
        ),
      );
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Choose an avatar before continuing.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '  小灰 🐾  ');
      await tester.runAsync(() async {
        await tester.tap(find.byType(CrayonAvatarButton));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(form.currentState!.validate(), isTrue);
      final profile = editor.currentState!.profile!;
      expect(profile.nickname, '小灰 🐾');
      final png = ByteData.sublistView(profile.avatar);
      expect(png.getUint32(16), 256);
      expect(png.getUint32(20), 256);
      expect(profile.avatar.length, lessThanOrEqualTo(256 * 1024));
      cancel = true;
      await tester.tap(find.byType(CrayonAvatarButton));
      await tester.pumpAndSettle();
      expect(editor.currentState!.profile!.avatar, profile.avatar);
      await tester.enterText(find.byType(TextFormField), 'a' * 33);
      expect(form.currentState!.validate(), isFalse);
    },
  );

  testWidgets(
    'invalid image displays a translated error without creating a profile',
    (tester) async {
      final key = GlobalKey<MemberProfileEditorState>();
      await tester.pumpWidget(
        localized(
          Form(
            child: MemberProfileEditor(
              key: key,
              selectImage: () async => XFile.fromData(
                Uint8List.fromList([1, 2, 3]),
                name: 'broken.png',
              ),
            ),
          ),
          locale: const Locale('zh'),
        ),
      );
      await tester.runAsync(() async {
        await tester.tap(find.byType(CrayonAvatarButton));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(key.currentState!.profile, isNull);
      expect(find.text('无法读取这张图片，请选择小于 10 MB 的 PNG 或 JPEG 图片'), findsOneWidget);
    },
  );

  test(
    'both invitations send member identity and sessions restore both profiles',
    () async {
      final profile = MemberProfile(
        nickname: 'Ash',
        avatar: Uint8List.fromList([1, 2, 3]),
      );
      final paths = <String>[];
      final api = PairingApi(
        MockClient((request) async {
          paths.add(request.url.path);
          if (request.method == 'GET') {
            expect(request.headers['authorization'], 'Bearer token');
            return http.Response(
              jsonEncode({
                'role': 'inviter',
                'status': 'paired',
                'profile': profile.toJson(),
                'partner': profile.toJson(),
              }),
              200,
            );
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['profile'], profile.toJson());
          if (request.url.path.endsWith('redeem')) {
            return http.Response(
              '{"status":"paired","pair_id":"pair","invitee_token":"token","recovery_code":"recovery"}',
              200,
            );
          }
          return http.Response(
            '{"expires_at":"2026-10-05T00:00:00Z","invite_url":"pawmate://pair","inviter_token":"token","recovery_code":"recovery"}',
            201,
          );
        }),
      );
      addTearDown(api.close);
      await api.createInvite('https://home.example.test', profile: profile);
      await api.redeemInvite(
        'https://home.example.test',
        'code',
        profile: profile,
      );
      final session = await api.validateSession(
        'https://home.example.test',
        'token',
      );
      expect(session.profile!.nickname, 'Ash');
      expect(session.partner!.avatar, profile.avatar);
      expect(paths.length, 3);
    },
  );
}
