import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/models/user_context.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/services/permission_service.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';

void main() {
  for (final moduleSlug in ['basic-warehouse', 'basic_warehouse']) {
    test('$moduleSlug full access permits warehouse operations', () {
      final user =
          User()
            ..permissionsJson = jsonEncode({
              moduleSlug: ['*'],
            });
      final permissions = PermissionService(
        context: UserContext.office,
        activeModules: {AppModule.basicWarehouse},
        grantedPermissions: user.grantedPermissions,
      );

      expect(permissions.hasPermission('warehouse.receipts'), isTrue);
      expect(permissions.hasPermission('warehouse.manage_stock'), isTrue);
      expect(permissions.canProcessAction('receive_material'), isTrue);
      expect(permissions.hasPermission('payments.approve'), isFalse);
      expect(permissions.hasPermission('safety-management.view'), isFalse);
    });
  }

  test('warehouse view access does not permit stock changes', () {
    final permissions = PermissionService(
      context: UserContext.office,
      activeModules: {AppModule.basicWarehouse},
      grantedPermissions: {'warehouse.view'},
    );

    expect(permissions.hasPermission('warehouse.view'), isTrue);
    expect(permissions.hasPermission('warehouse.receipts'), isFalse);
    expect(permissions.hasPermission('warehouse.manage_stock'), isFalse);
    expect(permissions.canProcessAction('receive_material'), isFalse);
  });

  test('warehouse grants do not activate an unavailable module', () {
    final permissions = PermissionService(
      context: UserContext.office,
      activeModules: {},
      grantedPermissions: {'basic-warehouse.*'},
    );

    expect(permissions.canAccessModule(AppModule.basicWarehouse), isFalse);
    expect(permissions.canProcessAction('receive_material'), isFalse);
  });
}
