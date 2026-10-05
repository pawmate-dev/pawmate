import 'package:flutter/material.dart';

import '../../design/components/couple_header_avatars.dart';
import '../../design/components/handdrawn_card.dart';
import '../../design/layouts/handdrawn_scaffold.dart';
import '../../design/theme/colors.dart';
import '../../l10n/generated/app_localizations.dart';
import 'pairing_api.dart';
import 'pairing_credentials.dart';
import 'widgets/devices_card.dart';
import 'widgets/pairing_error_note.dart';
import 'widgets/recovery_code_note.dart';

/// Account and pairing information reached from the couple's header portraits.
class CoupleDetailsPage extends StatelessWidget {
  const CoupleDetailsPage({
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
    final l10n = AppLocalizations.of(context)!;
    return HanddrawnScaffold(
      title: l10n.coupleDetails,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            HanddrawnCard(
              color: PawmateColors.lavenderPaper,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CoupleHeaderAvatars(
                      size: 80,
                      memberAvatar: session.profile?.avatar,
                      partnerAvatar: session.partner?.avatar,
                      memberNickname: session.profile?.nickname,
                      partnerNickname: session.partner?.nickname,
                      // Identity stays available to screen readers and tooltips,
                      // not as role labels below the portraits.
                      memberLabel: l10n.yourProfile,
                      partnerLabel: l10n.partnerProfile,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.coupleDetails,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: PawmateColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.connectedAsRole(session.role),
                    style: const TextStyle(
                      color: PawmateColors.softBrown,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.privateServer,
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
                      l10n.homeId(session.pairID!),
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
              PairingErrorNote(
                message: recoveryCodeToSave != null
                    ? l10n.storageWarningRecovery
                    : l10n.storageWarningDevice,
              ),
            ],
            if (recoveryCodeToSave != null) ...[
              const SizedBox(height: 18),
              RecoveryCodeNote(recoveryCode: recoveryCodeToSave!),
            ],
            const SizedBox(height: 18),
            DevicesCard(credentials: credentials),
          ],
        ),
      ),
    );
  }
}
