import 'dart:io';

import 'package:flutter/material.dart';

Widget? itemPhotoPreview(String? path, {double height = 140}) {
  if (path == null || path.isEmpty) return null;
  final file = File(path);
  if (!file.existsSync()) return null;
  return ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Image.file(
      file,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
    ),
  );
}
