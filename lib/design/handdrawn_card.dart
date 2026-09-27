import 'package:flutter/material.dart';

import 'pawmate_theme.dart';

/// A paper-like surface with a stable ink outline and a small offset shadow.
class HanddrawnCard extends StatelessWidget {
  const HanddrawnCard({required this.child, super.key, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFFFFCF3),
        border: Border.all(color: PawmateColors.ink, width: 2),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(14),
          bottomRight: Radius.circular(20),
          bottomLeft: Radius.circular(13),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x263C3530),
            offset: Offset(3, 4),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }
}
