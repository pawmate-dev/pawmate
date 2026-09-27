import 'package:flutter/material.dart';

import '../../../design/doodle_house.dart';
import '../../../design/pawmate_theme.dart';

/// Introduces the pairing flow with a small shared-home illustration.
class PairingHeader extends StatelessWidget {
  const PairingHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const DoodleHouse(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start your little home',
                style: textTheme.headlineMedium?.copyWith(
                  color: PawmateColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Set up a private place, then invite your favorite person in.',
                style: textTheme.bodyLarge?.copyWith(
                  color: PawmateColors.softBrown,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
