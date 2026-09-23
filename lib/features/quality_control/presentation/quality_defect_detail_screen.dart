import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../data/quality_defect_model.dart';
import '../domain/quality_control_provider.dart';
import 'quality_control_screen.dart';

class QualityDefectDetailScreen extends ConsumerStatefulWidget {
  const QualityDefectDetailScreen({super.key, required this.defectId});

  final int defectId;

  @override
  ConsumerState<QualityDefectDetailScreen> createState() =>
      _QualityDefectDetailScreenState();
}

class _QualityDefectDetailScreenState
    extends ConsumerState<QualityDefectDetailScreen> {
  late Future<QualityDefectModel> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = ref
        .read(qualityControlProvider.notifier)
        .fetchDefect(widget.defectId);
  }

  void _reload() {
    setState(() {
      _detailFuture = ref
          .read(qualityControlProvider.notifier)
          .fetchDefect(widget.defectId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Замечание качества')),
      body: FutureBuilder<QualityDefectModel>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(message: 'Загружаем замечание');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              title: 'Не удалось открыть замечание',
              description: UserMessage.fromError(snapshot.error!),
              onRetry: _reload,
            );
          }
          final defect = snapshot.data;
          if (defect == null) {
            return AppErrorState(
              title: 'Замечание не найдено',
              description: 'Обновите экран или проверьте доступ к записи.',
              onRetry: _reload,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [QualityDefectDetailView(defect: defect)],
          );
        },
      ),
    );
  }
}
