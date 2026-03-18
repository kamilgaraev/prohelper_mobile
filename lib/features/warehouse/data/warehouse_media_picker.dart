import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final warehouseMediaPickerProvider = Provider<WarehouseMediaPicker>((ref) {
  return WarehouseMediaPicker();
});

class WarehouseMediaPicker {
  WarehouseMediaPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<String?> pickFromCamera() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    return file?.path;
  }

  Future<List<String>> pickFromGallery({int limit = 4}) async {
    final files = await _picker.pickMultiImage(imageQuality: 85);

    if (files.isEmpty) {
      return const <String>[];
    }

    return files.take(limit).map((file) => file.path).toList();
  }
}
