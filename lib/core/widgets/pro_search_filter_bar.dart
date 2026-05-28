import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';

class ProFilterOption<T> {
  const ProFilterOption({required this.value, required this.label});

  final T value;
  final String label;
}

class ProSearchFilterBar<T> extends StatelessWidget {
  const ProSearchFilterBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.options,
    required this.selectedValue,
    required this.onFilterChanged,
    this.onClearSearch,
    this.resultLabel,
  });

  final TextEditingController controller;
  final String hintText;
  final List<ProFilterOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onFilterChanged;
  final VoidCallback? onClearSearch;
  final String? resultLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ProSurface(
      tone: ProSurfaceTone.subtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon:
                  onClearSearch == null
                      ? null
                      : IconButton(
                        tooltip: 'Очистить поиск',
                        onPressed: onClearSearch,
                        icon: const Icon(Icons.close_rounded),
                      ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.48,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ProRadius.sm),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: ProSpacing.md,
                vertical: ProSpacing.sm,
              ),
            ),
          ),
          if (options.isNotEmpty) ...[
            const SizedBox(height: ProSpacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final option in options) ...[
                    FilterChip(
                      selected: selectedValue == option.value,
                      label: Text(option.label),
                      onSelected: (_) => onFilterChanged(option.value),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: ProSpacing.xs),
                  ],
                ],
              ),
            ),
          ],
          if (resultLabel != null) ...[
            const SizedBox(height: ProSpacing.xs),
            Text(resultLabel!, style: AppTypography.caption(context)),
          ],
        ],
      ),
    );
  }
}
