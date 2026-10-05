import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../design/components/crayon_avatar_button.dart';
import '../../../design/components/handdrawn_text_field.dart';
import '../../../design/theme/colors.dart';
import '../../../design/theme/spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../member_profile.dart';

/// Collects required member identity inside the enclosing onboarding form.
class MemberProfileEditor extends StatefulWidget {
  const MemberProfileEditor({super.key, this.enabled = true, this.selectImage});

  final bool enabled;
  final Future<XFile?> Function()? selectImage;

  @override
  State<MemberProfileEditor> createState() => MemberProfileEditorState();
}

class MemberProfileEditorState extends State<MemberProfileEditor> {
  final _nickname = TextEditingController();
  Uint8List? _avatar;
  bool _picking = false;
  String? _pickerError;

  /// Returns submitted identity only after the enclosing form is validated.
  MemberProfile? get profile => _avatar == null
      ? null
      : MemberProfile(nickname: _nickname.text.trim(), avatar: _avatar!);

  /// Selects an image explicitly, then crops it locally to a bounded square PNG.
  Future<void> _pickAvatar(FormFieldState<Uint8List> field) async {
    if (_picking) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _picking = true;
      _pickerError = null;
    });
    try {
      final file = widget.selectImage != null
          ? await widget.selectImage!()
          : await openFile(
              acceptedTypeGroups: [
                XTypeGroup(
                  label: l10n.avatarImages,
                  extensions: const ['png', 'jpg', 'jpeg'],
                  mimeTypes: const ['image/png', 'image/jpeg'],
                  uniformTypeIdentifiers: const ['public.png', 'public.jpeg'],
                ),
              ],
            );
      if (file == null) return;
      if (await file.length() > 10 * 1024 * 1024) {
        throw const FormatException('avatar_file_too_large');
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(
        await file.readAsBytes(),
      );
      ui.ImageDescriptor? descriptor;
      ui.Codec? codec;
      ui.Image? image;
      ui.Picture? picture;
      ui.Image? resized;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        if (descriptor.width < 1 ||
            descriptor.height < 1 ||
            descriptor.width * descriptor.height > 40000000) {
          throw const FormatException('invalid_avatar');
        }
        final scale =
            512 /
            (descriptor.width > descriptor.height
                ? descriptor.width
                : descriptor.height);
        codec = await descriptor.instantiateCodec(
          targetWidth: (descriptor.width * scale).round().clamp(1, 512),
          targetHeight: (descriptor.height * scale).round().clamp(1, 512),
        );
        image = (await codec.getNextFrame()).image;
        final side = (image.width < image.height ? image.width : image.height)
            .toDouble();
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(
            (image.width - side) / 2,
            (image.height - side) / 2,
            side,
            side,
          ),
          const Rect.fromLTWH(0, 0, 256, 256),
          Paint()..filterQuality = FilterQuality.high,
        );
        picture = recorder.endRecording();
        resized = await picture.toImage(256, 256);
        final data = await resized.toByteData(format: ui.ImageByteFormat.png);
        if (data == null || data.lengthInBytes > 256 * 1024) {
          throw const FormatException('invalid_avatar');
        }
        if (!mounted) return;
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        setState(() => _avatar = bytes);
        field.didChange(bytes);
      } finally {
        resized?.dispose();
        picture?.dispose();
        image?.dispose();
        codec?.dispose();
        descriptor?.dispose();
        buffer.dispose();
      }
    } on Object {
      if (mounted) setState(() => _pickerError = l10n.avatarUploadError);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormField<Uint8List>(
          validator: (value) => value == null ? l10n.avatarRequired : null,
          builder: (field) => Column(
            children: [
              CrayonAvatarButton(
                label: _avatar == null ? l10n.uploadAvatar : l10n.changeAvatar,
                avatar: _avatar,
                onPressed: widget.enabled && !_picking
                    ? () => _pickAvatar(field)
                    : null,
              ),
              const SizedBox(height: PawmateSpace.small),
              Text(
                _avatar == null ? l10n.uploadAvatar : l10n.changeAvatar,
                style: const TextStyle(color: PawmateColors.softBrown),
              ),
              if (_pickerError != null || field.hasError) ...[
                const SizedBox(height: PawmateSpace.small),
                Text(
                  _pickerError ?? field.errorText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: PawmateColors.error),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: PawmateSpace.page),
        HanddrawnTextField(
          controller: _nickname,
          labelText: l10n.nickname,
          hintText: l10n.nicknameHint,
          keyboardType: TextInputType.text,
          enabled: widget.enabled,
          validator: (value) {
            final name = value?.trim() ?? '';
            return name.isEmpty ||
                    name.runes.length > 32 ||
                    RegExp(r'[\x00-\x1F\x7F-\x9F]').hasMatch(name)
                ? l10n.nicknameInvalid
                : null;
          },
        ),
      ],
    );
  }
}
