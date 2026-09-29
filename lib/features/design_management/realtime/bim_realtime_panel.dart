import 'package:flutter/material.dart';

import '../../../core/error/user_message.dart';
import 'bim_session_coordinator.dart';
import 'bim_session_models.dart';

class BimRealtimePanel extends StatefulWidget {
  const BimRealtimePanel({
    super.key,
    required this.coordinator,
    required this.sessions,
    required this.isLoading,
    required this.offline,
    required this.onRefresh,
    required this.onCreate,
    required this.onJoin,
    this.canCreate = false,
    this.error,
  });

  final BimSessionCoordinator coordinator;
  final List<BimSessionSummary> sessions;
  final bool isLoading;
  final bool offline;
  final bool canCreate;
  final Object? error;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String name) onCreate;
  final Future<void> Function(BimSessionSummary) onJoin;

  @override
  State<BimRealtimePanel> createState() => _BimRealtimePanelState();
}

class _BimRealtimePanelState extends State<BimRealtimePanel> {
  late BimSessionState _session;
  late void Function() _removeListener;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _removeListener = widget.coordinator.addListener((state) {
      if (mounted) setState(() => _session = state);
    });
  }

  @override
  void didUpdateWidget(BimRealtimePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coordinator != widget.coordinator) {
      _removeListener();
      _listen();
    }
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected =
        _session.connection == BimSessionConnection.connected &&
        !widget.offline;
    final error = widget.error ?? _session.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Совместный просмотр',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Обновить просмотры',
              onPressed:
                  widget.offline || widget.isLoading ? null : widget.onRefresh,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Создать совместный просмотр',
              onPressed:
                  widget.offline ||
                          widget.isLoading ||
                          !widget.canCreate ||
                          !widget.coordinator.rendererReady
                      ? null
                      : _create,
              icon: const Icon(Icons.group_add_outlined),
            ),
          ],
        ),
        if (widget.offline)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Совместный просмотр недоступен без сети.'),
          ),
        if (widget.isLoading) const LinearProgressIndicator(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              UserMessage.fromError(error),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_session.notice case final notice?)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(notice),
          ),
        if (_session.session case final session?) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(session.name),
            subtitle: Text(_connectionLabel(_session.connection)),
            trailing: IconButton(
              tooltip: 'Завершить участие',
              onPressed: widget.coordinator.leave,
              icon: const Icon(Icons.logout),
            ),
          ),
          if (_session.followLoading) const LinearProgressIndicator(),
          if (_session.participants.isEmpty) const Text('Ожидаем участников'),
          for (final participant in _session.participants)
            _participant(participant, connected),
        ] else if (widget.sessions.isEmpty && !widget.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Активных совместных просмотров нет.'),
          )
        else
          for (final session in widget.sessions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.groups_outlined),
              title: Text(session.name),
              trailing: OutlinedButton(
                onPressed:
                    widget.offline ||
                            widget.isLoading ||
                            !widget.coordinator.rendererReady
                        ? null
                        : () => widget.onJoin(session),
                child: const Text('Войти'),
              ),
            ),
      ],
    );
  }

  Widget _participant(BimParticipant participant, bool connected) {
    final own = participant.clientId == widget.coordinator.clientId;
    final following = _session.followingClientId == participant.clientId;
    final color = _participantColor(participant.color);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color,
        foregroundColor:
            ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                ? Colors.white
                : Colors.black,
        child: Text(
          participant.name.isEmpty
              ? '?'
              : participant.name.substring(0, 1).toUpperCase(),
        ),
      ),
      title: Text(own ? '${participant.name} (вы)' : participant.name),
      trailing:
          own
              ? null
              : IconButton(
                tooltip:
                    following
                        ? 'Продолжить самостоятельно'
                        : 'Следовать за участником',
                onPressed:
                    !connected || _session.followLoading
                        ? null
                        : () {
                          if (following) {
                            widget.coordinator.stopFollowing();
                          } else {
                            widget.coordinator.follow(participant.clientId);
                          }
                        },
                icon: Icon(
                  following ? Icons.link_off : Icons.link,
                  color:
                      following ? Theme.of(context).colorScheme.primary : null,
                ),
              ),
    );
  }

  Future<void> _create() async {
    final controller = TextEditingController(text: 'Совместный просмотр');
    final title = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Новый совместный просмотр'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 160,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () {
                  final title = controller.text.trim();
                  if (title.isNotEmpty) Navigator.pop(context, title);
                },
                child: const Text('Создать'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (title != null && mounted && !widget.offline) {
      await widget.onCreate(title);
    }
  }

  Color _participantColor(String value) {
    final hex = value.replaceFirst('#', '');
    final parsed = hex.length == 6 ? int.tryParse(hex, radix: 16) : null;
    return parsed == null
        ? Theme.of(context).colorScheme.primary
        : Color(0xff000000 | parsed);
  }

  String _connectionLabel(BimSessionConnection connection) =>
      switch (connection) {
        BimSessionConnection.joining => 'Подключаемся',
        BimSessionConnection.connected =>
          'Участники видят изменения в реальном времени',
        BimSessionConnection.reconnecting => 'Восстанавливаем соединение',
        BimSessionConnection.offline => 'Нет сети',
        BimSessionConnection.failed => 'Не удалось подключиться',
        BimSessionConnection.idle => 'Отключено',
      };
}
