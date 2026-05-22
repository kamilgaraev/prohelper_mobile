import 'package:flutter/material.dart';

import '../../module_companions/presentation/companion_module_screen.dart';

class VideoMonitoringScreen extends StatelessWidget {
  const VideoMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CompanionModuleScreen(
      moduleSlug: 'video-monitoring',
      title: 'Видеонаблюдение',
      icon: Icons.videocam_outlined,
    );
  }
}
