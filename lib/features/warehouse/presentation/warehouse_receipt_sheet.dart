import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/industrial_card.dart';
import '../data/warehouse_media_picker.dart';
import '../data/warehouse_repository.dart';
import '../data/warehouse_summary_model.dart';

class WarehouseReceiptSheet extends ConsumerStatefulWidget {
  const WarehouseReceiptSheet({
    super.key,
    required this.summary,
    this.initialWarehouseId,
    this.initialMaterial,
  });

  final WarehouseSummaryModel summary;
  final int? initialWarehouseId;
  final WarehouseMaterialOption? initialMaterial;

  @override
  ConsumerState<WarehouseReceiptSheet> createState() =>
      _WarehouseReceiptSheetState();
}

class _WarehouseReceiptSheetState extends ConsumerState<WarehouseReceiptSheet> {
  static const int _maxPhotos = 4;

  late final TextEditingController _materialController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late final TextEditingController _documentController;
  late final TextEditingController _reasonController;

  Timer? _searchDebounce;
  int? _selectedWarehouseId;
  WarehouseMaterialOption? _selectedMaterial;
  List<WarehouseMaterialOption> _suggestions =
      const <WarehouseMaterialOption>[];
  List<String> _photoPaths = const <String>[];
  bool _isSearching = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _materialController = TextEditingController();
    _quantityController = TextEditingController(text: '1');
    _priceController = TextEditingController();
    _documentController = TextEditingController();
    _reasonController = TextEditingController();
    _selectedWarehouseId =
        widget.initialWarehouseId ??
        (widget.summary.warehouses.isNotEmpty
            ? widget.summary.warehouses.first.id
            : null);
    _selectedMaterial = widget.initialMaterial;

