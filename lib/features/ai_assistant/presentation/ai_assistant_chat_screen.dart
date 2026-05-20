import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/industrial_card.dart';
import '../data/ai_assistant_models.dart';
import '../data/ai_assistant_repository.dart';

class AiAssistantChatScreen extends ConsumerStatefulWidget {
  const AiAssistantChatScreen({
    super.key,
    this.conversationId,
    this.initialPrompt,
  });

  final int? conversationId;
  final String? initialPrompt;

  @override
  ConsumerState<AiAssistantChatScreen> createState() =>
      _AiAssistantChatScreenState();
}

class _AiAssistantChatScreenState extends ConsumerState<AiAssistantChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<AiMessageModel> _messages = const [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  int? _conversationId;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _controller.text = widget.initialPrompt ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (_conversationId != null) {
      await _loadConversation(_conversationId!);
      return;
    }

    setState(() {
      _isLoading = false;
    });

    if ((widget.initialPrompt ?? '').trim().isNotEmpty) {
      await _sendMessage(widget.initialPrompt!.trim());
    }
  }

  Future<void> _loadConversation(int id) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final details = await ref
          .read(aiAssistantRepositoryProvider)
          .fetchConversation(id);

      setState(() {
        _conversationId = details.conversation.id;
        _messages = details.messages;
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (error) {
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage([String? forcedValue]) async {
    final message = (forcedValue ?? _controller.text).trim();
    if (message.isEmpty || _isSending) {
      return;
    }

    final optimistic = AiMessageModel(
      id: DateTime.now().millisecondsSinceEpoch,
      role: 'user',
      content: message,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages = [..._messages, optimistic];
      _isSending = true;
      _error = null;
      if (forcedValue == null) {
        _controller.clear();
      }
    });

    _scrollToBottom();

    try {
      final details = await ref
          .read(aiAssistantRepositoryProvider)
          .sendMessage(message: message, conversationId: _conversationId);

      setState(() {
        _conversationId = details.conversation.id;
        _messages = details.messages;
        _isSending = false;
      });
    } catch (error) {
      setState(() {
        _messages =
            _messages.where((item) => item.id != optimistic.id).toList();
        _error = _resolveError(error);
        _isSending = false;
      });
    }

    _scrollToBottom();
  }

  String _resolveError(Object error) {
    if (error is ApiException) {
      return switch (error.statusCode) {
        403 => 'Диалог недоступен или у пользователя нет прав.',
        422 => error.message,
        429 => error.message,
        _ => error.message,
      };
    }

    return error.toString();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openReportArtifact(AiAssistantArtifact artifact) async {
    final rawUrl = artifact.trustedUrl;
    final uri = Uri.tryParse(rawUrl ?? '');

    if (uri == null) {
      _showSnackBar('Ссылка на отчет недоступна.');
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        _showSnackBar('Не удалось открыть отчет.');
      }
    } catch (_) {
      _showSnackBar('Не удалось открыть отчет.');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _conversationId == null ? 'Новый чат' : 'Диалог #$_conversationId',
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            child: Text(
              'Ассистент помогает держать рабочий контекст по проектам, срокам и управленческим решениям.',
              style: AppTypography.bodyMedium(
                context,
              ).copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Material(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppTypography.bodyMedium(
                            context,
                          ).copyWith(color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                    ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        IndustrialCard(
                          child: AppStateView(
                            icon: Icons.smart_toy_outlined,
                            title: 'Ассистент готов',
                            description:
                                'Начните диалог с вопроса по рискам, срокам, финансам или подрядчикам.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              _quickPrompts.map((prompt) {
                                return ActionChip(
                                  label: Text(prompt),
                                  onPressed: () {
                                    _controller.text = prompt;
                                    _sendMessage(prompt);
                                  },
                                );
                              }).toList(),
                        ),
                      ],
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: _messages.length + (_isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isSending && index == _messages.length) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                CircularProgressIndicator(strokeWidth: 2),
                                SizedBox(width: 12),
                                Text('Ассистент готовит ответ...'),
                              ],
                            ),
                          );
                        }

                        final message = _messages[index];
                        final isUser = message.isUser;
                        final reportArtifacts =
                            isUser
                                ? const <AiAssistantArtifact>[]
                                : message.artifacts
                                    .where((artifact) => artifact.isReport)
                                    .toList(growable: false);

                        return Align(
                          alignment:
                              isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.84,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isUser
                                      ? theme.colorScheme.primary
                                      : theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (message.content.trim().isNotEmpty)
                                  Text(
                                    message.content,
                                    style: AppTypography.bodyMedium(
                                      context,
                                    ).copyWith(
                                      color:
                                          isUser
                                              ? theme.colorScheme.onPrimary
                                              : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                if (reportArtifacts.isNotEmpty)
                                  ...reportArtifacts.map(
                                    (artifact) => Padding(
                                      padding: EdgeInsets.only(
                                        top:
                                            message.content.trim().isEmpty
                                                ? 0
                                                : 12,
                                      ),
                                      child: _ReportArtifactCard(
                                        artifact: artifact,
                                        onOpen:
                                            () => _openReportArtifact(artifact),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'Введите вопрос для ассистента',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isSending ? null : () => _sendMessage(),
                    child: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportArtifactCard extends StatelessWidget {
  const _ReportArtifactCard({required this.artifact, required this.onOpen});

  final AiAssistantArtifact artifact;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = artifact.trustedUrl;
    final rows = _artifactRows(artifact);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.description_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artifact.displayTitle,
                        style: AppTypography.bodyMedium(
                          context,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Chip(
                            label: Text(_reportTypeLabel(artifact.reportType)),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: Text(_artifactTypeLabel(artifact)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    rows
                        .map(
                          (row) => Chip(
                            label: Text('${row.label}: ${row.value}'),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: url == null ? null : onOpen,
                icon: const Icon(Icons.download_rounded),
                label: Text(url == null ? 'Файл недоступен' : 'Открыть отчет'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtifactRow {
  const _ArtifactRow(this.label, this.value);

  final String label;
  final String value;
}

List<_ArtifactRow> _artifactRows(AiAssistantArtifact artifact) {
  final rows = <_ArtifactRow>[];
  final dateFrom = _dateLabel(artifact.filters['date_from']);
  final dateTo = _dateLabel(artifact.filters['date_to']);

  if (dateFrom != null || dateTo != null) {
    rows.add(
      _ArtifactRow(
        'Период',
        [dateFrom, dateTo].whereType<String>().join(' - '),
      ),
    );
  }

  const labels = {
    'project_id': 'Проект',
    'warehouse_id': 'Склад',
    'contractor_id': 'Подрядчик',
    'user_id': 'Сотрудник',
  };

  labels.forEach((key, label) {
    final value = artifact.filters[key];
    if (value is String || value is num) {
      rows.add(_ArtifactRow(label, value.toString()));
    }
  });

  final expiresAt = _dateLabel(artifact.expiresAt);
  if (expiresAt != null) {
    rows.add(_ArtifactRow('Доступен до', expiresAt));
  }

  return rows;
}

String _reportTypeLabel(String? value) {
  return switch (value) {
    'project_profitability' => 'Рентабельность',
    'work_completion' => 'Выполнение работ',
    'material_movements' => 'Движение материалов',
    'contractor_settlements' => 'Расчеты с подрядчиками',
    'warehouse_stock' => 'Остатки склада',
    'time_tracking' => 'Трудозатраты',
    'contract_payments' => 'Платежи по договорам',
    'project_timelines' => 'График работ',
    _ => 'Готовый отчет',
  };
}

String _artifactTypeLabel(AiAssistantArtifact artifact) {
  final raw = (artifact.type ?? artifact.mimeType ?? '').toLowerCase();

  if (raw.contains('pdf')) {
    return 'PDF';
  }

  if (raw.contains('excel') ||
      raw.contains('spreadsheet') ||
      raw.contains('xls')) {
    return 'Excel';
  }

  return 'Файл';
}

String? _dateLabel(Object? value) {
  final raw = value?.toString();
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }

  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
  if (match != null) {
    return '${match.group(3)}.${match.group(2)}.${match.group(1)}';
  }

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    return null;
  }

  return '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
}

const _quickPrompts = [
  'Что сейчас в зоне риска по срокам',
  'Собери краткую управленческую сводку',
  'Какие вопросы требуют внимания сегодня',
  'Есть ли перекос по финансам',
];
