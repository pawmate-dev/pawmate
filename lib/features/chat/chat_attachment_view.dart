import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../design/components/crayon_icon_button.dart';
import '../../design/icons/chat/composer_doodle_icon.dart';
import '../../design/theme/colors.dart';
import '../../design/theme/spacing.dart';
import '../../l10n/generated/app_localizations.dart';
import 'attachment_export.dart';
import 'chat_api.dart';
import 'chat_controller.dart';
import 'chat_image_preview_page.dart';

/// Loads image previews on demand and exports files only after an explicit tap.
class ChatAttachmentView extends StatefulWidget {
  const ChatAttachmentView({
    required this.attachment,
    required this.controller,
    super.key,
    this.localBytes,
  });
  final ChatAttachment attachment;
  final ChatController controller;
  final Uint8List? localBytes;
  @override
  State<ChatAttachmentView> createState() => _ChatAttachmentViewState();
}

class _ChatAttachmentViewState extends State<ChatAttachmentView> {
  Future<Uint8List>? _image;
  bool _saving = false;
  bool _transferAllowed = false;
  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(ChatAttachmentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.digest != widget.attachment.digest ||
        oldWidget.localBytes != widget.localBytes ||
        (!_transferAllowed && widget.controller.canTransferAttachments)) {
      _loadImage();
    }
  }

  /// FutureBuilder owns error presentation; no unhandled background download futures.
  void _loadImage() {
    _transferAllowed = widget.controller.canTransferAttachments;
    if (widget.attachment.kind == 'image') {
      _image = widget.localBytes == null
          ? widget.controller.attachmentData(widget.attachment)
          : Future.value(widget.localBytes!);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bytes =
          widget.localBytes ??
          await widget.controller.attachmentData(widget.attachment);
      final saved = await saveChatAttachment(
        widget.attachment.name,
        widget.attachment.contentType,
        bytes,
      );
      if (mounted && saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.attachmentSaved),
          ),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.attachmentUnavailable),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The thumbnail has already loaded verified bytes; preview must work offline.
  void _openPreview(Uint8List bytes) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            ChatImagePreviewPage(name: widget.attachment.name, bytes: bytes),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final metadata = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ComposerDoodleIcon(
          symbol: widget.attachment.kind == 'image'
              ? ComposerDoodle.photo
              : ComposerDoodle.file,
        ),
        const SizedBox(width: PawmateSpace.small),
        Flexible(
          child: Text(
            '${(widget.attachment.size / 1024).ceil()} KiB',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        CrayonIconButton(
          label: l10n.saveAttachment,
          onPressed: _saving ? null : _save,
          child: ComposerDoodleIcon(
            symbol: ComposerDoodle.save,
            enabled: !_saving,
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: PawmateSpace.tiny),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.attachment.kind == 'image')
            FutureBuilder<Uint8List>(
              future: _image,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Semantics(
                    label: l10n.openImagePreview,
                    button: true,
                    child: Tooltip(
                      message: l10n.openImagePreview,
                      excludeFromSemantics: true,
                      child: TextButton(
                        onPressed: () => _openPreview(snapshot.data!),
                        style:
                            TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(44, 44),
                              splashFactory: NoSplash.splashFactory,
                              overlayColor: Colors.transparent,
                              animationDuration: Duration.zero,
                            ).copyWith(
                              side: WidgetStateProperty.resolveWith(
                                (states) => states.contains(WidgetState.focused)
                                    ? const BorderSide(
                                        color: PawmateColors.ink,
                                        width: 2,
                                      )
                                    : BorderSide.none,
                              ),
                            ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            PawmateSpace.chatBubbleJoinedRadius,
                          ),
                          child: Image.memory(
                            snapshot.data!,
                            cacheWidth: 640,
                            height: 180,
                            fit: BoxFit.contain,
                            semanticLabel: widget.attachment.name,
                            errorBuilder: (_, _, _) =>
                                Text(l10n.attachmentUnavailable),
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return TextButton.icon(
                  onPressed: snapshot.connectionState == ConnectionState.waiting
                      ? null
                      : () => setState(_loadImage),
                  style: TextButton.styleFrom(
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: Colors.transparent,
                  ),
                  icon: const ComposerDoodleIcon(symbol: ComposerDoodle.photo),
                  label: Text(
                    snapshot.hasError
                        ? l10n.attachmentUnavailable
                        : l10n.loading,
                    style: const TextStyle(color: PawmateColors.softBrown),
                  ),
                );
              },
            ),
          metadata,
        ],
      ),
    );
  }
}
