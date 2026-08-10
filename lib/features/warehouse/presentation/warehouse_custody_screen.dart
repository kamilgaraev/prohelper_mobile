import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_notice.dart';
import '../../../core/widgets/industrial_card.dart';
import '../../auth/domain/auth_provider.dart';
import '../../construction_journal/presentation/construction_journal_screen.dart';
import '../../projects/domain/projects_provider.dart';
import '../data/project_material_delivery_model.dart';
import '../data/warehouse_custody_model.dart';
import '../data/warehouse_repository.dart';
import '../domain/warehouse_provider.dart';
import 'warehouse_issue_sheet.dart';
import 'warehouse_return_sheet.dart';

class WarehouseCustodyScreen extends ConsumerStatefulWidget {
  const WarehouseCustodyScreen({super.key});

  @override
  ConsumerState<WarehouseCustodyScreen> createState() =>
      _WarehouseCustodyScreenState();
}

class _WarehouseCustodyScreenState
    extends ConsumerState<WarehouseCustodyScreen> {
  late Future<List<ProjectMaterialDeliveryModel>> _deliveriesFuture;

  @override
  void initState() {
    super.initState();
    _deliveriesFuture = _loadDeliveries();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshWarehouseState();
    });
  }

  Future<void> _refreshWarehouseState() async {
    final projectId = ref.read(projectsProvider).selectedProject?.serverId;
    final notifier = ref.read(warehouseProvider.notifier);

    await Future.wait([
      notifier.loadCustodyBalances(projectId: projectId),
      notifier.loadProjectMaterialStock(projectId: projectId),
    ]);
  }

  Future<List<ProjectMaterialDeliveryModel>> _loadDeliveries() async {
    final projectId = ref.read(projectsProvider).selectedProject?.serverId;

    return ref
        .read(warehouseRepositoryProvider)
        .fetchProjectMaterialDeliveries(projectId: projectId);
  }

  Future<void> _refresh() async {
    setState(() {
      _deliveriesFuture = _loadDeliveries();
    });
    await Future.wait([_refreshWarehouseState(), _deliveriesFuture]);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(warehouseProvider);
    final selectedProject = ref.watch(projectsProvider).selectedProject;
    final stock = state.projectMaterialStock;
    final projectStockItems =
        stock?.items
            .where((item) => item.onProjectQuantity > 0)
            .toList(growable: false) ??
        const <ProjectMaterialStockItemModel>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Ответственное хранение')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (selectedProject == null) ...[
              const _InfoBanner(
                title: 'Объект не выбран',
                text:
                    'Выберите объект, чтобы видеть его склад, выдачу ответственным и ожидающие приемки.',
              ),
              const SizedBox(height: 12),
            ],
            _SectionHeader(
              title: 'У меня на ответственности',
              subtitle:
                  'Материалы, которые уже выданы сотруднику и еще не списаны в работу.',
            ),
            const SizedBox(height: 12),
            if (state.isCustodyLoading && state.custodyBalances.isEmpty)
              const _InlineLoading(text: 'Загружаем ответственные остатки')
            else if (state.custodyBalances.isEmpty)
              const AppEmptyState(
                icon: Icons.assignment_ind_outlined,
                title: 'Материалов у ответственных нет',
                description:
                    'После выдачи с объектового склада материалы появятся здесь.',
              )
            else
              ...state.custodyBalances.map(
                (balance) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CustodyBalanceCard(
                    balance: balance,
                    onReturn: () => _showReturnSheet(balance),
                    onConsume: _openConstructionJournal,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            _SectionHeader(
              title: 'На объекте',
              subtitle:
                  'Остатки объектового склада, которые можно взять под ответственность.',
            ),
            const SizedBox(height: 12),
            if (state.isProjectMaterialStockLoading && stock == null)
              const _InlineLoading(text: 'Загружаем остатки объекта')
            else if (stock == null || projectStockItems.isEmpty)
              const AppEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Остатков на объекте нет',
                description:
                    'Примите материал на объект или измените выбранный объект.',
              )
            else
              ...projectStockItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ProjectStockCard(
                    stock: item,
                    onIssue: () => _showIssueSheet(item),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            _SectionHeader(
              title: 'Ожидает приемки',
              subtitle:
                  'Поставки, которые можно принять на объект без мобильного сканера.',
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<ProjectMaterialDeliveryModel>>(
              future: _deliveriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _InlineLoading(text: 'Загружаем поставки');
                }

                if (snapshot.hasError) {
                  return _InfoBanner(
                    title: 'Не удалось загрузить поставки',
                    text: UserMessage.fromError(snapshot.error!),
                  );
                }

                final deliveries =
                    (snapshot.data ?? const <ProjectMaterialDeliveryModel>[])
                        .where((delivery) => delivery.remainingToAccept > 0)
                        .toList();

                if (deliveries.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'Поставок к приемке нет',
                    description:
                        'Когда материал будет в пути или частично принят, он появится здесь.',
                  );
                }

                return Column(
                  children:
                      deliveries
                          .map(
                            (delivery) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _DeliveryCard(
                                delivery: delivery,
                                onReceive:
                                    delivery.canReceive
                                        ? () => _showReceiveSheet(delivery)
                                        : null,
                              ),
                            ),
                          )
                          .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showIssueSheet(ProjectMaterialStockItemModel stock) async {
    final authState = ref.read(authProvider);
    final responsibleUserId = authState.user?.serverId;

    final issued = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => WarehouseIssueSheet(
            stock: stock,
            projectWarehouseId: stock.projectWarehouseId,
            responsibleUserId: responsibleUserId,
          ),
    );

    if (issued == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Материал выдан ответственному.')),
      );
    }
  }

  Future<void> _showReturnSheet(WarehouseCustodyBalanceModel balance) async {
    final returned = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => WarehouseReturnSheet(balance: balance),
    );

    if (returned == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Материал возвращен на объект.')),
      );
    }
  }

  Future<void> _showReceiveSheet(ProjectMaterialDeliveryModel delivery) async {
    final quantityController = TextEditingController(
      text: _formatQuantity(delivery.remainingToAccept),
    );
    final notesController = TextEditingController();

    final received = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (sheetContext) => Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                Text('Принять на объект', style: AppTypography.h2(context)),
                const SizedBox(height: 8),
                Text(delivery.materialName ?? 'Материал не указан'),
                const SizedBox(height: 12),
                Text(
                  'Осталось принять: ${_formatQuantity(delivery.remainingToAccept)} ${delivery.materialUnit ?? ''}',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Количество',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Комментарий',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    final quantity = double.tryParse(
                      quantityController.text.trim().replaceAll(',', '.'),
                    );

                    if (quantity == null ||
                        quantity <= 0 ||
                        quantity > delivery.remainingToAccept) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Количество должно быть больше нуля и не больше остатка к приемке.',
                          ),
                        ),
                      );
                      return;
                    }

                    try {
                      await ref
                          .read(warehouseRepositoryProvider)
                          .receiveProjectMaterialDelivery(
                            deliveryId: delivery.id,
                            quantity: quantity,
                            notes: notesController.text,
                          );

                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop(true);
                      }
                    } catch (error) {
                      if (sheetContext.mounted) {
                        AppErrorNotice.show(sheetContext, error);
                      }
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Принять на объект'),
                ),
              ],
            ),
          ),
    );

    quantityController.dispose();
    notesController.dispose();

    if (received == true && mounted) {
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Материал принят на объект.')),
        );
      }
    }
  }

  void _openConstructionJournal() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ConstructionJournalScreen()),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.h2(context)),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTypography.bodyMedium(
            context,
          ).copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _CustodyBalanceCard extends StatelessWidget {
  const _CustodyBalanceCard({
    required this.balance,
    required this.onReturn,
    required this.onConsume,
  });

  final WarehouseCustodyBalanceModel balance;
  final VoidCallback onReturn;
  final VoidCallback onConsume;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            balance.materialName,
            style: AppTypography.bodyLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text('${balance.projectName} · ${balance.responsibleUserName}'),
          const SizedBox(height: 12),
          Text(
            '${_formatQuantity(balance.availableQuantity)} ${balance.unit ?? ''}',
            style: AppTypography.h2(context),
          ),
          const SizedBox(height: 6),
          Text('Списано в работу', style: AppTypography.caption(context)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: onConsume,
                  icon: const Icon(Icons.playlist_add_check_outlined),
                  label: const Text('Списать в работу'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReturn,
                  icon: const Icon(Icons.keyboard_return_outlined),
                  label: const Text('Вернуть на объект'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectStockCard extends StatelessWidget {
  const _ProjectStockCard({required this.stock, required this.onIssue});

  final ProjectMaterialStockItemModel stock;
  final VoidCallback onIssue;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stock.materialName ?? 'Материал не указан',
            style: AppTypography.bodyLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(stock.projectName ?? 'Объект не указан'),
          const SizedBox(height: 12),
          Text(
            '${_formatQuantity(stock.onProjectQuantity)} ${stock.materialUnit ?? ''}',
            style: AppTypography.h2(context),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onIssue,
              icon: const Icon(Icons.assignment_ind_outlined),
              label: const Text('Взять под ответственность'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.delivery, required this.onReceive});

  final ProjectMaterialDeliveryModel delivery;
  final VoidCallback? onReceive;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            delivery.materialName ?? 'Материал не указан',
            style: AppTypography.bodyLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(delivery.projectName ?? 'Объект не указан'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Отгружено',
                  value: _formatQuantity(delivery.shippedQuantity),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Осталось',
                  value: _formatQuantity(delivery.remainingToAccept),
                  alignEnd: true,
                ),
              ),
            ],
          ),
          if (onReceive != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onReceive,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Принять на объект'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption(context)),
        const SizedBox(height: 4),
        Text(value, style: AppTypography.bodyLarge(context)),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      backgroundColor: AppColors.warning.withValues(alpha: 0.08),
      borderColor: AppColors.warning.withValues(alpha: 0.24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.bodyLarge(context)),
          const SizedBox(height: 6),
          Text(text),
        ],
      ),
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return IndustrialCard(
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

String _formatQuantity(double value) {
  return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
}
