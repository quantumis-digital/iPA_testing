import 'package:flutter/material.dart';

import 'item_photo_preview_stub.dart' if (dart.library.io) 'item_photo_preview_io.dart' as impl;

/// Shows a local file image when running on IO platforms; null on web.
Widget? itemPhotoPreview(String? path, {double height = 140}) {
  return impl.itemPhotoPreview(path, height: height);
}
