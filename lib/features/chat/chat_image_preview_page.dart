import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/components/crayon_icon_button.dart';
import '../../design/icons/chat/composer_doodle_icon.dart';
import '../../design/theme/colors.dart';
import '../../design/theme/spacing.dart';
import '../../l10n/generated/app_localizations.dart';

/// Displays already verified attachment bytes without another network request.
class ChatImagePreviewPage extends StatelessWidget {
  const ChatImagePreviewPage({
    required this.name,
    required this.bytes,
    super.key,
  });

  final String name;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              Navigator.of(context).maybePop();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: PawmateColors.paper,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: PawmateColors.paper,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              elevation: 0,
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              actions: [
                CrayonIconButton(
                  label: l10n.closeImagePreview,
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const ComposerDoodleIcon(symbol: ComposerDoodle.close),
                ),
                const SizedBox(width: PawmateSpace.small),
              ],
            ),
            body: SafeArea(
              child: Semantics(
                hint: l10n.imagePreviewHint,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  trackpadScrollCausesScale: true,
                  child: SizedBox.expand(
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      semanticLabel: name,
                      errorBuilder: (_, _, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(PawmateSpace.page),
                          child: Text(l10n.attachmentUnavailable),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
