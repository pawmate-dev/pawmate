import 'package:flutter/material.dart';

import '../../../design/components/handdrawn_button.dart';
import '../../../design/components/handdrawn_card.dart';
import '../../../design/components/handdrawn_text_field.dart';
import '../../../design/theme/colors.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Collects the server address and recovery code after an app reinstall.
class PairingRecoveryCard extends StatelessWidget {
  const PairingRecoveryCard({
    required this.serverController,
    required this.codeController,
    required this.isLoading,
    required this.onRecover,
    super.key,
  });

  final TextEditingController serverController;
  final TextEditingController codeController;
  final bool isLoading;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HanddrawnCard(
      color: const Color(0xFFF0F6F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.restoreExistingHome,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: PawmateColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.recoveryHelp,
            style: TextStyle(color: PawmateColors.softBrown, height: 1.35),
          ),
          const SizedBox(height: 14),
          HanddrawnTextField(
            controller: serverController,
            labelText: l10n.serverUrlExisting,
            hintText: l10n.serverUrlHint,
            prefixIcon: Icons.link,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: codeController,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(
              labelText: l10n.recoveryCode,
              prefixIcon: Icon(Icons.key_outlined),
            ),
          ),
          const SizedBox(height: 14),
          HanddrawnButton(
            onPressed: isLoading ? null : onRecover,
            icon: Icons.settings_backup_restore,
            label: isLoading ? l10n.restoringAccess : l10n.restoreAccess,
            primary: false,
          ),
        ],
      ),
    );
  }
}
