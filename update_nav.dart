import 'dart:io';

void main() {
  final files = [
    'lib/screens/inventory_list_screen.dart',
    'lib/screens/inventory_screen.dart',
    'lib/screens/reminders_screen.dart',
    'lib/screens/room_items_screen.dart'
  ];

  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) continue;

    var content = file.readAsStringSync();
    
    // Replace existingItem: item, with existingItem: item, isViewOnly: true,
    content = content.replaceAll(
      'existingItem: item,\n',
      'existingItem: item,\n                  isViewOnly: true,\n'
    );
    // Also handle case with different indentation
    content = content.replaceAll(
      'existingItem: item,\n        )',
      'existingItem: item,\n          isViewOnly: true,\n        )'
    );

    file.writeAsStringSync(content);
  }
}
