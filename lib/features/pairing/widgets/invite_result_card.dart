import 'package:flutter/material.dart';

import '../../../design/components/handdrawn_button.dart';
import '../../../design/components/handdrawn_card.dart';
import '../../../design/theme/colors.dart';
import '../pairing_api.dart';
import 'recovery_code_note.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Displays the one-time invitation and the current partner pairing status.
class InviteResultCard extends StatelessWidget {
  const InviteResultCard({
    required this.invite,
    required this.recoveryCode,
    required this.status,
    required this.isLoading,
    required this.onCopy,
    required this.onRefresh,
    super.key,
  });

  final PairingInvite invite;
  final String recoveryCode;
  final PairingStatus? status;
  final bool isLoading;
  final VoidCallback onCopy;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPaired = status?.status == 'paired';
    return HanddrawnCard(
      color: const Color(0xFFF4F0FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isPaired ? Icons.favorite : Icons.mail_outline,
                color: isPaired ? PawmateColors.rose : PawmateColors.lavender,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isPaired ? l10n.homeConnected : l10n.invitationReady,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: PawmateColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isPaired ? l10n.connectedMemories : l10n.shareInvitation,
            style: const TextStyle(
              color: PawmateColors.softBrown,
              height: 1.35,
            ),
          ),
          if (!isPaired) ...[
            const SizedBox(height: 16),
            SelectableText(
              invite.inviteURL,
              style: const TextStyle(
                color: PawmateColors.ink,
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            HanddrawnButton(
              onPressed: onCopy,
              icon: Icons.copy_outlined,
              label: l10n.copyInvitation,
              primary: false,
            ),
            const SizedBox(height: 10),
            Text(
              l10n.expiresAt(
                MaterialLocalizations.of(
                  context,
                ).formatMediumDate(invite.expiresAt.toLocal()),
              ),
              style: const TextStyle(
                color: PawmateColors.softBrown,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),
          RecoveryCodeNote(recoveryCode: recoveryCode),
          const SizedBox(height: 18),
          HanddrawnButton(
            onPressed: isLoading ? null : onRefresh,
            icon: isPaired ? Icons.check_circle_outline : Icons.refresh,
            label: isPaired ? l10n.pairingComplete : l10n.checkPairingStatus,
            primary: isPaired,
          ),
          if (!isPaired && status != null) ...[
            const SizedBox(height: 10),
            Text(
              l10n.waitingForPartner,
              style: TextStyle(color: PawmateColors.softBrown),
            ),
          ],
        ],
      ),
    );
  }
}
