import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Provides the paper surface and restrained app bar shared by Pawmate pages.
class HanddrawnScaffold extends StatelessWidget {
  const HanddrawnScaffold({
    required this.title,
    required this.body,
    super.key,
    this.bottomNavigationBar,
    this.actions,
  });

  final String? title;
  final Widget body;
  final Widget? bottomNavigationBar;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: title == null
            ? null
            : Text(
                title!,
                style: const TextStyle(
                  color: PawmateColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
        actions: actions,
      ),
      body: body,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
