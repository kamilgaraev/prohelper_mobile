import 'dart:convert';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/domain/auth_provider.dart';
import '../../../core/widgets/pro_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/act_model.dart';
import '../data/acts_repository.dart';

class ActsScreen extends ConsumerStatefulWidget {
  const ActsScreen({super.key});
  @override
  ConsumerState<ActsScreen> createState() => _ActsScreenState();
}

class _ActsScreenState extends ConsumerState<ActsScreen> {
  final _items = <ActModel>[];
  bool _loading = false;
  String? _error;
  int _page = 1;
  int _lastPage = 1;
  int? _projectId;

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(projectsProvider).selectedProject?.serverId;
    if (id != _projectId && !_loading) {
      _projectId = id;
      _items.clear();
      _page = 1;
      if (id != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
      }
    }
    final Widget body;
    if (id == null) {
      body = const Center(child: Text('Выберите объект'));
    } else if (_loading && _items.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _items.isEmpty) {
      body = _ErrorPanel(message: _error!, retry: () => _load(reset: true));
    } else {
      body = RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              _ErrorPanel(message: _error!, retry: () => _load(reset: true)),
            if (_items.isEmpty && !_loading)
              const Padding(
                padding: EdgeInsets.all(36),
                child: Center(child: Text('Акты не найдены')),
              ),
            for (final act in _items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ProCard(
                  onTap: () => _open(act.id),
                  child: Row(
                    children: [
                      const Icon(Icons.fact_check_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              act.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(act.status),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            if (_page <= _lastPage)
              Center(
                child: TextButton(
                  onPressed: _loading ? null : _loadMore,
                  child: Text(_loading ? 'Загрузка…' : 'Загрузить ещё'),
                ),
              ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Акты'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: id == null ? null : () => _load(reset: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: body,
    );
  }

  Future<void> _load({bool reset = false}) async {
    final id = _projectId;
    if (id == null || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _page = 1;
        _items.clear();
      }
    });
    try {
      final result = await ref
          .read(actsRepositoryProvider)
          .list(projectId: id, page: _page);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _page = result.currentPage + 1;
        _lastPage = result.lastPage;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _message(e);
        });
      }
    }
  }

  Future<void> _loadMore() => _load();
  Future<void> _open(int id) async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => ActDetailScreen(id: id)));
    if (changed == true) _load(reset: true);
  }
}

class ActDetailScreen extends ConsumerStatefulWidget {
  const ActDetailScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<ActDetailScreen> createState() => _ActDetailScreenState();
}

class _ActDetailScreenState extends ConsumerState<ActDetailScreen> {
  ActModel? _act;
  bool _loading = true;
  String? _error;
  int? _projectId;
  Object? _boundActor;
  int? _openingFile;
  @override
  void initState() {
    super.initState();
    _projectId = ref.read(projectsProvider).selectedProject?.serverId;
    _boundActor = _actorContext;
    _load();
  }

  Object get _actorContext {
    final auth = ref.read(authProvider);
    return (
      user: auth.user?.serverId,
      organization: auth.user?.currentOrganizationId,
      session: auth is AuthAuthenticated ? auth.sessionIdentity : null,
    );
  }

  bool get _contextCurrent =>
      mounted &&
      _projectId != null &&
      ref.read(projectsProvider).selectedProject?.serverId == _projectId &&
      _act?.projectId == _projectId &&
      _boundActor == _actorContext;

