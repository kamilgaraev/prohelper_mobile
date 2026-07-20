import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final legalDocumentOriginalPickerProvider = Provider<LegalDocumentOriginalPicker>((ref) {
  return LegalDocumentOriginalPicker();
});

class LegalDocumentOriginalPicker {
  LegalDocumentOriginalPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<String?> pickFromCamera() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );

    return image?.path;
  }
}
