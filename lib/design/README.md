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
