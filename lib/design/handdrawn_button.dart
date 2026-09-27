import 'package:flutter/material.dart';

import 'pawmate_theme.dart';

/// A semantic Material button styled as a small hand-drawn paper label.
class HanddrawnButton extends StatelessWidget {
  const HanddrawnButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.primary = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: primary ? PawmateColors.ink : PawmateColors.softBrown,
        width: 2,
      ),
    );
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(label),
            ],
          );

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: primary
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: PawmateColors.ink,
                foregroundColor: PawmateColors.paper,
                disabledBackgroundColor: PawmateColors.softBrown.withAlpha(100),
                disabledForegroundColor: PawmateColors.paper,
                elevation: 0,
                shape: shape,
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: PawmateColors.ink,
                side: const BorderSide(
                  color: PawmateColors.softBrown,
                  width: 2,
                ),
                shape: shape,
              ),
              child: child,
            ),
    );
  }
}
