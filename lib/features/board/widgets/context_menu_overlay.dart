import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/kanban_controller.dart';

const double _kRowHeight = 32;
const double _kMenuWidth = 220;

/// A generic right-click/picker popup menu, driven entirely by
/// [contextMenuProvider] - has no kanban-specific knowledge itself (every
/// item's label and `onSelected` closure is built by the caller, e.g.
/// the right-click "Link to task..." handler in `board_canvas.dart`).
/// Dismissed by `board_canvas.dart`'s own pointer-down handling: any
/// click outside [screenRectFor]'s rect clears [contextMenuProvider],
/// same click-through-guard convention every other floating overlay in
/// this app already follows (`FrameRenameOverlay.screenRectFor`, etc).
class ContextMenuOverlay extends ConsumerWidget {
  const ContextMenuOverlay({super.key});

  static Rect screenRectFor(ContextMenuRequest request) {
    return Rect.fromLTWH(
      request.screenPosition.dx,
      request.screenPosition.dy,
      _kMenuWidth,
      _kRowHeight * request.items.length,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(contextMenuProvider);
    if (request == null) return const SizedBox.shrink();

    return Positioned(
      left: request.screenPosition.dx,
      top: request.screenPosition.dy,
      width: _kMenuWidth,
      child: Material(
        elevation: 0,
        color: AppTheme.surfaceElevated,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in request.items)
              InkWell(
                onTap: () {
                  ref.read(contextMenuProvider.notifier).state = null;
                  item.onSelected();
                },
                child: SizedBox(
                  height: _kRowHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
