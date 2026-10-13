import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../../core/widgets/app_error_notice.dart';
import '../../auth/domain/auth_provider.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/bim_models.dart';
import '../data/bim_repository.dart';
import '../data/design_package_model.dart';
import '../data/drawing_annotations.dart';
import '../domain/drawing_issues_provider.dart';
import 'drawing_layer.dart';

class DrawingViewerScreen extends ConsumerStatefulWidget {
  const DrawingViewerScreen({
    super.key,
    required this.path,
    required this.file,
    required this.projectId,
    required this.packageId,
    required this.sessionIdentity,
  });
  final String path;
  final DesignPackageFile file;
  final int projectId;
  final int packageId;
  final Object sessionIdentity;
  @override
  ConsumerState<DrawingViewerScreen> createState() =>
      _DrawingViewerScreenState();
}

class _DrawingViewerScreenState extends ConsumerState<DrawingViewerScreen> {
  final _pdf = PdfViewerController();
  late final _pdfDocument = PdfDocumentRefFile(
    widget.path,
    useProgressiveLoading: false,
  );
  final _drafts = <int, List<DrawingStroke>>{};
  final _sizes = <int, Size>{};
  final _created = <BimIssue>[];
  DrawingTool? _tool;
  int _page = 1;
  int _pageCount = 1;
  bool _ready = false;
  bool _saving = false;
  bool _showSaved = true;
  bool _discard = false;
  bool _confirming = false;
  String? _saveKey;
  String? _savePayload;
  String _lastTitle = '';
  String? _imageError;
  DrawingIssueKey get _issueKey => (
    projectId: widget.projectId,
    versionId: widget.file.id,
  );
  bool get _dirty =>
      _lastTitle.isNotEmpty ||
      _drafts.values.any((strokes) => strokes.isNotEmpty);
  bool get _contextCurrent {
    final auth = ref.read(authProvider);
    return auth is AuthAuthenticated &&
        auth.sessionIdentity == widget.sessionIdentity &&
        ref.read(projectsProvider).selectedProject?.serverId ==
            widget.projectId;
  }

  @override
  void initState() {
    super.initState();
    if (!widget.file.isPdf) {
      _loadImageSize();
    }
  }

