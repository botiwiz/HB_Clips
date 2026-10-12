import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../services/backup_folder_service.dart';

/// Zero-footprint widget (renders nothing) that checks, once per app
/// launch, whether a backup folder is configured yet - if not, shows the
/// "choose a backup folder" prompt via `ensureBackupFolderConfigured`.
/// Mirrors `AutoBackupScheduler`'s shape exactly: a `ConsumerStatefulWidget`
/// inserted as a plain `Stack` child of `BoardScreen`, firing on the first
/// post-frame callback rather than gating anything on a loading screen
/// (nothing else in this app blocks startup on a splash screen, and this
/// DB read resolves in milliseconds anyway). If the user picks "Later",
/// nothing is persisted, so this same prompt fires again on the *next*
/// app launch - not repeatedly within one session (`_checked` guards
/// that for this widget instance's whole lifetime).
class BackupFolderPromptController extends ConsumerStatefulWidget {
  const BackupFolderPromptController({super.key});

  @override
  ConsumerState<BackupFolderPromptController> createState() => _State();
}

class _State extends ConsumerState<BackupFolderPromptController> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
    }
  }

  Future<void> _maybePrompt() async {
    if (_checked) return;
    _checked = true;
    final path = await ref
        .read(appSettingsRepositoryProvider)
        .getBackupFolderPath();
    if (path != null || !mounted) return;
    await ensureBackupFolderConfigured(context, ref);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
