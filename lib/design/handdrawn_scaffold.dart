import 'package:flutter/material.dart';

import 'pawmate_theme.dart';

/// Provides the paper surface and restrained app bar shared by Pawmate pages.
class HanddrawnScaffold extends StatelessWidget {
  const HanddrawnScaffold({required this.title, required this.body, super.key});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: PawmateColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: body,
    );
  }
}
