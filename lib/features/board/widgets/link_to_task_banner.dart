import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/kanban_controller.dart';

/// Small persistent banner shown while [linkToTaskSourceProvider] is
/// armed - stays up through the camera pan to the kanban board (the one
/// "arm, use once" gesture in this app that spans an animation rather
/// than resolving on the very next click), so the user has a visible
/// reminder of what they're doing and a way to back out. Purely
/// presentational; the actual click-to-link resolution and Escape-to-
/// cancel handling both live in `board_canvas.dart`, same "overlay
/// renders, canvas Listener decides" split every other overlay in this
/// app follows.
class LinkToTaskBanner extends ConsumerWidget {
  const LinkToTaskBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final armed = ref.watch(linkToTaskSourceProvider);
    if (armed == null) return const SizedBox.shrink();

    return Positioned(
      top: 76,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          elevation: 0,
          color: AppTheme.accent,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              'Click a task to link — Esc to cancel',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
