import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/mesh_background.dart';
import 'package:prohelpers_mobile/core/widgets/pro_button.dart';
import 'package:prohelpers_mobile/core/widgets/pro_card.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_meta_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_provider.dart';

class SiteRequestFormScreen extends HookConsumerWidget {
  const SiteRequestFormScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final metaAsync = ref.watch(siteRequestsMetaProvider);

    final titleController = useTextEditingController();
    final descriptionController = useTextEditingController();
    final materialNameController = useTextEditingController();
    final quantityController = useTextEditingController();
    final selectedUnit = useState<String?>(null);
    final personnelCountController = useTextEditingController(text: '1');
    final selectedPersonnelType = useState<String?>(null);
    final workStartDate = useState<DateTime?>(null);
    final workEndDate = useState<DateTime?>(null);
    final selectedEquipmentType = useState<String?>(null);
    final rentalStartDate = useState<DateTime?>(null);
    final rentalEndDate = useState<DateTime?>(null);

    final requestType = useState<String>('material_request');
    final selectedProject = ref.watch(projectsProvider).selectedProject;
    final isLoading = useState(false);

    Future<void> submit() async {
      final validationError = _validateForm(
        selectedProjectId: selectedProject?.serverId,
        title: titleController.text,
        requestType: requestType.value,
        materialName: materialNameController.text,
        quantity: quantityController.text,
        unit: selectedUnit.value,
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
        final data = <String, dynamic>{
          'project_id': selectedProject!.serverId,
          'title': titleController.text.trim(),
          'description': _optionalText(descriptionController.text),
          'request_type': requestType.value,
          'priority': 'medium',
        };

        if (requestType.value == 'material_request') {
          data.addAll({
            'material_name': materialNameController.text.trim(),
            'material_quantity': double.parse(quantityController.text.trim()),
            'material_unit': selectedUnit.value,
          });
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

        await ref.read(siteRequestsRepositoryProvider).createSiteRequest(data);
        await ref.read(siteRequestsProvider.notifier).loadRequests(refresh: true);

        if (context.mounted) {
          Navigator.pop(context);
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
          title: Text('Новая заявка', style: AppTypography.h2(context)),
          leading: IconButton(
            icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: metaAsync.when(
          data: (meta) {
            final units = (meta['units'] as List<dynamic>? ?? const []);

            if (selectedUnit.value == null && units.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                selectedUnit.value = units.first['short_name'].toString();
              });
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTypeSelector(
                    context,
                    requestType,
                    meta['request_types'] as List<dynamic>,
                  ),
                  const SizedBox(height: 24),
                  Text('ОСНОВНАЯ ИНФОРМАЦИЯ', style: AppTypography.caption(context)),
                  const SizedBox(height: 12),
                  ProCard(
                    child: Column(
                      children: [
                        _buildField(context, 'Заголовок заявки', titleController),
                        const SizedBox(height: 16),
                        _buildField(
                          context,
                          'Описание / примечания',
                          descriptionController,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (requestType.value == 'material_request')
                    _buildMaterialFields(
                      context,
                      materialNameController,
                      quantityController,
                      selectedUnit,
                      units,
                    ),
                  if (requestType.value == 'personnel_request')
                    _buildPersonnelFields(
                      context,
                      personnelCountController,
                      selectedPersonnelType,
                      workStartDate,
                      workEndDate,
                      meta['personnel_types'] as List<dynamic>,
                    ),
                  if (requestType.value == 'equipment_request')
                    _buildEquipmentFields(
                      context,
                      selectedEquipmentType,
                      rentalStartDate,
                      rentalEndDate,
                      meta['equipment_types'] as List<dynamic>,
                    ),
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text('Ошибка загрузки данных: $error'),
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: ProButton(
            text: 'СОЗДАТЬ ЗАЯВКУ',
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
    required String materialName,
    required String quantity,
    required String? unit,
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
      final parsedQuantity = double.tryParse(quantity.trim());

      if (materialName.trim().isEmpty) {
        return 'Укажите материал.';
      }

      if (parsedQuantity == null || parsedQuantity <= 0) {
        return 'Количество материала должно быть больше нуля.';
      }

      if (unit == null || unit.isEmpty) {
        return 'Выберите единицу измерения.';
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
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ТИП ЗАЯВКИ', style: AppTypography.caption(context)),
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
                onSelected: (selected) {
                  if (selected) {
                    currentType.value = type['value'].toString();
                  }
                },
                selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
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

  Widget _buildMaterialFields(
    BuildContext context,
    TextEditingController nameController,
    TextEditingController quantityController,
    ValueNotifier<String?> unit,
    List<dynamic> units,
  ) {
    final unitOptions = units
        .map((item) => item['short_name']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ДЕТАЛИ МАТЕРИАЛА', style: AppTypography.caption(context)),
        const SizedBox(height: 12),
        ProCard(
          child: Column(
            children: [
              _buildField(context, 'Наименование материала', nameController),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      context,
                      'Количество',
                      quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: unit.value,
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
                      onChanged: (value) => unit.value = value,
                      decoration: InputDecoration(
                        labelText: 'Ед. изм.',
                        labelStyle: AppTypography.caption(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
        Text('ДЕТАЛИ ПЕРСОНАЛА', style: AppTypography.caption(context)),
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
        Text('ДЕТАЛИ ТЕХНИКИ', style: AppTypography.caption(context)),
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
          borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.primary),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
    );
  }
}
