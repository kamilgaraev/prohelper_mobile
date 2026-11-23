import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/industrial_card.dart';
import '../data/ai_assistant_models.dart';
import '../data/ai_assistant_presentation.dart';

class AiAssistantPresentationView extends StatelessWidget {
  const AiAssistantPresentationView({
    super.key,
    required this.presentation,
    required this.sources,
    required this.evidence,
    required this.canOpenArticle,
    required this.onOpenArticle,
    required this.canOpenDocument,
    required this.onOpenDocument,
  });

  final AiAssistantPresentation presentation;
  final Map<int, AiAssistantPublishedSource> sources;
  final List<AiAssistantEvidenceModel> evidence;
  final bool canOpenArticle;
  final ValueChanged<AiAssistantKnowledgeSource> onOpenArticle;
  final bool canOpenDocument;
  final ValueChanged<int> onOpenDocument;

  @override
  Widget build(BuildContext context) {
    final numbers = <Object, int>{};
    final sourceNumbers = <int, int>{};
    final sourceItems = <(int, AiAssistantPublishedSource)>[];
    for (final MapEntry(key: index, value: source) in sources.entries) {
      sourceNumbers[index] = numbers.putIfAbsent(source.key, () {
        sourceItems.add((index, source));
        return sourceItems.length;
      });
    }
    final sourceLabels = sourceItems.map((entry) => entry.$2.label).toSet();
    final extraTitles =
        evidence
            .map((item) => item.title)
            .where((title) => !sourceLabels.contains(title))
            .toSet();
    final style = AppTypography.caption(
      context,
    ).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

    Iterable<int> refs(List<int> indices, [List<int> fallback = const []]) =>
        (indices.isEmpty ? fallback : indices)
            .map((index) => sourceNumbers[index])
            .whereType<int>()
            .toSet();

    Widget sourceMarker(Iterable<int> refs) =>
        Text('[${refs.join(', ')}]', style: style);

    Widget field(AiAssistantField field, [List<int> fallback = const []]) {
      final fieldRefs = refs(field.sourceRefs, fallback);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.label, style: style),
            Text(field.value),
            if (fieldRefs.isNotEmpty) sourceMarker(fieldRefs),
          ],
        ),
      );
    }

    Widget table(AiAssistantTableBlock block) {
      final hasDetails = block.rows.any((row) => row.details != null);
      final hasRefs = block.rows.any(
        (row) => refs(row.sourceRefs, block.sourceRefs).isNotEmpty,
      );
      Widget cell(String text) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: Text(text),
      );
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          horizontalMargin: 0,
          columnSpacing: 18,
          dataRowMaxHeight: double.infinity,
          columns: [
            for (final column in block.columns) DataColumn(label: cell(column)),
            if (hasDetails) const DataColumn(label: Text('Примечание')),
            if (hasRefs) const DataColumn(label: Text('№ источника')),
          ],
          rows: [
            for (final row in block.rows)
              DataRow(
                cells: [
                  for (final value in row.cells) DataCell(cell(value)),
                  if (hasDetails) DataCell(cell(row.details ?? '')),
                  if (hasRefs)
                    DataCell(
                      refs(row.sourceRefs, block.sourceRefs).isEmpty
                          ? const SizedBox.shrink()
                          : sourceMarker(
                            refs(row.sourceRefs, block.sourceRefs),
                          ),
                    ),
                ],
              ),
          ],
        ),
      );
    }

    Widget visual(AiAssistantVisualBlock block) => switch (block) {
      AiAssistantFactsBlock() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in block.fields) field(item, block.sourceRefs),
        ],
      ),
      AiAssistantListBlock() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, item) in block.items.indexed) ...[
            if (index > 0) const Divider(),
            Text(item.title, style: Theme.of(context).textTheme.titleSmall),
            if (item.status case final status?) Text(status, style: style),
            if (item.details case final details?) Text(details),
            if (refs(item.sourceRefs, block.sourceRefs).isNotEmpty)
              sourceMarker(refs(item.sourceRefs, block.sourceRefs)),
            for (final itemField in item.fields) field(itemField),
          ],
        ],
      ),
      AiAssistantTableBlock() => table(block),
    };

    Widget source(int index, AiAssistantPublishedSource source) {
      final label = '[${sourceNumbers[index]}] ${source.label}';
      final article = source.article;
      final readAt = source.fetchedAt;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (article != null && canOpenArticle)
            TextButton.icon(
              onPressed: () => onOpenArticle(article),
              icon: const Icon(Icons.menu_book_outlined, size: 16),
              label: Text(label),
            )
          else if (source.documentPreview && canOpenDocument)
            TextButton.icon(
              onPressed: () => onOpenDocument(index),
              icon: const Icon(Icons.description_outlined, size: 16),
              label: Text(label),
            )
          else
            Text(label, style: style),
          if (readAt != null)
            Text(
              MaterialLocalizations.of(context).formatCompactDate(readAt),
              style: style,
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in presentation.blocks)
          Padding(
            key: ValueKey(block.id),
            padding: const EdgeInsets.only(top: 10),
            child: IndustrialCard(
              padding: const EdgeInsets.all(12),
              child: visual(block),
            ),
          ),
        if (sourceItems.isNotEmpty || extraTitles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Источники', style: style),
                for (final (index, item) in sourceItems) source(index, item),
                for (final title in extraTitles) Text(title, style: style),
              ],
            ),
          ),
      ],
    );
  }
}
