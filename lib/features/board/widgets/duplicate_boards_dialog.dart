import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/database.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/boards_repository.dart';

/// Groups [boards] by trimmed, case-insensitive name - the duplicate-board
/// detection signal (see the duplicate-boards plan addendum): cheap, no new
/// schema, and matches how a user would spot a duplicate themselves. Only
/// groups with 2+ boards are duplicates; a unique name never appears here.
List<List<BoardRow>> _duplicateGroups(List<BoardRow> boards) {
  final byName = <String, List<BoardRow>>{};
  for (final board in boards) {
    final key = board.name.trim().toLowerCase();
    byName.putIfAbsent(key, () => []).add(board);
  }
  return [
    for (final group in byName.values)
      if (group.length > 1) group,
  ];
}

/// Entry point for both the File menu's "FIND DUPLICATES..." item and the
/// automatic post-Load check - scans every current board for name
/// collisions and shows a review dialog, or a plain "none found" message.
Future<void> showDuplicateBoardsDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final boards = ref.read(boardsProvider).valueOrNull ?? [];
  final groups = _duplicateGroups(boards);

  if (groups.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Find duplicates'),
        content: const Text('No duplicate board names found.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _DuplicateBoardsReviewDialog(groups: groups),
  );
}

/// One board's created/content summary, fetched once when the dialog opens
/// (not re-fetched per rebuild) - same "fetch once, cache in State" pattern
/// this app already uses for one-shot async detail fetches elsewhere.
class _BoardDetail {
  final int clipCount;
  final int frameCount;

  const _BoardDetail({required this.clipCount, required this.frameCount});
}

String _formatDate(DateTime dt) {
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

class _DuplicateBoardsReviewDialog extends ConsumerStatefulWidget {
  final List<List<BoardRow>> groups;

  const _DuplicateBoardsReviewDialog({required this.groups});

  @override
  ConsumerState<_DuplicateBoardsReviewDialog> createState() =>
      _DuplicateBoardsReviewDialogState();
}

class _DuplicateBoardsReviewDialogState
    extends ConsumerState<_DuplicateBoardsReviewDialog> {
  final Set<String> _checked = {};
  Map<String, _BoardDetail>? _details;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final clipsRepo = ref.read(clipsRepositoryProvider);
    final framesRepo = ref.read(framesRepositoryProvider);
    final details = <String, _BoardDetail>{};
    for (final group in widget.groups) {
      for (final board in group) {
        final clipCount = await clipsRepo.countActiveClips(board.id);
        final frameCount = await framesRepo.countFrames(board.id);
        details[board.id] = _BoardDetail(
          clipCount: clipCount,
          frameCount: frameCount,
        );
      }
    }
    if (!mounted) return;
    setState(() => _details = details);
  }

  Future<void> _confirmAndDelete(BuildContext context) async {
    if (_checked.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete boards?'),
        content: Text(
          "Delete ${_checked.length} board${_checked.length == 1 ? '' : 's'}? "
          "This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final repo = ref.read(boardsRepositoryProvider);
    final lastBoardFailures = <String>[];
    for (final group in widget.groups) {
      for (final board in group) {
        if (!_checked.contains(board.id)) continue;
        try {
          final wasCurrent = ref.read(currentBoardIdProvider) == board.id;
          await repo.deleteBoard(board.id);
          if (wasCurrent) {
            final remaining = ref.read(boardsProvider).valueOrNull ?? [];
            if (remaining.isNotEmpty) {
              ref.read(currentBoardIdProvider.notifier).state =
                  remaining.first.id;
            }
          }
        } on LastBoardException {
          lastBoardFailures.add(board.name);
        }
      }
    }

    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (lastBoardFailures.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Couldn't delete the only remaining board: "
            '${lastBoardFailures.join(', ')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    return AlertDialog(
      title: const Text('Possible duplicate boards'),
      content: SizedBox(
        width: 420,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final group in widget.groups) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, top: 8),
                  child: Text(
                    group.first.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                for (final board in group)
                  CheckboxListTile(
                    dense: true,
                    value: _checked.contains(board.id),
                    onChanged: (checked) => setState(() {
                      if (checked ?? false) {
                        _checked.add(board.id);
                      } else {
                        _checked.remove(board.id);
                      }
                    }),
                    title: Text(board.name, overflow: TextOverflow.ellipsis),
                    subtitle: details == null
                        ? const Text('Loading...')
                        : Text(
                            'Created ${_formatDate(board.createdAt)} · '
                            '${details[board.id]?.clipCount ?? 0} images · '
                            '${details[board.id]?.frameCount ?? 0} frames',
                          ),
                  ),
                const Divider(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
          onPressed: _checked.isEmpty
              ? null
              : () => _confirmAndDelete(context),
          child: Text('DELETE SELECTED (${_checked.length})'),
        ),
      ],
    );
  }
}
