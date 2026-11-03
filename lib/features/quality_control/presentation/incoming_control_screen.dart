import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/sync/sync_queue_service.dart';
import '../../../core/utils/quantity_format.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_notice.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/incoming_control_model.dart';
import '../data/incoming_control_draft_store.dart';
import '../data/incoming_control_repository.dart';
import '../data/incoming_control_file_service.dart';
import '../data/quality_photo_picker.dart';
import '../domain/incoming_control_provider.dart';
import 'incoming_control_fields.dart';

class IncomingControlScreen extends ConsumerStatefulWidget {
  const IncomingControlScreen({super.key});

  @override
  ConsumerState<IncomingControlScreen> createState() =>
      _IncomingControlScreenState();
}

class _IncomingControlScreenState extends ConsumerState<IncomingControlScreen> {
  final _search = TextEditingController();
  List<IncomingControlModel> _items = [];
  String? _status;
  String? _sourceFilter;
  DateTimeRange? _dates;
  int? _projectId;
  String? _scope;
  int _page = 0;
  int _lastPage = 1;
  int _request = 0;
  bool _loading = false;
  Object? _error;
  bool _exporting = false;

  Future<void> _export(String format) async {
    if (_exporting || _projectId == null) return;
    final service = ref.read(incomingControlFileServiceProvider);
    setState(() => _exporting = true);
    try {
      await service.export(projectId: _projectId!, format: format);
    } catch (error) {
      if (mounted) AppErrorNotice.show(context, error);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  void dispose() {
    _request++;
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    final projectId = _projectId;
    if (projectId == null || (more && _loading)) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(incomingControlRepositoryProvider)
          .fetchPage(
            projectId: projectId,
            page: more ? _page + 1 : 1,
            status: _status,
            search: _search.text,
            sourceType: _sourceFilter,
            dateFrom: _dates?.start.toIso8601String().substring(0, 10),
            dateTo: _dates?.end.toIso8601String().substring(0, 10),
          );
      if (!mounted || request != _request) return;
      setState(() {
        _items = more ? [..._items, ...page.items] : page.items;
        _page = page.page;
        _lastPage = page.lastPage;
      });
    } catch (error) {
      if (mounted && request == _request) setState(() => _error = error);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _policy(IncomingControlReferences references) async {
    var enabled = references.enabled;
    var documents = references.policy['mandatory_documents'] == true;
    var batch = references.policy['require_batch_number'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Входной контроль объекта'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Правила применяются к новым поступлениям. Ранее накопленные остатки не считаются проверенными.',
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Контроль включён'),
                          value: enabled,
                          onChanged:
                              (value) => setDialogState(() => enabled = value),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Обязательные документы качества'),
                          value: documents,
                          onChanged:
                              (value) => setDialogState(
                                () => documents = value == true,
                              ),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Обязательный номер партии'),
                          value: batch,
                          onChanged:
                              (value) =>
                                  setDialogState(() => batch = value == true),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Сохранить'),
                    ),
                  ],
                ),
          ),
    );
    if (confirmed != true || !mounted || _projectId == null) return;
    try {
      await ref
          .read(incomingControlRepositoryProvider)
          .updatePolicy(
            _projectId!,
            enabled: enabled,
            mandatoryDocuments: documents,
            requireBatchNumber: batch,
          );
      ref.invalidate(incomingControlReferencesProvider(_projectId!));
    } catch (error) {
      if (mounted) AppErrorNotice.show(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectId = ref.watch(projectsProvider).selectedProject?.serverId;
    final scope = ref.watch(incomingControlOwnerScopeProvider);
    if (projectId != _projectId || scope != _scope) {
      _scope = scope;
      _projectId = projectId;
      _items = [];
      _request++;
      _error = null;
      _loading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    final references =
        projectId == null
            ? null
            : ref.watch(incomingControlReferencesProvider(projectId));
    final canCreate = references?.valueOrNull?.can('create') == true;
    ref.watch(incomingControlFileServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Входной контроль'),
        actions: [
          if (references?.valueOrNull?.can('settings_manage') == true)
            IconButton(
              tooltip: 'Правила объекта',
              onPressed: () => _policy(references!.valueOrNull!),
              icon: const Icon(Icons.tune_outlined),
            ),
          if (references?.valueOrNull?.can('export') == true)
            PopupMenuButton<String>(
              tooltip: 'Выгрузить журнал',
              enabled: !_exporting,
              onSelected: _export,
              itemBuilder:
                  (_) => const [
                    PopupMenuItem(value: 'pdf', child: Text('Скачать PDF')),
                    PopupMenuItem(value: 'xlsx', child: Text('Скачать Excel')),
                  ],
              icon:
                  _exporting
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.download_outlined),
            ),
          IconButton(
            tooltip: 'Новая приёмка',
            onPressed:
                canCreate
                    ? () async {
                      final changed = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder:
                              (_) =>
                                  IncomingControlEditor(projectId: projectId!),
                        ),
                      );
                      if (changed == true && mounted) _load();
                    }
                    : null,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Обновить журнал',
            onPressed: projectId == null ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body:
          projectId == null
              ? const AppEmptyState(
                icon: Icons.apartment_outlined,
                title: 'Выберите объект',
                description:
                    'Журнал входного контроля ведётся отдельно по каждому объекту.',
              )
              : Column(
                children: [
                  if (references?.valueOrNull case final data?)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        data.enabled
                            ? 'Контроль включён для новых поступлений. Исторические остатки не переаттестованы.'
                            : 'Контроль новых поступлений на объекте пока не включён.',
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _search,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _load(),
                          decoration: InputDecoration(
                            labelText: 'Материал, партия или номер',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              tooltip: 'Найти',
                              onPressed: () => _load(),
                              icon: const Icon(Icons.search),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ExpansionTile(
                          title: const Text('Источник и период'),
                          tilePadding: EdgeInsets.zero,
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: _sourceFilter,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Источник поступления',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Все источники'),
                                ),
                                for (final entry
                                    in {
                                      'purchase_receipt': 'Закупка',
                                      'warehouse_receipt': 'Складской приход',
                                      'project_delivery': 'Поставка на объект',
                                      'direct': 'Прямая поставка',
                                      'customer_supplied': 'Материал заказчика',
                                    }.entries)
                                  DropdownMenuItem(
                                    value: entry.key,
                                    child: Text(entry.value),
                                  ),
                              ],
                              onChanged: (value) {
                                setState(() => _sourceFilter = value);
                                _load();
                              },
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final dates = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                  initialDateRange: _dates,
                                );
                                if (dates != null && mounted) {
                                  setState(() => _dates = dates);
                                  _load();
                                }
                              },
                              icon: const Icon(Icons.date_range_outlined),
                              label: Text(
                                _dates == null
                                    ? 'Выбрать период'
                                    : '${_dates!.start.toIso8601String().substring(0, 10)} — ${_dates!.end.toIso8601String().substring(0, 10)}',
                              ),
                            ),
                            if (_dates != null)
                              TextButton(
                                onPressed: () {
                                  setState(() => _dates = null);
                                  _load();
                                },
                                child: const Text('Сбросить период'),
                              ),
                          ],
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _status,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Статус',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Все записи'),
                            ),
                            for (final status in [
                              'draft',
                              'pending',
                              'accepted',
                              'accepted_with_restrictions',
                              'rejected',
                              'revoked',
                            ])
                              DropdownMenuItem(
                                value: status,
                                child: Text(incomingControlStatusLabel(status)),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() => _status = value);
                            _load();
                          },
                        ),
                      ],
                    ),
                  ),
                  if (_loading && _items.isNotEmpty)
                    const LinearProgressIndicator(),
                  Expanded(
                    child:
                        _loading && _items.isEmpty
                            ? const AppLoadingState(message: 'Загружаем журнал')
                            : _error != null && _items.isEmpty
                            ? AppErrorState(
                              title: 'Не удалось загрузить журнал',
                              description: UserMessage.fromError(_error!),
                              onRetry: () => _load(),
                            )
                            : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  24,
                                ),
                                itemCount: _items.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == _items.length) {
                                    if (_error != null) {
                                      return AppErrorState(
                                        title: 'Страница не загружена',
                                        description: UserMessage.fromError(
                                          _error!,
                                        ),
                                        onRetry: () => _load(more: true),
                                      );
                                    }
                                    if (_items.isEmpty) {
                                      return const AppEmptyState(
                                        icon: Icons.inventory_2_outlined,
                                        title: 'Записей пока нет',
                                        description:
                                            'Записи появятся после приёмки материалов с входным контролем.',
                                      );
                                    }
                                    return _page < _lastPage
                                        ? TextButton(
                                          onPressed:
                                              _loading
                                                  ? null
                                                  : () => _load(more: true),
                                          child: const Text('Загрузить ещё'),
                                        )
                                        : const SizedBox.shrink();
                                  }
                                  final record = _items[index];
                                  return Card(
                                    child: ListTile(
                                      isThreeLine: true,
                                      title: Text(
                                        '${record.number} · ${record.materialName}',
                                      ),
                                      subtitle: Text(
                                        '${record.statusLabel}\nПартия: ${record.text('batch_number') ?? 'не указана'} · принято ${formatQuantity(record.quantity('accepted_quantity'))} из ${formatQuantity(record.quantity('presented_quantity'))}',
                                      ),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () async {
                                        await Navigator.of(context).push<void>(
                                          MaterialPageRoute(
                                            builder:
                                                (_) =>
                                                    IncomingControlDetailScreen(
                                                      id: record.id,
                                                    ),
                                          ),
                                        );
                                        if (mounted) _load();
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                  ),
                ],
              ),
    );
  }
}

