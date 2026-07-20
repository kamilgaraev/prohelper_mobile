import 'package:flutter/material.dart';

class LegalDocumentUpload extends StatelessWidget {
  const LegalDocumentUpload({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(16),
    child: Text('Загрузка оригинала открывается только после получения доступного действия от сервера.'),
  );
}
