import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final journalPhotoPickerProvider = Provider<JournalPhotoPicker>(
  (ref) => JournalPhotoPicker(),
);

class JournalPhotoPicker {
  Future<String?> pick({required bool camera}) async {
    final image = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 90,
    );
    return image?.path;
  }
}
