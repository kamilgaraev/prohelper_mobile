import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/mesh_background.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/legal_document_model.dart';
import '../domain/legal_document_provider.dart';
import '../domain/legal_document_state.dart';
import 'widgets/legal_document_detail.dart';
import 'widgets/legal_document_list.dart';

class ContractManagementScreen extends ConsumerStatefulWidget {
  const ContractManagementScreen({super.key});

  @override
  ConsumerState<ContractManagementScreen> createState() => _ContractManagementScreenState();
}

class _ContractManagementScreenState extends ConsumerState<ContractManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncAndLoad());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(legalDocumentProvider);
    final projectId = ref.watch(projectsProvider).selectedProject?.serverId;
    if (state.projectId != projectId && !state.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncAndLoad());
    }
    return MeshBackground(child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Юридические документы'), backgroundColor: Colors.transparent, actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Обновить', onPressed: projectId == null ? null : () => ref.read(legalDocumentProvider.notifier).load()),
      ]),
      body: _body(state, projectId),
    ));
  }

  Widget _body(LegalDocumentState state, int? projectId) {
    if (projectId == null) return const AppEmptyState(icon: Icons.domain_disabled_outlined, title: 'Выберите объект', description: 'Документы открываются по выбранному объекту.');
    if (state.isLoading && state.documents.isEmpty) return const AppLoadingState(message: 'Загружаем документы');
    if (state.error != null && state.documents.isEmpty) return AppErrorState(title: 'Не удалось загрузить документы', description: state.error!, onRetry: () => ref.read(legalDocumentProvider.notifier).load());
    if (state.documents.isEmpty) return const AppEmptyState(icon: Icons.folder_open_outlined, title: 'Документов пока нет', description: 'Для выбранного объекта юридические документы не найдены.');
    return RefreshIndicator(onRefresh: () => ref.read(legalDocumentProvider.notifier).load(), child: LegalDocumentList(documents: state.documents, onOpen: _open));
  }

  void _syncAndLoad() {
    final notifier = ref.read(legalDocumentProvider.notifier);
    notifier.syncProject(ref.read(projectsProvider).selectedProject?.serverId);
    notifier.load();
  }

  void _open(LegalDocumentModel document) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _LegalDocumentDetailScreen(id: document.id)));
  }
}

class _LegalDocumentDetailScreen extends ConsumerStatefulWidget {
  const _LegalDocumentDetailScreen({required this.id});
  final int id;
  @override
  ConsumerState<_LegalDocumentDetailScreen> createState() => _LegalDocumentDetailScreenState();
}

class _LegalDocumentDetailScreenState extends ConsumerState<_LegalDocumentDetailScreen> {
  late Future<LegalDocumentModel> _future;
  @override
  void initState() { super.initState(); _future = ref.read(legalDocumentProvider.notifier).detail(widget.id); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Документ')),
    body: FutureBuilder<LegalDocumentModel>(future: _future, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const AppLoadingState(message: 'Загружаем документ');
      if (!snapshot.hasData) return AppErrorState(title: 'Не удалось загрузить документ', description: 'Повторите попытку позже.', onRetry: _reload);
      return LegalDocumentDetail(document: snapshot.data!, onAction: _action);
    }),
  );
  void _reload() => setState(() => _future = ref.read(legalDocumentProvider.notifier).detail(widget.id));
  Future<void> _action(LegalDocumentAction action) async {
    final comment = await _comment(action);
    if (!mounted || comment == null) return;
    try { await ref.read(legalDocumentProvider.notifier).action(id: widget.id, action: action.action, comment: comment); _reload(); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось выполнить действие'))); }
  }
  Future<String?> _comment(LegalDocumentAction action) async {
    if (!action.requiresComment && !action.requiresReason) return '';
    final controller = TextEditingController();
    final result = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: Text(action.label), content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Комментарий')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Отправить'))]));
    controller.dispose();
    return result;
  }
}
