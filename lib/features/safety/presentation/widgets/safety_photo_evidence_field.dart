import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class SafetyPhotoEvidenceField extends StatelessWidget {
  const SafetyPhotoEvidenceField({
    super.key,
    required this.path,
    required this.onChanged,
  });

  final String? path;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: () => _pickPhoto(context),
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text(path == null ? 'Добавить фото' : 'Заменить фото'),
        ),
        if (path != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.photo_outlined),
            title: Text(_fileName(path!)),
            trailing: IconButton(
              tooltip: 'Удалить фото',
              onPressed: () => onChanged(null),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
      ],
    );
  }

  Future<void> _pickPhoto(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder:
          (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Сделать фото'),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Выбрать из галереи'),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
                ),
              ],
            ),
          ),
    );
    if (source == null || !context.mounted) return;

    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
      );
      if (image != null) onChanged(image.path);
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось получить фото.')),
        );
      }
    }
  }
}

String _fileName(String path) {
  final separator = path.lastIndexOf(RegExp(r'[/\\]'));
  return path.substring(separator + 1);
}
