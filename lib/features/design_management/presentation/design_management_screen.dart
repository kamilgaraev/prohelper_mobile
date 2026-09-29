import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_notice.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/app_permission_state.dart';
import '../../../core/widgets/industrial_card.dart';
import '../../auth/domain/auth_provider.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/design_package_file_service.dart';
import '../data/design_package_model.dart';
import '../domain/design_package_provider.dart';
import 'bim_catalog_screen.dart';

class DesignManagementScreen extends ConsumerStatefulWidget {
  const DesignManagementScreen({super.key});

  @override
  ConsumerState<DesignManagementScreen> createState() =>
      _DesignManagementScreenState();
}

class _DesignManagementScreenState
    extends ConsumerState<DesignManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncProject());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(designPackageProvider);
    final projectId = ref.watch(
      projectsProvider.select((value) => value.selectedProject?.serverId),
    );
    if (state.projectId != projectId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncProject());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ПИР'),
        actions: [
          IconButton(
            tooltip: 'BIM-модели',
            icon: const Icon(Icons.view_in_ar_outlined),
            onPressed:
                projectId == null
                    ? null
                    : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BimCatalogScreen(projectId: projectId),
                      ),
                    ),
          ),
          IconButton(
            tooltip: 'Обновить',
            onPressed:
                projectId == null || state.isLoading
                    ? null
                    : () => ref.read(designPackageProvider.notifier).load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _body(state, projectId),
    );
  }

  Widget _body(DesignPackageState state, int? projectId) {
    if (projectId == null) {
      return const AppEmptyState(
        icon: Icons.domain_disabled_outlined,
        title: 'Выберите объект',
        description: 'Пакеты документации показываются для выбранного объекта.',
      );
    }
    if (state.projectId != projectId) {
      return const AppLoadingState(message: 'Обновляем список пакетов');
    }
    if (state.isLoading && state.page == null) {
      return const AppLoadingState(message: 'Загружаем пакеты');
    }
    if (state.error != null && state.page == null) {
      if (state.permissionDenied) {
        return const AppPermissionState(
          title: 'Раздел недоступен',
          description: 'У вас нет прав на просмотр этого раздела.',
        );
      }
      return AppErrorState(
        title: 'Не удалось загрузить пакеты',
        description: UserMessage.fromError(state.error!),
        onRetry: () => ref.read(designPackageProvider.notifier).load(),
      );
    }
    final page = state.page;
    if (page == null || page.items.isEmpty) {
      return const AppEmptyState(
        icon: Icons.design_services_outlined,
        title: 'Пакетов пока нет',
        description: 'Для выбранного объекта пакеты документации не найдены.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(designPackageProvider.notifier).load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text('Показано ${page.items.length} из ${page.total}'),
          const SizedBox(height: 10),
          for (final item in page.items) ...[
            IndustrialCard(
              onTap: () => _openDetail(item),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.statusLabel != null || item.status != null)
                    Chip(
                      label: Text(item.statusLabel ?? item.status!),
                      visualDensity: VisualDensity.compact,
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.title),
                    subtitle: Text(
                      [
                        if (item.stage != null) item.stage!,
                        if (item.discipline != null) item.discipline!,
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (page.currentPage < page.lastPage)
            OutlinedButton.icon(
              onPressed:
                  state.isLoadingMore
                      ? null
                      : () =>
                          ref.read(designPackageProvider.notifier).loadMore(),
              icon:
                  state.isLoadingMore
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.expand_more_rounded),
              label: Text(state.isLoadingMore ? 'Загружаем' : 'Показать ещё'),
            ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }

  void _syncProject() {
    final notifier = ref.read(designPackageProvider.notifier);
    final projectId = ref.read(projectsProvider).selectedProject?.serverId;
    notifier.syncProject(projectId);
    if (projectId != null) notifier.load();
  }

  void _openDetail(DesignPackageModel item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DesignPackageDetailScreen(id: item.id),
      ),
    );
  }
}

class _DesignPackageDetailScreen extends ConsumerStatefulWidget {
  const _DesignPackageDetailScreen({required this.id});

  final int id;

  @override
  ConsumerState<_DesignPackageDetailScreen> createState() =>
      _DesignPackageDetailScreenState();
}

class _DesignPackageDetailScreenState
    extends ConsumerState<_DesignPackageDetailScreen> {
  late Future<DesignPackageModel> _future;
  bool _isOpeningFile = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<DesignPackageModel> _load() =>
      ref.read(designPackageProvider.notifier).fetchDetail(widget.id);

  @override
  Widget build(BuildContext context) {
    final selectedProjectId = ref.watch(
      projectsProvider.select((value) => value.selectedProject?.serverId),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Пакет документации')),
      body: FutureBuilder<DesignPackageModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppLoadingState(message: 'Загружаем пакет');
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return AppErrorState(
              title: 'Не удалось загрузить пакет',
              description:
                  snapshot.hasError
                      ? UserMessage.fromError(snapshot.error!)
                      : 'Повторите попытку позже.',
              onRetry: () => setState(() => _future = _load()),
            );
          }
          final package = snapshot.requireData;
          if (selectedProjectId == null ||
              package.projectId != selectedProjectId) {
            return AppEmptyState(
              icon: Icons.domain_disabled_outlined,
              title:
                  selectedProjectId == null
                      ? 'Выберите объект'
                      : 'Объект изменился',
              description:
                  selectedProjectId == null
                      ? 'Вернитесь к списку после выбора объекта.'
                      : 'Вернитесь к списку и откройте пакет выбранного объекта.',
            );
          }
          return _detail(package);
        },
      ),
    );
  }

  Widget _detail(DesignPackageModel package) => RefreshIndicator(
    onRefresh: () async {
      setState(() => _future = _load());
      await _future;
    },
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _InfoCard(package: package),
        if (package.result.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Результат',
            child: Column(
              children: [
                for (final row in package.result)
                  ListTile(
                    title: Text(row.label),
                    subtitle: Text(row.displayValue ?? row.value),
                  ),
              ],
            ),
          ),
        ],
        if (package.files.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Файлы',
            child: Column(
              children: [
                for (final file in package.files)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(file.name),
                    subtitle:
                        file.mimeType == null ||
                                file.mimeType == 'application/octet-stream'
                            ? null
                            : Text(file.mimeType!),
                    trailing: Wrap(
                      children: [
                        if (_isOpeningFile)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        if (!_isOpeningFile && file.uriFor('preview') != null)
                          IconButton(
                            tooltip: 'Просмотреть',
                            onPressed:
                                () => _openFile(package, file, 'preview'),
                            icon: const Icon(Icons.visibility_outlined),
                          ),
                        if (!_isOpeningFile && file.uriFor('download') != null)
                          IconButton(
                            tooltip: 'Скачать и открыть',
                            onPressed:
                                () => _openFile(package, file, 'download'),
                            icon: const Icon(Icons.download_outlined),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (package.comments.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Комментарии',
            child: Column(
              children: [
                for (final comment in package.comments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(comment.author),
                    subtitle: Text(
                      [
                        comment.body,
                        if (comment.status != null) comment.status!,
                        if (comment.createdAt != null)
                          _dateLabel(comment.createdAt!),
                      ].join('\n'),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (package.workflowHistory.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: 'История',
            child: Column(
              children: [
                for (final entry in package.workflowHistory)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.title),
                    subtitle: Text(
                      [
                        if (entry.description != null) entry.description!,
                        if (entry.createdAt != null)
                          _dateLabel(entry.createdAt!),
                      ].join('\n'),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (package.availableActions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Доступные действия',
            child: Column(
              children: [
                for (final action in package.availableActions) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _performAction(package, action),
                      child: Text(action.title),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ],
    ),
  );

  Future<void> _openFile(
    DesignPackageModel package,
    DesignPackageFile file,
    String purpose,
  ) async {
    if (_isOpeningFile || !_projectContextCurrent(package)) return;
    final selectedProjectId =
        ref.read(projectsProvider).selectedProject?.serverId;
    final initialAuth = ref.read(authProvider);
    if (selectedProjectId == null || initialAuth is! AuthAuthenticated) return;
    final sessionIdentity = initialAuth.sessionIdentity;
    if (sessionIdentity == null) return;
    final service = ref.read(designPackageFileServiceProvider);
    setState(() => _isOpeningFile = true);
    String? downloadedPath;
    try {
      final freshPackage = await _load();
      if (!_fileContextCurrent(
        selectedProjectId,
        sessionIdentity,
        freshPackage,
      )) {
        return;
      }
      if (freshPackage.id != widget.id ||
          freshPackage.id != package.id ||
          freshPackage.projectId != package.projectId) {
        return;
      }
      final freshFile =
          freshPackage.files
              .where((candidate) => candidate.id == file.id)
              .firstOrNull;
      if (freshFile == null) return;
      final uri = freshFile.uriFor(purpose);
      if (uri == null) {
        throw const FormatException('Для файла нет актуальной ссылки.');
      }
      if (purpose == 'preview') {
        final opened = await service.openPreview(uri);
        if (!_fileContextCurrent(
          selectedProjectId,
          sessionIdentity,
          freshPackage,
        )) {
          return;
        }
        if (!opened) {
          throw const FormatException(
            'Не удалось открыть файл. Проверьте, что на устройстве есть приложение для просмотра документов.',
          );
        }
      } else {
        downloadedPath = await service.download(uri, freshFile.name);
        if (!_fileContextCurrent(
          selectedProjectId,
          sessionIdentity,
          freshPackage,
        )) {
          await service.deleteDownloaded(downloadedPath);
          downloadedPath = null;
          return;
        }
        final opened = await service.openLocalFile(downloadedPath);
        if (!_fileContextCurrent(
          selectedProjectId,
          sessionIdentity,
          freshPackage,
        )) {
          await service.deleteDownloaded(downloadedPath);
          downloadedPath = null;
          return;
        }
        if (!opened) {
          throw const FormatException(
            'Не удалось открыть файл. Проверьте, что на устройстве есть приложение для просмотра документов.',
          );
        }
        service.scheduleCleanup(downloadedPath);
        downloadedPath = null;
      }
    } catch (error) {
      if (downloadedPath != null) {
        try {
          await service.deleteDownloaded(downloadedPath);
        } catch (_) {}
      }
      if (mounted &&
          _fileContextCurrent(selectedProjectId, sessionIdentity, package)) {
        AppErrorNotice.show(context, error);
      }
    } finally {
      if (mounted) setState(() => _isOpeningFile = false);
    }
  }

  bool _fileContextCurrent(
    int projectId,
    Object sessionIdentity,
    DesignPackageModel package,
  ) {
    if (!mounted ||
        package.id != widget.id ||
        package.projectId != projectId ||
        ref.read(projectsProvider).selectedProject?.serverId != projectId) {
      return false;
    }
    final auth = ref.read(authProvider);
    return auth is AuthAuthenticated && auth.sessionIdentity == sessionIdentity;
  }

  Future<void> _performAction(
    DesignPackageModel package,
    DesignPackageAction action,
  ) async {
    if (!_projectContextCurrent(package)) return;
    final comment = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ActionSheet(action: action),
    );
    if (!mounted || comment == null) return;
    if (!_projectContextCurrent(package)) return;
    if (action.requiresComment && comment.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите комментарий к действию')),
      );
      return;
    }
    try {
      await ref
          .read(designPackageProvider.notifier)
          .executeAction(id: widget.id, action: action, comment: comment);
      if (mounted) setState(() => _future = _load());
    } catch (error) {
      if (mounted) AppErrorNotice.show(context, error);
    }
  }

  bool _projectContextCurrent(DesignPackageModel package) {
    final selectedProjectId =
        ref.read(projectsProvider).selectedProject?.serverId;
    return selectedProjectId != null && selectedProjectId == package.projectId;
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.package});

  final DesignPackageModel package;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: package.title,
    child: Column(
      children: [
        if (package.stage != null)
          ListTile(title: const Text('Стадия'), subtitle: Text(package.stage!)),
        if (package.projectStage != null)
          ListTile(
            title: const Text('Этап объекта'),
            subtitle: Text(package.projectStageLabel ?? package.projectStage!),
          ),
        if (package.discipline != null)
          ListTile(
            title: const Text('Раздел'),
            subtitle: Text(package.discipline!),
          ),
        if (package.statusLabel != null || package.status != null)
          ListTile(
            title: const Text('Статус'),
            subtitle: Text(package.statusLabel ?? package.status!),
          ),
        if (package.plannedIssueDate != null)
          ListTile(
            title: const Text('Плановый выпуск'),
            subtitle: Text(_dateLabel(package.plannedIssueDate!)),
          ),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => IndustrialCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

class _ActionSheet extends StatefulWidget {
  const _ActionSheet({required this.action});

  final DesignPackageAction action;

  @override
  State<_ActionSheet> createState() => _ActionSheetState();
}

class _ActionSheetState extends State<_ActionSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.of(context).viewInsets.bottom + 20,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.action.title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText:
                widget.action.requiresComment
                    ? 'Комментарий'
                    : 'Комментарий (необязательно)',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, _controller.text.trim()),
              child: const Text('Выполнить'),
            ),
          ],
        ),
      ],
    ),
  );
}

String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
