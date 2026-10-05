import 'package:flutter/material.dart';

import '../../../design/components/handdrawn_button.dart';
import '../../../design/components/handdrawn_card.dart';
import '../../../design/components/handdrawn_text_field.dart';
import '../../../design/theme/colors.dart';
import '../../../design/icons/access/access_doodle_icon.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Collects and submits the inviter's private Pawmate server address.
class ServerSetupCard extends StatelessWidget {
  const ServerSetupCard({
    required this.formKey,
    required this.controller,
    required this.isLoading,
    required this.onCreateInvite,
    super.key,
    this.profileEditor,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onCreateInvite;
  final Widget? profileEditor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HanddrawnCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (profileEditor != null)
              profileEditor!
            else
              const Center(
                child: AccessDoodleIcon(symbol: AccessDoodle.createInvitation),
              ),
            const SizedBox(height: 12),
            Text(
              l10n.chooseHomeAddress,
              textAlign: TextAlign.start,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: PawmateColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.trustedServerHelp,
              style: TextStyle(color: PawmateColors.softBrown, height: 1.35),
            ),
            const SizedBox(height: 18),
            HanddrawnTextField(
              controller: controller,
              labelText: l10n.serverUrlDomain,
              hintText: l10n.serverUrlHint,
              prefixIcon: Icons.link,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.enterServerUrl;
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            HanddrawnButton(
              onPressed: isLoading ? null : onCreateInvite,
              icon: Icons.favorite_border,
              label: isLoading ? l10n.makingRoom : l10n.createInvitationAction,
            ),
          ],
        ),
      ),
    );
  }
}
