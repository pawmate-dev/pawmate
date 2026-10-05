import 'package:flutter/material.dart';

import '../icons/navigation/navigation_doodle_icon.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

/// Icon-only couple navigation with localized semantics and unread reminders.
class CrayonNavigationBar extends StatelessWidget {
  const CrayonNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.chatLabel,
    required this.gamesLabel,
    required this.lifeLabel,
    super.key,
    this.unreadCount = 0,
  }) : assert(selectedIndex >= 0 && selectedIndex < 3),
       assert(unreadCount >= 0);

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final String chatLabel;
  final String gamesLabel;
  final String lifeLabel;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final labels = [chatLabel, gamesLabel, lifeLabel];
    return Material(
      color: PawmateColors.paper,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PawmateSpace.large,
            vertical: PawmateSpace.small,
          ),
          child: Row(
            children: [
              for (final symbol in NavigationDoodle.values)
                Expanded(
                  child: _Destination(
                    symbol: symbol,
                    label: labels[symbol.index],
                    selected: selectedIndex == symbol.index,
                    unreadCount: symbol == NavigationDoodle.chat
                        ? unreadCount
                        : 0,
                    onPressed: () => onDestinationSelected(symbol.index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Retains native keyboard activation without Material ink or text labels.
class _Destination extends StatefulWidget {
  const _Destination({
    required this.symbol,
    required this.label,
    required this.selected,
    required this.unreadCount,
    required this.onPressed,
  });

  final NavigationDoodle symbol;
  final String label;
  final bool selected;
  final int unreadCount;
  final VoidCallback onPressed;

  @override
  State<_Destination> createState() => _DestinationState();
}

class _DestinationState extends State<_Destination> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      label: widget.label,
      button: true,
      selected: widget.selected,
      child: Tooltip(
        message: widget.label,
        excludeFromSemantics: true,
        child: TextButton(
          onPressed: widget.onPressed,
          onFocusChange: (focused) => setState(() => _focused = focused),
          style: TextButton.styleFrom(
            minimumSize: const Size(64, 64),
            padding: EdgeInsets.zero,
            splashFactory: NoSplash.splashFactory,
            overlayColor: Colors.transparent,
          ),
          child: Badge(
            isLabelVisible: widget.unreadCount > 0,
            backgroundColor: PawmateColors.ink,
            textColor: PawmateColors.paper,
            label: ExcludeSemantics(
              child: Text(
                widget.unreadCount > 99 ? '99+' : '${widget.unreadCount}',
              ),
            ),
            child: NavigationDoodleIcon(
              symbol: widget.symbol,
              selected: widget.selected,
              focused: _focused,
            ),
          ),
        ),
      ),
    ),
  );
}
