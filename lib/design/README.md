# Pawmate design system

Keep presentation primitives separate from feature state, networking and storage.
Import the specific component or token file you need; do not reintroduce flat
compatibility files or a catch-all barrel at the design root.

| Directory | Responsibility |
| --- | --- |
| `theme/` | Color/spacing tokens and Material theme construction |
| `layouts/` | Page scaffolds and shared layout shells |
| `components/` | Reusable content surfaces, controls and display widgets |
| `illustrations/` | Reusable decorative compositions |
| `icons/` | Purpose-based symbols and the shared deterministic crayon renderer |

`theme/colors.dart` owns `PawmateColors`; `theme/spacing.dart` owns `PawmateSpace`.
Only application setup and theme tests need `theme/pawmate_theme.dart`. Widgets
that only use colors or spacing should import those token modules directly.

Feature pages compose layouts, components, illustrations and icons. The design
layer must not import `features/`, API clients or credential models. Stateful
business actions stay in their features: for example, `ChatMessageBubble`
receives text, status and an optional retry callback, but never sends messages.

Do not create a subdirectory for every widget. Add purpose-based icon families
as needed; see [the crayon icon guidelines](icons/README.md) for texture, seeds,
semantics and preview generation. Moving files must not alter visual geometry,
tokens or interaction behavior.

## Chat bubbles

`ChatMessageBubble` uses a 96% width cap and 5px vertical content padding.
The center-facing corners use the shared large radius; the sender-facing lower
corner uses the smaller joined radius until the group ends, when it becomes a
tail. Features determine groups: consecutive same-sender messages no more than
five minutes apart, including locally pending messages.

The last word (or final Unicode grapheme of a long token) stays together with
the `h:mm am/pm` timestamp and optional delivery mark. Native selection is kept
for confirmed messages. Role labels and textual delivery states are not visible;
localized status remains available to assistive technology. Failed bubbles are
retryable by tap or keyboard with a minimum 44px hit area, while the painted
surface remains compact. Status marks live in `icons/chat/` and share the
deterministic crayon renderer rather than Material icons or animated spinners.
