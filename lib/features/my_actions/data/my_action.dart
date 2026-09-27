class MyAction {
  const MyAction({
    required this.id,
    required this.type,
    required this.route,
    required this.title,
    required this.status,
    required this.projectId,
    this.projectName,
    this.dueAt,
    this.allowedActions = const [],
  });

  final int id;
  final String type;
  final String route;
  final String title;
  final String status;
  final int projectId;
  final String? projectName;
  final DateTime? dueAt;
  final List<String> allowedActions;

  String get statusLabel => myActionStatusLabel(status);

  factory MyAction.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawProjectId = json['project_id'];
    return MyAction(
      id: rawId is num ? rawId.toInt() : int.parse(rawId.toString()),
      type: json['type']?.toString() ?? '',
      route: json['route']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      projectId:
          rawProjectId is num
              ? rawProjectId.toInt()
              : int.parse(rawProjectId.toString()),
      projectName: json['project_name']?.toString(),
      dueAt: DateTime.tryParse(json['due_at']?.toString() ?? ''),
      allowedActions: (json['allowed_actions'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
    );
  }
}

String myActionStatusLabel(String status) {
  final normalized = status.trim().toLowerCase();

  return switch (normalized) {
    'draft' => 'Черновик',
    'assigned' => 'Назначено',
    'pending' ||
    'pending_approval' ||
    'in_review' ||
    'awaiting_approval' => 'На согласовании',
    'submitted' || 'under_review' => 'На проверке',
    'approved' => 'Согласовано',
    'rejected' => 'Отклонено',
    'completed' || 'done' => 'Завершено',
    'closed' => 'Закрыто',
    'cancelled' || 'canceled' => 'Отменено',
    'in_progress' || 'in-progress' || 'active' => 'В работе',
    'overdue' => 'Просрочено',
    'blocked' => 'Заблокировано',
    _ => status.trim(),
  };
}

class MyActionsPage {
  const MyActionsPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<MyAction> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}
