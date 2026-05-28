import 'package:flutter/material.dart';

import 'package:prohelpers_mobile/core/models/user_context.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';

enum MobileNavTab { overview, work, actions, more }

enum MobileWorkIntent { create, inspect, approve, record, search, manage }

enum MobileModuleGroup {
  fieldWork,
  warehouseAndSupply,
  approvalsAndDocs,
  management,
}

extension MobileModuleGroupLabel on MobileModuleGroup {
  String get label {
    return switch (this) {
      MobileModuleGroup.fieldWork => 'Полевые работы',
      MobileModuleGroup.warehouseAndSupply => 'Склад и снабжение',
      MobileModuleGroup.approvalsAndDocs => 'Согласования и документы',
      MobileModuleGroup.management => 'Управление',
    };
  }
}

class MobileModuleDestination {
  const MobileModuleDestination({
    required this.route,
    required this.slug,
    required this.title,
    required this.shortTitle,
    required this.icon,
    required this.group,
    required this.builder,
    this.aliases = const <String>[],
    this.isPrimaryAction = false,
    this.appModule,
    this.actionId,
    this.basePriority = 100,
    this.recommendedReason = 'Доступно по вашей роли',
    this.preferredContexts = const <UserContext>{},
    this.requiresProject = true,
    this.searchKeywords = const <String>[],
    this.intent = MobileWorkIntent.inspect,
    this.isSecondary = false,
  });

  final String route;
  final String slug;
  final String title;
  final String shortTitle;
  final IconData icon;
  final MobileModuleGroup group;
  final WidgetBuilder builder;
  final List<String> aliases;
  final bool isPrimaryAction;
  final AppModule? appModule;
  final String? actionId;
  final int basePriority;
  final String recommendedReason;
  final Set<UserContext> preferredContexts;
  final bool requiresProject;
  final List<String> searchKeywords;
  final MobileWorkIntent intent;
  final bool isSecondary;

  bool matches(String value) {
    return route == value || slug == value || aliases.contains(value);
  }

  bool matchesSearch(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }

    final haystack = [
      route,
      slug,
      title,
      shortTitle,
      recommendedReason,
      ...aliases,
      ...searchKeywords,
    ].join(' ').toLowerCase();

    return haystack.contains(normalized);
  }
}
