import 'package:flutter/material.dart';

import '../icons/chat/composer_doodle_icon.dart';
import '../icons/crayon_strokes.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import 'crayon_icon_button.dart';

/// A quiet native multiline editor with fixed crayon chrome and no placeholder.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    required this.controller,
    required this.onChanged,
    required this.onAttachments,
    required this.onStickers,
    required this.onSend,
    required this.inputLabel,
    required this.attachmentsLabel,
    required this.stickersLabel,
    required this.sendLabel,
    super.key,
    this.errorText,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onAttachments;
  final VoidCallback onStickers;
  final VoidCallback? onSend;
  final String inputLabel;
  final String attachmentsLabel;
  final String stickersLabel;
  final String sendLabel;
  final String? errorText;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PawmateSpace.small,
        vertical: PawmateSpace.small,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CrayonIconButton(
                label: attachmentsLabel,
                onPressed: onAttachments,
                child: const ComposerDoodleIcon(symbol: ComposerDoodle.add),
              ),
              const SizedBox(width: PawmateSpace.tiny),
              Expanded(
                child: CustomPaint(
                  painter: const _ComposePaperPainter(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: PawmateSpace.medium,
                        vertical: PawmateSpace.small,
                      ),
                      child: Semantics(
                        label: inputLabel,
                        child: TextField(
                          controller: controller,
                          onChanged: onChanged,
                          minLines: 1,
                          maxLines: 4,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          cursorColor: PawmateColors.ink,
                          cursorOpacityAnimates: false,
                          // Null decoration bypasses InputDecorator and its floating label,
                          // animated border and focus fill. Selection and IME stay native.
                          decoration: null,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: PawmateSpace.tiny),
              CrayonIconButton(
                label: stickersLabel,
                onPressed: onStickers,
                child: const ComposerDoodleIcon(
                  symbol: ComposerDoodle.stickers,
                ),
              ),
              CrayonIconButton(
                label: sendLabel,
                onPressed: onSend,
                child: ComposerDoodleIcon(
                  symbol: ComposerDoodle.send,
                  enabled: onSend != null,
                ),
              ),
            ],
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: PawmateSpace.small),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  errorText!,
                  style: const TextStyle(color: PawmateColors.error),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Fixed paper outline, deliberately unchanged by focus or pointer state.
class _ComposePaperPainter extends CustomPainter {
  const _ComposePaperPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final shape = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          const Radius.circular(PawmateSpace.chatBubbleRadius),
        ),
      );
    canvas.drawPath(shape, Paint()..color = PawmateColors.card);
    CrayonStrokes(
      canvas,
      seed: 4409,
    ).stroke(shape, PawmateColors.softBrown, width: 1.5);
  }

  @override
  bool shouldRepaint(_ComposePaperPainter oldDelegate) => false;
}
