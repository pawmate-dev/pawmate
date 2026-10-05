import 'package:flutter/material.dart';

import 'handdrawn_card.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

/// A whole-card action with native focus, keyboard activation and screen reading.
class HanddrawnActionCard extends StatelessWidget {
  const HanddrawnActionCard({
    required this.label,
    required this.description,
    required this.illustration,
    required this.onPressed,
    required this.color,
    super.key,
  });

  final String label;
  final String description;
  final Widget illustration;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    hint: description,
    onTap: onPressed,
    child: ExcludeSemantics(
      child: HanddrawnCard(
        color: color,
        padding: EdgeInsets.zero,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            focusColor: PawmateColors.lavender.withAlpha(65),
            child: Padding(
              padding: const EdgeInsets.all(PawmateSpace.large),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: illustration),
                  const SizedBox(height: PawmateSpace.medium),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: PawmateColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: PawmateSpace.small),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: PawmateColors.ink,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
