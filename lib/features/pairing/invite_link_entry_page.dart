import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/components/handdrawn_button.dart';
import '../../design/components/handdrawn_card.dart';
import '../../design/layouts/handdrawn_scaffold.dart';
import '../../design/components/handdrawn_text_field.dart';
import '../../design/icons/access/access_doodle_icon.dart';
import '../../design/theme/spacing.dart';
import 'invitation_link.dart';
import 'invitee_accept_page.dart';
import 'widgets/pairing_error_note.dart';
import '../../l10n/generated/app_localizations.dart';

/// Receives an explicitly pasted link before showing the server/accept review.
class InviteLinkEntryPage extends StatefulWidget {
  const InviteLinkEntryPage({super.key});

  @override
  State<InviteLinkEntryPage> createState() => _InviteLinkEntryPageState();
}

class _InviteLinkEntryPageState extends State<InviteLinkEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _link = TextEditingController();
  String? _clipboardError;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  /// Reads the clipboard only after a user gesture, never automatically at startup.
  Future<void> _paste() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      setState(() {
        if (data?.text?.trim().isNotEmpty == true) {
          _link.text = data!.text!.trim();
          _clipboardError = null;
        } else {
          _clipboardError = l10n.pasteInvitationLinkFirst;
        }
      });
    } on Object {
      if (mounted) {
        setState(() => _clipboardError = l10n.clipboardUnavailable);
      }
    }
  }

  /// Opens a review page; simply pasting a link never accepts the invitation.
  void _review() {
    if (!_formKey.currentState!.validate()) return;
    final uri = InvitationLink.parse(_link.text);
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => InviteeAcceptPage(inviteUri: uri)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HanddrawnScaffold(
      title: l10n.acceptInvitation,
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(PawmateSpace.page),
          children: [
            HanddrawnCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: AccessDoodleIcon(
                        symbol: AccessDoodle.acceptInvitation,
                      ),
                    ),
                    const SizedBox(height: PawmateSpace.large),
                    Text(
                      l10n.anInvitationForTwo,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: PawmateSpace.medium),
                    Text(
                      l10n.invitationPasteHelp,
                      style: TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: PawmateSpace.page),
                    HanddrawnTextField(
                      controller: _link,
                      labelText: l10n.invitationLink,
                      hintText: l10n.invitationLinkHint,
                      validator: (value) {
                        try {
                          InvitationLink.parse(value ?? '');
                          return null;
                        } on FormatException {
                          return l10n.invalidInvitationLink;
                        }
                      },
                    ),
                    const SizedBox(height: PawmateSpace.medium),
                    HanddrawnButton(
                      label: l10n.pasteLink,
                      onPressed: _paste,
                      icon: Icons.content_paste,
                      primary: false,
                    ),
                    const SizedBox(height: PawmateSpace.large),
                    HanddrawnButton(
                      label: l10n.reviewInvitation,
                      onPressed: _review,
                    ),
                  ],
                ),
              ),
            ),
            if (_clipboardError != null) ...[
              const SizedBox(height: PawmateSpace.large),
              PairingErrorNote(message: _clipboardError!),
            ],
          ],
        ),
      ),
    );
  }
}
