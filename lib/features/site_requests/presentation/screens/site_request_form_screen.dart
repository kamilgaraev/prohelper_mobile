import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:prohelpers_mobile/core/theme/app_colors.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/app_state_view.dart';
import 'package:prohelpers_mobile/core/widgets/mesh_background.dart';
import 'package:prohelpers_mobile/core/widgets/pro_button.dart';
import 'package:prohelpers_mobile/core/widgets/pro_card.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_request_model.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_meta_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_provider.dart';

class SiteRequestFormScreen extends HookConsumerWidget {
  const SiteRequestFormScreen({
    super.key,
    this.initialRequest,
  });

  final SiteRequestModel? initialRequest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final metaAsync = ref.watch(siteRequestsMetaProvider);
    final isEditing = initialRequest != null;
    final isMaterialGroupEditing = initialRequest != null &&
        initialRequest!.requestType == 'material_request' &&
        initialRequest!.siteRequestGroupId != null &&
        initialRequest!.groupRequestCount > 1;
    final allowMultipleMaterials = !isEditing || isMaterialGroupEditing;

    final titleController =
        useTextEditingController(text: initialRequest?.title ?? '');
    final descriptionController =
        useTextEditingController(text: initialRequest?.description ?? '');
    final personnelCountController = useTextEditingController(
      text: initialRequest?.personnelCount?.toString() ?? '1',
    );
    final selectedPersonnelType = useState<String?>(initialRequest?.personnelType);
    final workStartDate = useState<DateTime?>(_tryParseDate(initialRequest?.workStartDate));
    final workEndDate = useState<DateTime?>(_tryParseDate(initialRequest?.workEndDate));
    final selectedEquipmentType = useState<String?>(initialRequest?.equipmentType);
    final rentalStartDate = useState<DateTime?>(_tryParseDate(initialRequest?.rentalStartDate));
    final rentalEndDate = useState<DateTime?>(_tryParseDate(initialRequest?.rentalEndDate));
    final selectedPriority = useState<String>(initialRequest?.priority ?? 'medium');
    final requestType = useState<String>(initialRequest?.requestType ?? 'material_request');
    final materialItems = useState<List<_MaterialRequestItemDraft>>(
      _buildInitialMaterialItems(initialRequest),
    );
    final screenTitle = isEditing ? 'Редактирование заявки' : 'Новая заявка';
    final submitButtonLabel = isEditing
        ? (isMaterialGroupEditing ? 'Сохранить группу' : 'Сохранить изменения')
        : 'Создать заявку';

    final selectedProject = ref.watch(projectsProvider).selectedProject;
    final isLoading = useState(false);

