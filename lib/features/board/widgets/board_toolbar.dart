import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/theme/app_theme.dart';

/// A floating rounded-pill cluster of icon buttons - the Miro-style
/// "grouped toolbar island" shape used throughout `board_screen.dart`
/// instead of a full-width Material `AppBar`.
class PillGroup extends StatelessWidget {
  final List<Widget> children;

  const PillGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceElevated,
      borderRadius: BorderRadius.circular(999),
      elevation: 6,
      shadowColor: Colors.black54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

/// A compact icon button sized to sit comfortably inside a [PillGroup].
class PillIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color? color;
  final VoidCallback onPressed;

  const PillIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, color: color),
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}

/// The window's only close control, now that the OS title bar is gone -
/// styled like a sticky note's corner X. Fills solid red on hover, matching
/// the app's "red = irreversible action" rule (closing is about as
/// irreversible as it gets).
class WindowCloseButton extends StatefulWidget {
  const WindowCloseButton({super.key});

  @override
  State<WindowCloseButton> createState() => _WindowCloseButtonState();
}

class _WindowCloseButtonState extends State<WindowCloseButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: () => windowManager.close(),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hovering ? AppTheme.red : AppTheme.surfaceElevated,
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Icon(
            Icons.close,
            size: 16,
            color: _hovering ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
