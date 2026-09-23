import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/services/permission_service.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/field_catalog_repository.dart';
import '../data/team_expansion_repository.dart';
import 'field_catalog_screen.dart';

class ContractorMarketplaceScreen extends StatelessWidget {
  const ContractorMarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) => FieldCatalogScreen(
    title: 'Подрядчики',
    catalog: 'team-expansion-contractors',
    apiPrefix: '/team-expansion/contractors',
    queryParameter: 'search',
    icon: Icons.engineering_outlined,
    detailActionBuilder:
        (context, entry, projectId) =>
            _ContractorInvitationAction(profile: entry),
  );
}

class _ContractorInvitationAction extends ConsumerWidget {
  const _ContractorInvitationAction({required this.profile});

  final FieldCatalogEntry profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionServiceProvider);
    if (!permissions.hasPermission('contractor_marketplace.offers.create')) {
      return const SizedBox.shrink();
    }
    final project = ref.watch(
      projectsProvider.select((state) => state.selectedProject),
    );
    final categories = _categories(profile.fields['categories']);
    if (project == null) {
      return const ListTile(
        leading: Icon(Icons.info_outline_rounded),
        title: Text('Выберите объект, чтобы отправить предложение'),
      );
    }
    return FilledButton.icon(
      onPressed:
          categories.isEmpty
              ? null
              : () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder:
                      (_) => ContractorOfferFormScreen(
                        profile: profile,
                        categories: categories,
                        projectId: project.serverId,
                        projectName: project.name,
                      ),
                ),
              ),
      icon: const Icon(Icons.mail_outline_rounded),
      label: const Text('Отправить предложение'),
    );
  }
}

class ContractorOfferFormScreen extends ConsumerStatefulWidget {
  const ContractorOfferFormScreen({
    super.key,
    required this.profile,
    required this.categories,
    required this.projectId,
    required this.projectName,
  });

  final FieldCatalogEntry profile;
  final List<ContractorCategoryOption> categories;
  final int projectId;
  final String projectName;

  @override
  ConsumerState<ContractorOfferFormScreen> createState() =>
      _ContractorOfferFormScreenState();
}

class _ContractorOfferFormScreenState
    extends ConsumerState<ContractorOfferFormScreen> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  late int _categoryId;
  String _role = 'contractor';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.categories.first.id;
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowed = ref
        .watch(permissionServiceProvider)
        .hasPermission('contractor_marketplace.offers.create');
    return Scaffold(
      appBar: AppBar(title: const Text('Предложение подрядчику')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!allowed)
            const ListTile(
              leading: Icon(Icons.lock_outline_rounded),
              title: Text('У вас нет права отправлять предложения.'),
            )
          else ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.apartment_outlined),
                title: Text(widget.projectName),
                subtitle: Text(widget.profile.title),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Специализация'),
              items: [
                for (final category in widget.categories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  ),
              ],
              onChanged:
                  _saving
                      ? null
                      : (value) {
                        if (value != null) setState(() => _categoryId = value);
                      },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Роль на объекте'),
              items: const [
                DropdownMenuItem(value: 'contractor', child: Text('Подрядчик')),
                DropdownMenuItem(
                  value: 'subcontractor',
                  child: Text('Субподрядчик'),
                ),
                DropdownMenuItem(
                  value: 'designer',
                  child: Text('Проектировщик'),
                ),
                DropdownMenuItem(
                  value: 'construction_supervision',
                  child: Text('Строительный контроль'),
                ),
                DropdownMenuItem(value: 'observer', child: Text('Наблюдатель')),
              ],
              onChanged:
                  _saving
                      ? null
                      : (value) {
                        if (value != null) setState(() => _role = value);
                      },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Название работ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Сообщение подрядчику',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon:
                  _saving
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.send_rounded),
              label: Text(_saving ? 'Отправляем' : 'Отправить предложение'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!ref
        .read(permissionServiceProvider)
        .hasPermission('contractor_marketplace.offers.create')) {
      return;
    }
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Укажите название работ.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(teamExpansionRepositoryProvider)
          .create(
            path: '/team-expansion/contractor-invitations',
            payload: {
              'project_id': widget.projectId,
              'contractor_profile_id': int.tryParse(widget.profile.uuid),
              'role': _role,
              'title': title,
              if (_message.text.trim().isNotEmpty)
                'message': _message.text.trim(),
              'work_packages': [
                {'category_id': _categoryId, 'title': title},
              ],
            },
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = UserMessage.fromError(error);
      });
    }
  }
}

class ContractorCategoryOption {
  const ContractorCategoryOption({required this.id, required this.name});

  final int id;
  final String name;
}

List<ContractorCategoryOption> _categories(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) {
        final map = item.map((key, value) => MapEntry(key.toString(), value));
        final category =
            map['category'] is Map
                ? (map['category'] as Map).map(
                  (key, value) => MapEntry(key.toString(), value),
                )
                : const <String, dynamic>{};
        return ContractorCategoryOption(
          id:
              int.tryParse(
                (map['category_id'] ?? category['id'] ?? '').toString(),
              ) ??
              0,
          name: (category['name'] ?? 'Специализация').toString(),
        );
      })
      .where((category) => category.id > 0)
      .toList(growable: false);
}
