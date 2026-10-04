import 'package:flutter/material.dart';

import 'handdrawn_card.dart';
import 'pawmate_theme.dart';

/// A native, selectable message on a stable paper surface with a labeled state.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.text,
    required this.own,
    required this.status,
    super.key,
    this.time,
    this.onRetry,
  });

  final String text;
  final bool own;
  final String status;
  final DateTime? time;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Align(
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: constraints.maxWidth * .88),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: HanddrawnCard(
            color: own
                ? Color.alphaBlend(
                    PawmateColors.rose.withAlpha(35),
                    PawmateColors.paper,
                  )
                : PawmateColors.paper,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  own ? 'You' : 'Your partner',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                SelectableText(text),
                const SizedBox(height: 8),
                Text(
                  [
                    if (time != null)
                      '${time!.toLocal().hour.toString().padLeft(2, '0')}:${time!.toLocal().minute.toString().padLeft(2, '0')}',
                    if (status.isNotEmpty) status,
                  ].join(' · '),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                if (onRetry != null)
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry message'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
