import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/error/user_message.dart';
import '../../auth/domain/auth_provider.dart';
import '../data/ai_assistant_models.dart';
import '../data/ai_assistant_repository.dart';

class AiAssistantSharingScreen extends ConsumerStatefulWidget {
  const AiAssistantSharingScreen({super.key, required this.conversationId});
  final int conversationId;
  @override
  ConsumerState<AiAssistantSharingScreen> createState() => _SharingState();
}

class _SharingState extends ConsumerState<AiAssistantSharingScreen> {
  List<AiConversationParticipantModel> _participants = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _sessionRevision = 0;
  final _userId = TextEditingController();
  String _role = 'viewer';
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      authProvider.select(
        (state) => (state.user?.serverId, state.user?.currentOrganizationId),
      ),
      (previous, next) {
        if (previous != next) {
          _sessionRevision++;
          if (mounted) Navigator.maybePop(context);
        }
      },
    );
    _load();
  }

  @override
  void dispose() {
    _userId.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final revision = _sessionRevision;
    try {
      final items = await ref
          .read(aiAssistantRepositoryProvider)
          .fetchParticipants(widget.conversationId);
      if (mounted && revision == _sessionRevision) {
        setState(() {
          _participants = items;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted && revision == _sessionRevision) {
        setState(() {
          _error = UserMessage.fromError(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final revision = _sessionRevision;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(aiAssistantRepositoryProvider)
          .updateParticipants(widget.conversationId, _participants);
      if (mounted && revision == _sessionRevision) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = UserMessage.fromError(error);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Доступ к чату')),
    body:
        _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Новые чаты личные. Только автор может предоставить доступ активным участникам организации. Доступ к исходным данным проверяется отдельно.',
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ..._participants.map(
                  (item) => ListTile(
                    title: Text(item.name ?? 'Участник ${item.userId}'),
                    subtitle: Text(
                      item.role == 'editor'
                          ? 'Может писать в чат'
                          : 'Только просмотр',
                    ),
                    trailing: IconButton(
                      onPressed:
                          _saving
                              ? null
                              : () => setState(
                                () =>
                                    _participants =
                                        _participants
                                            .where(
                                              (p) => p.userId != item.userId,
                                            )
                                            .toList(),
                              ),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ),
                ),
                TextField(
                  controller: _userId,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Номер участника организации',
                  ),
                ),
                DropdownButton<String>(
                  value: _role,
                  items: const [
                    DropdownMenuItem(
                      value: 'viewer',
                      child: Text('Только просмотр'),
                    ),
                    DropdownMenuItem(
                      value: 'editor',
                      child: Text('Может писать в чат'),
                    ),
                  ],
                  onChanged:
                      _saving
                          ? null
                          : (value) =>
                              setState(() => _role = value ?? 'viewer'),
                ),
                OutlinedButton(
                  onPressed:
                      _saving
                          ? null
                          : () {
                            final id = int.tryParse(_userId.text.trim());
                            if (id == null || id <= 0) return;
                            setState(() {
                              _participants = [
                                ..._participants.where(
                                  (p) => p.userId != '$id',
                                ),
                                AiConversationParticipantModel(
                                  userId: '$id',
                                  role: _role,
                                ),
                              ];
                              _userId.clear();
                            });
                          },
                  child: const Text('Добавить участника'),
                ),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Сохранить доступ'),
                ),
              ],
            ),
  );
}
