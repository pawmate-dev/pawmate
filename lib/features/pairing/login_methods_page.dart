import 'package:flutter/material.dart';

import '../../design/components/handdrawn_action_card.dart';
import '../../design/layouts/handdrawn_scaffold.dart';
import '../../design/icons/access/access_doodle_icon.dart';
import '../../design/theme/colors.dart';
import '../../design/theme/spacing.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/locale_controller.dart';
import 'device_login_page.dart';
import 'invite_link_entry_page.dart';
import 'inviter_setup_page.dart';
import 'pairing_recovery_page.dart';

/// Offers four distinct access paths before asking for sensitive form values.
class LoginMethodsPage extends StatelessWidget {
  const LoginMethodsPage({super.key});

  /// Opens one focused flow; returning restores the same two-by-two landing page.
  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _chooseLanguage(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.chooseLanguage),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'en'),
            child: Text(l10n.english),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'zh'),
            child: Text(l10n.chinese),
          ),
        ],
      ),
    );
    if (selected != null && context.mounted) {
      await LocaleControllerScope.of(context).setLocale(Locale(selected));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HanddrawnScaffold(
      title: null,
      actions: [
        IconButton(
          tooltip: l10n.changeLanguage,
          onPressed: () => _chooseLanguage(context),
          icon: const Icon(Icons.language),
        ),
      ],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PawmateSpace.page),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: PawmateSpace.contentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.homeHeadline,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: PawmateColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: PawmateSpace.medium),
                  Text(
                    l10n.homeIntro,
                    style: TextStyle(color: PawmateColors.ink, height: 1.4),
                  ),
                  const SizedBox(height: PawmateSpace.page),
                  // Content-driven rows keep two columns even with large text.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: HanddrawnActionCard(
                            label: l10n.createInvitation,
                            description: l10n.createInvitationDescription,
                            illustration: const AccessDoodleIcon(
                              symbol: AccessDoodle.createInvitation,
                            ),
                            color: PawmateColors.rosePaper,
                            onPressed: () =>
                                _open(context, const InviterSetupPage()),
                          ),
                        ),
                        const SizedBox(width: PawmateSpace.large),
                        Expanded(
                          child: HanddrawnActionCard(
                            label: l10n.acceptInvitation,
                            description: l10n.acceptInvitationDescription,
                            illustration: const AccessDoodleIcon(
                              symbol: AccessDoodle.acceptInvitation,
                            ),
                            color: PawmateColors.rosePaper,
                            onPressed: () =>
                                _open(context, const InviteLinkEntryPage()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: PawmateSpace.large),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: HanddrawnActionCard(
                            label: l10n.restoreData,
                            description: l10n.restoreDataDescription,
                            illustration: const AccessDoodleIcon(
                              symbol: AccessDoodle.restoreHome,
                              color: PawmateColors.lavender,
                            ),
                            color: PawmateColors.lavenderPaper,
                            onPressed: () =>
                                _open(context, const PairingRecoveryPage()),
                          ),
                        ),
                        const SizedBox(width: PawmateSpace.large),
                        Expanded(
                          child: HanddrawnActionCard(
                            label: l10n.addDevice,
                            description: l10n.addDeviceDescription,
                            illustration: const AccessDoodleIcon(
                              symbol: AccessDoodle.addDevice,
                              color: PawmateColors.lavender,
                            ),
                            color: PawmateColors.lavenderPaper,
                            onPressed: () =>
                                _open(context, const DeviceLoginPage()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: PawmateSpace.page),
                  Text(
                    l10n.alreadyPaired,
                    style: TextStyle(color: PawmateColors.ink, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
