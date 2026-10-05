import 'package:flutter/material.dart';

import '../../../design/components/handdrawn_card.dart';
import '../../../design/theme/colors.dart';

/// Shows a readable network or validation error on a paper-like note.
class PairingErrorNote extends StatelessWidget {
  const PairingErrorNote({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return HanddrawnCard(
      color: const Color(0xFFFFE9E4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: PawmateColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: PawmateColors.ink, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
