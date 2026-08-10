import 'dart:async';

import 'package:flutter/material.dart';

import '../error/user_message.dart';

class AppErrorNotice {
  AppErrorNotice._();

  static OverlayEntry? _activeEntry;
  static OverlayState? _activeOverlay;

  static void show(
    BuildContext context,
    Object error, {
    Duration duration = const Duration(seconds: 6),
  }) {
    showMessage(context, UserMessage.fromError(error), duration: duration);
  }

  static void showMessage(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 6),
  }) {
    final normalized = message.trim();
    if (normalized.isEmpty) {
      return;
    }

    _removeActiveEntry();

    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder:
          (_) => _AppErrorNoticeContent(
            message: normalized,
            duration: duration,
            onDismiss: () => _removeEntry(entry),
          ),
    );

    _activeEntry = entry;
    _activeOverlay = overlay;
    overlay.insert(entry);
  }

  static void _removeActiveEntry() {
    final entry = _activeEntry;
    if (entry != null) {
      _removeEntry(entry);
    }
  }

  static void _removeEntry(OverlayEntry entry) {
    if (!identical(_activeEntry, entry)) {
      return;
    }

    final overlay = _activeOverlay;
    _activeEntry = null;
    _activeOverlay = null;

    if (overlay?.mounted ?? false) {
      entry.remove();
      entry.dispose();
    }
  }
}

class _AppErrorNoticeContent extends StatefulWidget {
  const _AppErrorNoticeContent({
    required this.message,
    required this.duration,
    required this.onDismiss,
  });

  final String message;
  final Duration duration;
  final VoidCallback onDismiss;

  @override
  State<_AppErrorNoticeContent> createState() => _AppErrorNoticeContentState();
}

class _AppErrorNoticeContentState extends State<_AppErrorNoticeContent> {
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _dismissTimer = Timer(widget.duration, widget.onDismiss);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomInset + 16,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Semantics(
              container: true,
              liveRegion: true,
              label: 'Ошибка: ${widget.message}',
              child: Material(
                key: const Key('app-error-notice'),
                color: theme.colorScheme.errorContainer,
                elevation: 12,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Закрыть сообщение',
                        onPressed: widget.onDismiss,
                        icon: const Icon(Icons.close_rounded),
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
