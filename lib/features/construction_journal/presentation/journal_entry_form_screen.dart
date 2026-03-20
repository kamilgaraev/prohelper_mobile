import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/construction_journal_models.dart';
import '../data/construction_journal_repository.dart';

class JournalEntryFormScreen extends ConsumerStatefulWidget {
  const JournalEntryFormScreen({
    super.key,
    required this.journalId,
    this.initialEntry,
  });

  final int journalId;
  final ConstructionJournalEntryModel? initialEntry;

  @override
  ConsumerState<JournalEntryFormScreen> createState() => _JournalEntryFormScreenState();
}

class _JournalEntryFormScreenState extends ConsumerState<JournalEntryFormScreen> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _problemsController;
  late final TextEditingController _safetyController;
  late final TextEditingController _visitorsController;
  late final TextEditingController _qualityController;
  late DateTime _entryDate;
  bool _isSaving = false;

  bool get _isEdit => widget.initialEntry != null;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.initialEntry?.workDescription ?? '');
    _problemsController = TextEditingController(text: widget.initialEntry?.problemsDescription ?? '');
    _safetyController = TextEditingController(text: widget.initialEntry?.safetyNotes ?? '');
    _visitorsController = TextEditingController(text: widget.initialEntry?.visitorsNotes ?? '');
    _qualityController = TextEditingController(text: widget.initialEntry?.qualityNotes ?? '');
    _entryDate = DateTime.tryParse(widget.initialEntry?.entryDate ?? '') ?? DateTime.now();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _problemsController.dispose();
    _safetyController.dispose();
    _visitorsController.dispose();
    _qualityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Редактирование записи' : 'Новая запись'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Дата записи'),
            subtitle: Text(_formatDate(_entryDate)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _entryDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );

              if (picked != null) {
                setState(() {
                  _entryDate = picked;
                });
              }
            },
          ),
          const SizedBox(height: 12),
          _buildField(controller: _descriptionController, label: 'Описание работ', maxLines: 4),
          const SizedBox(height: 12),
          _buildField(controller: _problemsController, label: 'Проблемы', maxLines: 3),
          const SizedBox(height: 12),
          _buildField(controller: _safetyController, label: 'Замечания по безопасности', maxLines: 3),
          const SizedBox(height: 12),
          _buildField(controller: _visitorsController, label: 'Замечания посетителей', maxLines: 3),
          const SizedBox(height: 12),
          _buildField(controller: _qualityController, label: 'Замечания по качеству', maxLines: 3),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () => _save(isDraft: true),
                  child: const Text('Сохранить'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () => _save(isDraft: false),
                  child: const Text('Отправить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required int maxLines,
  }) {
    return TextField(
      controller: controller,
      minLines: 1,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Future<void> _save({required bool isDraft}) async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте описание работ.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(constructionJournalRepositoryProvider);
      final entry = _isEdit
          ? await repository.updateEntry(
              entryId: widget.initialEntry!.id,
              entryDate: _entryDate.toIso8601String().split('T').first,
              workDescription: _descriptionController.text.trim(),
              problemsDescription: _problemsController.text.trim(),
              safetyNotes: _safetyController.text.trim(),
              visitorsNotes: _visitorsController.text.trim(),
              qualityNotes: _qualityController.text.trim(),
            )
          : await repository.createEntry(
              journalId: widget.journalId,
              entryDate: _entryDate.toIso8601String().split('T').first,
              workDescription: _descriptionController.text.trim(),
              problemsDescription: _problemsController.text.trim(),
              safetyNotes: _safetyController.text.trim(),
              visitorsNotes: _visitorsController.text.trim(),
              qualityNotes: _qualityController.text.trim(),
            );

      if (!isDraft) {
        await repository.submitEntry(entry.id);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}