class IncomingControlDetailScreen extends ConsumerStatefulWidget {
  const IncomingControlDetailScreen({super.key, required this.id});
  final int id;

  @override
  ConsumerState<IncomingControlDetailScreen> createState() =>
      _IncomingControlDetailScreenState();
}

class _IncomingControlDetailScreenState
    extends ConsumerState<IncomingControlDetailScreen> {
  bool _busy = false;
  final _operationKeys = <String, String>{};

  void _refresh() {
    ref.invalidate(incomingControlDetailProvider(widget.id));
    ref.invalidate(incomingControlHistoryProvider(widget.id));
    ref.invalidate(incomingControlDependenciesProvider(widget.id));
  }

  Future<void> _returnMaterials(IncomingControlModel record) async {
    if (_busy) return;
    final scope = ref.read(incomingControlOwnerScopeProvider);
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (_) => _IncomingControlReturnDialog(
            maxQuantity:
                record.quantity('rejected_quantity') -
                record.quantity('returned_quantity'),
          ),
    );
    if (values == null ||
        !mounted ||
        scope != ref.read(incomingControlOwnerScopeProvider)) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(incomingControlRepositoryProvider)
          .returnMaterials(
            record,
            quantity: values['quantity'] as double,
            reason: values['reason'].toString(),
            idempotencyKey: _operationKeys.putIfAbsent(
              'return:${record.version}',
              newIncomingControlOperationKey,
            ),
          );
      _refresh();
    } on SyncQueuedException catch (error) {
      if (mounted) _queued(context, error);
    } catch (error) {
      if (mounted) AppErrorNotice.show(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createExecutive(
    IncomingControlModel record,
    IncomingControlReferences references,
  ) async {
    final sets = incomingMaps(references.data['document_sets']);
    if (_busy || sets.isEmpty) return;
    int? setId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Передать в исполнительную документацию'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Сохранится неизменяемый экземпляр текущей версии журнала и документов партии.',
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: setId,
                        decoration: const InputDecoration(
                          labelText: 'Комплект документов',
                        ),
                        items: [
                          for (final set in sets)
                            DropdownMenuItem(
                              value: int.parse(set['id'].toString()),
                              child: Text(
                                set['title']?.toString() ?? 'Комплект',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged:
                            (value) => setDialogState(() => setId = value),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена'),
                    ),
                    FilledButton(
                      onPressed:
                          setId == null
                              ? null
                              : () => Navigator.pop(context, true),
                      child: const Text('Передать'),
                    ),
                  ],
                ),
          ),
    );
    if (confirmed != true || !mounted || setId == null) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(incomingControlRepositoryProvider)
          .createExecutiveDocument(
            record,
            documentSetId: setId!,
            idempotencyKey: _operationKeys.putIfAbsent(
              'executive:${record.version}:$setId',
              newIncomingControlOperationKey,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Экземпляр журнала сохранён в комплекте. Версия ${result['version_id']}.',
            ),
          ),
        );
      }
      _refresh();
    } on SyncQueuedException catch (error) {
      if (mounted) _queued(context, error);
    } catch (error) {
      if (mounted) AppErrorNotice.show(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(IncomingControlModel record) async {
    if (_busy) return;
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Отозвать решение'),
            content: TextField(
              controller: reason,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Причина обязательна',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () {
                  if (reason.text.trim().isNotEmpty) {
                    Navigator.pop(context, true);
                  }
                },
                child: const Text('Подтвердить'),
              ),
            ],
          ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(incomingControlRepositoryProvider)
          .revoke(
            record,
            reason: text,
            idempotencyKey: _operationKeys.putIfAbsent(
              'revoke:${record.version}',
              newIncomingControlOperationKey,
            ),
          );
      _refresh();
    } on SyncQueuedException catch (error) {
      if (mounted) _queued(context, error);
    } catch (error) {
      if (mounted) AppErrorNotice.show(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAttachment(
    IncomingControlModel record,
    Map<String, dynamic> attachment,
  ) async {
    if (_busy) return;
    final service = ref.read(incomingControlFileServiceProvider);
    setState(() => _busy = true);
    try {
      await service.openAttachment(record.id, attachment);
    } catch (error) {
      if (mounted) AppErrorNotice.show(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attach(
    IncomingControlModel record, {
    bool document = false,
  }) async {
    if (_busy) return;
    final file =
        document
            ? await pickIncomingControlDocument(
              context,
              batchNumber:
                  record.text('batch_number') ?? record.text('serial_number'),
            )
            : null;
    final path =
        document
            ? file?.path
            : await ref.read(qualityPhotoPickerProvider).pickInitialPhoto();
    if (path == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(incomingControlRepositoryProvider)
          .attach(
            record,
            path,
            kind: file?.kind ?? 'inspection_photo',
            metadata: file?.metadata ?? const {},
            idempotencyKey: _operationKeys.putIfAbsent(
              'photo:$path',
              newIncomingControlOperationKey,
            ),
          );
      _refresh();
    } on SyncQueuedException catch (error) {
      if (mounted) _queued(context, error);
    } catch (error) {
      if (mounted) AppErrorNotice.show(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(incomingControlDetailProvider(widget.id));
    ref.watch(incomingControlFileServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Карточка входного контроля'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: result.when(
        loading: () => const AppLoadingState(message: 'Загружаем проверку'),
        error:
            (error, _) => AppErrorState(
              title: 'Проверка недоступна',
              description: UserMessage.fromError(error),
              onRetry: _refresh,
            ),
        data: (record) {
          final history = ref.watch(incomingControlHistoryProvider(record.id));
          final references =
              record.availableActions.contains('create_executive_document')
                  ? ref
                      .watch(
                        incomingControlReferencesProvider(record.projectId),
                      )
                      .valueOrNull
                  : null;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${record.number} · ${record.materialName}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('${record.statusLabel} · версия ${record.version}'),
              for (final entry
                  in {
                    'received_at': 'Дата приёмки',
                    'batch_number': 'Партия',
                    'serial_number': 'Серийный номер',
                    'location_name': 'Место приёмки',
                    'supplier_name': 'Поставщик',
                    'manufacturer_name': 'Изготовитель',
                    'inspection_result': 'Осмотр',
                    'documents_result': 'Документы',
                    'reason': 'Основание решения',
                    'restrictions': 'Ограничения',
                    'custodian_name': 'Хранитель',
                    'authority_basis': 'Полномочия',
                    'testing_basis': 'Основание испытаний',
                    'testing_result': 'Результат испытаний',
                  }.entries)
                if (record.text(entry.key)?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${entry.value}: ${_displayValue(record.text(entry.key)!)}',
                    ),
                  ),
              const Divider(height: 32),
              for (final entry
                  in {
                    'document_quantity': 'По документам',
                    'presented_quantity': 'Предъявлено',
                    'accepted_quantity': 'Принято',
                    'pending_quantity': 'Ожидает решения',
                    'rejected_quantity': 'Отклонено',
                    'returned_quantity': 'Возвращено',
                    'shortage_quantity': 'Недопоставка',
                  }.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.value),
                  trailing: Text(formatQuantity(record.quantity(entry.key))),
                ),
              if (record.quantity('pending_quantity') > 0 ||
                  record.quantity('rejected_quantity') > 0)
                const Text(
                  'Ожидающее и отклонённое количество не доступно для использования.',
                ),
              const Divider(height: 32),
              Text(
                'Документы качества',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (record.documents.isEmpty)
                const Text('Документы не прикреплены.'),
              for (final document in record.documents)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(
                    '${document['name'] ?? document['document_name'] ?? 'Документ'}',
                  ),
                  subtitle: Text(
                    'Версия ${document['version_number'] ?? document['version_id'] ?? 'не указана'}',
                  ),
                ),
              Text('Файлы проверки: ${record.attachments.length}'),
              for (final attachment in record.attachments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.attach_file),
                  title: Text(
                    attachment['name']?.toString() ?? 'Файл проверки',
                  ),
                  onTap:
                      attachment['url'] == null || _busy
                          ? null
                          : () => _openAttachment(record, attachment),
                ),
              if (record.availableActions.contains('attach'))
                TextButton.icon(
                  onPressed:
                      _busy ? null : () => _attach(record, document: true),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Приложить документ'),
                ),
              if (record.availableActions.contains('attach'))
                TextButton.icon(
                  onPressed: _busy ? null : () => _attach(record),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Добавить фотографию'),
                ),
              if (_busy) const LinearProgressIndicator(),
              if (record.availableActions.contains('return'))
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _returnMaterials(record),
                  icon: const Icon(Icons.undo_outlined),
                  label: const Text('Оформить возврат'),
                ),
              if (record.availableActions.contains('create_executive_document'))
                OutlinedButton.icon(
                  onPressed:
                      _busy ||
                              references == null ||
                              incomingMaps(
                                references.data['document_sets'],
                              ).isEmpty
                          ? null
                          : () => _createExecutive(record, references),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('В исполнительную документацию'),
                ),
              if (record.availableActions.contains('decide'))
                FilledButton(
                  onPressed:
                      _busy
                          ? null
                          : () async {
                            final changed = await Navigator.of(
                              context,
                            ).push<bool>(
                              MaterialPageRoute(
                                builder:
                                    (_) => IncomingControlEditor(
                                      projectId: record.projectId,
                                      record: record,
                                    ),
                              ),
                            );
                            if (changed == true && mounted) _refresh();
                          },
                  child: const Text('Принять решение'),
                ),
              if (record.availableActions.contains('revise'))
                OutlinedButton(
                  onPressed:
                      _busy
                          ? null
                          : () async {
                            final changed = await Navigator.of(
                              context,
                            ).push<bool>(
                              MaterialPageRoute(
                                builder:
                                    (_) => IncomingControlEditor(
                                      projectId: record.projectId,
                                      record: record,
                                      revise: true,
                                    ),
                              ),
                            );
                            if (changed == true && mounted) _refresh();
                          },
                  child: const Text('Пересмотреть решение'),
                ),
              if (record.availableActions.contains('revoke'))
                OutlinedButton(
                  onPressed: _busy ? null : () => _revoke(record),
                  child: const Text('Отозвать решение'),
                ),
              const Divider(height: 32),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Использование и связанные документы'),
                children: [
                  Consumer(
                    builder: (context, ref, _) {
                      return ref
                          .watch(incomingControlDependenciesProvider(record.id))
                          .when(
                            loading: () => const LinearProgressIndicator(),
                            error:
                                (error, _) => AppErrorState(
                                  title: 'Связи не загружены',
                                  description: UserMessage.fromError(error),
                                  onRetry:
                                      () => ref.invalidate(
                                        incomingControlDependenciesProvider(
                                          record.id,
                                        ),
                                      ),
                                ),
                            data:
                                (dependencies) => Column(
                                  children: [
                                    if (dependencies['redacted'] == true &&
                                        dependencies['redaction_notice'] !=
                                            null)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          dependencies['redaction_notice']
                                              .toString(),
                                        ),
                                      ),
                                    for (final entry
                                        in {
                                          'balances': 'Остатки',
                                          'movements': 'Складские движения',
                                          'journal_materials':
                                              'Материалы журнала',
                                          'completed_works':
                                              'Выполненные работы',
                                          'acts': 'Акты',
                                        }.entries)
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(entry.value),
                                        trailing: Text(
                                          '${(dependencies[entry.key] as List? ?? []).length}',
                                        ),
                                      ),
                                    if (dependencies['quality_defect_id'] !=
                                        null)
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          'Несоответствие № ${dependencies['quality_defect_id']}',
                                        ),
                                      ),
                                  ],
                                ),
                          );
                    },
                  ),
                ],
              ),
              Text('История', style: Theme.of(context).textTheme.titleMedium),
              history.when(
                loading: () => const LinearProgressIndicator(),
                error:
                    (error, _) => AppErrorState(
                      title: 'История не загружена',
                      description: UserMessage.fromError(error),
                      onRetry:
                          () => ref.invalidate(
                            incomingControlHistoryProvider(record.id),
                          ),
                    ),
                data:
                    (events) => Column(
                      children: [
                        for (final event in events)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${event['label'] ?? event['action_label'] ?? _historyAction(event['action']?.toString() ?? event['event_type']?.toString() ?? '')}',
                            ),
                            subtitle: Text(
                              [
                                    event['created_at'],
                                    incomingMap(event['user'])['name'],
                                    event['reason'],
                                  ]
                                  .where(
                                    (value) =>
                                        value != null &&
                                        value.toString().isNotEmpty,
                                  )
                                  .join(' · '),
                            ),
                          ),
                      ],
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class IncomingControlEditor extends ConsumerStatefulWidget {
  const IncomingControlEditor({
    super.key,
    required this.projectId,
    this.record,
    this.revise = false,
  });
  final int projectId;
  final IncomingControlModel? record;
  final bool revise;

  @override
  ConsumerState<IncomingControlEditor> createState() =>
      _IncomingControlEditorState();
}

