import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/database.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/boards_repository.dart';

const _uuid = Uuid();

BoardRow? _findBoard(List<BoardRow> boards, String id) {
  for (final board in boards) {
    if (board.id == id) return board;
  }
  return null;
}

/// Compact board-name button (matches the app's pill chrome) that opens a
/// dropdown menu for switching boards, creating a new one, or opening the
/// full rename/delete "Manage boards" dialog - the board-switcher UI called
/// for by the multi-board sub-phase.
class BoardSwitcher extends ConsumerWidget {
  const BoardSwitcher({super.key});

  Future<void> _createBoard(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: 'My Board');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New board'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Board name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;

    final id = _uuid.v4();
    await ref.read(boardsRepositoryProvider).createBoard(id, name.trim());
    ref.read(currentBoardIdProvider.notifier).state = id;
  }

  Future<void> _manageBoards(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (context) => const _ManageBoardsDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boards = ref.watch(boardsProvider).valueOrNull ?? [];
    final currentId = ref.watch(currentBoardIdProvider);
    final label = _findBoard(boards, currentId)?.name ?? 'Board';

    return Material(
      color: AppTheme.surfaceElevated,
      borderRadius: BorderRadius.circular(999),
      elevation: 6,
      shadowColor: Colors.black54,
      child: PopupMenuButton<String>(
        tooltip: 'Switch board',
        onSelected: (value) {
          if (value == '__new__') {
            _createBoard(context, ref);
          } else if (value == '__manage__') {
            _manageBoards(context, ref);
          } else {
            ref.read(currentBoardIdProvider.notifier).state = value;
          }
        },
        itemBuilder: (context) => [
          for (final board in boards)
            PopupMenuItem<String>(
              value: board.id,
              child: Row(
                children: [
                  Icon(
                    board.id == currentId
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    size: 16,
                    color: board.id == currentId
                        ? AppTheme.red
                        : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(board.name, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: '__new__',
            child: Row(
              children: [
                Icon(Icons.add, size: 16),
                SizedBox(width: 8),
                Text('New board'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: '__manage__',
            child: Row(
              children: [
                Icon(Icons.settings_outlined, size: 16),
                SizedBox(width: 8),
                Text('Manage boards...'),
              ],
            ),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.dashboard_outlined, size: 16),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManageBoardsDialog extends ConsumerWidget {
  const _ManageBoardsDialog();

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    BoardRow board,
  ) async {
    final controller = TextEditingController(text: board.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename board'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    await ref.read(boardsRepositoryProvider).renameBoard(board.id, name.trim());
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    BoardRow board,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete board?'),
        content: Text(
          'This permanently deletes "${board.name}" and every clip and '
          "annotation on it. This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final wasCurrent = ref.read(currentBoardIdProvider) == board.id;
      await ref.read(boardsRepositoryProvider).deleteBoard(board.id);
      if (wasCurrent) {
        final remaining = ref.read(boardsProvider).valueOrNull ?? [];
        if (remaining.isNotEmpty) {
          ref.read(currentBoardIdProvider.notifier).state = remaining.first.id;
        }
      }
    } on LastBoardException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Can't delete the only remaining board.")),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boards = ref.watch(boardsProvider).valueOrNull ?? [];

    return AlertDialog(
      title: const Text('Manage boards'),
      content: SizedBox(
        width: 360,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: boards.length,
          itemBuilder: (context, index) {
            final board = boards[index];
            return ListTile(
              title: Text(board.name, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Rename',
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _rename(context, ref, board),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: boards.length > 1
                        ? () => _delete(context, ref, board)
                        : null,
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
