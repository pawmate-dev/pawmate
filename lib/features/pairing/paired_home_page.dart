import 'package:flutter/material.dart';

import '../../design/handdrawn_card.dart';
import '../../design/handdrawn_scaffold.dart';
import '../../design/pawmate_theme.dart';
import 'pairing_api.dart';
import 'pairing_credentials.dart';
import 'widgets/pairing_error_note.dart';
import 'widgets/recovery_code_note.dart';

/// Shows the authenticated couple home after the server validates a member.
class PairedHomePage extends StatelessWidget {
  const PairedHomePage({
    required this.credentials,
    required this.session,
    super.key,
    this.recoveryCodeToSave,
    this.storageWarning = false,
  });

  final SavedPairingCredentials credentials;
  final PairingSession session;
  final String? recoveryCodeToSave;
  final bool storageWarning;

  @override
  Widget build(BuildContext context) {
    return HanddrawnScaffold(
      title: 'Our little home',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            HanddrawnCard(
              color: const Color(0xFFF4F0FF),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.home_rounded,
                    size: 36,
                    color: PawmateColors.rose,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You are home together',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: PawmateColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This device is connected as the ${session.role}.',
                    style: const TextStyle(
                      color: PawmateColors.softBrown,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Private server',
                    style: TextStyle(
                      color: PawmateColors.softBrown,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    credentials.serverURL,
                    style: const TextStyle(
                      color: PawmateColors.ink,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (session.pairID != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Home ID: ${session.pairID}',
                      style: const TextStyle(
                        color: PawmateColors.softBrown,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (storageWarning) ...[
              const SizedBox(height: 18),
              const PairingErrorNote(
                message:
                    'Access was restored for this session, but this device could not securely save it. Keep the recovery code below and restore again if the app closes.',
              ),
            ],
            if (recoveryCodeToSave != null) ...[
              const SizedBox(height: 18),
              RecoveryCodeNote(recoveryCode: recoveryCodeToSave!),
            ],
          ],
        ),
      ),
    );
  }
}
