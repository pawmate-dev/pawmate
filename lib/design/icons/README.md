# Pawmate crayon icons

Organize native Dart illustrations by purpose, not by individual feature pages:

- `access/`: invitations, recovery and additional-device login.
- `profile/`: avatar upload circles and plus signs, reused by profile controls.
- Future `chat/`, `home/` and `play/` families should reuse `CrayonStrokes`.
- `crayon_strokes.dart`: shared dry-wax renderer, not a catalog of symbols.

Use granular crayon/oil-pastel strokes with bounded jitter, irregular pressure
overdraw and slightly rough or broken edges. The result should feel casual,
warm and handmade, like pigment catching on journal paper. Keep silhouettes
legible and use labels for actions; texture is decorative, not semantic.

All strokes use fixed purpose-based seeds. Repainting identical inputs must
produce identical pixels. Keep drawing inside a normalized coordinate space,
wrap static illustrations in repaint boundaries, and do not add animated noise.
Expose optional semantic labels for standalone icons; illustrations inside a
labeled action should not be announced twice. Text remains native Flutter text.

Pixel-stability and access-flow tests live in `test/login_methods_test.dart`.
To regenerate the before/after widget previews with a readable local font:

```bash
PAWMATE_PREVIEW_FONT=/path/to/reading-font.ttf flutter test \
  test/onboarding_preview_test.dart --dart-define=PAWMATE_CAPTURE_PREVIEWS=true
```

This opt-in capture test is skipped in normal CI. `login-before.png` is a
reconstruction of the former stacked composition, not a historical device
screenshot. Both previews contain no real invitation or credentials.

Member-profile previews are captured by `test/profile_preview_test.dart`.
Use a Chinese-capable reading font and optionally set
`PAWMATE_PREVIEW_MONO_FONT` to a monospace font for server URLs. The opt-in test
writes English and Chinese inviter/invitee screenshots under `books/src/images/`.
