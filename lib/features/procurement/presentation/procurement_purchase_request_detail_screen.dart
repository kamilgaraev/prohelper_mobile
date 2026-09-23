import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/mesh_background.dart';
import '../../../core/widgets/pro_card.dart';
import '../data/procurement_model.dart';
import '../domain/procurement_provider.dart';

class ProcurementPurchaseRequestDetailScreen extends ConsumerStatefulWidget {
  const ProcurementPurchaseRequestDetailScreen({
    required this.requestId,
    super.key,
  });

  final int requestId;

  @override
  ConsumerState<ProcurementPurchaseRequestDetailScreen> createState() =>
      _ProcurementPurchaseRequestDetailScreenState();
}

class _ProcurementPurchaseRequestDetailScreenState
    extends ConsumerState<ProcurementPurchaseRequestDetailScreen> {
  late Future<ProcurementPurchaseRequestModel> _request;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _request = ref
        .read(procurementProvider.notifier)
        .fetchPurchaseRequest(widget.requestId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Заявка на закупку'),
        ),
        body: FutureBuilder<ProcurementPurchaseRequestModel>(
          future: _request,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AppErrorState(
                title: 'Не удалось загрузить заявку',
                description: UserMessage.fromError(snapshot.error!),
                onRetry: () => setState(_load),
              );
            }
            if (!snapshot.hasData) {
              return const AppLoadingState(message: 'Загружаем заявку');
            }
            final request = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ProCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.title, style: AppTypography.h2(context)),
                      const SizedBox(height: 6),
                      Text(
                        request.requestNumber,
                        style: AppTypography.caption(
                          context,
                        ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      _Fact(label: 'Статус', value: request.statusLabel),
                      if ((request.projectLabel ?? '').trim().isNotEmpty)
                        _Fact(label: 'Объект', value: request.projectLabel!),
                      if ((request.assignedUserLabel ?? '').trim().isNotEmpty)
                        _Fact(
                          label: 'Ответственный',
                          value: request.assignedUserLabel!,
                        ),
                      if (request.neededBy != null)
                        _Fact(label: 'Нужно к', value: request.neededBy!),
                      if (request.budgetAmount != null)
                        _Fact(
                          label: 'Бюджет',
                          value:
                              '${request.budgetAmount} ${request.budgetCurrency ?? 'RUB'}',
                        ),
                      if ((request.notes ?? '').trim().isNotEmpty)
                        _Fact(label: 'Комментарий', value: request.notes!),
                      if (request.siteRequest != null) ...[
                        const Divider(height: 24),
                        Text(
                          'Заявка с объекта',
                          style: AppTypography.bodyLarge(context),
                        ),
                        Text(
                          request.siteRequest!.title,
                          style: AppTypography.bodyMedium(context),
                        ),
                        if (request.siteRequest!.requiredDate != null)
                          Text(
                            'Требуется к ${request.siteRequest!.requiredDate}',
                            style: AppTypography.caption(context),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ProCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Состав заявки', style: AppTypography.h2(context)),
                      const SizedBox(height: 8),
                      if (request.lines.isEmpty)
                        const Text('Позиции не указаны.'),
                      ...request.lines.map(
                        (line) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.name,
                                style: AppTypography.bodyLarge(context),
                              ),
                              Text(
                                '${line.quantity} ${line.unit ?? ''}'.trim(),
                                style: AppTypography.bodyMedium(context),
                              ),
                              if ((line.specification ?? '').trim().isNotEmpty)
                                Text(
                                  line.specification!,
                                  style: AppTypography.caption(
                                    context,
                                  ).copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              if (line.neededBy != null)
                                Text(
                                  'Нужно к ${line.neededBy}',
                                  style: AppTypography.caption(
                                    context,
                                  ).copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (request.purchaseOrders.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ProCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Связанные заказы',
                          style: AppTypography.h2(context),
                        ),
                        const SizedBox(height: 8),
                        ...request.purchaseOrders.map(
                          (order) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(order.orderNumber),
                            subtitle: Text(order.status),
                            trailing: Text(
                              '${order.totalAmount} ${order.currency ?? 'RUB'}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: AppTypography.caption(context)),
          ),
          Expanded(
            child: Text(value, style: AppTypography.bodyMedium(context)),
          ),
        ],
      ),
    );
  }
}
