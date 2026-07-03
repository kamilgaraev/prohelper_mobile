import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/design/pro_design_tokens.dart';
import 'package:prohelpers_mobile/core/theme/app_typography.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';

class ProFilterOption<T> {
  const ProFilterOption({required this.value, required this.label});

  final T value;
  final String label;
}

enum ProSearchFilterDensity { comfortable, compact }

class ProSearchFilterBar<T> extends StatefulWidget {
  const ProSearchFilterBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.options,
    required this.selectedValue,
    required this.onFilterChanged,
    this.onClearSearch,
    this.resultLabel,
    this.density = ProSearchFilterDensity.comfortable,
  });

  final TextEditingController controller;
  final String hintText;
  final List<ProFilterOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onFilterChanged;
  final VoidCallback? onClearSearch;
  final String? resultLabel;
  final ProSearchFilterDensity density;

  @override
  State<ProSearchFilterBar<T>> createState() => _ProSearchFilterBarState<T>();
}

class _ProSearchFilterBarState<T> extends State<ProSearchFilterBar<T>> {
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleSearchStateChanged);
    _searchFocusNode.addListener(_handleSearchStateChanged);
  }

  @override
  void didUpdateWidget(covariant ProSearchFilterBar<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }

    oldWidget.controller.removeListener(_handleSearchStateChanged);
    widget.controller.addListener(_handleSearchStateChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleSearchStateChanged);
    _searchFocusNode
      ..removeListener(_handleSearchStateChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchStateChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _setSearchText(String value) {
    widget.controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semanticLabel = 'Поле поиска: ${widget.hintText}';
    final hasClearSearch = widget.onClearSearch != null;
    final isCompact = widget.density == ProSearchFilterDensity.compact;
    final surfacePadding =
        isCompact
            ? const EdgeInsets.all(ProSpacing.sm)
            : const EdgeInsets.all(ProSpacing.md);
    final inputContentPadding =
        isCompact
            ? const EdgeInsets.symmetric(
              horizontal: ProSpacing.md,
              vertical: ProSpacing.xs,
            )
            : const EdgeInsets.symmetric(
              horizontal: ProSpacing.md,
              vertical: ProSpacing.sm,
            );

    return ProSurface(
      tone: isCompact ? ProSurfaceTone.elevated : ProSurfaceTone.subtle,
      padding: surfacePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCompact && widget.resultLabel != null) ...[
            Text(widget.resultLabel!, style: AppTypography.caption(context)),
            const SizedBox(height: ProSpacing.xs),
          ],
          Stack(
            alignment: AlignmentDirectional.centerEnd,
            children: [
              Semantics(
                container: true,
                excludeSemantics: true,
                label: semanticLabel,
                value: widget.controller.text,
                textField: true,
                enabled: true,
                focusable: true,
                focused: _searchFocusNode.hasFocus,
                onTap: _searchFocusNode.requestFocus,
                onSetText: _setSearchText,
                child: ExcludeSemantics(
                  child: TextField(
                    focusNode: _searchFocusNode,
                    controller: widget.controller,
                    textInputAction: TextInputAction.search,
                    style: AppTypography.bodyMedium(context),
                    decoration: InputDecoration(
                      labelText: widget.hintText,
                      isDense: isCompact,
                      prefixIcon: const Icon(Icons.search_rounded),
                      prefixIconConstraints:
                          isCompact
                              ? const BoxConstraints(
                                minWidth: ProTouchTarget.comfortable,
                                minHeight: ProTouchTarget.comfortable,
                              )
                              : null,
                      suffixIcon:
                          hasClearSearch
                              ? const SizedBox(
                                width: ProTouchTarget.comfortable,
                              )
                              : null,
                      suffixIconConstraints:
                          hasClearSearch
                              ? const BoxConstraints(
                                minWidth: ProTouchTarget.comfortable,
                                minHeight: ProTouchTarget.comfortable,
                              )
                              : null,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.48),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ProRadius.sm),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: inputContentPadding,
                    ),
                  ),
                ),
              ),
              if (hasClearSearch)
                PositionedDirectional(
                  top: 0,
                  end: 0,
                  bottom: 0,
                  child: Center(
                    child: Semantics(
                      container: true,
                      button: true,
                      enabled: true,
                      label: 'Очистить поиск',
                      onTap: widget.onClearSearch,
                      child: ExcludeSemantics(
                        child: IconButton(
                          tooltip: 'Очистить поиск',
                          onPressed: widget.onClearSearch,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (widget.options.isNotEmpty) ...[
            const SizedBox(height: ProSpacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final option in widget.options) ...[
                    FilterChip(
                      selected: widget.selectedValue == option.value,
                      label: Text(option.label),
                      onSelected: (_) => widget.onFilterChanged(option.value),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: ProSpacing.xs),
                  ],
                ],
              ),
            ),
          ],
          if (!isCompact && widget.resultLabel != null) ...[
            const SizedBox(height: ProSpacing.xs),
            Text(widget.resultLabel!, style: AppTypography.caption(context)),
          ],
        ],
      ),
    );
  }
}
