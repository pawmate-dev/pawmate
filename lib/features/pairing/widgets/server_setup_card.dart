import 'package:flutter/material.dart';

import '../../../design/handdrawn_button.dart';
import '../../../design/handdrawn_card.dart';
import '../../../design/handdrawn_text_field.dart';
import '../../../design/pawmate_theme.dart';

/// Collects and submits the inviter's private Pawmate server address.
class ServerSetupCard extends StatelessWidget {
  const ServerSetupCard({
    required this.formKey,
    required this.controller,
    required this.isLoading,
    required this.onCreateInvite,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onCreateInvite;

  @override
  Widget build(BuildContext context) {
    return HanddrawnCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.home_work_outlined, color: PawmateColors.ink),
                const SizedBox(width: 8),
                Text(
                  'Choose your home address',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: PawmateColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Use the URL or domain of the private server you trust.',
              style: TextStyle(color: PawmateColors.softBrown, height: 1.35),
            ),
            const SizedBox(height: 18),
            HanddrawnTextField(
              controller: controller,
              labelText: 'Server URL or domain',
              hintText: 'https://pawmate.example.com',
              prefixIcon: Icons.link,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter your server URL.';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            HanddrawnButton(
              onPressed: isLoading ? null : onCreateInvite,
              icon: Icons.favorite_border,
              label: isLoading ? 'Making a little room…' : 'Create invitation',
            ),
          ],
        ),
      ),
    );
  }
}
