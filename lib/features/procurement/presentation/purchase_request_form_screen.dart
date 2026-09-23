import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/widgets/app_error_notice.dart';
import '../../site_requests/data/site_request_model.dart';
import '../../site_requests/data/site_requests_repository.dart';
import '../../site_requests/domain/site_requests_scope.dart';
import '../domain/procurement_provider.dart';

class PurchaseRequestFormScreen extends ConsumerStatefulWidget {
  const PurchaseRequestFormScreen({required this.projectId, super.key});

  final int projectId;

  @override
  ConsumerState<PurchaseRequestFormScreen> createState() =>
      _PurchaseRequestFormScreenState();
}

class _PurchaseRequestFormScreenState
    extends ConsumerState<PurchaseRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _budgetController = TextEditingController();
  final _notesController = TextEditingController();
  final List<_PurchaseLineControllers> _lines = [_PurchaseLineControllers()];
  late Future<List<SiteRequestModel>> _siteRequestsFuture;
  SiteRequestModel? _selectedSiteRequest;
  DateTime? _neededBy;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _siteRequestsFuture = ref
        .read(siteRequestsRepositoryProvider)
        .fetchSiteRequests(
          projectId: widget.projectId,
          perPage: 50,
          scope: SiteRequestsScope.own,
        );
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _notesController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _selectNeededBy() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _neededBy ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (selected != null) setState(() => _neededBy = selected);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSiteRequest == null) {
      AppErrorNotice.show(context, 'Выберите заявку с объекта для закупки.');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final payload = <String, dynamic>{
        'site_request_id': _selectedSiteRequest!.serverId,
        if (_neededBy != null) 'needed_by': _date(_neededBy!),
        if (_budgetController.text.trim().isNotEmpty)
          'budget_amount': double.parse(
            _budgetController.text.trim().replaceAll(',', '.'),
          ),
        'budget_currency': 'RUB',
        if (_notesController.text.trim().isNotEmpty)
          'notes': _notesController.text.trim(),
        'lines': _lines
            .map(
              (line) => {
                'name': line.name.text.trim(),
                'quantity': double.parse(
                  line.quantity.text.trim().replaceAll(',', '.'),
                ),
                'unit': line.unit.text.trim(),
                if (line.specification.text.trim().isNotEmpty)
                  'specification': line.specification.text.trim(),
                if (_neededBy != null) 'needed_by': _date(_neededBy!),
              },
            )
            .toList(growable: false),
      };
      await ref
          .read(procurementProvider.notifier)
          .createPurchaseRequest(payload);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) AppErrorNotice.show(context, error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новая заявка на закупку')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<List<SiteRequestModel>>(
              future: _siteRequestsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Не удалось загрузить заявки объекта.');
                }
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }
                final requests = snapshot.data!;
                if (requests.isEmpty) {
                  return const Text(
                    'На объекте нет доступных заявок для закупки.',
                  );
                }
                _selectedSiteRequest ??= requests.first;
                return DropdownButtonFormField<SiteRequestModel>(
                  initialValue: _selectedSiteRequest,
                  decoration: const InputDecoration(
                    labelText: 'Заявка с объекта',
                  ),
                  items:
                      requests
                          .map(
                            (request) => DropdownMenuItem(
                              value: request,
                              child: Text(
                                request.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (value) => setState(() => _selectedSiteRequest = value),
                );
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _selectNeededBy,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _neededBy == null
                    ? 'Нужна к дате'
                    : 'Нужна к ${_date(_neededBy!)}',
              ),
            ),
            TextFormField(
              controller: _budgetController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Бюджет, ₽'),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) return null;
                final amount = double.tryParse(
                  value!.trim().replaceAll(',', '.'),
                );
                return amount == null || amount < 0
                    ? 'Введите сумму не меньше нуля.'
                    : null;
              },
            ),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Комментарий'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Состав закупки',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ..._lines.asMap().entries.map(
              (entry) => _lineFields(entry.key, entry.value),
            ),
            TextButton.icon(
              onPressed:
                  () => setState(() => _lines.add(_PurchaseLineControllers())),
              icon: const Icon(Icons.add),
              label: const Text('Добавить позицию'),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon:
                  _isSubmitting
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.send_outlined),
              label: const Text('Создать заявку'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineFields(int index, _PurchaseLineControllers line) {
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextFormField(
              controller: line.name,
              decoration: InputDecoration(labelText: 'Позиция ${index + 1}'),
              validator:
                  (value) =>
                      (value ?? '').trim().isEmpty
                          ? 'Укажите наименование.'
                          : null,
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: line.quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Количество'),
                    validator: (value) {
                      final amount = double.tryParse(
                        (value ?? '').trim().replaceAll(',', '.'),
                      );
                      return amount == null || amount < 0.001
                          ? 'Введите количество.'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: line.unit,
                    decoration: const InputDecoration(
                      labelText: 'Ед. измерения',
                    ),
                    validator:
                        (value) =>
                            (value ?? '').trim().isEmpty
                                ? 'Укажите единицу.'
                                : null,
                  ),
                ),
                if (_lines.length > 1)
                  IconButton(
                    onPressed:
                        () => setState(() {
                          _lines.removeAt(index).dispose();
                        }),
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: 'Удалить позицию',
                  ),
              ],
            ),
            TextFormField(
              controller: line.specification,
              decoration: const InputDecoration(labelText: 'Спецификация'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseLineControllers {
  final name = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final unit = TextEditingController();
  final specification = TextEditingController();

  void dispose() {
    name.dispose();
    quantity.dispose();
    unit.dispose();
    specification.dispose();
  }
}

String _date(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
