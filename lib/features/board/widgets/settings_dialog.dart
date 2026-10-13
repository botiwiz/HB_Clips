import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants.dart' show kCornerRadius;
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_fonts.dart';
import '../../../core/theme/theme_settings.dart';
import '../../../core/widgets/hsv_color_picker.dart';
import '../../../data/local/database.dart' show ThemeRow;
import '../../../data/providers.dart';
import '../services/backup_folder_service.dart';

const _uuid = Uuid();

/// Opens the Settings dialog (General + Theming) - reached from the new
/// header button, see `board_screen.dart`.
Future<void> showSettingsDialog(BuildContext context, WidgetRef ref) async {
  await showDialog<void>(
    context: context,
    builder: (context) => const SettingsDialog(),
  );
}

enum _SettingsSection { general, theming }

/// A single editable chrome color token - [get]/[set] close over
/// [ThemeSettings]'s matching field/`copyWith` parameter, so the 8 rows in
/// the Theming section are generated from one list instead of 8 hand-
/// written, near-identical widgets.
class _ColorToken {
  final String label;
  final Color Function(ThemeSettings) get;
  final ThemeSettings Function(ThemeSettings, Color) set;
  const _ColorToken(this.label, this.get, this.set);
}

final List<_ColorToken> _colorTokens = [
  _ColorToken('Accent', (s) => s.accent, (s, c) => s.copyWith(accent: c)),
  _ColorToken('Danger', (s) => s.danger, (s, c) => s.copyWith(danger: c)),
  _ColorToken(
    'Canvas background',
    (s) => s.canvasBackground,
    (s, c) => s.copyWith(canvasBackground: c),
  ),
  _ColorToken(
    'Surface (card)',
    (s) => s.surfaceCard,
    (s, c) => s.copyWith(surfaceCard: c),
  ),
  _ColorToken(
    'Surface (elevated)',
    (s) => s.surfaceElevated,
    (s, c) => s.copyWith(surfaceElevated: c),
  ),
  _ColorToken('Border', (s) => s.border, (s, c) => s.copyWith(border: c)),
  _ColorToken(
    'Text (primary)',
    (s) => s.textPrimary,
    (s, c) => s.copyWith(textPrimary: c),
  ),
  _ColorToken(
    'Text (secondary)',
    (s) => s.textSecondary,
    (s, c) => s.copyWith(textSecondary: c),
  ),
];

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  _SettingsSection _section = _SettingsSection.general;

  // General section state.
  String? _backupFolderPath;
  bool _loadingBackupPath = true;

  // Theming section state - a local, dialog-only draft. Nothing here
  // writes to the DB (and nothing re-themes the live app) until "Apply",
  // "Save changes", or "Save as new theme..." is pressed - see those
  // methods below.
  late ThemeSettings _draft;
  String? _draftSourceThemeId;
  String? _openColorRow;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(resolvedThemeSettingsProvider);
    _draftSourceThemeId = ref.read(activeThemeIdProvider).valueOrNull;
    _loadBackupPath();
  }

  Future<void> _loadBackupPath() async {
    final path = await ref
        .read(appSettingsRepositoryProvider)
        .getBackupFolderPath();
    if (!mounted) return;
    setState(() {
      _backupFolderPath = path;
      _loadingBackupPath = false;
    });
  }

  /// Whether [_draftSourceThemeId] refers to a user-saved theme (not the
  /// built-in default, not a `kBuiltInThemes` preset) - "Save changes"
  /// only makes sense for that case; a built-in/default draft has no row
  /// of its own to overwrite.
  bool get _isEditableSavedTheme {
    final id = _draftSourceThemeId;
    return id != null && !kBuiltInThemes.containsKey(id);
  }

  Future<void> _applyTheme(String? id, ThemeSettings settings) async {
    await ref.read(appSettingsRepositoryProvider).setActiveThemeId(id);
    if (!mounted) return;
    setState(() {
      _draft = settings;
      _draftSourceThemeId = id;
      _openColorRow = null;
    });
  }

  Future<void> _saveChanges() async {
    final id = _draftSourceThemeId;
    if (id == null) return;
    await ref.read(themesRepositoryProvider).updateTheme(id, settings: _draft);
  }

  Future<void> _saveAsNewTheme() async {
    final controller = TextEditingController(text: 'My theme');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save as new theme'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Theme name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;

    final id = _uuid.v4();
    await ref
        .read(themesRepositoryProvider)
        .createTheme(id, name.trim(), _draft);
    await _applyTheme(id, _draft);
  }

  Future<void> _renameTheme(ThemeRow theme) async {
    final controller = TextEditingController(text: theme.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename theme'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    await ref
        .read(themesRepositoryProvider)
        .updateTheme(theme.id, name: name.trim());
  }

  Future<void> _deleteTheme(ThemeRow theme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete theme?'),
        content: Text('This permanently deletes "${theme.name}".'),
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
    if (confirmed != true || !mounted) return;

    await ref.read(themesRepositoryProvider).deleteTheme(theme.id);
    if (_draftSourceThemeId == theme.id) {
      await _applyTheme(null, ThemeSettings.builtInDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('SETTINGS'),
      content: SizedBox(
        width: 620,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SectionTab(
                  label: 'GENERAL',
                  selected: _section == _SettingsSection.general,
                  onTap: () =>
                      setState(() => _section = _SettingsSection.general),
                ),
                const SizedBox(width: 8),
                _SectionTab(
                  label: 'THEMING',
                  selected: _section == _SettingsSection.theming,
                  onTap: () =>
                      setState(() => _section = _SettingsSection.theming),
                ),
              ],
            ),
            const Divider(height: 16),
            Expanded(
              child: _section == _SettingsSection.general
                  ? _buildGeneral()
                  : _buildTheming(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CLOSE'),
        ),
      ],
    );
  }

  Widget _buildGeneral() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BACKUP FOLDER',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "HB_Clips saves every board's .hbbackup file into one folder "
            'you choose - handy if you sync it yourself (Dropbox, '
            "OneDrive, etc), so every machine always has every board's "
            'latest state.',
          ),
          const SizedBox(height: 12),
          _loadingBackupPath
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(),
                )
              : Text(_backupFolderPath ?? 'Not set yet'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () async {
                  final picked = await pickBackupFolder(context);
                  if (picked == null) return;
                  await ref
                      .read(appSettingsRepositoryProvider)
                      .setBackupFolderPath(picked);
                  if (!mounted) return;
                  setState(() => _backupFolderPath = picked);
                },
                child: const Text('CHANGE FOLDER...'),
              ),
              TextButton(
                onPressed: _backupFolderPath == null
                    ? null
                    : () => openBackupFolderInFileManager(
                        context,
                        _backupFolderPath!,
                      ),
                child: const Text('OPEN IN FILE MANAGER'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTheming() {
    final themes = ref.watch(themesProvider).valueOrNull ?? const [];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SAVED THEMES',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          _ThemeListRow(
            label: 'DEFAULT',
            active: _draftSourceThemeId == null,
            onApply: () => _applyTheme(null, ThemeSettings.builtInDefault),
          ),
          for (final entry in kBuiltInThemes.entries)
            _ThemeListRow(
              label: kBuiltInThemeNames[entry.key] ?? entry.key,
              active: _draftSourceThemeId == entry.key,
              onApply: () => _applyTheme(entry.key, entry.value),
            ),
          for (final theme in themes)
            _ThemeListRow(
              label: theme.name,
              active: _draftSourceThemeId == theme.id,
              onApply: () =>
                  _applyTheme(theme.id, ThemeSettings.fromRow(theme)),
              onRename: () => _renameTheme(theme),
              onDelete: () => _deleteTheme(theme),
            ),
          const SizedBox(height: 16),
          Text(
            'COLORS',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          for (final token in _colorTokens) _buildColorRow(token),
          const SizedBox(height: 16),
          Text(
            'TYPOGRAPHY',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Font family'),
              const SizedBox(width: 12),
              DropdownButton<String?>(
                value: _draft.fontFamily,
                items: [
                  for (final entry in kThemeFontChoices.entries)
                    DropdownMenuItem<String?>(
                      value: entry.value,
                      child: Text(entry.key),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _draft = _draft.copyWith(fontFamily: value)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Font size'),
              const SizedBox(width: 12),
              Expanded(
                child: Slider(
                  value: _draft.fontSizeScale.clamp(0.85, 1.3),
                  min: 0.85,
                  max: 1.3,
                  divisions: 9,
                  label: '${(_draft.fontSizeScale * 100).round()}%',
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(fontSizeScale: value),
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                child: Text('${(_draft.fontSizeScale * 100).round()}%'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _saveAsNewTheme,
                child: const Text('SAVE AS NEW THEME...'),
              ),
              if (_isEditableSavedTheme)
                FilledButton(
                  onPressed: _saveChanges,
                  child: const Text('SAVE CHANGES'),
                ),
              TextButton(
                onPressed: () =>
                    _applyTheme(null, ThemeSettings.builtInDefault),
                child: const Text('RESET TO DEFAULT'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorRow(_ColorToken token) {
    final color = token.get(_draft);
    final open = _openColorRow == token.label;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(token.label)),
              InlineColorPickerSwatch(
                color: color,
                open: open,
                onTap: () =>
                    setState(() => _openColorRow = open ? null : token.label),
              ),
            ],
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: InlineHsvPickerBar(
                initialColor: color,
                onChanged: (c) => setState(() => _draft = token.set(_draft, c)),
                onDone: () => setState(() => _openColorRow = null),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SectionTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.surfaceElevated : null,
          borderRadius: BorderRadius.circular(kCornerRadius),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.accent : AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ThemeListRow extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onApply;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const _ThemeListRow({
    required this.label,
    required this.active,
    required this.onApply,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: active ? AppTheme.accent : AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
          TextButton(onPressed: onApply, child: const Text('APPLY')),
          if (onRename != null)
            IconButton(
              tooltip: 'Rename',
              icon: const Icon(Icons.edit_outlined, size: 16),
              onPressed: onRename,
            ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline, size: 16),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
