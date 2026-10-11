import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../services/add_image_service.dart' show showBoardSnack;
import '../services/pinterest_import_service.dart';
import '../services/pinterest_service.dart';

/// Lets the user search Pinterest for boards by keyword and import one in
/// full - every pin downloaded at original resolution into a new frame.
/// A modal dialog rather than an anchored toolbar popover: the trigger
/// button lives inside the header's horizontally-scrolling icon row (see
/// `PillGroup`), so there's no stable screen position to anchor a popover
/// to as that row scrolls - same reasoning `board_screen.dart`'s frame-
/// color picker already documents for using `AlertDialog` instead of an
/// inline popover. The modal barrier also already blocks
/// `board_canvas.dart`'s raw gesture `Listener` for free, same as every
/// other dialog in this app - no separate click-through guard needed.
///
/// Talks to Pinterest's unofficial "resource" JSON endpoints (see
/// `PinterestService`'s doc comment for the full disclosure on that) -
/// this sandbox's network policy blocks pinterest.com entirely, so none
/// of this could be exercised against the real API while building it.
/// If search comes back empty/malformed on a real run, see
/// `PinterestService`'s doc comment for the specific two things to check
/// first.
void showPinterestSearchDialog(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    builder: (context) => const _PinterestSearchDialog(),
  );
}

class _PinterestSearchDialog extends ConsumerStatefulWidget {
  const _PinterestSearchDialog();

  @override
  ConsumerState<_PinterestSearchDialog> createState() =>
      _PinterestSearchDialogState();
}

class _PinterestSearchDialogState
    extends ConsumerState<_PinterestSearchDialog> {
  final _controller = TextEditingController();
  final _pinterest = PinterestService();

  bool _searching = false;
  List<PinterestBoard>? _results;
  String? _errorMessage;

  // Set while a board is being imported - the whole dialog shows a
  // progress state instead of the search UI, since importing can mean
  // hundreds of sequential network requests and the user needs to see
  // it's actually working, not just a frozen dialog.
  PinterestBoard? _importingBoard;
  int _importCompleted = 0;
  int _importTotal = 0;

  @override
  void dispose() {
    _controller.dispose();
    _pinterest.close();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _errorMessage = null;
      _results = null;
    });
    try {
      final results = await _pinterest.searchBoards(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is PinterestRequestException
            ? e.message
            : 'Search failed: $e';
        _searching = false;
      });
    }
  }

  Future<void> _import(PinterestBoard board) async {
    setState(() {
      _importingBoard = board;
      _importCompleted = 0;
      _importTotal = 0;
    });
    try {
      final result = await importPinterestBoard(
        ref,
        board: board,
        context: context,
        onProgress: (completed, total) {
          if (!mounted) return;
          setState(() {
            _importCompleted = completed;
            _importTotal = total;
          });
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      final summary = result.failedCount == 0
          ? 'Imported ${result.importedCount} images from "${board.name}".'
          : 'Imported ${result.importedCount} images from "${board.name}" '
                '(${result.failedCount} failed to download).';
      showBoardSnack(context, summary, isError: result.importedCount == 0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _importingBoard = null);
      showBoardSnack(
        context,
        e is PinterestRequestException ? e.message : 'Import failed: $e',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_importingBoard != null) {
      return AlertDialog(
        title: const Text('Importing board...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${_importingBoard!.name}"'),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _importTotal == 0 ? null : _importCompleted / _importTotal,
            ),
            const SizedBox(height: 8),
            Text(
              _importTotal == 0
                  ? 'Fetching board...'
                  : 'Downloaded $_importCompleted of $_importTotal images',
            ),
          ],
        ),
      );
    }

    return AlertDialog(
      title: const Text('Search Pinterest boards'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g. mid-century furniture',
                isDense: true,
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 12),
            if (_searching) const Center(child: CircularProgressIndicator()),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppTheme.danger),
              ),
            if (_results != null && _results!.isEmpty)
              const Text('No boards found.'),
            if (_results != null && _results!.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results!.length,
                  itemBuilder: (context, index) {
                    final board = _results![index];
                    return ListTile(
                      leading: board.thumbnailUrl == null
                          ? const Icon(Icons.dashboard_outlined)
                          : Image.network(
                              board.thumbnailUrl!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.dashboard_outlined),
                            ),
                      title: Text(board.name),
                      subtitle: Text(
                        [
                          if (board.ownerUsername != null)
                            '@${board.ownerUsername}',
                          if (board.pinCount != null) '${board.pinCount} pins',
                        ].join(' · '),
                      ),
                      trailing: FilledButton(
                        onPressed: () => _import(board),
                        child: const Text('Import'),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _searching ? null : _search,
          child: const Text('Search'),
        ),
      ],
    );
  }
}
