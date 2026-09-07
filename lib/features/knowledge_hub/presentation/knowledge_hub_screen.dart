import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prohelpers_mobile/core/widgets/pro_page_scaffold.dart';
import 'package:prohelpers_mobile/core/widgets/pro_surface.dart';
import '../domain/knowledge_assistant_provider.dart';

class KnowledgeHubScreen extends ConsumerStatefulWidget {
  const KnowledgeHubScreen({super.key, this.contextKey});

  final String? contextKey;

  @override
  ConsumerState<KnowledgeHubScreen> createState() => _KnowledgeHubScreenState();
}

class _KnowledgeHubScreenState extends ConsumerState<KnowledgeHubScreen> {
  final _question = TextEditingController();

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant KnowledgeHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contextKey != widget.contextKey) _question.clear();
  }

  @override
  Widget build(BuildContext context) {
    final provider = knowledgeAssistantProvider(widget.contextKey);
    final state = ref.watch(provider);
    final theme = Theme.of(context);

    return ProPageScaffold(
      title: 'Помощник МОСТ',
      subtitle: 'Задайте вопрос по работе в системе',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _question,
                  enabled: !state.loading,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 1000,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Ваш вопрос',
                    hintText: 'Например, как создать заявку?',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: state.loading || _question.text.trim().isEmpty
                      ? null
                      : () async {
                          final requestContext = widget.contextKey;
                          await ref.read(provider.notifier).ask(_question.text);
                          if (mounted && widget.contextKey == requestContext && ref.read(provider).error == null) {
                            setState(_question.clear);
                          }
                        },
                  icon: const Icon(Icons.send_rounded),
                  label: Text(state.loading ? 'Готовим ответ…' : 'Спросить'),
                ),
                if (state.turns.isNotEmpty)
                  TextButton(
                    onPressed: state.loading ? null : () {
                      ref.read(provider.notifier).reset();
                      setState(_question.clear);
                    },
                    child: const Text('Новый разговор'),
                  ),
                if (state.loading) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(semanticsLabel: 'Ищем подходящие инструкции'),
                ],
                if (state.error != null) ...[
                  const SizedBox(height: 16),
                  Semantics(liveRegion: true, child: Text(state.error!, style: TextStyle(color: theme.colorScheme.error))),
                ],
                if (!state.loading && state.turns.isEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final question in ['Как создать заявку?', 'Как принять материалы?', 'Как восстановить пароль?'])
                        ActionChip(label: Text(question), onPressed: () => setState(() => _question.text = question)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          for (final turn in state.turns) ...[
            const SizedBox(height: 20),
            ProSurface(
              child: Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(turn.question, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Text(turn.result.answered ? 'Что нужно сделать' : turn.result.needsClarification ? 'Уточните, пожалуйста' : 'Ответ не найден', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    SelectableText(turn.result.answer, style: theme.textTheme.bodyLarge),
                    if (turn.result.sources.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('По материалам: ${turn.result.sources.map((source) => source.title).join(', ')}', style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
