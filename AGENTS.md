# Pawmate UI Engineering Guidelines

These guidelines define the visual language and implementation constraints for
the Pawmate Flutter client. Pawmate is a private two-person digital home. Its
interface should feel like a shared hand-made journal: warm, personal, and
slightly imperfect while remaining predictable, readable, accessible, and easy
to operate.

## Visual language

Use the following design direction for new screens and reusable components:

```text
Pawmate Hand-drawn Home Journal
warm / intimate / doodled / paper-based / calm / lightly imperfect
```

The hand-drawn character comes from paper surfaces, ink outlines, restrained
crayon accents, stickers, and stable organic geometry. Do not make the UI look
random or unfinished. Decoration must support navigation and emotional tone,
never obscure content or actions.

## Design tokens

Centralize these values in the Flutter design system. Do not scatter equivalent
color or spacing literals through feature widgets.

### Color tokens

```dart
const paper = Color(0xFFFFF8E7);
const ink = Color(0xFF3C3530);
const softBrown = Color(0xFF8B7666);
const rose = Color(0xFFE98B8B);
const lavender = Color(0xFFA99BD6);
const mint = Color(0xFF9BC7B0);
const sun = Color(0xFFF3C969);
const sky = Color(0xFF9DC6D8);
```

- Use `paper` as the primary application surface and `ink` instead of pure
  black for primary text and line work.
- Use one or two accent colors per screen. Feature colors are semantic accents,
  not replacement themes.
- Use low-saturation semantic colors for success, warning, and error states.
- Maintain WCAG AA contrast for body text, controls, and error messages.
- Never use an accent color as the only indication of state.

### Geometry and elevation tokens

- Standard outline width: `2.0`; emphasis outline width: `3.0` logical pixels.
- Use organic rounded rectangles with small, bounded radius variation rather
  than unrelated shapes per widget.
- Use short, low-opacity, slightly offset shadows instead of heavy Material
  elevation. Shadows should suggest paper separation, not depth-heavy cards.
- Use a consistent spacing scale (for example 4, 8, 12, 16, 24, 32 logical
  pixels) and preserve a minimum 44x44 logical-pixel touch target.

## Component architecture

Build visual behavior into reusable widgets under `lib/design/`, organized by
responsibility:

```text
theme/          colors.dart, spacing.dart, pawmate_theme.dart
layouts/        HanddrawnScaffold
components/     HanddrawnCard, HanddrawnActionCard, HanddrawnButton,
                HanddrawnTextField, ChatMessageBubble
illustrations/  Reusable decorative compositions
icons/          purpose-based icon families and the shared crayon renderer
```

Feature screens should compose these components instead of drawing one-off
cards, buttons, fields, or borders. Components must expose semantic Flutter
properties (`label`, `enabled`, `onPressed`, validation state) and preserve
standard focus, keyboard, screen-reader, and test behavior.

Import color and spacing tokens directly from their `theme/` modules. Keep
networking, credentials, message delivery and other business state in
`lib/features/`; the design layer must not depend on feature implementations.
Future Sticker, PaperNote and CoupleAvatar widgets belong in `components/`,
not new top-level categories. See `lib/design/README.md` for the directory contract.

## Stable hand-drawn rendering

### Crayon and oil-pastel icon language

This is a core Pawmate visual requirement: icon strokes should have visible
pigment grain, bounded hand-drawn jitter or irregular pressure overdraw, with
slightly rough or intermittently broken edges. Simulate crayon or oil pastel
catching on paper for a casual, warm, handmade feel. Do not substitute clean
uniform vector outlines or blurry noise for this texture. Silhouettes must
remain recognizable and actions must retain readable native text labels.

Organize Dart icon families by purpose under `lib/design/icons/` (for example
`access/`, followed by `chat/`, `home/` and `play/` when needed), sharing the
seeded stroke renderer. Keep texture deterministic across rebuilds, theme
changes with identical inputs, screenshots and golden tests.

- Implement organic outlines and paper details with `CustomPainter` or SVG
  assets where appropriate.
- If a painter uses jitter, use a stable seed derived from widget identity or an
  explicit parameter. Never generate a new random shape during every `build`;
  that causes visual flicker and invalidates golden tests.
- Keep decorative textures lightweight. Prefer small tiled PNG/WebP assets or
  procedural low-contrast details over full-screen high-resolution images.
- Prefer SVG for line icons and PNG/WebP for illustrations and stickers.
- Do not replace the entire layout with a bitmap. Text, controls, and content
  must remain native Flutter widgets.
- Material or Cupertino primitives may provide behavior, but their visual
  styling must be adapted through the Pawmate theme and hand-drawn components.

## Typography

Use two type roles:

- Display role: an appropriately licensed hand-written or rounded font for
  titles, empty states, and short sticker labels.
- Reading role: a clear Chinese-capable sans-serif font for chat, recipes,
  learning content, form labels, errors, and all substantial body text.

Use a monospace face for server URLs, invitation codes, and other technical
values when it improves copying and scanning. Never use a decorative font as the
only presentation of an important instruction or error.

## Page composition

Pages should feel like rooms in one shared home while retaining conventional
information architecture:

```text
header: title + optional small illustration or couple status
content: primary paper/card surface
navigation: stable, labeled, easy to reach
decoration: restrained stickers, tape, doodles, or notes
```

Suggested thematic metaphors are optional and must not replace labels:

```text
chat            living room / message wall
recipes         kitchen notes
language        shared desk / flash cards
games           play corner
backup          storage box / folder
```

## Motion and interaction

Use Flutter animation primitives for short, purposeful feedback:

- micro-interaction: 120–180 ms;
- page transition: 220–300 ms;
- celebratory pairing or milestone animation: 600–900 ms.

Motion may suggest paper unfolding, a button settling, a sticker wobbling, or
two pieces joining. Keep animations subtle, interruptible, and non-blocking.
Honor `MediaQuery.disableAnimations` and provide an equivalent static state.
Do not use motion as the only way to communicate success, failure, or progress.

## Onboarding and private data

The server URL, invitation code, access token, chat content, media, exports, and
backups are sensitive in different ways:

- validate and normalize server URLs before requests;
- never log authorization headers, invitation links, or private content;
- keep technical values selectable and easy to copy;
- show clear loading, unreachable-server, incompatible-version, invalid-input,
  expired-invitation, and success states;
- store authentication tokens only in platform secure storage when that flow is
  implemented;
- do not enable production cleartext HTTP merely to simplify local development.

## Accessibility and localization

- Every icon-only control needs a semantic label and tooltip where appropriate.
- Preserve logical reading order and support text scaling without clipping.
- Do not encode meaning with color alone; pair color with text, iconography, or
  shape.
- Keep body text readable at large accessibility text scales.
- Route all user-facing Flutter copy, validation feedback, semantics, and
  tooltips through the localization resources. Provide English and Simplified
  Chinese translations. Chinese sentence endings must not use terminal Chinese
  punctuation such as `。`, `！`, or `？`; keep UI copy concise and natural.
- Route user-facing strings through the localization layer when one is added;
  do not hard-code text into painters or image assets.

## Review checklist

For a visual Flutter change, reviewers should check:

- [ ] The screen uses shared Pawmate components and design tokens.
- [ ] Hand-drawn geometry is stable across rebuilds.
- [ ] Decorative elements do not reduce readability or touch targets.
- [ ] Loading, empty, error, and success states are designed.
- [ ] Text remains readable with larger accessibility sizes.
- [ ] Icons and controls have semantic labels.
- [ ] Before/after screenshots or a short recording are included for meaningful
      visual changes.