  Future<void> _load() async {
    try {
      final value = await ref.read(actsRepositoryProvider).detail(widget.id);
      if (mounted) {
        setState(() {
          _act = value;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _message(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectId = ref.watch(
      projectsProvider.select((state) => state.selectedProject?.serverId),
    );
    ref.watch(authProvider);
    final act = _act;
    if (projectId != _projectId ||
        _boundActor != _actorContext ||
        (act?.projectId != null && act!.projectId != _projectId)) {
      return const Scaffold(
        appBar: null,
        body: AppEmptyState(
          icon: Icons.apartment_outlined,
          title: 'Объект или организация изменились',
          description: 'Откройте акт из списка выбранного объекта.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Акт')),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null && act == null
              ? _ErrorPanel(message: _error!, retry: _load)
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ProCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          act!.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(act.status),
                        for (final item in _rows(act.values))
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text('${item.key}: ${item.value}'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ProCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Файлы акта',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (act.files.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text('Файлы пока не приложены.'),
                          ),
                        for (final file in act.files)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.description_outlined),
                            title: Text(file.name),
                            trailing:
                                _openingFile == file.id
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.open_in_new_outlined),
                            onTap:
                                act.canViewFiles &&
                                        _contextCurrent &&
                                        _openingFile == null
                                    ? () => _openFile(act, file)
                                    : null,
                          ),
                        if (act.files.isNotEmpty && !act.canViewFiles)
                          const Text(
                            'Просмотр файлов недоступен для текущего пользователя.',
                          ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 18),
                    child: Text(
                      'Полевая проверка сохраняет подтверждение пользователя. Она не изменяет статус акта и не заменяет юридическую подпись.',
                    ),
                  ),
                  if (act.canFieldConfirm)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: FilledButton.icon(
                        onPressed:
                            _contextCurrent && _openingFile == null
                                ? _confirm
                                : null,
                        icon: const Icon(Icons.draw_outlined),
                        label: const Text('Зафиксировать проверку'),
                      ),
                    ),
                  if (_error != null)
                    _ErrorPanel(message: _error!, retry: _load),
                ],
              ),
    );
  }

  Future<void> _confirm() async {
    if (!_contextCurrent || _act?.canFieldConfirm != true) return;
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => _FieldConfirmationSheet(
            actId: widget.id,
            isContextCurrent:
                () => _contextCurrent && _act?.canFieldConfirm == true,
          ),
    );
    if (accepted == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _openFile(ActModel act, ActFile file) async {
    if (!_contextCurrent || !act.canViewFiles || _openingFile != null) return;
    final service = ref.read(actFileServiceProvider);
    String? path;
    setState(() => _openingFile = file.id);
    try {
      path = await ref.read(actsRepositoryProvider).downloadFile(act.id, file);
      if (!_contextCurrent) return;
      final opened = await service.openLocalFile(path);
      if (!_contextCurrent) return;
      if (!opened) {
        throw const ApiException(
          'Не удалось открыть файл. Проверьте приложение для просмотра документов.',
        );
      }
      service.scheduleCleanup(path);
      path = null;
    } catch (error) {
      if (_contextCurrent) setState(() => _error = _message(error));
    } finally {
      if (path != null) await service.deleteDownloaded(path);
      if (mounted) setState(() => _openingFile = null);
    }
  }
}

class _FieldConfirmationSheet extends ConsumerStatefulWidget {
  const _FieldConfirmationSheet({
    required this.actId,
    required this.isContextCurrent,
  });
  final int actId;
  final bool Function() isContextCurrent;
  @override
  ConsumerState<_FieldConfirmationSheet> createState() =>
      _FieldConfirmationSheetState();
}

