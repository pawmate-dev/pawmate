import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Native tooltip, semantics and keyboard activation without ink/press animation.
class CrayonIconButton extends StatelessWidget {
  const CrayonIconButton({
    required this.label,
    required this.child,
    required this.onPressed,
    super.key,
  });
  final String label;
  final Widget child;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    enabled: onPressed != null,
    child: Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              maximumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
              splashFactory: NoSplash.splashFactory,
              overlayColor: Colors.transparent,
              animationDuration: Duration.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ).copyWith(
              side: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.focused)
                    ? const BorderSide(color: PawmateColors.ink, width: 2)
                    : BorderSide.none,
              ),
            ),
        child: ExcludeSemantics(child: child),
      ),
    ),
  );
}
