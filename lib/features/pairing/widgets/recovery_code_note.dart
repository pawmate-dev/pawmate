import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/handdrawn_card.dart';
import '../../../design/pawmate_theme.dart';

/// Presents a member's one-time recovery code with a copy action.
class RecoveryCodeNote extends StatelessWidget {
  const RecoveryCodeNote({required this.recoveryCode, super.key});

  final String recoveryCode;

  @override
  Widget build(BuildContext context) {
    return HanddrawnCard(
      color: const Color(0xFFFFF3CF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Keep this recovery code somewhere safe',
            style: TextStyle(
              color: PawmateColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Save this outside the app. Recovery signs out all your devices and issues a new code. For another phone, tablet or computer, use Add a device instead.',
            style: TextStyle(color: PawmateColors.softBrown, height: 1.35),
          ),
          const SizedBox(height: 12),
          SelectableText(
            recoveryCode,
            style: const TextStyle(
              color: PawmateColors.ink,
              fontFamily: 'monospace',
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: recoveryCode));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Recovery code copied')),
                  );
                }
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy code'),
            ),
          ),
        ],
      ),
    );
  }
}