    Future<void> submit() async {
      final validationError = _validateForm(
        selectedProjectId: selectedProject?.serverId,
        title: titleController.text,
        requestType: requestType.value,
        materialItems: materialItems.value,
        allowMultipleMaterials: allowMultipleMaterials,
        personnelType: selectedPersonnelType.value,
        personnelCount: personnelCountController.text,
        equipmentType: selectedEquipmentType.value,
        rentalStartDate: rentalStartDate.value,
      );

      if (validationError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validationError)),
        );
        return;
      }

      isLoading.value = true;

      try {
        var createdPositions = 1;
        var successMessage = isEditing ? 'Заявка обновлена.' : 'Заявка создана.';
        final data = <String, dynamic>{
          'project_id': selectedProject!.serverId,
          'title': titleController.text.trim(),
          'description': _optionalText(descriptionController.text),
          'request_type': requestType.value,
          'priority': selectedPriority.value,
        };

        if (requestType.value == 'material_request') {
          final payloadItems = materialItems.value
              .map(
                (item) => {
                  if (item.requestId != null) 'id': item.requestId,
                  'name': item.nameController.text.trim(),
                  'quantity': double.parse(item.quantityController.text.trim()),
                  'unit': item.unit,
                  if (item.noteController.text.trim().isNotEmpty)
                    'note': item.noteController.text.trim(),
                },
              )
              .toList(growable: false);
          createdPositions = payloadItems.length;

          if (payloadItems.length == 1) {
            data.addAll({
              'material_name': payloadItems.first['name'],
              'material_quantity': payloadItems.first['quantity'],
              'material_unit': payloadItems.first['unit'],
              if (payloadItems.first['note'] != null) 'notes': payloadItems.first['note'],
            });
          } else {
            data['materials'] = payloadItems;
          }
        } else if (requestType.value == 'personnel_request') {
          data.addAll({
            'personnel_type': selectedPersonnelType.value,
            'personnel_count': int.parse(personnelCountController.text.trim()),
            'work_start_date': _formatDate(workStartDate.value),
            'work_end_date': _formatDate(workEndDate.value),
          });
        } else if (requestType.value == 'equipment_request') {
          data.addAll({
            'equipment_type': selectedEquipmentType.value,
            'rental_start_date': _formatDate(rentalStartDate.value),
            'rental_end_date': _formatDate(rentalEndDate.value),
          });
        }

        data.removeWhere((_, value) => value == null);

        if (isEditing) {
          if (requestType.value == 'material_request' && isMaterialGroupEditing) {
            data['materials'] = materialItems.value
                .map(
                  (item) => {
                    if (item.requestId != null) 'id': item.requestId,
                    'name': item.nameController.text.trim(),
                    'quantity': double.parse(item.quantityController.text.trim()),
                    'unit': item.unit,
                    if (item.noteController.text.trim().isNotEmpty)
                      'note': item.noteController.text.trim(),
                  },
                )
                .toList(growable: false);
            data.remove('material_name');
            data.remove('material_quantity');
            data.remove('material_unit');
            data.remove('notes');

            await ref
                .read(siteRequestsRepositoryProvider)
                .updateSiteRequestGroup(initialRequest!.siteRequestGroupId!, data);
            successMessage = 'Группа материалов обновлена.';
          } else {
            await ref
                .read(siteRequestsRepositoryProvider)
                .updateSiteRequest(initialRequest!.serverId, data);
          }
        } else {
          await ref.read(siteRequestsRepositoryProvider).createSiteRequest(data);
        }
        await ref.read(siteRequestsProvider.notifier).loadRequests(refresh: true);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                !isEditing && requestType.value == 'material_request' && createdPositions > 1
                    ? 'Создано $createdPositions позиций материалов в одной группе заявок.'
                    : successMessage,
              ),
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(screenTitle, style: AppTypography.h2(context)),
          leading: IconButton(
            icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: selectedProject == null
            ? const AppStateView(
                icon: Icons.apartment_outlined,
                title: 'Объект не выбран',
                description:
                    'Сначала выберите объект, а затем создавайте заявку.',
              )
            : metaAsync.when(
                data: (meta) {
                  final units = (meta['units'] as List<dynamic>? ?? const []);
                  final requestTypes =
                      (meta['request_types'] as List<dynamic>? ?? const []);
                  final personnelTypes =
                      (meta['personnel_types'] as List<dynamic>? ?? const []);
                  final equipmentTypes =
                      (meta['equipment_types'] as List<dynamic>? ?? const []);

                  if (materialItems.value.any((item) => item.unit == null) &&
                      units.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final defaultUnit = units.first['short_name']?.toString();
                      if (defaultUnit == null || defaultUnit.isEmpty) {
                        return;
                      }

                      for (final item in materialItems.value) {
                        item.unit ??= defaultUnit;
                      }
                    });
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ProjectContextCard(projectName: selectedProject.name),
                        const SizedBox(height: 16),
                        _RequestFlowBanner(
                          requestType: requestType.value,
                          priority: selectedPriority.value,
                          isEditing: isEditing,
                        ),
                        const SizedBox(height: 16),
                        _buildTypeSelector(
                          context,
                          requestType,
                          requestTypes,
                          enabled: !isEditing,
                        ),
                        if (isEditing) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Тип заявки зафиксирован. Для другой категории создайте новую заявку.',
                            style: AppTypography.bodySmall(context).copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildPrioritySelector(context, selectedPriority),
                        const SizedBox(height: 24),
                        Text(
                          'Основная информация',
                          style: AppTypography.caption(context),
                        ),
                        const SizedBox(height: 12),
                        ProCard(
                          child: Column(
                            children: [
                              _buildField(
                                context,
                                'Заголовок заявки',
                                titleController,
                              ),
                              const SizedBox(height: 16),
                              _buildField(
                                context,
                                'Описание или комментарий',
                                descriptionController,
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (requestType.value == 'material_request')
                          _buildMaterialFields(
                            context,
                            materialItems,
                            units,
                            allowMultipleMaterials,
                            isEditing: isEditing,
                            isGroupEditing: isMaterialGroupEditing,
                          ),
                        if (requestType.value == 'personnel_request')
                          _buildPersonnelFields(
                            context,
                            personnelCountController,
                            selectedPersonnelType,
                            workStartDate,
                            workEndDate,
                            personnelTypes,
                          ),
                        if (requestType.value == 'equipment_request')
                          _buildEquipmentFields(
                            context,
                            selectedEquipmentType,
                            rentalStartDate,
                            rentalEndDate,
                            equipmentTypes,
                          ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => AppStateView(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось загрузить справочники',
                  description: error.toString(),
                ),
              ),
        bottomNavigationBar: selectedProject == null
            ? null
            : Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: ProButton(
                  text: submitButtonLabel,
                  isLoading: isLoading.value,
                  onPressed: submit,
                ),
              ),
      ),
    );
  }

  String? _validateForm({
    required int? selectedProjectId,
    required String title,
    required String requestType,
    required List<_MaterialRequestItemDraft> materialItems,
    required bool allowMultipleMaterials,
    required String? personnelType,
    required String personnelCount,
    required String? equipmentType,
    required DateTime? rentalStartDate,
  }) {
    if (selectedProjectId == null) {
      return 'Сначала выберите объект.';
    }

    if (title.trim().isEmpty) {
      return 'Укажите заголовок заявки.';
    }

    if (requestType == 'material_request') {
      if (!allowMultipleMaterials && materialItems.length > 1) {
        return 'Для этой заявки можно редактировать только текущую позицию материала.';
      }

      for (var index = 0; index < materialItems.length; index += 1) {
        final item = materialItems[index];
        final parsedQuantity = double.tryParse(item.quantityController.text.trim());

        if (item.nameController.text.trim().isEmpty) {
          return 'Укажите материал в позиции ${index + 1}.';
        }

        if (parsedQuantity == null || parsedQuantity <= 0) {
          return 'Количество материала в позиции ${index + 1} должно быть больше нуля.';
        }

        if ((item.unit ?? '').trim().isEmpty) {
          return 'Выберите единицу измерения в позиции ${index + 1}.';
        }
      }
    }

    if (requestType == 'personnel_request') {
      final parsedPersonnelCount = int.tryParse(personnelCount.trim());

      if (personnelType == null || personnelType.isEmpty) {
        return 'Выберите специальность.';
      }

      if (parsedPersonnelCount == null || parsedPersonnelCount <= 0) {
        return 'Количество персонала должно быть больше нуля.';
      }
    }

    if (requestType == 'equipment_request') {
      if (equipmentType == null || equipmentType.isEmpty) {
        return 'Выберите тип техники.';
      }

      if (rentalStartDate == null) {
        return 'Укажите дату начала аренды.';
      }
    }

    return null;
  }

  String? _optionalText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _formatDate(DateTime? value) {
    if (value == null) {
      return null;
    }

    return DateFormat('yyyy-MM-dd').format(value);
  }

  Widget _buildTypeSelector(
    BuildContext context,
    ValueNotifier<String> currentType,
    List<dynamic> types,
    {required bool enabled}
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Тип заявки', style: AppTypography.caption(context)),
        const SizedBox(height: 12),
        SizedBox(
          height: 45,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: types.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final type = types[index] as Map<String, dynamic>;
              final isSelected = currentType.value == type['value'];

              return ChoiceChip(
                label: Text(type['label'].toString()),
                selected: isSelected,
                onSelected: !enabled
                    ? null
                    : (selected) {
                  if (selected) {
                    currentType.value = type['value'].toString();
                  }
                },
                selectedColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.2),
                labelStyle: AppTypography.bodySmall(context).copyWith(
                  color: isSelected ? Theme.of(context).colorScheme.primary : null,
                  fontWeight: isSelected ? FontWeight.bold : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPrioritySelector(
    BuildContext context,
    ValueNotifier<String> currentPriority,
  ) {
    const priorities = [
      ('low', 'Низкий'),
      ('medium', 'Средний'),
      ('high', 'Высокий'),
      ('urgent', 'Срочно'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Приоритет', style: AppTypography.caption(context)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: priorities.map((entry) {
            final isSelected = currentPriority.value == entry.$1;
            final color = _priorityColor(entry.$1);

            return ChoiceChip(
              label: Text(entry.$2),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  currentPriority.value = entry.$1;
                }
              },
              selectedColor: color.withOpacity(0.18),
              labelStyle: AppTypography.bodySmall(context).copyWith(
                color: isSelected ? color : null,
                fontWeight: isSelected ? FontWeight.w700 : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMaterialFields(
    BuildContext context,
    ValueNotifier<List<_MaterialRequestItemDraft>> itemsState,
    List<dynamic> units,
    bool allowMultiple,
    {required bool isEditing, required bool isGroupEditing}
  ) {
    final unitOptions = units
        .map((item) => item['short_name']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Детали материала', style: AppTypography.caption(context)),
        const SizedBox(height: 12),
        ...itemsState.value.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          return Padding(
            padding: EdgeInsets.only(bottom: index == itemsState.value.length - 1 ? 0 : 12),
            child: _MaterialItemCard(
              index: index,
              item: item,
              unitOptions: unitOptions,
              canRemove: itemsState.value.length > 1,
              onRemove: () {
                item.dispose();
                itemsState.value = [
                  ...itemsState.value.where((current) => current != item),
                ];
              },
            ),
          );
        }),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: !allowMultiple
              ? null
              : () {
                  itemsState.value = [
                    ...itemsState.value,
                    _MaterialRequestItemDraft(
                      unit: unitOptions.isNotEmpty ? unitOptions.first : null,
                    ),
                  ];
                },
          icon: const Icon(Icons.add_rounded),
          label: const Text('+ Добавить материал'),
        ),
        const SizedBox(height: 8),
        Text(
          isGroupEditing
              ? 'Изменения применятся ко всей группе материалов сразу.'
              : isEditing
                  ? 'В этом режиме редактируется только текущая позиция материала.'
                  : 'Каждая позиция создастся как отдельная заявка в одной общей группе.',
          style: AppTypography.bodySmall(context).copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPersonnelFields(
    BuildContext context,
    TextEditingController countController,
    ValueNotifier<String?> type,
    ValueNotifier<DateTime?> start,
    ValueNotifier<DateTime?> end,
    List<dynamic> types,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Детали персонала', style: AppTypography.caption(context)),
        const SizedBox(height: 12),
        ProCard(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: type.value,
                items: types
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item['value'].toString(),
                        child: Text(
                          item['label'].toString(),
                          style: AppTypography.bodyMedium(context),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => type.value = value,
                decoration: InputDecoration(
                  labelText: 'Специальность',
                  labelStyle: AppTypography.caption(context),
                ),
              ),
              const SizedBox(height: 16),
              _buildField(
                context,
                'Количество человек',
                countController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildDatePicker(context, 'Дата начала', start),
              const SizedBox(height: 16),
              _buildDatePicker(context, 'Дата окончания', end),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEquipmentFields(
    BuildContext context,
    ValueNotifier<String?> type,
    ValueNotifier<DateTime?> start,
    ValueNotifier<DateTime?> end,
    List<dynamic> types,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Детали техники', style: AppTypography.caption(context)),
        const SizedBox(height: 12),
        ProCard(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: type.value,
                items: types
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item['value'].toString(),
                        child: Text(
                          item['label'].toString(),
                          style: AppTypography.bodyMedium(context),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => type.value = value,
                decoration: InputDecoration(
                  labelText: 'Тип техники',
                  labelStyle: AppTypography.caption(context),
                ),
              ),
              const SizedBox(height: 16),
              _buildDatePicker(context, 'Дата начала аренды', start),
              const SizedBox(height: 16),
              _buildDatePicker(context, 'Дата окончания аренды', end),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(
    BuildContext context,
    String label,
    ValueNotifier<DateTime?> date,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date.value ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );

        if (picked != null) {
          date.value = picked;
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTypography.caption(context),
        ),
        child: Text(
          date.value != null
              ? DateFormat('dd.MM.yyyy').format(date.value!)
              : 'Выберите дату',
          style: AppTypography.bodyLarge(context),
        ),
      ),
    );
  }

  Widget _buildField(
    BuildContext context,
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: AppTypography.bodyLarge(context),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.caption(context),
        enabledBorder: UnderlineInputBorder(
          borderSide:
              BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.primary),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
    );
  }
}

class _MaterialItemCard extends StatelessWidget {
  const _MaterialItemCard({
    required this.index,
    required this.item,
    required this.unitOptions,
    required this.canRemove,
    required this.onRemove,
  });

  final int index;
  final _MaterialRequestItemDraft item;
  final List<String> unitOptions;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return ProCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Материал ${index + 1}',
                      style: AppTypography.bodyLarge(context).copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (canRemove)
                    IconButton(
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _FormField(
                label: 'Наименование материала',
                controller: item.nameController,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _FormField(
                      label: 'Количество',
                      controller: item.quantityController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: item.unit,
                      items: unitOptions
                          .map(
                            (shortName) => DropdownMenuItem<String>(
                              value: shortName,
                              child: Text(
                                shortName,
                                style: AppTypography.bodyMedium(context),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => item.unit = value),
                      decoration: InputDecoration(
                        labelText: 'Ед. изм.',
                        labelStyle: AppTypography.caption(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _FormField(
                label: 'Комментарий к позиции',
                controller: item.noteController,
                maxLines: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: AppTypography.bodyLarge(context),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.caption(context),
        enabledBorder: UnderlineInputBorder(
          borderSide:
              BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.primary),
        ),
      ),
    );
  }
}

class _ProjectContextCard extends StatelessWidget {
  const _ProjectContextCard({required this.projectName});

  final String projectName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ProCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.apartment_outlined,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Текущий объект',
                  style: AppTypography.caption(context),
                ),
                const SizedBox(height: 4),
                Text(
                  projectName,
                  style: AppTypography.bodyLarge(context).copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestFlowBanner extends StatelessWidget {
  const _RequestFlowBanner({
    required this.requestType,
    required this.priority,
    required this.isEditing,
  });

  final String requestType;
  final String priority;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _priorityColor(priority);

    return ProCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.edit_note_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _bannerTitle(requestType, priority),
                  style: AppTypography.bodyLarge(context).copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _bannerDescription(requestType),
                  style: AppTypography.bodyMedium(context).copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _bannerTitle(String requestType, String priority) {
    final requestLabel = switch (requestType) {
      'material_request' => 'заявка на материалы',
      'personnel_request' => 'заявка на персонал',
      'equipment_request' => 'заявка на технику',
      _ => 'заявка',
    };

    final priorityLabel = switch (priority) {
      'urgent' => 'срочную',
      'high' => 'приоритетную',
      'low' => 'плановую',
      _ => 'рабочую',
    };

    return isEditing
        ? 'Вы редактируете $priorityLabel $requestLabel'
        : 'Вы создаёте $priorityLabel $requestLabel';
  }

  String _bannerDescription(String requestType) {
    return switch (requestType) {
      'material_request' =>
        'Укажите материал, объем и единицу измерения, чтобы заявку можно было быстро обработать.',
      'personnel_request' =>
        'Опишите нужную специализацию, количество и желаемые сроки выхода.',
      'equipment_request' =>
        'Выберите тип техники и период, когда она нужна на объекте.',
      _ => 'Заполните основные параметры заявки и отправьте её в работу.',
    };
  }
}

Color _priorityColor(String priority) {
  return switch (priority.trim().toLowerCase()) {
    'high' || 'urgent' => AppColors.error,
    'medium' => AppColors.warning,
    'normal' => AppColors.textSecondary,
    'low' => AppColors.success,
    _ => AppColors.textSecondary,
  };
}

class _MaterialRequestItemDraft {
  _MaterialRequestItemDraft({
    this.requestId,
    String? name,
    String? quantity,
    String? note,
    this.unit,
  })  : nameController = TextEditingController(text: name ?? ''),
        quantityController = TextEditingController(text: quantity ?? ''),
        noteController = TextEditingController(text: note ?? '');

  final int? requestId;
  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController noteController;
  String? unit;

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    noteController.dispose();
  }
}

List<_MaterialRequestItemDraft> _buildInitialMaterialItems(SiteRequestModel? request) {
  if (request == null || request.requestType != 'material_request') {
    return [_MaterialRequestItemDraft()];
  }

  if (request.groupItems.isNotEmpty) {
    return request.groupItems
        .map(
          (item) => _MaterialRequestItemDraft(
            requestId: item.id,
            name: item.materialName ?? item.title,
            quantity: item.materialQuantity?.toString(),
            note: item.notes,
            unit: item.materialUnit,
          ),
        )
        .toList(growable: false);
  }

  return [
    _MaterialRequestItemDraft(
      requestId: request.serverId,
      name: request.materialName,
      quantity: request.materialQuantity?.toString(),
      note: request.notes,
      unit: request.materialUnit,
    ),
  ];
}

DateTime? _tryParseDate(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(value);
}