class _IncomingControlEditorState extends ConsumerState<IncomingControlEditor> {
  final _fields = GlobalKey<IncomingControlFieldsState>();
  String _key = newIncomingControlOperationKey();
  int? _materialId;
  int? _warehouseId;
  final _price = TextEditingController();
  String _source = 'direct';
  bool _busy = false;
  late final String? _ownerScope;
  String get _draftId =>
      widget.record == null
          ? 'direct:new'
          : 'record:${widget.record!.id}:${widget.record!.version}:${widget.revise}';

  @override
  void initState() {
    super.initState();
    _ownerScope = ref.read(incomingControlOwnerScopeProvider);
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || ref.read(incomingControlOwnerScopeProvider) != _ownerScope) {
      return;
    }
    IncomingControlRestoredFileLease? fileLease;
    try {
      final values = _fields.currentState!.payload();
      if (widget.revise &&
          (values['reason']?.toString().trim().isEmpty ?? true)) {
        throw const FormatException('Укажите причину пересмотра решения.');
      }
      if (widget.record == null && _materialId == null) {
        throw const FormatException('Выберите материал.');
      }
      final price = double.tryParse(_price.text.trim().replaceAll(',', '.'));
      if (widget.record == null &&
          _warehouseId != null &&
          incomingQuantity(values['accepted_quantity']) > 0 &&
          (price == null || !price.isFinite || price < 0)) {
        throw const FormatException(
          'Укажите цену для прихода на склад. Нулевая цена допустима для материала заказчика.',
        );
      }
      setState(() => _busy = true);
      fileLease = _fields.currentState!.holdRestoredFiles();
      final files = _fields.currentState!.files;
      final repository = ref.read(incomingControlRepositoryProvider);
      if (widget.record case final record?) {
        if (widget.revise) {
          await repository.revise(
            record,
            values,
            idempotencyKey: _key,
            files: files,
          );
        } else {
          await repository.decide(
            record,
            values,
            idempotencyKey: _key,
            files: files,
          );
        }
      } else {
        await repository.create(
          {
            ...values,
            'project_id': widget.projectId,
            'source_type': _source,
            'material_id': _materialId,
            if (_warehouseId != null) 'warehouse_id': _warehouseId,
            if (price != null) 'unit_price': price,
            'is_customer_transfer': _source == 'customer_supplied',
          },
          idempotencyKey: _key,
          files: files,
        );
      }
      await _fields.currentState?.clearDraft();
      if (mounted) Navigator.of(context).pop(true);
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on SyncQueuedException catch (error) {
      await _fields.currentState?.clearDraft();
      if (mounted) {
        _queued(context, error);
        Navigator.of(context).pop(false);
      }
    } catch (error) {
      if (mounted) AppErrorNotice.show(context, error);
    } finally {
      await fileLease?.release();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final references = ref.watch(
      incomingControlReferencesProvider(widget.projectId),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.record == null ? 'Приёмка материала' : 'Решение по проверке',
        ),
      ),
      body:
          ref.watch(incomingControlOwnerScopeProvider) != _ownerScope
              ? const AppEmptyState(
                icon: Icons.lock_outline,
                title: 'Сеанс изменился',
                description: 'Закройте форму и откройте приёмку заново.',
              )
              : references.when(
                loading:
                    () => const AppLoadingState(
                      message: 'Загружаем данные объекта',
                    ),
                error:
                    (error, _) => AppErrorState(
                      title: 'Приёмка недоступна',
                      description: UserMessage.fromError(error),
                      onRetry:
                          () => ref.invalidate(
                            incomingControlReferencesProvider(widget.projectId),
                          ),
                    ),
                data: (data) {
                  if (widget.record == null && !data.can('create')) {
                    return const AppEmptyState(
                      icon: Icons.lock_outline,
                      title: 'Нет права на приёмку',
                      description: 'Обратитесь к руководителю объекта.',
                    );
                  }
                  return AbsorbPointer(
                    absorbing: _busy,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (widget.record == null) ...[
                          DropdownButtonFormField<String>(
                            initialValue: _source,
                            decoration: const InputDecoration(
                              labelText: 'Источник',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'direct',
                                child: Text('Прямая поставка'),
                              ),
                              DropdownMenuItem(
                                value: 'customer_supplied',
                                child: Text('Материал заказчика'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _source = value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: _materialId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Материал',
                            ),
                            items: [
                              for (final material in data.materials)
                                DropdownMenuItem(
                                  value: int.parse(material['id'].toString()),
                                  child: Text(
                                    material['name']?.toString() ?? 'Материал',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged:
                                (value) => setState(() => _materialId = value),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int>(
                            initialValue: _warehouseId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Склад, если используется',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Без складского прихода'),
                              ),
                              for (final warehouse in data.warehouses)
                                DropdownMenuItem(
                                  value: int.parse(warehouse['id'].toString()),
                                  child: Text(
                                    warehouse['name']?.toString() ?? 'Склад',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged:
                                (value) => setState(() => _warehouseId = value),
                          ),
                          if (_warehouseId != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: TextField(
                                controller: _price,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Цена за единицу',
                                  helperText:
                                      'Для материала заказчика допустима явная нулевая цена.',
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                        ] else
                          Text(
                            widget.record!.materialName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        IncomingControlFields(
                          key: _fields,
                          references: data,
                          materialId:
                              _materialId ??
                              int.tryParse(
                                widget.record?.data['material_id']
                                        ?.toString() ??
                                    incomingMap(
                                      widget.record?.data['material'],
                                    )['id']?.toString() ??
                                    '',
                              ),
                          projectId: widget.projectId,
                          draftId: _draftId,
                          draftContextBuilder:
                              () => {
                                'operation_key': _key,
                                'material_id': _materialId,
                                'warehouse_id': _warehouseId,
                                'source_type': _source,
                                'price': _price.text,
                              },
                          onRestoreContext:
                              (context) => setState(() {
                                _key =
                                    context['operation_key']?.toString() ??
                                    _key;
                                final materialId = int.tryParse(
                                  context['material_id']?.toString() ?? '',
                                );
                                if (data.materials.any(
                                  (material) =>
                                      material['id'].toString() ==
                                      materialId.toString(),
                                )) {
                                  _materialId = materialId;
                                }
                                final warehouseId = int.tryParse(
                                  context['warehouse_id']?.toString() ?? '',
                                );
                                if (data.warehouses.any(
                                  (warehouse) =>
                                      warehouse['id'].toString() ==
                                      warehouseId.toString(),
                                )) {
                                  _warehouseId = warehouseId;
                                }
                                final source =
                                    context['source_type']?.toString();
                                if (source == 'direct' ||
                                    source == 'customer_supplied') {
                                  _source = source!;
                                }
                                _price.text =
                                    context['price']?.toString() ?? '';
                              }),
                          initial: widget.record?.data ?? const {},
                          identityEditable: widget.record == null,
                          canComplete: data.can('inspect'),
                          canAccept: data.can('approve'),
                          canReject: data.can('reject'),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: Text(
                            _busy ? 'Сохраняем…' : 'Сохранить приёмку',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'При отсутствии связи операция сохранится в очереди. Приход и решение подтверждаются только сервером.',
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}

void _queued(BuildContext context, SyncQueuedException error) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${error.message} Приход и решение ещё не подтверждены сервером.',
        ),
      ),
    );
String _displayValue(String value) => switch (value) {
  'compliant' => 'Соответствует',
  'not_checked' => 'Не проверено',
  'non_compliant' => 'Не соответствует',
  _ => value,
};
String _historyAction(String value) => switch (value) {
  'return' || 'returned' => 'Оформлен возврат',
  'created' || 'create' => 'Создана запись',
  'decision' || 'decided' => 'Принято решение',
  'revise' || 'revised' => 'Решение пересмотрено',
  'revoke' || 'revoked' => 'Решение отозвано',
  'attachment' || 'attached' => 'Добавлен файл',
  _ => 'Изменение проверки',
};

class _IncomingControlReturnDialog extends StatefulWidget {
  const _IncomingControlReturnDialog({required this.maxQuantity});
  final double maxQuantity;
  @override
  State<_IncomingControlReturnDialog> createState() =>
      _IncomingControlReturnDialogState();
}

class _IncomingControlReturnDialogState
    extends State<_IncomingControlReturnDialog> {
  final _form = GlobalKey<FormState>();
  late final _quantity = TextEditingController(
    text: widget.maxQuantity.toString(),
  );
  final _reason = TextEditingController();
  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Возврат отклонённого материала'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Количество',
                helperText: 'К возврату: ${formatQuantity(widget.maxQuantity)}',
              ),
              validator: (value) {
                final number = double.tryParse(
                  (value ?? '').replaceAll(',', '.'),
                );
                return number == null ||
                        !number.isFinite ||
                        number <= 0 ||
                        number > widget.maxQuantity
                    ? 'Укажите количество в пределах отклонённого остатка'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reason,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Причина возврата'),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Укажите причину'
                          : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState?.validate() == true) {
            Navigator.pop(context, {
              'quantity': double.parse(_quantity.text.replaceAll(',', '.')),
              'reason': _reason.text.trim(),
            });
          }
        },
        child: const Text('Оформить возврат'),
      ),
    ],
  );
}
