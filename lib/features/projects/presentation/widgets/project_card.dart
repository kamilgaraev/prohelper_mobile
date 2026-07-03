import 'package:flutter/material.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/industrial_card.dart';
import '../../data/project_model.dart';

class ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;
  final bool isSelected;

  const ProjectCard({
    super.key,
    required this.project,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = project.myRole?.trim();
    final address = project.address?.trim();

    return Semantics(
      container: true,
      button: true,
      enabled: true,
      selected: isSelected,
      label: _semanticLabel(project, address: address, role: role),
      onTap: onTap,
      child: ExcludeSemantics(
        child: IndustrialCard(
          onTap: onTap,
          padding: const EdgeInsets.all(16),
          backgroundColor:
              isSelected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.1)
                  : theme.cardTheme.color,
          border:
              isSelected
                  ? Border.all(color: theme.colorScheme.primary, width: 2)
                  : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? theme.colorScheme.primary.withValues(alpha: 0.1)
                              : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.apartment_rounded,
                      color:
                          isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      project.name,
                      style: AppTypography.h2(
                        context,
                      ).copyWith(fontSize: 16, height: 1.18),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.check_circle_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
              if (address != null && address.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address,
                        style: AppTypography.bodySmall(
                          context,
                        ).copyWith(height: 1.28),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (role != null && role.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: AppTypography.mono.copyWith(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
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

  String _semanticLabel(Project project, {String? address, String? role}) {
    final parts = <String>[
      isSelected ? 'Выбранный объект' : 'Выбрать объект',
      project.name,
      if (address != null && address.isNotEmpty) 'Адрес: $address',
      if (role != null && role.isNotEmpty) 'Роль: $role',
    ];

    return parts.join('. ');
  }
}
