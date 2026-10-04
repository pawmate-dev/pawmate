import 'package:flutter/material.dart';

import '../../../design/handdrawn_button.dart';
import '../../../design/handdrawn_card.dart';
import '../../../design/handdrawn_text_field.dart';
import '../../../design/pawmate_theme.dart';

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
    return HanddrawnCard(
      color: const Color(0xFFF0F6F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Restoring an existing home?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: PawmateColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use your recovery code if you have lost access. Recovery signs out all your devices and replaces the recovery code; your partner stays signed in. To add a device, use a device login code instead.',
            style: TextStyle(color: PawmateColors.softBrown, height: 1.35),
          ),
          const SizedBox(height: 14),
          HanddrawnTextField(
            controller: serverController,
            labelText: 'Existing server URL',
            hintText: 'https://pawmate.example.com',
            prefixIcon: Icons.link,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: codeController,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            decoration: const InputDecoration(
              labelText: 'Recovery code',
              prefixIcon: Icon(Icons.key_outlined),
            ),
          ),
          const SizedBox(height: 14),
          HanddrawnButton(
            onPressed: isLoading ? null : onRecover,
            icon: Icons.settings_backup_restore,
            label: isLoading ? 'Restoring access…' : 'Restore access',
            primary: false,
          ),
        ],
      ),
    );
  }
}
