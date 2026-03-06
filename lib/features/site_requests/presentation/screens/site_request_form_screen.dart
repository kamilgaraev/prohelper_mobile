import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/mesh_background.dart';
import 'package:prohelpers_mobile/core/widgets/pro_card.dart';
import 'package:prohelpers_mobile/core/widgets/pro_button.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_meta_provider.dart';

class SiteRequestFormScreen extends HookConsumerWidget {
  const SiteRequestFormScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final metaAsync = ref.watch(siteRequestsMetaProvider);
    
    // Form Controllers
    final titleController = useTextEditingController();
    final descriptionController = useTextEditingController();
    
    // Material Fields
    final materialNameController = useTextEditingController();
    final quantityController = useTextEditingController();
    final selectedUnit = useState<String?>(null);
    
    // Personnel Fields
    final personnelCountController = useTextEditingController(text: '1');
    final selectedPersonnelType = useState<String?>(null);
    final workStartDate = useState<DateTime?>(null);
    final workEndDate = useState<DateTime?>(null);
    
    // Equipment Fields
    final selectedEquipmentType = useState<String?>(null);
    final rentalStartDate = useState<DateTime?>(null);
    final rentalEndDate = useState<DateTime?>(null);

    // Common State
    final requestType = useState<String>('material_request');
    final selectedProject = ref.watch(projectsProvider).selectedProject;
    final isLoading = useState(false);
    final templates = useState<List<Map<String, dynamic>>>([]);

    useEffect(() {
      ref.read(siteRequestsRepositoryProvider).fetchTemplates().then((value) {
        templates.value = value;
      });
      return null;
    }, []);

    Future<void> submit() async {
      if (selectedProject == null) return;
      
      isLoading.value = true;
      try {
        final Map<String, dynamic> data = {
          'project_id': selectedProject.serverId,
          'title': titleController.text,
          'description': descriptionController.text,
          'request_type': requestType.value,
          'status': 'draft',
          'priority': 'medium',
        };

        if (requestType.value == 'material_request') {
          data.addAll({
            'material_name': materialNameController.text,
            'material_quantity': double.tryParse(quantityController.text) ?? 0,
            'material_unit': selectedUnit.value,
          });
        } else if (requestType.value == 'personnel_request') {
          data.addAll({
            'personnel_type': selectedPersonnelType.value,
            'personnel_count': int.tryParse(personnelCountController.text) ?? 1,
            'work_start_date': workStartDate.value != null ? DateFormat('yyyy-MM-dd').format(workStartDate.value!) : null,
            'work_end_date': workEndDate.value != null ? DateFormat('yyyy-MM-dd').format(workEndDate.value!) : null,
          });
        } else if (requestType.value == 'equipment_request') {
          data.addAll({
            'equipment_type': selectedEquipmentType.value,
            'rental_start_date': rentalStartDate.value != null ? DateFormat('yyyy-MM-dd').format(rentalStartDate.value!) : null,
            'rental_end_date': rentalEndDate.value != null ? DateFormat('yyyy-MM-dd').format(rentalEndDate.value!) : null,
          });
        }

        await ref.read(siteRequestsRepositoryProvider).createSiteRequest(data);
        
        ref.read(siteRequestsProvider.notifier).loadRequests(refresh: true);
        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
            // Назначаем юнит по умолчанию, если он еще не выбран
            if (selectedUnit.value == null && (meta['units'] as List).isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                selectedUnit.value = meta['units'][0]['short_name'].toString();
              });
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTypeSelector(context, requestType, meta['request_types']),
                const SizedBox(height: 24),
                
                Text('ОСНОВНАЯ ИНФОРМАЦИЯ', style: AppTypography.caption(context)),
                const SizedBox(height: 12),
                ProCard(
                  child: Column(
                    children: [
                      _buildField(context, 'Заголовок заявки', titleController),
                      const SizedBox(height: 16),
                      _buildField(context, 'Описание / Примечания', descriptionController, maxLines: 2),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (requestType.value == 'material_request') 
                  _buildMaterialFields(context, materialNameController, quantityController, selectedUnit, meta['units']),
                
                if (requestType.value == 'personnel_request')
                  _buildPersonnelFields(context, personnelCountController, selectedPersonnelType, workStartDate, workEndDate, meta['personnel_types']),

                if (requestType.value == 'equipment_request')
                  _buildEquipmentFields(context, selectedEquipmentType, rentalStartDate, rentalEndDate, meta['equipment_types']),

                const SizedBox(height: 100),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Ошибка загрузки данных: $e')),
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

  Widget _buildTypeSelector(BuildContext context, ValueNotifier<String> currentType, List<dynamic> types) {
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
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final type = types[index];
              final isSelected = currentType.value == type['value'];
              return ChoiceChip(
                label: Text(type['label']),
                selected: isSelected,
                onSelected: (val) {
                  if (val) currentType.value = type['value'];
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

  Widget _buildMaterialFields(BuildContext context, TextEditingController name, TextEditingController qty, ValueNotifier<String?> unit, List<dynamic> units) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ДЕТАЛИ МАТЕРИАЛА', style: AppTypography.caption(context)),
        const SizedBox(height: 12),
        ProCard(
          child: Column(
            children: [
              _buildField(context, 'Наименование материала', name),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildField(context, 'Количество', qty, keyboardType: TextInputType.number)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: unit.value,
                      items: units.map((u) => u['short_name'].toString()).toSet().map((shortName) => DropdownMenuItem(
                        value: shortName,
                        child: Text(shortName, style: AppTypography.bodyMedium(context)),
                      )).toList(),
                      onChanged: (val) => unit.value = val,
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

  Widget _buildPersonnelFields(BuildContext context, TextEditingController count, ValueNotifier<String?> type, ValueNotifier<DateTime?> start, ValueNotifier<DateTime?> end, List<dynamic> types) {
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
                items: types.map((t) => DropdownMenuItem(
                  value: t['value'].toString(),
                  child: Text(t['label'], style: AppTypography.bodyMedium(context)),
                )).toList(),
                onChanged: (val) => type.value = val,
                decoration: InputDecoration(
                  labelText: 'Специальность',
                  labelStyle: AppTypography.caption(context),
                ),
              ),
              const SizedBox(height: 16),
              _buildField(context, 'Количество человек', count, keyboardType: TextInputType.number),
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

  Widget _buildEquipmentFields(BuildContext context, ValueNotifier<String?> type, ValueNotifier<DateTime?> start, ValueNotifier<DateTime?> end, List<dynamic> types) {
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
                items: types.map((t) => DropdownMenuItem(
                  value: t['value'].toString(),
                  child: Text(t['label'], style: AppTypography.bodyMedium(context)),
                )).toList(),
                onChanged: (val) => type.value = val,
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

  Widget _buildDatePicker(BuildContext context, String label, ValueNotifier<DateTime?> date) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date.value ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) date.value = picked;
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTypography.caption(context),
        ),
        child: Text(
          date.value != null ? DateFormat('dd.MM.yyyy').format(date.value!) : 'Выберите дату',
          style: AppTypography.bodyLarge(context),
        ),
      ),
    );
  }

  Widget _buildField(BuildContext context, String label, TextEditingController controller, {TextInputType? keyboardType, int maxLines = 1}) {
    final theme = Theme.of(context);
    
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: AppTypography.bodyLarge(context),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.caption(context),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2))),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.primary),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
    );
  }
}
