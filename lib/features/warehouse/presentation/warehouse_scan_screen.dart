import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/industrial_card.dart';
import '../data/warehouse_repository.dart';
import '../data/warehouse_scan_model.dart';
import '../data/warehouse_summary_model.dart';
import 'warehouse_camera_scanner_screen.dart';
import 'warehouse_scan_result_screen.dart';
import 'warehouse_tasks_screen.dart';

class WarehouseScanScreen extends ConsumerStatefulWidget {
  const WarehouseScanScreen({
    super.key,
    required this.summary,
    this.initialWarehouseId,
  });

  final WarehouseSummaryModel summary;
  final int? initialWarehouseId;

  @override
  ConsumerState<WarehouseScanScreen> createState() =>
      _WarehouseScanScreenState();
}

class _WarehouseScanScreenState extends ConsumerState<WarehouseScanScreen> {
  late final TextEditingController _codeController;
  int? _selectedWarehouseId;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    _selectedWarehouseId =
        widget.initialWarehouseId ??
        (widget.summary.warehouses.isNotEmpty
            ? widget.summary.warehouses.first.id
            : null);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warehouses = widget.summary.warehouses;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Сканирование')),
      body:
          warehouses.isEmpty
              ? const AppStateView(
                icon: Icons.warehouse_outlined,
                title: 'Нет активных складов',
                description:
                    'Скан-flow станет доступен, когда в организации появится хотя бы один склад.',
              )
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  IndustrialCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Контекст сканирования',
                          style: AppTypography.bodyLarge(
                            context,
                          ).copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _selectedWarehouseId,
                          items:
                              warehouses.map((warehouse) {
                                return DropdownMenuItem<int>(
                                  value: warehouse.id,
                                  child: Text(warehouse.name),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedWarehouseId = value;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Склад',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(
                              alpha: 0.7,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Что можно сканировать',
                                style: AppTypography.bodyLarge(
                                  context,
                                ).copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              const Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _ScanExampleChip(
                                    icon: Icons.precision_manufacturing_outlined,
                                    label: 'Актив: AST-15-000123',
                                  ),
                                  _ScanExampleChip(
                                    icon: Icons.grid_view_rounded,
                                    label: 'Ячейка: CELL-A-01-03',
                                  ),
                                  _ScanExampleChip(
                                    icon: Icons.inventory_2_outlined,
                                    label: 'Логединица: LU-000245',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withValues(
                              alpha: 0.45,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.qr_code_scanner_rounded,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Можно работать двумя способами',
                                      style: AppTypography.bodyLarge(
                                        context,
                                      ).copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '1. Сканировать код камерой телефона.\n2. Ввести код вручную или принять его с внешнего сканера-клавиатуры.',
                                      style: AppTypography.bodyMedium(context),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed:
                                _isResolving ? null : _openCameraScanner,
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Сканировать камерой'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _codeController,
                          autofocus: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _resolveCurrentCode(),
                          decoration: InputDecoration(
                            labelText: 'Код для ручного ввода',
                            hintText: 'Например, AST-15-000123',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed:
                                  _isResolving ? null : _resolveCurrentCode,
                              icon: const Icon(Icons.search_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Поддерживаются QR-коды и распространенные складские штрихкоды. После распознавания откроется результат сканирования и доступные действия.',
                          style: AppTypography.bodyMedium(
                            context,
                          ).copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                _isResolving ? null : _resolveCurrentCode,
                            icon:
                                _isResolving
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.qr_code_2_outlined),
                            label: Text(
                              _isResolving
                                  ? 'Распознаем...'
                                  : 'Распознать введенный код',
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (_) => WarehouseTasksScreen(
                                          summary: widget.summary,
                                          initialWarehouseId:
                                              _selectedWarehouseId,
                                        ),
                                  ),
                                ),
                            icon: const Icon(Icons.task_alt_outlined),
                            label: const Text('Открыть очередь задач'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  Future<void> _openCameraScanner() async {
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const WarehouseCameraScannerScreen(),
      ),
    );

    if (!mounted || scannedCode == null || scannedCode.trim().isEmpty) {
      return;
    }

    _codeController.text = scannedCode;
    await _resolveCode(scannedCode);
  }

  Future<void> _resolveCurrentCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      _showMessage(
        'Сначала введите код в поле или отсканируйте его камерой.',
      );
      return;
    }

    await _resolveCode(code);
  }

  Future<void> _resolveCode(String code) async {
    setState(() {
      _isResolving = true;
    });

    try {
      final result = await ref.read(warehouseRepositoryProvider).resolveScan(
        WarehouseScanPayload(
          code: code,
          warehouseId: _selectedWarehouseId,
          scanContext: 'warehouse_scan_flow',
        ),
      );

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => WarehouseScanResultScreen(
                initialResult: result,
                summary: widget.summary,
                initialWarehouseId: _selectedWarehouseId,
              ),
        ),
      );
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(content: Text(message.replaceFirst('ApiException: ', ''))),
    );
  }
}

class _ScanExampleChip extends StatelessWidget {
  const _ScanExampleChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(label, style: AppTypography.caption(context)),
        ],
      ),
    );
  }
}
