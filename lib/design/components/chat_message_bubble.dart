import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons/chat/message_status_icon.dart';
import '../icons/crayon_strokes.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../../l10n/generated/app_localizations.dart';

/// Selectable text with inline time/receipts on a compact directional paper shape.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.text,
    required this.own,
    required this.status,
    super.key,
    this.time,
    this.delivery,
    this.isGroupEnd = true,
    this.onRetry,
    this.content,
  });

  final String text;
  final bool own;

  /// Localized status for assistive technologies, never a visible role label.
  final String status;
  final DateTime? time;
  final MessageDelivery? delivery;
  final bool isGroupEnd;
  final VoidCallback? onRetry;

  /// Optional native media presentation; data loading remains outside design.
  final Widget? content;

  @override
  Widget build(BuildContext context) {
    final localTime = time?.toLocal();
    final timestamp = localTime == null
        ? ''
        : '${localTime.hour % 12 == 0 ? 12 : localTime.hour % 12}:${localTime.minute.toString().padLeft(2, '0')} ${localTime.hour < 12 ? 'am' : 'pm'}';
    final l10n = AppLocalizations.of(context)!;
    final metadata = Semantics(
      label: [
        timestamp,
        if (own) status,
      ].where((part) => part.isNotEmpty).join(', '),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (timestamp.isNotEmpty)
              Text(
                timestamp,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: PawmateColors.softBrown,
                ),
              ),
            if (own && delivery != null) ...[
              const SizedBox(width: 4),
              MessageStatusIcon(delivery: delivery!),
            ],
          ],
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final surface = CustomPaint(
          painter: ChatBubblePainter(own: own, isGroupEnd: isGroupEnd),
          child: Padding(
            padding: EdgeInsets.only(
              left:
                  PawmateSpace.medium +
                  (!own && isGroupEnd ? PawmateSpace.chatBubbleTail : 0),
              right:
                  PawmateSpace.medium +
                  (own && isGroupEnd ? PawmateSpace.chatBubbleTail : 0),
              top: PawmateSpace.chatBubbleVerticalPadding,
              bottom: PawmateSpace.chatBubbleVerticalPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ?content,
                _MessageText(
                  text: text,
                  metadata: metadata,
                  timestamp: timestamp,
                  delivery: own ? delivery : null,
                ),
              ],
            ),
          ),
        );
        return Align(
          alignment: own ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: PawmateSpace.chatBubbleGap,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    constraints.maxWidth * PawmateSpace.chatBubbleWidthFraction,
                minHeight: onRetry == null ? 0 : 44,
              ),
              child: onRetry == null
                  ? surface
                  : Semantics(
                      button: true,
                      label: l10n.retryMessage,
                      child: Tooltip(
                        message: l10n.retryMessage,
                        child: FocusableActionDetector(
                          shortcuts: const {
                            SingleActivator(LogicalKeyboardKey.enter):
                                ActivateIntent(),
                            SingleActivator(LogicalKeyboardKey.space):
                                ActivateIntent(),
                          },
                          actions: {
                            ActivateIntent: CallbackAction<ActivateIntent>(
                              onInvoke: (_) {
                                onRetry!();
                                return null;
                              },
                            ),
                          },
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onRetry,
                            child: Align(
                              widthFactor: 1,
                              heightFactor: 1,
                              child: IgnorePointer(child: surface),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// Keeps the final word (or Unicode grapheme for a long token) beside metadata.
/// Both text runs remain native selectable text, including emoji/combining marks.
class _MessageText extends StatelessWidget {
  const _MessageText({
    required this.text,
    required this.metadata,
    required this.timestamp,
    required this.delivery,
  });
  final String text;
  final Widget metadata;
  final String timestamp;
  final MessageDelivery? delivery;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final body = Theme.of(
        context,
      ).textTheme.bodyMedium!.copyWith(height: 1.3);
      final small = Theme.of(context).textTheme.labelSmall!;
      final scaler = MediaQuery.textScalerOf(context);
      double width(String value, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(text: value, style: style),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout();
        final result = painter.width;
        painter.dispose();
        return result;
      }

      final metadataWidth =
          width(timestamp, small) +
          (delivery == null
              ? 0
              : (4 + (delivery == MessageDelivery.read ? 22 : 16)) *
                    scaler.scale(body.fontSize!) /
                    body.fontSize!);
      final whitespace = RegExp(r'\s+').allMatches(text).lastOrNull;
      var split = whitespace?.end ?? 0;
      var suffix = text.substring(split);
      if (width(suffix, body) +
              metadataWidth +
              6 * scaler.scale(body.fontSize!) / body.fontSize! >
          constraints.maxWidth) {
        suffix = text.characters.isEmpty ? '' : text.characters.last;
        split = text.length - suffix.length;
      }
      return SelectionArea(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: text.substring(0, split)),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                // WidgetSpan already scales its entire child. Disable nested
                // scaling to avoid scaling the text twice at accessibility sizes.
                child: MediaQuery.withNoTextScaling(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          // One grapheme can be unusually wide when an emoji font
                          // is unavailable; keep it intact without overflowing.
                          child: Text(
                            suffix,
                            key: const ValueKey('message-final-text'),
                            style: body,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      metadata,
                    ],
                  ),
                ),
              ),
            ],
          ),
          style: body,
          textWidthBasis: TextWidthBasis.longestLine,
        ),
      );
    },
  );
}

/// Mirrors one path: rounded towards the center, joined or tailed at the sender.
class ChatBubblePainter extends CustomPainter {
  const ChatBubblePainter({required this.own, required this.isGroupEnd});
  final bool own;
  final bool isGroupEnd;

  /// Exposed for geometry tests; the left-facing shape is the canonical path.
  Path outline(Size size) {
    final tail = isGroupEnd ? PawmateSpace.chatBubbleTail : 0.0;
    final left = tail + 1;
    final right = size.width - 1;
    final bottom = size.height - 1;
    final r1 = PawmateSpace.chatBubbleRadius.clamp(0.0, (size.height - 2) / 2);
    final r3 = PawmateSpace.chatBubbleJoinedRadius;
    final path = Path()
      ..moveTo(left + r1, 1)
      ..lineTo(right - r1, 1)
      ..quadraticBezierTo(right, 1, right, 1 + r1)
      ..lineTo(right, bottom - r1)
      ..quadraticBezierTo(right, bottom, right - r1, bottom);
    if (isGroupEnd) {
      path
        ..lineTo(left + r3, bottom)
        ..quadraticBezierTo(left, bottom, 1, bottom)
        ..quadraticBezierTo(left, bottom - 3, left, bottom - 10);
    } else {
      path
        ..lineTo(left + r3, bottom)
        ..quadraticBezierTo(left, bottom, left, bottom - r3);
    }
    path
      ..lineTo(left, 1 + r1)
      ..quadraticBezierTo(left, 1, left + r1, 1)
      ..close();
    return own
        ? path.transform(
            Float64List.fromList([
              -1,
              0,
              0,
              0,
              0,
              1,
              0,
              0,
              0,
              0,
              1,
              0,
              size.width,
              0,
              0,
              1,
            ]),
          )
        : path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shape = outline(size);
    canvas.drawPath(
      shape,
      Paint()..color = own ? PawmateColors.rosePaper : PawmateColors.card,
    );
    CrayonStrokes(
      canvas,
      seed: 3301 + (own ? 17 : 0),
    ).stroke(shape, PawmateColors.softBrown, width: 1.7);
  }

  @override
  bool shouldRepaint(ChatBubblePainter oldDelegate) =>
      oldDelegate.own != own || oldDelegate.isGroupEnd != isGroupEnd;
}
