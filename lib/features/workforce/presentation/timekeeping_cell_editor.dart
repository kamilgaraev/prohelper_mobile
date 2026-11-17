import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/month_timekeeping_model.dart';
import '../data/timekeeping_interval_input.dart';
import '../domain/month_timekeeping_provider.dart';

class TimekeepingCellEditor extends ConsumerStatefulWidget {
  const TimekeepingCellEditor({
    super.key,
    required this.period,
    required this.row,
    required this.day,
  });
  final TimekeepingPeriod period;
  final TimekeepingRow row;
  final TimekeepingDay day;
  @override
  ConsumerState<TimekeepingCellEditor> createState() =>
      _TimekeepingCellEditorState();
}

class _TimekeepingCellEditorState extends ConsumerState<TimekeepingCellEditor> {
  late final TextEditingController _hours;
  late final TextEditingController _comment;
  final _basis = TextEditingController();
  final _reason = TextEditingController();
  late final List<TimekeepingIntervalInput> _intervals;
  late bool _aggregate;
  bool _clear = false;
  bool _saving = false;
  bool _canSave = true;
  String? _latestFact;
  String? _error;

  @override
  void initState() {
    super.initState();
    _hours = TextEditingController(
      text: timekeepingHours(widget.day.factMinutes),
    );
    _comment = TextEditingController(text: widget.day.comment);
    _aggregate = widget.row.hoursOnly && widget.day.intervals.isEmpty;
    _intervals =
        widget.day.intervals.map(TimekeepingIntervalInput.fromJson).toList();
    if (_intervals.isEmpty) _intervals.add(TimekeepingIntervalInput());
  }

