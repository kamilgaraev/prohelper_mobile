class MobileModuleModel {
  const MobileModuleModel({
    required this.slug,
    required this.title,
    required this.description,
    required this.icon,
    required this.supportedOnMobile,
    required this.order,
    this.route,
    this.permissions = const [],
  });

  final String slug;
  final String title;
  final String description;
  final String icon;
  final bool supportedOnMobile;
  final int order;
  final String? route;
  final List<String> permissions;

  factory MobileModuleModel.fromJson(Map<String, dynamic> json) {
    return MobileModuleModel(
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? 'grid',
      supportedOnMobile: json['supported_on_mobile'] as bool? ?? false,
      order: json['order'] as int? ?? 0,
      route: json['route'] as String?,
      permissions: (json['permissions'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}
