import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/user_message.dart';
import '../../../core/services/permission_service.dart';
import '../../projects/domain/projects_provider.dart';
import '../../construction_journal/data/construction_journal_models.dart';
import '../../construction_journal/data/construction_journal_repository.dart';
import '../data/project_files_repository.dart';
import 'field_catalog_screen.dart';

class ProjectFilesScreen extends StatelessWidget {
  const ProjectFilesScreen({super.key});

  @override
  Widget build(BuildContext context) => FieldCatalogScreen(
    title: 'Файлы объекта',
    catalog: 'project-files',
    apiPrefix: '/files',
    projectScoped: true,
    icon: Icons.folder_outlined,
    appBarActionBuilder:
        (context, refresh) => _ProjectFileUploadAction(onUploaded: refresh),
  );
}

class _ProjectFileUploadAction extends ConsumerStatefulWidget {
  const _ProjectFileUploadAction({required this.onUploaded});

  final Future<void> Function() onUploaded;

  @override
  ConsumerState<_ProjectFileUploadAction> createState() =>
      _ProjectFileUploadActionState();
}

class _ProjectFileUploadActionState
    extends ConsumerState<_ProjectFileUploadAction> {
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    final projectId = ref.watch(
      projectsProvider.select((state) => state.selectedProject?.serverId),
    );
    final permissions = ref.watch(permissionServiceProvider);
    final canUpload = permissions.hasAnyPermission(const [
      'reports.photo_upload',
      'projects.upload_photos',
      'projects.upload_progress_photos',
    ]);
    if (projectId == null || !canUpload) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Загрузить фото или документ',
      onPressed: _uploading ? null : _chooseUpload,
      icon:
          _uploading
              ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : const Icon(Icons.upload_file_rounded),
    );
  }

  Future<void> _chooseUpload() async {
    final project = ref.read(projectsProvider).selectedProject;
    final projectId = project?.serverId;
    if (projectId == null) return;
    final target = await _chooseRecordTarget(projectId, project!.name);
    if (target == null || !mounted) return;
    final kind = await showModalBottomSheet<String>(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Снять фото'),
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Выбрать фото'),
                  onTap: () => Navigator.pop(context, 'photo'),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Выбрать документ'),
                  onTap: () => Navigator.pop(context, 'document'),
                ),
              ],
            ),
          ),
    );
    if (kind == null || !mounted) return;
    try {
      String? path;
      String type;
      if (kind == 'camera' || kind == 'photo') {
        final image = await ImagePicker().pickImage(
          source: kind == 'camera' ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 90,
        );
        path = image?.path;
        type = 'photo';
      } else {
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const [
            'pdf',
            'doc',
            'docx',
            'xls',
            'xlsx',
            'odt',
            'ods',
            'txt',
          ],
          allowMultiple: false,
          withData: false,
        );
        path = result?.files.singleOrNull?.path;
        type = 'document';
      }
      if (path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось прочитать выбранный файл.'),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      await _upload(path, type, target);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(UserMessage.fromError(error))));
    }
  }

  Future<void> _upload(
    String path,
    String type,
    _FileRecordTarget target,
  ) async {
    final projectId = ref.read(projectsProvider).selectedProject?.serverId;
    final permissions = ref.read(permissionServiceProvider);
    if (projectId == null ||
        !permissions.hasAnyPermission(const [
          'reports.photo_upload',
          'projects.upload_photos',
          'projects.upload_progress_photos',
        ])) {
      return;
    }
    if (await File(path).length() > 20 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Размер файла не должен превышать 20 МиБ.'),
          ),
        );
      }
      return;
    }
    final description = await _askDescription();
    if (description == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      await ref
          .read(projectFilesRepositoryProvider)
          .uploadProjectFile(
            projectId: projectId,
            recordType: target.type,
            recordId: target.id,
            path: path,
            fileType: type,
            description: description,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Файл прикреплён: ${target.label}')),
      );
      await widget.onUploaded();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(UserMessage.fromError(error))));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<_FileRecordTarget?> _chooseRecordTarget(
    int projectId,
    String projectName,
  ) async {
    final canReadJournal = ref
        .read(permissionServiceProvider)
        .hasPermission('construction-journal.view');
    final type = await showModalBottomSheet<String>(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.domain_outlined),
                  title: Text('Объект: $projectName'),
                  onTap: () => Navigator.pop(context, 'project'),
                ),
                if (canReadJournal)
                  ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: const Text('Выбрать запись журнала работ'),
                    onTap: () => Navigator.pop(context, 'journal'),
                  ),
              ],
            ),
          ),
    );
    if (!mounted || type == null) return null;
    if (type == 'project') {
      return _FileRecordTarget(
        type: 'project',
        id: projectId,
        label: 'объект $projectName',
      );
    }

    try {
      final journals = await ref
          .read(constructionJournalRepositoryProvider)
          .fetchJournals(projectId: projectId, perPage: 50);
      if (!mounted) return null;
      if (journals.items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('В выбранном объекте нет журналов работ.'),
          ),
        );
        return null;
      }
      final journal = await showModalBottomSheet<ConstructionJournalModel>(
        context: context,
        isScrollControlled: true,
        builder:
            (context) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  const ListTile(title: Text('Выберите журнал')),
                  for (final item in journals.items)
                    ListTile(
                      leading: const Icon(Icons.menu_book_outlined),
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.journalNumber} · ${item.statusLabel}',
                      ),
                      onTap: () => Navigator.pop(context, item),
                    ),
                ],
              ),
            ),
      );
      if (!mounted || journal == null) return null;
      final detail = await ref
          .read(constructionJournalRepositoryProvider)
          .fetchJournalDetail(journal.id);
      if (!mounted) return null;
      if (detail.entries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('В выбранном журнале нет записей.')),
        );
        return null;
      }
      final entry = await showModalBottomSheet<ConstructionJournalEntryModel>(
        context: context,
        isScrollControlled: true,
        builder:
            (context) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(title: Text(journal.name)),
                  for (final item in detail.entries)
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(
                        'Запись №${item.entryNumber} · ${item.entryDate}',
                      ),
                      subtitle: Text(item.workDescription),
                      onTap: () => Navigator.pop(context, item),
                    ),
                ],
              ),
            ),
      );
      if (entry == null) return null;
      return _FileRecordTarget(
        type: 'construction_journal_entry',
        id: entry.id,
        label: 'запись №${entry.entryNumber} журнала «${journal.name}»',
      );
    } catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(UserMessage.fromError(error))));
      return null;
    }
  }

  Future<String?> _askDescription() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Комментарий к файлу'),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Например, общий вид объекта',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Продолжить'),
              ),
            ],
          ),
    );
    controller.dispose();
    return result;
  }
}

class _FileRecordTarget {
  const _FileRecordTarget({
    required this.type,
    required this.id,
    required this.label,
  });

  final String type;
  final int id;
  final String label;
}
