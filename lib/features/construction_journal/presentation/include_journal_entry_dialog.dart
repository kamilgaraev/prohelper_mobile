import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/error/user_message.dart';
import '../data/construction_journal_models.dart';
import '../data/construction_journal_repository.dart';

class IncludeJournalEntryDialog extends ConsumerStatefulWidget {
  const IncludeJournalEntryDialog({
    super.key,
    required this.sourceId,
    required this.isContextCurrent,
  });
  final int sourceId;
  final bool Function() isContextCurrent;
  @override
  ConsumerState<IncludeJournalEntryDialog> createState() =>
      _IncludeJournalEntryDialogState();
}

class _IncludeJournalEntryDialogState
    extends ConsumerState<IncludeJournalEntryDialog> {
  final _comment = TextEditingController();
  List<JournalReportingTarget>? _targets;
  int? _targetId;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final targets = await ref
          .read(constructionJournalRepositoryProvider)
          .reportingTargets(widget.sourceId);
      if (mounted) setState(() => _targets = targets);
    } catch (error) {
      if (mounted) setState(() => _error = UserMessage.fromError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _include() async {
    if (_saving || _targetId == null) return;
    if (!widget.isContextCurrent()) {
      setState(
        () =>
            _error =
                'Объект или организация изменились. Откройте запись заново.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final entry = await ref
          .read(constructionJournalRepositoryProvider)
          .includeInJournal(widget.sourceId, _targetId!, _comment.text);
      if (mounted && widget.isContextCurrent()) {
        Navigator.of(context).pop(entry);
      }
    } catch (error) {
      if (mounted) setState(() => _error = UserMessage.fromError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Включить в свой журнал'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Создаётся черновик для отчёта выше. Принятые факты и источник сохраняются без повторного учёта объёмов и материалов.',
              ),
              const SizedBox(height: 16),
              if (_loading)
                const CircularProgressIndicator()
              else if (_targets?.isNotEmpty == true)
                DropdownButtonFormField<int>(
                  initialValue: _targetId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Ваш журнал',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      _targets!
                          .map(
                            (target) => DropdownMenuItem(
                              value: target.id,
                              child: Text(
                                target.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged:
                      _saving ? null : (id) => setState(() => _targetId = id),
                )
              else if (_error == null)
                const Text(
                  'Нет активного собственного журнала с договором в этом проекте. Создайте журнал и повторите действие.',
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _comment,
                maxLength: 4000,
                minLines: 2,
                maxLines: 4,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Комментарий к отчёту',
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (!_loading && _targets == null)
                TextButton(onPressed: _load, child: const Text('Повторить')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving || _targetId == null || _loading ? null : _include,
          child: Text(_saving ? 'Включаем…' : 'Включить'),
        ),
      ],
    ),
  );
}