  Future<void> _loadImageSize() async {
    try {
      final buffer = await ui.ImmutableBuffer.fromFilePath(widget.path);
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        try {
          if (mounted) {
            setState(() {
              _sizes[1] = Size(
                descriptor.width.toDouble(),
                descriptor.height.toDouble(),
              );
              _ready = true;
              _imageError = null;
            });
          }
        } finally {
          descriptor.dispose();
        }
      } finally {
        buffer.dispose();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _imageError =
                  'Не удалось прочитать изображение. Закройте просмотр и загрузите файл заново.',
        );
      }
    }
  }

  Future<void> _close() async {
    if (_saving || _confirming) return;
    if (!_dirty || !_contextCurrent) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _confirming = true;
    final discard = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Закрыть без сохранения?'),
            content: const Text('Несохранённые рисунки будут потеряны.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Продолжить работу'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Закрыть без сохранения'),
              ),
            ],
          ),
    );
    _confirming = false;
    if (discard == true && mounted) {
      setState(() => _discard = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  Future<void> _save() async {
    if (_saving || !_ready || !_contextCurrent || !widget.file.canAnnotate) {
      return;
    }
    final page = _page;
    final size = _sizes[page];
    if (size == null) return;
    final text = await showDialog<String>(
      context: context,
      builder:
          (context) =>
              _DrawingIssueDialog(page: page, initialTitle: _lastTitle),
    );
    if (text == null || !mounted || !_contextCurrent) return;
    _lastTitle = text;
    final payload = {
      'title': text,
      'severity': 'minor',
      'package_id': widget.packageId,
      'version_id': widget.file.id,
      'annotations':
          DrawingAnnotations.page(
            page,
            size.width,
            size.height,
            _drafts[page] ?? [],
          ).toJson(),
    };
    final serialized = jsonEncode(payload);
    if (_savePayload != serialized) {
      _savePayload = serialized;
      final random = math.Random.secure();
      _saveKey =
          List.generate(
            16,
            (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
          ).join();
    }
    setState(() => _saving = true);
    try {
      final issue = await ref
          .read(bimRepositoryProvider)
          .createIssue(widget.projectId, payload, idempotencyKey: _saveKey);
      if (!mounted || !_contextCurrent) return;
      setState(() {
        _created.add(issue);
        _drafts.remove(page);
        _tool = null;
        _saveKey = null;
        _savePayload = null;
        _lastTitle = '';
      });
      ref.invalidate(drawingIssuesProvider(_issueKey));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Замечание и разметка сохранены')),
      );
    } catch (error) {
      if (mounted && _contextCurrent) AppErrorNotice.show(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _layer(int pageNumber, Size size, List<BimIssue> issues) =>
      DrawingLayer(
        key: ValueKey(pageNumber),
        size: size,
        pageNumber: pageNumber,
        tool: _saving ? null : _tool,
        saved:
            _showSaved
                ? issues
                    .map(
                      (issue) => DrawingAnnotations.tryParse(
                        issue.context['annotations'],
                      ),
                    )
                    .whereType<DrawingAnnotations>()
                    .where((value) => value.pageNumber == pageNumber)
                    .toList()
                : [],
        drafts: _drafts[pageNumber] ?? [],
        onStroke:
            (page, stroke) => setState(() {
              _drafts.putIfAbsent(page, () => []).add(stroke);
              _page = page;
            }),
      );

  Future<void> _showIssues(List<BimIssue> issues) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.65,
              child:
                  issues.isEmpty
                      ? const Center(
                        child: Text('Сохранённых замечаний пока нет'),
                      )
                      : ListView(
                        children: [
                          for (final issue in issues)
                            ListTile(
                              title: Text(issue.title),
                              subtitle: Text(
                                'Лист ${DrawingAnnotations.tryParse(issue.context['annotations'])!.pageNumber} · ${issue.statusLabel}',
                              ),
                              onTap: () {
                                final page =
                                    DrawingAnnotations.tryParse(
                                      issue.context['annotations'],
                                    )!.pageNumber;
                                Navigator.pop(context);
                                if (!mounted || !_contextCurrent) return;
                                setState(() {
                                  _page = page;
                                  _tool = null;
                                  _showSaved = true;
                                });
                                if (widget.file.isPdf && _pdf.isReady) {
                                  _pdf.goToPage(pageNumber: page);
                                }
                              },
                            ),
                        ],
                      ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authProvider);
    ref.watch(projectsProvider);
    final current = _contextCurrent;
    final loaded =
        current
            ? ref.watch(drawingIssuesProvider(_issueKey))
            : const AsyncData<List<BimIssue>>([]);
    final issues =
        <int, BimIssue>{
          for (final issue in [...loaded.valueOrNull ?? [], ..._created])
            if (bimInt(issue.context['version_id']) == widget.file.id &&
                DrawingAnnotations.tryParse(issue.context['annotations']) !=
                    null)
              issue.id: issue,
        }.values.toList();
    return PopScope(
      canPop: !_saving && (!_dirty || _discard || !current),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.file.name),
          leading: IconButton(
            onPressed: _saving ? null : _close,
            tooltip: 'Закрыть просмотр',
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            IconButton(
              onPressed: current ? () => _showIssues(issues) : null,
              tooltip: 'Замечания',
              icon: const Icon(Icons.comment_outlined),
            ),
          ],
        ),
        body:
            !current
                ? const Center(
                  child: Text(
                    'Проект или сеанс изменился. Закройте просмотр и откройте документ заново.',
                  ),
                )
                : Column(
                  children: [
                    if (widget.file.versionNumber != null)
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text('Редакция ${widget.file.versionNumber}'),
                      ),
                    if (loaded.hasError)
                      MaterialBanner(
                        content: const Text(
                          'Не удалось загрузить сохранённые замечания.',
                        ),
                        actions: [
                          TextButton(
                            onPressed:
                                () => ref.invalidate(
                                  drawingIssuesProvider(_issueKey),
                                ),
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    if (_imageError != null)
                      MaterialBanner(
                        content: Text(_imageError!),
                        actions: [
                          TextButton(
                            onPressed: _loadImageSize,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    Expanded(
                      child:
                          widget.file.isPdf
                              ? PdfViewer(
                                _pdfDocument,
                                controller: _pdf,
                                params: PdfViewerParams(
                                  backgroundColor:
                                      Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                  panEnabled: _tool == null,
                                  scaleEnabled: _tool == null,
                                  maxImageBytesCachedOnMemory: 32 * 1024 * 1024,
                                  onViewerReady: (document, controller) {
                                    if (mounted) {
                                      setState(() {
                                        _ready = true;
                                        _pageCount = document.pages.length;
                                        for (final page in document.pages) {
                                          _sizes[page.pageNumber] = Size(
                                            page.width,
                                            page.height,
                                          );
                                        }
                                      });
                                    }
                                  },
                                  onPageChanged: (page) {
                                    if (page != null &&
                                        mounted &&
                                        _tool == null) {
                                      setState(() => _page = page);
                                    }
                                  },
                                  pageOverlaysBuilder:
                                      (context, rect, page) => [
                                        Positioned.fill(
                                          child: _layer(
                                            page.pageNumber,
                                            Size(page.width, page.height),
                                            issues,
                                          ),
                                        ),
                                      ],
                                  errorBannerBuilder:
                                      (
                                        context,
                                        error,
                                        stackTrace,
                                        documentRef,
                                      ) => const Center(
                                        child: Text(
                                          'Не удалось прочитать PDF. Закройте просмотр и загрузите файл заново.',
                                        ),
                                      ),
                                ),
                              )
                              : !_ready
                              ? const Center(child: CircularProgressIndicator())
                              : LayoutBuilder(
                                builder: (context, constraints) {
                                  final original = _sizes[1]!;
                                  final scale = math.min(
                                    constraints.maxWidth / original.width,
                                    constraints.maxHeight / original.height,
                                  );
                                  return InteractiveViewer(
                                    minScale: 0.5,
                                    maxScale: 8,
                                    panEnabled: _tool == null,
                                    scaleEnabled: _tool == null,
                                    child: Center(
                                      child: SizedBox(
                                        width: original.width * scale,
                                        height: original.height * scale,
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: Image.file(
                                                File(widget.path),
                                                fit: BoxFit.fill,
                                                cacheWidth: 2048,
                                              ),
                                            ),
                                            Positioned.fill(
                                              child: _layer(
                                                1,
                                                original,
                                                issues,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  tooltip: 'Предыдущий лист',
                                  onPressed:
                                      widget.file.isPdf &&
                                              _ready &&
                                              _page > 1 &&
                                              !_saving
                                          ? () {
                                            setState(() => _tool = null);
                                            _pdf.goToPage(
                                              pageNumber: _page - 1,
                                            );
                                          }
                                          : null,
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                Text('Лист $_page / $_pageCount'),
                                IconButton(
                                  tooltip: 'Следующий лист',
                                  onPressed:
                                      widget.file.isPdf &&
                                              _ready &&
                                              _page < _pageCount &&
                                              !_saving
                                          ? () {
                                            setState(() => _tool = null);
                                            _pdf.goToPage(
                                              pageNumber: _page + 1,
                                            );
                                          }
                                          : null,
                                  icon: const Icon(Icons.chevron_right),
                                ),
                                IconButton(
                                  tooltip: 'Разметка',
                                  onPressed:
                                      () => setState(
                                        () => _showSaved = !_showSaved,
                                      ),
                                  icon: Icon(
                                    _showSaved
                                        ? Icons.layers
                                        : Icons.layers_outlined,
                                  ),
                                ),
                              ],
                            ),
                            if (widget.file.canAnnotate)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Перемещение и масштаб',
                                      isSelected: _tool == null,
                                      onPressed:
                                          _saving
                                              ? null
                                              : () =>
                                                  setState(() => _tool = null),
                                      icon: const Icon(Icons.pan_tool_outlined),
                                    ),
                                    for (final tool in DrawingTool.values)
                                      IconButton(
                                        tooltip: switch (tool) {
                                          DrawingTool.freehand => 'Карандаш',
                                          DrawingTool.line => 'Линия',
                                          DrawingTool.arrow => 'Стрелка',
                                        },
                                        isSelected: _tool == tool,
                                        onPressed:
                                            !_ready || _saving
                                                ? null
                                                : () => setState(
                                                  () => _tool = tool,
                                                ),
                                        icon: Icon(switch (tool) {
                                          DrawingTool.freehand =>
                                            Icons.edit_outlined,
                                          DrawingTool.line => Icons.show_chart,
                                          DrawingTool.arrow => Icons.north_east,
                                        }),
                                      ),
                                    IconButton(
                                      tooltip: 'Отменить штрих',
                                      onPressed:
                                          (_drafts[_page]?.isNotEmpty ??
                                                      false) &&
                                                  !_saving
                                              ? () => setState(
                                                () =>
                                                    _drafts[_page]!
                                                        .removeLast(),
                                              )
                                              : null,
                                      icon: const Icon(Icons.undo),
                                    ),
                                    FilledButton(
                                      onPressed:
                                          _ready && !_saving ? _save : null,
                                      child: Text(
                                        _saving ? 'Сохраняем…' : 'Замечание',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

class _DrawingIssueDialog extends StatefulWidget {
  const _DrawingIssueDialog({required this.page, required this.initialTitle});
  final int page;
  final String initialTitle;

  @override
  State<_DrawingIssueDialog> createState() => _DrawingIssueDialogState();
}

class _DrawingIssueDialogState extends State<_DrawingIssueDialog> {
  late final _title = TextEditingController(text: widget.initialTitle);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Замечание к чертежу'),
    content: TextField(
      controller: _title,
      autofocus: true,
      maxLength: 255,
      minLines: 2,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: 'Текст замечания',
        helperText: 'Лист ${widget.page}',
      ),
      onChanged: (_) => setState(() {}),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed:
            _title.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, _title.text.trim()),
        child: const Text('Сохранить'),
      ),
    ],
  );
}