class _FieldConfirmationSheetState
    extends ConsumerState<_FieldConfirmationSheet> {
  final _padKey = GlobalKey<_SignaturePadState>();
  bool _saving = false;
  String? _error;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Полевая проверка акта',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Поставьте подпись на экране. Она будет сохранена как подтверждение проверки с указанием пользователя и времени.',
          ),
          const SizedBox(height: 12),
          SizedBox(height: 190, child: _SignaturePad(key: _padKey)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _padKey.currentState?.clear,
              child: const Text('Очистить'),
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Сохраняем…' : 'Сохранить проверку'),
          ),
        ],
      ),
    ),
  );
  Future<void> _save() async {
    if (!widget.isContextCurrent()) return;
    final image = await _padKey.currentState?.pngBase64();
    if (image == null) {
      setState(() => _error = 'Добавьте подпись в поле');
      return;
    }
    if (!mounted || !widget.isContextCurrent()) return;
    if (!await _hasNetwork()) {
      setState(() => _error = 'Для фиксации приёмки подключитесь к интернету.');
      return;
    }
    if (!mounted || !widget.isContextCurrent()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final storage = ref.read(secureStorageProvider);
    final fingerprint =
        'act:${widget.actId}:user:${ref.read(authProvider).user?.serverId ?? 0}:organization:${ref.read(authProvider).user?.currentOrganizationId ?? 0}';
    try {
      final key = await storage.getOrCreateOperationKey(
        namespace: 'act-field-confirmation',
        fingerprint: fingerprint,
      );
      if (!mounted || !widget.isContextCurrent()) return;
      await ref
          .read(actsRepositoryProvider)
          .confirmField(
            id: widget.actId,
            signatureData: image,
            idempotencyKey: key,
          );
      await storage.clearOperationKey(
        namespace: 'act-field-confirmation',
        fingerprint: fingerprint,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (e is ApiException &&
          e.statusCode != null &&
          e.statusCode! >= 400 &&
          e.statusCode! < 500) {
        await storage.clearOperationKey(
          namespace: 'act-field-confirmation',
          fingerprint: fingerprint,
        );
      }
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _message(e);
        });
      }
    }
  }
}

class _SignaturePad extends StatefulWidget {
  const _SignaturePad({super.key});
  @override
  State<_SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<_SignaturePad> {
  final List<List<Offset>> _strokes = [];
  bool get _empty => _strokes.every((stroke) => stroke.length < 2);
  void clear() => setState(_strokes.clear);
  void _start(Offset point, Size size) => setState(
    () => _strokes.add([Offset(point.dx / size.width, point.dy / size.height)]),
  );
  void _move(Offset point, Size size) {
    if (_strokes.isEmpty) return;
    setState(
      () => _strokes.last.add(
        Offset(point.dx / size.width, point.dy / size.height),
      ),
    );
  }

  Future<String?> pngBase64() async {
    if (_empty) return null;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || box.size.isEmpty) return null;
    const pixelRatio = 2.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    final size = box.size;
    canvas.drawColor(Colors.white, BlendMode.src);
    _SignaturePainter(_strokes).paint(canvas, size);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size.width * pixelRatio).round(),
      (size.height * pixelRatio).round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return data == null ? null : base64Encode(data.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return Semantics(
        label: 'Поле для подписи',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _start(d.localPosition, size),
          onPanUpdate: (d) => _move(d.localPosition, size),
          child: CustomPaint(
            foregroundPainter: _SignaturePainter(_strokes),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.strokes);
  final List<List<Offset>> strokes;
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.black
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path =
          Path()..moveTo(
            stroke.first.dx * size.width,
            stroke.first.dy * size.height,
          );
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) =>
      oldDelegate.strokes != strokes;
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        TextButton(onPressed: retry, child: const Text('Повторить')),
      ],
    ),
  );
}

List<MapEntry<String, String>> _rows(Map<String, dynamic> values) {
  const labels = {
    'date': 'Дата',
    'amount': 'Сумма',
    'contractor_name': 'Подрядчик',
    'project_name': 'Объект',
    'description': 'Описание',
    'created_at': 'Создан',
  };
  return labels.entries
      .where(
        (row) =>
            values[row.key] != null && '${values[row.key]}'.trim().isNotEmpty,
      )
      .map((row) => MapEntry(row.value, '${values[row.key]}'))
      .toList();
}

String _message(Object error) =>
    error is ApiException
        ? error.message
        : 'Не удалось выполнить операцию. Проверьте связь и повторите.';

Future<bool> _hasNetwork() async {
  try {
    final results = await Connectivity().checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  } catch (_) {
    return false;
  }
}
