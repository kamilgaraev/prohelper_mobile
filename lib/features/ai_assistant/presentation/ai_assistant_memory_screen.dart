import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../auth/domain/auth_provider.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/industrial_card.dart';
import '../data/ai_assistant_models.dart';
import '../data/ai_assistant_repository.dart';

class AiAssistantMemoryScreen extends ConsumerStatefulWidget {
  const AiAssistantMemoryScreen({super.key});

  @override
  ConsumerState<AiAssistantMemoryScreen> createState() =>
      _AiAssistantMemoryScreenState();
}

class _AiAssistantMemoryScreenState
    extends ConsumerState<AiAssistantMemoryScreen> {
  List<AiMemoryModel> _items = const [];
  bool _loading = true;
  String? _error;
  int _sessionRevision = 0;

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

  Future<void> _load() async {
    final revision = _sessionRevision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref.read(aiAssistantRepositoryProvider).fetchMemory();
      if (!mounted || revision != _sessionRevision) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || revision != _sessionRevision) return;
      setState(() {
        _error = UserMessage.fromError(error);
        _loading = false;
      });
    }
  }

  Future<void> _edit([AiMemoryModel? item]) async {
    final revision = _sessionRevision;
    final controller = TextEditingController(text: item?.content ?? '');
    const scope = 'user';
    final saved = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(
                    item == null ? 'Новая память' : 'Изменить память',
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Личная память внутри текущей организации. Сохранение подтверждает использование записи в будущих диалогах.',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Что помнить между диалогами',
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Отмена'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Сохранить'),
                    ),
                  ],
                ),
          ),
    );
    final content = controller.text.trim();
    controller.dispose();
    if (saved != true ||
        content.isEmpty ||
        !mounted ||
        revision != _sessionRevision) {
      return;
    }
    try {
      final repository = ref.read(aiAssistantRepositoryProvider);
      if (item == null) {
        await repository.createMemory(scope: scope, content: content);
      } else {
        await repository.updateMemory(item.id, content: content);
      }
      if (mounted && revision == _sessionRevision) await _load();
    } catch (error) {
      if (mounted) _showMessage(UserMessage.fromError(error));
    }
  }

  Future<void> _delete(AiMemoryModel item) async {
    final revision = _sessionRevision;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Удалить память?'),
            content: const Text(
              'Ассистент перестанет использовать эту запись в новых диалогах.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted || revision != _sessionRevision) return;
    try {
      await ref.read(aiAssistantRepositoryProvider).deleteMemory(item.id);
      if (mounted && revision == _sessionRevision) await _load();
    } catch (error) {
      if (mounted) _showMessage(UserMessage.fromError(error));
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Память помощника')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _loading ? null : _edit,
      icon: const Icon(Icons.add),
      label: const Text('Добавить'),
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child:
          _loading
              ? const AppLoadingState(message: 'Загружаем память')
              : _error != null
              ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!),
                  ),
                ],
              )
              : _items.isEmpty
              ? ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: AppEmptyState(
                      icon: Icons.psychology_outlined,
                      title: 'Память пуста',
                      description:
                          'Добавьте важный контекст для будущих диалогов.',
                    ),
                  ),
                ],
              )
              : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return IndustrialCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item.content,
                        style: AppTypography.bodyMedium(context),
                      ),
                      subtitle: Text('Только я в текущей организации'),
                      onTap: () => _edit(item),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(item),
                      ),
                    ),
                  );
                },
              ),
    ),
  );
}
