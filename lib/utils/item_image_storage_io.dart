import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String?> persistPickedImage(String xfilePath) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'item_photos'));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final ext = p.extension(xfilePath).toLowerCase();
  final safeExt = ext.isEmpty ? '.jpg' : ext;
  final destPath = p.join(dir.path, 'item_${DateTime.now().millisecondsSinceEpoch}$safeExt');
  await File(xfilePath).copy(destPath);
  return destPath;
}
