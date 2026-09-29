import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 35),
  writeResponseOnFailure: true,
  responseDataCallback:
      (data) => writeResponseData(
        data,
        testOutputFilename:
            Platform.environment['BIM_DEVICE_REPORT_NAME'] ??
            'bim-device-result',
        destinationDirectory:
            Platform.environment['BIM_DEVICE_REPORT_DIRECTORY'] ??
            Directory.systemTemp.path,
      ),
);