  @override
  void dispose() {
    _hours.dispose();
    _comment.dispose();
    _basis.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(timekeepingDetailProvider(widget.period.id).notifier)
          .load();
      if (!mounted) return;
      final latest =
          ref.read(timekeepingDetailProvider(widget.period.id)).requireValue;
      final rows = latest.rows.where(
        (row) =>
            row.key == widget.row.key && row.hoursOnly == widget.row.hoursOnly,
      );
      final days =
          rows.isEmpty
              ? <TimekeepingDay>[]
              : rows.first.days
                  .where((day) => day.date == widget.day.date)
                  .toList();
      setState(() {
        _canSave = latest.editable && days.isNotEmpty;
        _error =
            _canSave
                ? null
                : 'Состав или статус табеля изменился. Откройте день заново.';
        _latestFact =
            days.isEmpty
                ? null
                : 'На сервере сейчас ${timekeepingHours(days.first.factMinutes)} ч. Ваш ввод сохранён. Проверьте его перед повторным сохранением.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error =
                  'Не удалось загрузить свежую версию табеля. Повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{
        'employee_id': widget.row.employeeId,
        'work_date': widget.day.date,
        'comment': _comment.text.trim(),
        'intervals': <Map<String, dynamic>>[],
      };
      if (!widget.row.hoursOnly) {
        if (_basis.text.trim().isEmpty || _reason.text.trim().isEmpty) {
          throw const FormatException(
            'Укажите причину и документальное основание изменения.',
          );
        }
        data.addAll({
          'employment_contract_id': widget.row.contractId,
          'reason_code': _reason.text.trim(),
          'basis_reference': _basis.text.trim(),
        });
      }
      if (_clear) {
        if (widget.row.hoursOnly) data['duration_minutes'] = 0;
      } else if (_aggregate) {
        final minutes = parseTimekeepingHours(_hours.text);
        if (minutes == null) {
          throw const FormatException(
            'Введите часы от 0 до 24, например 8 или 7,5.',
          );
        }
        data['duration_minutes'] = minutes;
      } else {
        if (_intervals.isEmpty) {
          throw const FormatException(
            'Добавьте рабочий интервал или выберите обнуление часов.',
          );
        }
        data['intervals'] =
            _intervals.map((interval) => interval.toJson()).toList();
      }
      await ref
          .read(timekeepingDetailProvider(widget.period.id).notifier)
          .saveCell(data);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _error =
                  error is ApiException
                      ? error.message
                      : error is FormatException
                      ? error.message.toString()
                      : 'Не удалось сохранить часы. Повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _dateField(
    String label,
    String value,
    ValueChanged<String> change,
    Key key,
  ) => TextFormField(
    key: key,
    initialValue: value,
    decoration: InputDecoration(labelText: label, hintText: '01.11.2026 09:00'),
    keyboardType: TextInputType.datetime,
    onChanged: change,
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Часы сотрудника',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('${widget.row.name}\n${widget.day.date}'),
            if (widget.day.intervals.isNotEmpty && widget.row.hoursOnly)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Ввод общего числа часов заменит подробные интервалы этого дня.',
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_error != null)
              TextButton(
                onPressed: _saving ? null : _reload,
                child: const Text('Загрузить новую версию'),
              ),
            if (_latestFact != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_latestFact!),
              ),
            AbsorbPointer(
              absorbing: _saving,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.row.hoursOnly)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Только количество часов'),
                      value: _aggregate,
                      onChanged: (value) => setState(() => _aggregate = value),
                    ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Обнулить часы за день'),
                    value: _clear,
                    onChanged:
                        (value) => setState(() => _clear = value ?? false),
                  ),
                  if (!_clear && _aggregate)
                    TextField(
                      controller: _hours,
                      decoration: const InputDecoration(
                        labelText: 'Часы за день',
                        hintText: '8 или 7,5',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  if (!_clear && !_aggregate) ...[
                    const Text(
                      'Даты и время указывайте в часовом поясе рабочего интервала.',
                    ),
                    ..._intervals.asMap().entries.map((entry) {
                      final interval = entry.value;
                      void change(VoidCallback callback) {
                        interval.original = null;
                        callback();
                      }

                      return Card(
                        key: ObjectKey(interval),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Рабочий интервал ${entry.key + 1}',
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Удалить интервал',
                                    onPressed:
                                        () => setState(
                                          () => _intervals.remove(interval),
                                        ),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                              _dateField(
                                'Начало работы',
                                interval.start,
                                (v) => change(() => interval.start = v),
                                ValueKey('start-${identityHashCode(interval)}'),
                              ),
                              _dateField(
                                'Конец работы',
                                interval.end,
                                (v) => change(() => interval.end = v),
                                ValueKey('end-${identityHashCode(interval)}'),
                              ),
                              TextFormField(
                                initialValue: interval.timezone,
                                decoration: const InputDecoration(
                                  labelText: 'Часовой пояс',
                                  helperText: 'Например Europe/Moscow',
                                ),
                                onChanged:
                                    (v) => change(() => interval.timezone = v),
                              ),
                              ...interval.breaks.map(
                                (pause) => Column(
                                  key: ObjectKey(pause),
                                  children: [
                                    _dateField(
                                      'Начало перерыва',
                                      pause.start,
                                      (v) => change(() => pause.start = v),
                                      ValueKey(
                                        'pause-start-${identityHashCode(pause)}',
                                      ),
                                    ),
                                    _dateField(
                                      'Конец перерыва',
                                      pause.end,
                                      (v) => change(() => pause.end = v),
                                      ValueKey(
                                        'pause-end-${identityHashCode(pause)}',
                                      ),
                                    ),
                                    TextButton(
                                      onPressed:
                                          () => setState(() {
                                            interval.original = null;
                                            interval.breaks.remove(pause);
                                          }),
                                      child: const Text('Убрать перерыв'),
                                    ),
                                  ],
                                ),
                              ),
                              if (interval.breaks.length < 10)
                                TextButton(
                                  onPressed:
                                      () => setState(() {
                                        interval.original = null;
                                        interval.breaks.add(
                                          TimekeepingBreakInput('', ''),
                                        );
                                      }),
                                  child: const Text('Добавить перерыв'),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (_intervals.length < 10)
                      OutlinedButton(
                        onPressed:
                            () => setState(
                              () => _intervals.add(TimekeepingIntervalInput()),
                            ),
                        child: const Text('Добавить рабочий интервал'),
                      ),
                  ],
                  if (!widget.row.hoursOnly) ...[
                    TextField(
                      controller: _reason,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Причина изменения',
                      ),
                    ),
                    TextField(
                      controller: _basis,
                      maxLength: 255,
                      decoration: const InputDecoration(
                        labelText: 'Документальное основание',
                      ),
                    ),
                  ],
                  TextField(
                    controller: _comment,
                    maxLength: 2000,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Комментарий'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving || !_canSave ? null : _save,
              child: Text(_saving ? 'Сохранение…' : 'Сохранить часы'),
            ),
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
          ],
        ),
      ),
    ),
  );
}
