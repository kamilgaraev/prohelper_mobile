import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/error/user_message.dart';
import '../../../core/design/pro_status.dart';
import '../../../core/storage/snapshot_read.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/pro_status_banner.dart';
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
  late Future<SnapshotRead<QualityDefectModel>> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = ref
        .read(qualityControlProvider.notifier)
        .loadDefectSnapshot(widget.defectId);
  }

  void _reload() {
    setState(() {
      _detailFuture = ref
          .read(qualityControlProvider.notifier)
          .loadDefectSnapshot(widget.defectId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Замечание качества')),
      body: FutureBuilder<SnapshotRead<QualityDefectModel>>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(message: 'Загружаем замечание');
          }
          final read = snapshot.data;
          if (snapshot.hasError ||
              read == null ||
              read.presence == SnapshotPresence.permissionDenied ||
              read.data == null) {
            return AppErrorState(
              title: 'Не удалось открыть замечание',
              description:
                  snapshot.error == null
                      ? read?.error
                      : UserMessage.fromError(snapshot.error!),
              onRetry: _reload,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (read.fromCache || read.hasDirtyLocal)
                ProStatusBanner(
                  title:
                      read.hasDirtyLocal
                          ? 'Есть локальные изменения'
                          : 'Показаны сохранённые данные',
                  description:
                      read.error ??
                      'Актуальность данных не подтверждена сетью.',
                  tone:
                      read.hasDirtyLocal
                          ? ProStatusTone.warning
                          : ProStatusTone.info,
                  fullText: true,
                ),
              if (read.fromCache || read.hasDirtyLocal)
                const SizedBox(height: 12),
              QualityDefectDetailView(defect: read.data!),
            ],
          );
        },
      ),
    );
  }
}