    if (widget.initialMaterial != null) {
      _materialController.text = widget.initialMaterial!.name;
      if (widget.initialMaterial!.defaultPrice > 0) {
        _priceController.text = widget.initialMaterial!.defaultPrice.toString();
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _materialController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _documentController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return FractionallySizedBox(
      heightFactor: 0.95,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
        child: ListView(
          children: [
            Text('Оприходование', style: AppTypography.h2(context)),
            const SizedBox(height: 8),
            Text(
              'Выбери склад, материал и приложи до 4 фотографий.',
              style: AppTypography.bodyMedium(
                context,
              ).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _selectedWarehouseId,
              decoration: const InputDecoration(
                labelText: 'Склад',
                border: OutlineInputBorder(),
              ),
              items:
                  widget.summary.warehouses
                      .map(
                        (warehouse) => DropdownMenuItem<int>(
                          value: warehouse.id,
                          child: Text(warehouse.name),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedWarehouseId = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _materialController,
              decoration: InputDecoration(
                labelText: 'Материал',
                hintText: 'Начни вводить название или код',
                border: const OutlineInputBorder(),
                suffixIcon:
                    _isSearching
                        ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                        : IconButton(
                          onPressed:
                              () => _searchMaterials(_materialController.text),
                          icon: const Icon(Icons.search),
                        ),
              ),
              onChanged: (value) {
                _selectedMaterial = null;
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                  _searchMaterials(value);
                });
                setState(() {});
              },
            ),
            if (_selectedMaterial != null) ...[
              const SizedBox(height: 8),
              IndustrialCard(
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedMaterial!.name,
                            style: AppTypography.bodyLarge(
                              context,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if ((_selectedMaterial!.code ?? '').isNotEmpty)
                                _selectedMaterial!.code!,
                              if (_selectedMaterial!
                                  .measurementLabel
                                  .isNotEmpty)
                                _selectedMaterial!.measurementLabel,
                            ].join(' • '),
                            style: AppTypography.caption(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._suggestions.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedMaterial = item;
                        _materialController.text = item.name;
                        if (item.defaultPrice > 0) {
                          _priceController.text = item.defaultPrice.toString();
                        }
                        _suggestions = const <WarehouseMaterialOption>[];
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.35,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: AppTypography.bodyMedium(
                                context,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                if ((item.code ?? '').isNotEmpty) item.code!,
                                if (item.measurementLabel.isNotEmpty)
                                  item.measurementLabel,
                                if (item.defaultPrice > 0)
                                  'Цена: ${_formatNumber(item.defaultPrice)} ₽',
                              ].join(' • '),
                              style: AppTypography.caption(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Количество',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Цена',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _documentController,
              decoration: const InputDecoration(
                labelText: 'Документ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Основание',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Фотографии',
              style: AppTypography.bodyLarge(
                context,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _photoPaths.isEmpty
                  ? 'Можно прикрепить до 4 фото.'
                  : 'Выбрано ${_photoPaths.length} из $_maxPhotos.',
              style: AppTypography.bodyMedium(
                context,
              ).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _pickFromCamera,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Камера'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _pickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Галерея'),
                  ),
                ),
              ],
            ),
            if (_photoPaths.isNotEmpty) ...[
              const SizedBox(height: 12),
              ..._photoPaths.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: IndustrialCard(
                    child: Row(
                      children: [
                        const Icon(Icons.image_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _fileName(entry.value),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium(context),
                          ),
                        ),
                        IconButton(
                          onPressed:
                              _isSubmitting
                                  ? null
                                  : () => setState(() {
                                    _photoPaths = List<String>.from(_photoPaths)
                                      ..removeAt(entry.key);
                                  }),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon:
                  _isSubmitting
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.check_circle_outline),
              label: Text(_isSubmitting ? 'Сохраняем...' : 'Провести приход'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _searchMaterials(String value) async {
    final query = value.trim();
    if (query.length < 2) {
      if (mounted) {
        setState(() {
          _suggestions = const <WarehouseMaterialOption>[];
          _isSearching = false;
        });
      }
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final suggestions = await ref
          .read(warehouseRepositoryProvider)
          .searchMaterials(query);

      if (!mounted) {
        return;
      }

      setState(() {
        _suggestions = suggestions;
        _isSearching = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _suggestions = const <WarehouseMaterialOption>[];
        _isSearching = false;
      });
      _showMessage(error.toString());
    }
  }

  Future<void> _pickFromCamera() async {
    if (_photoPaths.length >= _maxPhotos) {
      _showMessage('Можно прикрепить не больше 4 фотографий.');
      return;
    }

    final picked =
        await ref.read(warehouseMediaPickerProvider).pickFromCamera();
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _photoPaths = List<String>.from(_photoPaths)..add(picked);
    });
  }

  Future<void> _pickFromGallery() async {
    final remain = _maxPhotos - _photoPaths.length;
    if (remain <= 0) {
      _showMessage('Можно прикрепить не больше 4 фотографий.');
      return;
    }

    final picked = await ref
        .read(warehouseMediaPickerProvider)
        .pickFromGallery(limit: remain);
    if (picked.isEmpty || !mounted) {
      return;
    }

    setState(() {
      _photoPaths = List<String>.from(_photoPaths)..addAll(picked.take(remain));
    });
  }

  Future<void> _submit() async {
    final warehouseId = _selectedWarehouseId;
    final material = _selectedMaterial;
    final quantity = double.tryParse(
      _quantityController.text.replaceAll(',', '.'),
    );
    final price = double.tryParse(_priceController.text.replaceAll(',', '.'));

    if (warehouseId == null) {
      _showMessage('Выбери склад.');
      return;
    }
    if (material == null) {
      _showMessage('Выбери материал из списка.');
      return;
    }
    if (quantity == null || quantity <= 0) {
      _showMessage('Укажи корректное количество.');
      return;
    }
    if (price == null || price < 0) {
      _showMessage('Укажи корректную цену.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref.read(warehouseRepositoryProvider).createReceipt(
        WarehouseReceiptPayload(
          warehouseId: warehouseId,
          materialId: material.id,
          quantity: quantity,
          price: price,
          documentNumber: _documentController.text.trim(),
          reason: _reasonController.text.trim(),
          photos: _photoPaths,
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _fileName(String path) {
    final segments = path.replaceAll('\\', '/').split('/');
    return segments.isEmpty ? path : segments.last;
  }

  String _formatNumber(double value) {
    return value.toStringAsFixed(
      value.truncateToDouble() == value ? 0 : 2,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.replaceFirst('ApiException: ', ''))),
    );
  }
}
