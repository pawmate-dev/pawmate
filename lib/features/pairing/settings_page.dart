import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../design/components/handdrawn_card.dart';
import '../../design/layouts/handdrawn_scaffold.dart';
import '../../design/theme/colors.dart';
import '../../design/theme/spacing.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/locale_controller.dart';
import 'connection_status.dart';
import 'login_methods_page.dart';
import 'pairing_recovery_page.dart';

/// Houses language, connection verification and explicit recovery/access actions.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.serverURL,
    required this.connection,
    required this.onRetry,
    super.key,
  });
  final String serverURL;
  final ValueListenable<ConnectionStatus> connection;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locales = LocaleControllerScope.maybeOf(context);
    return HanddrawnScaffold(
      title: l10n.settings,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(PawmateSpace.page),
          children: [
            HanddrawnCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.chooseLanguage,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: PawmateSpace.medium),
                  if (locales != null)
                    RadioGroup<String>(
                      groupValue: locales.locale.languageCode,
                      onChanged: (value) async {
                        if (value == null) return;
                        try {
                          await locales.setLocale(Locale(value));
                        } on Object {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.languageSaveError,
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: Material(
                        type: MaterialType.transparency,
                        child: Column(
                          children: [
                            RadioListTile(
                              value: 'en',
                              title: Text(l10n.english),
                            ),
                            RadioListTile(
                              value: 'zh',
                              title: Text(l10n.chinese),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Text(l10n.languageUnavailable),
                ],
              ),
            ),
            const SizedBox(height: PawmateSpace.large),
            HanddrawnCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.serverConnection,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: PawmateSpace.small),
                  SelectableText(
                    serverURL,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: PawmateColors.softBrown,
                    ),
                  ),
                  ValueListenableBuilder<ConnectionStatus>(
                    valueListenable: connection,
                    builder: (_, status, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: PawmateSpace.small),
                        Text(connectionLabel(l10n, status)),
                        TextButton(
                          onPressed: status == ConnectionStatus.checking
                              ? null
                              : onRetry,
                          child: Text(l10n.revalidateConnection),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: PawmateSpace.large),
            HanddrawnCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.accessAndRecovery,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: PawmateSpace.small),
                  Text(l10n.recoverySettingsHelp),
                  TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) =>
                            PairingRecoveryPage(initialServerURL: serverURL),
                      ),
                    ),
                    child: Text(l10n.restoreAccess),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const LoginMethodsPage(),
                      ),
                    ),
                    child: Text(l10n.chooseSignInMethod),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
