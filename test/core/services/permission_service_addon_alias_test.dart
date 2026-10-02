import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/models/user_context.dart';
import 'package:prohelpers_mobile/core/providers/module_provider.dart';
import 'package:prohelpers_mobile/core/services/permission_service.dart';
import 'package:prohelpers_mobile/features/auth/data/user_model.dart';

void main() {
  for (final moduleSlug in ['file-management', 'file_management']) {
    test('$moduleSlug full access permits registered report actions', () {
      final user =
          User()
            ..permissionsJson = jsonEncode({
              moduleSlug: ['*'],
            });
      final permissions = PermissionService(
        context: UserContext.office,
        activeModules: {AppModule.fileManagement},
        grantedPermissions: user.grantedPermissions,
      );

      expect(permissions.hasPermission('report_files.view'), isTrue);
      expect(permissions.hasPermission('report_files.delete'), isTrue);
      expect(permissions.hasPermission('rate_coefficients.view'), isFalse);
      expect(permissions.hasPermission('payments.approve'), isFalse);
    });
  }

  for (final moduleSlug in ['rate-management', 'rate_management']) {
    test('$moduleSlug full access permits registered coefficient actions', () {
      final user =
          User()
            ..permissionsJson = jsonEncode({
              moduleSlug: ['*'],
            });
      final permissions = PermissionService(
        context: UserContext.office,
        activeModules: {AppModule.rateManagement},
        grantedPermissions: user.grantedPermissions,
      );

      expect(permissions.hasPermission('rate_coefficients.view'), isTrue);
      expect(permissions.hasPermission('rate_coefficients.edit'), isTrue);
      expect(permissions.hasPermission('report_files.view'), isFalse);
      expect(permissions.hasPermission('payments.approve'), isFalse);
    });
  }

  test('report read access does not permit report deletion', () {
    final permissions = PermissionService(
      context: UserContext.office,
      activeModules: {AppModule.fileManagement},
      grantedPermissions: {'report_files.view'},
    );

    expect(permissions.hasPermission('report_files.view'), isTrue);
    expect(permissions.hasPermission('report_files.delete'), isFalse);
    expect(permissions.hasPermission('rate_coefficients.view'), isFalse);
  });

  test('coefficient read access does not permit coefficient edits', () {
    final permissions = PermissionService(
      context: UserContext.office,
      activeModules: {AppModule.rateManagement},
      grantedPermissions: {'rate_coefficients.view'},
    );

    expect(permissions.hasPermission('rate_coefficients.view'), isTrue);
    expect(permissions.hasPermission('rate_coefficients.edit'), isFalse);
    expect(permissions.hasPermission('report_files.view'), isFalse);
  });

  test('unrelated permissions do not grant addon reads', () {
    for (final grants in [
      <String>{},
      {'basic-warehouse.*'},
      {'personal_files.view'},
    ]) {
      final permissions = PermissionService(
        context: UserContext.office,
        activeModules: {AppModule.fileManagement, AppModule.rateManagement},
        grantedPermissions: grants,
      );

      expect(permissions.hasPermission('report_files.view'), isFalse);
      expect(permissions.hasPermission('rate_coefficients.view'), isFalse);
    }
  });

  test('addon grants do not activate unavailable modules', () {
    final permissions = PermissionService(
      context: UserContext.office,
      activeModules: {},
      grantedPermissions: {'file-management.*', 'rate-management.*'},
    );

    expect(permissions.canAccessModule(AppModule.fileManagement), isFalse);
    expect(permissions.canAccessModule(AppModule.rateManagement), isFalse);
  });
}
