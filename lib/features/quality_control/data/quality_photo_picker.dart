import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final qualityPhotoPickerProvider = Provider<QualityPhotoPicker>((ref) {
  return QualityPhotoPicker();
});

class QualityPhotoPicker {
  QualityPhotoPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<String?> pickInitialPhoto() async {
    return _pickPhoto();
  }

  Future<String?> pickResultPhoto() async {
    return _pickPhoto();
  }

  Future<String?> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    return file?.path;
  }
}
