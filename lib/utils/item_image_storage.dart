import 'item_image_storage_stub.dart' if (dart.library.io) 'item_image_storage_io.dart' as impl;

/// Copies a picked image into app documents. No-op on web.
Future<String?> persistPickedImage(String xfilePath) => impl.persistPickedImage(xfilePath);
