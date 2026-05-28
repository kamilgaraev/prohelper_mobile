import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/widgets/app_empty_state.dart';

class ProNoProjectState extends StatelessWidget {
  const ProNoProjectState({super.key, this.action});

  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.domain_disabled_outlined,
      title: 'Объект не выбран',
      description: 'Выберите объект, чтобы открыть рабочие разделы.',
      action: action,
    );
  }
}

class ProNoAccessState extends StatelessWidget {
  const ProNoAccessState({super.key, this.action});

  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.lock_outline_rounded,
      title: 'Раздел недоступен',
      description: 'Если раздел нужен, попросите администратора выдать доступ.',
      action: action,
    );
  }
}
