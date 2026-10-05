import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/components/handdrawn_card.dart';
import '../../../design/theme/colors.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Presents a member's one-time recovery code with a copy action.
class RecoveryCodeNote extends StatelessWidget {
  const RecoveryCodeNote({required this.recoveryCode, super.key});

  final String recoveryCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HanddrawnCard(
      color: const Color(0xFFFFF3CF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.recoveryCodeTitle,
            style: TextStyle(
              color: PawmateColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.recoveryCodeHelp,
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
                    SnackBar(content: Text(l10n.recoveryCodeCopied)),
                  );
                }
              },
              icon: const Icon(Icons.copy_outlined),
              label: Text(l10n.copyCode),
            ),
          ),
        ],
      ),
    );
  }
}
