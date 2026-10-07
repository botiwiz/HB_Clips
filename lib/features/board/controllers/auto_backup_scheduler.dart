import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart'
    show kAutoBackupInitialDelay, kAutoBackupInterval, kAutoBackupMinGap;
import '../services/auto_backup_service.dart';

/// Zero-footprint widget (renders nothing) that periodically writes a
/// fresh backup of every board to disk - see `auto_backup_service.dart`.
/// Mirrors `BoardViewPersistence`'s shape exactly: a `ConsumerStatefulWidget`
/// whose `Timer`/`WidgetsBindingObserver` are held as real `State`
/// instance fields, inserted once as a plain `Stack` child of
/// `BoardScreen`. Native-desktop-only - never schedules anything on web.
class AutoBackupScheduler extends ConsumerStatefulWidget {
  const AutoBackupScheduler({super.key});

  @override
  ConsumerState<AutoBackupScheduler> createState() =>
      _AutoBackupSchedulerState();
}

class _AutoBackupSchedulerState extends ConsumerState<AutoBackupScheduler>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _lastRun;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    WidgetsBinding.instance.addObserver(this);
    Future.delayed(kAutoBackupInitialDelay, _run);
    _timer = Timer.periodic(kAutoBackupInterval, (_) => _run());
  }

  @override
  void dispose() {
    if (!kIsWeb) WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _run();
  }

  Future<void> _run() async {
    final now = DateTime.now();
    if (_lastRun != null && now.difference(_lastRun!) < kAutoBackupMinGap) {
      return;
    }
    _lastRun = now;
    await runAutoBackup(ref);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
