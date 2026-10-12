import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/error/user_message.dart';
import '../../auth/domain/auth_provider.dart';
import '../data/project_hierarchy_repository.dart';
import '../domain/projects_provider.dart';

class ProjectHierarchyScreen extends ConsumerStatefulWidget {
  const ProjectHierarchyScreen({super.key, required this.projectId});
  final int projectId;
  @override
  ConsumerState<ProjectHierarchyScreen> createState() =>
      _ProjectHierarchyScreenState();
}

class _ProjectHierarchyScreenState
    extends ConsumerState<ProjectHierarchyScreen> {
  final _form = GlobalKey<FormState>();
  final _parents = <int, int>{};
  ProjectHierarchy? _hierarchy;
  int? _rootId;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  late final Object _actor;
  Object get _currentActor {
    final auth = ref.read(authProvider);
    return (
      user: auth.user?.serverId,
      org: auth.user?.currentOrganizationId,
      session: auth is AuthAuthenticated ? auth.sessionIdentity : null,
    );
  }

  bool get _contextCurrent =>
      _actor == _currentActor &&
      ref.read(projectsProvider).selectedProject?.serverId == widget.projectId;
  @override
  void initState() {
    super.initState();
    _actor = _currentActor;
    _load();
  }

  void _apply(ProjectHierarchy data) {
    _hierarchy = data;
    _rootId = data.rootId;
    _parents.clear();
    for (final row in data.participants) {
      if (row.parentId != null) _parents[row.id] = row.parentId!;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(projectHierarchyRepositoryProvider)
          .load(widget.projectId);
      if (mounted && _contextCurrent) setState(() => _apply(data));
    } catch (error) {
      if (mounted) setState(() => _error = UserMessage.fromError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || !_contextCurrent || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(projectHierarchyRepositoryProvider)
          .save(widget.projectId, _rootId!, _parents);
      if (mounted && _contextCurrent) {
        setState(() => _apply(data));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Иерархия проекта сохранена.')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = UserMessage.fromError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authProvider);
    ref.watch(projectsProvider);
    final data = _hierarchy;
    final editable = data?.canManage == true && !_saving && _contextCurrent;
    return Scaffold(
      appBar: AppBar(title: const Text('Иерархия организаций')),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_contextCurrent)
                        const Text(
                          'Объект или организация изменились. Откройте настройки заново.',
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (data == null)
                        TextButton(
                          onPressed: _contextCurrent ? _load : null,
                          child: const Text('Повторить'),
                        )
                      else ...[
                        Text(
                          data.configured
                              ? 'Иерархия настроена. Записи видны вышестоящим компаниям, согласование выполняет непосредственный родитель.'
                              : 'Выберите корневую компанию и вышестоящую для каждого участника. До сохранения связей отправка записей недоступна.',
                        ),
                        if (!data.canManage)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Настройку меняет сотрудник с правом управления организациями проекта.',
                            ),
                          ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          key: ValueKey('root-$_rootId'),
                          initialValue: _rootId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Корневая компания',
                            border: OutlineInputBorder(),
                          ),
                          items:
                              data.participants
                                  .map(
                                    (row) => DropdownMenuItem(
                                      value: row.id,
                                      child: Text(
                                        row.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              editable
                                  ? (id) => setState(() {
                                    _rootId = id;
                                    _parents.remove(id);
                                  })
                                  : null,
                          validator:
                              (value) =>
                                  value == null
                                      ? 'Выберите корневую компанию — верхнего участника проекта.'
                                      : null,
                        ),
                        for (final row in data.participants.where(
                          (row) => row.id != _rootId,
                        ))
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: DropdownButtonFormField<int>(
                              key: ValueKey(
                                'parent-${row.id}-${_parents[row.id]}',
                              ),
                              initialValue: _parents[row.id],
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Вышестоящая для «${row.name}»',
                                border: const OutlineInputBorder(),
                              ),
                              items:
                                  data.participants
                                      .where((parent) => parent.id != row.id)
                                      .map(
                                        (parent) => DropdownMenuItem(
                                          value: parent.id,
                                          child: Text(
                                            parent.name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged:
                                  editable
                                      ? (id) => setState(() {
                                        if (id != null) _parents[row.id] = id;
                                      })
                                      : null,
                              validator:
                                  (value) =>
                                      value == null
                                          ? 'Выберите вышестоящую компанию.'
                                          : null,
                            ),
                          ),
                        if (data.canManage)
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: FilledButton(
                              onPressed: editable ? _save : null,
                              child: Text(
                                _saving ? 'Сохраняем…' : 'Сохранить иерархию',
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
    );
  }
}
