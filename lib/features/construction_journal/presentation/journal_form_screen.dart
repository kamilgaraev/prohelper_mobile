import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/widgets/app_state_view.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/construction_journal_models.dart';
import '../data/construction_journal_repository.dart';

class JournalFormScreen extends ConsumerStatefulWidget {
  const JournalFormScreen({
    super.key,
    this.initialJournal,
  });

  final ConstructionJournalModel? initialJournal;

  @override
  ConsumerState<JournalFormScreen> createState() => _JournalFormScreenState();
}

class _JournalFormScreenState extends ConsumerState<JournalFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _numberController;
  late DateTime _startDate;
  bool _isSaving = false;

  bool get _isEdit => widget.initialJournal != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialJournal?.name ?? '');
    _numberController = TextEditingController(text: widget.initialJournal?.journalNumber ?? '');
    _startDate = DateTime.tryParse(widget.initialJournal?.startDate ?? '') ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedProject = ref.watch(projectsProvider).selectedProject;

    if (!_isEdit && selectedProject == null) {
      return const Scaffold(
        body: AppStateView(
          icon: Icons.apartment_outlined,
          title: 'Объект не выбран',
          description: 'Сначала выберите объект, а затем создавайте журнал.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Редактирование журнала' : 'Новый журнал'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Название журнала',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _numberController,
            decoration: const InputDecoration(
              labelText: 'Номер журнала',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Дата начала'),
            subtitle: Text(_formatDate(_startDate)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );

              if (picked != null) {
                setState(() {
                  _startDate = picked;
                });
              }
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSaving ? null : () => _save(selectedProject?.serverId),
            child: Text(_isEdit ? 'Сохранить' : 'Создать'),
          ),
        ],
      ),
    );
  }

  Future<void> _save(int? projectId) async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите название журнала.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(constructionJournalRepositoryProvider);
      if (_isEdit) {
        await repository.updateJournal(
          journalId: widget.initialJournal!.id,
          name: _nameController.text.trim(),
          journalNumber: _numberController.text.trim(),
          startDate: _startDate.toIso8601String().split('T').first,
        );
      } else {
        await repository.createJournal(
          projectId: projectId ?? 0,
          name: _nameController.text.trim(),
          journalNumber: _numberController.text.trim(),
          startDate: _startDate.toIso8601String().split('T').first,
        );
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
