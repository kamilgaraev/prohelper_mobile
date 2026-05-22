import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final handoverDocumentPickerProvider = Provider<HandoverDocumentPicker>((ref) {
  return HandoverDocumentPicker();
});

class HandoverDocumentPicker {
  HandoverDocumentPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<String?> pickDocumentPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    return file?.path;
  }
}
