import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:prohelpers_mobile/core/theme/app_colors.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/mesh_background.dart';
import 'package:prohelpers_mobile/core/widgets/pro_card.dart';
import 'package:prohelpers_mobile/core/widgets/pro_button.dart';
import 'package:prohelpers_mobile/features/projects/domain/projects_provider.dart';
import 'package:prohelpers_mobile/features/site_requests/data/site_requests_repository.dart';
import 'package:prohelpers_mobile/features/site_requests/domain/site_requests_provider.dart';

class SiteRequestFormScreen extends HookConsumerWidget {
  const SiteRequestFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleController = useTextEditingController();
    final nameController = useTextEditingController();
    final quantityController = useTextEditingController();
    final unitController = useTextEditingController(text: 'м³');
    final descriptionController = useTextEditingController();
    
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
        await ref.read(siteRequestsRepositoryProvider).createSiteRequest({
          'project_id': selectedProject.serverId,
          'title': titleController.text,
          'material_name': nameController.text,
          'material_quantity': double.tryParse(quantityController.text) ?? 0,
          'material_unit': unitController.text,
          'description': descriptionController.text,
          'status': 'draft',
          'priority': 'normal',
          'request_type': 'material',
        });
        
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

    Future<void> createFromTemplate(Map<String, dynamic> template) async {
       if (selectedProject == null) return;
       
       isLoading.value = true;
       try {
         await ref.read(siteRequestsRepositoryProvider).createFromTemplate(
           template['id'], 
           selectedProject.serverId
         );
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
          title: Text('Новая заявка', style: AppTypography.h2),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (templates.value.isNotEmpty) ...[
                Text(
                  'БЫСТРОЕ СОЗДАНИЕ ИЗ ШАБЛОНА', 
                  style: AppTypography.caption.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: templates.value.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final t = templates.value[index];
                      return ProCard(
                        onTap: () => createFromTemplate(t),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.copy_rounded, color: theme.colorScheme.primary),
                            const SizedBox(height: 4),
                            Text(
                              t['title'] ?? 'Шаблон', 
                              style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurface),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
              ],
              
              Text(
                'ОСНОВНАЯ ИНФОРМАЦИЯ', 
                style: AppTypography.caption.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              ProCard(
                child: Column(
                  children: [
                    _buildField(context, 'Заголовок (например, Бетон М400)', titleController),
                    const SizedBox(height: 16),
                    _buildField(context, 'Наименование материала', nameController),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildField(context, 'Количество', quantityController, keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildField(context, 'Ед. изм.', unitController)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'ДОПОЛНИТЕЛЬНО', 
                style: AppTypography.caption.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              ProCard(
                child: _buildField(context, 'Описание / Примечания', descriptionController, maxLines: 3),
              ),
              const SizedBox(height: 100),
            ],
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

  Widget _buildField(BuildContext context, String label, TextEditingController controller, {TextInputType? keyboardType, int maxLines = 1}) {
    final theme = Theme.of(context);
    
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: AppTypography.bodyLarge.copyWith(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.caption.copyWith(color: theme.colorScheme.onSurfaceVariant),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2))),
        focusedBorder: BorderSide.none.copyWith(
          borderSide: BorderSide(color: theme.colorScheme.primary),
        ),
        // Force the text visible even if hints are buggy
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
    );
  }
}
