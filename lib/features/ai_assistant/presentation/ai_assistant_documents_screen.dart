import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/error/user_message.dart';
import '../../auth/domain/auth_provider.dart';
import '../data/ai_assistant_models.dart';
import '../data/ai_assistant_document_models.dart';
import '../data/ai_assistant_repository.dart';

class AiAssistantDocumentsScreen extends ConsumerStatefulWidget {
  const AiAssistantDocumentsScreen({super.key});
  @override
  ConsumerState<AiAssistantDocumentsScreen> createState() => _DocumentsState();
}

class _DocumentsState extends ConsumerState<AiAssistantDocumentsScreen> {
  AiDocumentProcessingStatus? _status;
  AiDocumentBudget? _budget;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _enabled = false;
  bool _budgetDraft = false;
  String _scope = 'new';
  int _revision = 0;
  bool _sessionChanged = false;
  final _limit = TextEditingController();
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      authProvider.select(
        (state) => (state.user?.serverId, state.user?.currentOrganizationId),
      ),
      (previous, next) {
        if (previous != next) {
          _revision++;
          _sessionChanged = true;
          if (mounted) {
            setState(() {
              _status = null;
              _budget = null;
            });
            Navigator.maybePop(context);
          }
        }
      },
    );
    _load();
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_sessionChanged || _saving) return;
    final revision = ++_revision;
    try {
      final repository = ref.read(aiAssistantRepositoryProvider);
      final status = await repository.fetchDocumentProcessing();
      if (!mounted || revision != _revision) return;
      setState(() {
        _status = status;
        _loading = false;
      });
      AiDocumentBudget? budget;
      if (status.statusAvailable && status.canManageSettings) {
        budget = await repository.fetchDocumentBudget();
      }
      if (!mounted || revision != _revision) return;
      setState(() {
        _status = status;
        _loading = false;
        _error = null;
        if (!status.statusAvailable || !status.canManageSettings) {
          _budget = null;
        }
        if (budget != null) {
          _budget = budget;
          if (!_budgetDraft) {
            _enabled = budget.enabled;
            _scope = budget.scope;
            _limit.text = formatAiMinor(budget.limitMinor);
          }
        }
      });
    } catch (error) {
      if (!mounted || revision != _revision) return;
      setState(() {
        _error = UserMessage.fromError(error);
        _loading = false;
      });
    }
  }

  Future<void> _saveBudget() async {
    if (_saving || _sessionChanged || _status?.canManageSettings != true) {
      return;
    }
    final limit = parseAiDocumentLimit(_limit.text);
    if (limit == null) {
      setState(
        () =>
            _error =
                'Введите лимит от 0 до 10 000 000 единиц, максимум два знака после запятой.',
      );
      return;
    }
    if (_budget != null &&
        limit < _budget!.spentMinor + _budget!.reservedMinor) {
      setState(
        () =>
            _error =
                'Лимит не может быть ниже потраченных и зарезервированных единиц.',
      );
      return;
    }
    final revision = _revision;
    final enabled = _enabled;
    final scope = _scope;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Подтвердить распознавание?'),
            content: Text(
              enabled
                  ? 'Лимит: ${formatAiMinor(limit)} единиц. ${scope == 'archive' ? 'Будут проверены файлы архива и новые файлы.' : 'Будут обрабатываться новые файлы.'} Распознавание расходует единицы помощника.'
                  : 'Автоматическое распознавание будет отключено.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Подтвердить'),
              ),
            ],
          ),
    );
    if (confirmed != true ||
        !mounted ||
        revision != _revision ||
        _sessionChanged) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    var succeeded = false;
    try {
      final budget = await ref
          .read(aiAssistantRepositoryProvider)
          .approveDocumentBudget(
            enabled: enabled,
            scope: scope,
            limitMinor: limit,
          );
      if (!mounted || revision != _revision || _sessionChanged) return;
      succeeded = true;
      setState(() {
        _budgetDraft = false;
        _budget = budget;
        _enabled = budget.enabled;
        _scope = budget.scope;
        _limit.text = formatAiMinor(budget.limitMinor);
      });
    } catch (error) {
      if (mounted && revision == _revision) {
        setState(() => _error = UserMessage.fromError(error));
      }
    } finally {
      if (mounted && revision == _revision) {
        setState(() => _saving = false);
        if (succeeded) await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Обработка документов'),
      actions: [
        IconButton(
          tooltip: 'Обновить',
          onPressed: _saving ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body:
        _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_status != null && !_status!.statusAvailable)
                  const Text('Статистика временно недоступна'),
                if (_status != null && _status!.statusAvailable) ...[
                  Text(
                    'Документы: готовы ${_status!.documentCoverage['ready'] ?? 0} из ${_status!.documentCoverage['total'] ?? 0}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text(
                    'Показаны только доступные вам документы. Необработанные файлы могут отсутствовать в ответах помощника.',
                  ),
                  const SizedBox(height: 12),
                  for (final entry
                      in const {
                        'total': 'Всего документов',
                        'ready': 'Готовы для ответов',
                        'pending': 'Ожидают обработки',
                        'ocr_required': 'Требуют распознавания',
                        'ocr_processing': 'Распознаются',
                        'failed': 'Ошибки обработки',
                        'unsupported': 'Неподдерживаемый формат',
                        'empty': 'Без текста',
                        'processed_units': 'Обработано частей',
                        'total_pages': 'Всего страниц',
                        'ocr_completed_pages': 'Распознано страниц',
                      }.entries)
                    ListTile(
                      dense: true,
                      title: Text(entry.value),
                      trailing: Text(
                        '${_status!.documentCoverage[entry.key] ?? 0}',
                      ),
                    ),
                  const Divider(),
                  Text(
                    'Архив: проверено ${_status!.archiveScan.scanned} из ${_status!.archiveScan.expected} файлов',
                  ),
                  if (_status!.archiveScan.processing)
                    const Text('Проверка архива продолжается'),
                  if (_status!.archiveScan.completedAt != null)
                    Text(
                      'Проверка завершена: ${_status!.archiveScan.completedAt!.toLocal().toString().split('.').first}',
                    ),
                  if (_status!.canManageSettings && _budget != null) ...[
                    const Divider(),
                    Text(
                      'Автоматическое распознавание',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Потрачено: ${formatAiMinor(_budget!.spentMinor)}; резерв: ${formatAiMinor(_budget!.reservedMinor)}; доступно: ${formatAiMinor(_budget!.availableMinor)} единиц.',
                    ),
                    SwitchListTile(
                      title: const Text('Разрешить распознавание'),
                      value: _enabled,
                      onChanged:
                          _saving
                              ? null
                              : (value) => setState(() {
                                _enabled = value;
                                _budgetDraft = true;
                              }),
                    ),
                    DropdownButton<String>(
                      value: _scope,
                      items: const [
                        DropdownMenuItem(
                          value: 'new',
                          child: Text('Новые файлы'),
                        ),
                        DropdownMenuItem(
                          value: 'archive',
                          child: Text('Архив и новые файлы'),
                        ),
                      ],
                      onChanged:
                          _saving
                              ? null
                              : (value) => setState(() {
                                _scope = value ?? 'new';
                                _budgetDraft = true;
                              }),
                    ),
                    TextField(
                      controller: _limit,
                      onChanged: (_) => _budgetDraft = true,
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Общий лимит, единицы помощника',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _saving ? null : _saveBudget,
                      child: const Text('Сохранить лимит'),
                    ),
                  ],
                ],
              ],
            ),
  );
}

int? parseAiDocumentLimit(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,8}(?:\.\d{1,2})?$').hasMatch(normalized)) return null;
  final parts = normalized.split('.');
  final minor =
      int.parse(parts[0]) * 100 +
      int.parse((parts.length == 2 ? parts[1] : '').padRight(2, '0'));
  return minor <= 1000000000 ? minor : null;
}
