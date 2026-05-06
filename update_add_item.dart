import 'dart:io';

void main() {
  var file = File('lib/screens/add_item_screen.dart');
  var content = file.readAsStringSync();

  content = content.replaceFirst(
    '  final String? initialCategory;',
    '  final String? initialCategory;\n  final bool isViewOnly;'
  );

  content = content.replaceFirst(
    '    this.initialCategory,\n  });',
    '    this.initialCategory,\n    this.isViewOnly = false,\n  });'
  );

  content = content.replaceFirst(
    'class _AddItemScreenState extends State<AddItemScreen> {',
    'class _AddItemScreenState extends State<AddItemScreen> {\n  late bool _isViewOnly;'
  );

  content = content.replaceFirst(
    '  void initState() {\n    super.initState();',
    '  void initState() {\n    super.initState();\n    _isViewOnly = widget.isViewOnly;'
  );

  content = content.replaceFirst(
    '  Future<void> _showImageSourcePicker() async {',
    '  Future<void> _showImageSourcePicker() async {\n    if (_isViewOnly) return;'
  );

  content = content.replaceFirst(
    '                controller: _nameController,\n                decoration:',
    '                controller: _nameController,\n                readOnly: _isViewOnly,\n                decoration:'
  );

  content = content.replaceFirst(
    '                controller: _locationController,\n                decoration:',
    '                controller: _locationController,\n                readOnly: _isViewOnly,\n                decoration:'
  );

  content = content.replaceFirst(
    '                onChanged: (val) {\n                  setState(() {',
    '                onChanged: _isViewOnly ? null : (val) {\n                  setState(() {'
  );

  content = content.replaceFirst(
    '              InkWell(\n                onTap: () async {\n                  final date = await showDatePicker(',
    '              InkWell(\n                onTap: _isViewOnly ? null : () async {\n                  final date = await showDatePicker('
  );

  content = content.replaceFirst(
    '              InkWell(\n                onTap: () async {\n                  final date = await showDatePicker(',
    '              InkWell(\n                onTap: _isViewOnly ? null : () async {\n                  final date = await showDatePicker('
  );

  content = content.replaceFirst(
    '      onSelected: (selected) {',
    '      onSelected: _isViewOnly ? null : (selected) {'
  );

  content = content.replaceFirst(
    '              // Save Button\n              SizedBox(',
    '              // Save Button\n              if (!_isViewOnly) SizedBox('
  );

  content = content.replaceFirst(
    '          ),\n        ),\n      ),\n    );\n  }',
    '          ),\n        ),\n      ),\n      floatingActionButton: _isViewOnly\n          ? FloatingActionButton(\n              onPressed: () => setState(() => _isViewOnly = false),\n              backgroundColor: AppColors.primaryBlue,\n              child: const Icon(Icons.edit, color: Colors.white),\n            )\n          : null,\n    );\n  }'
  );

  file.writeAsStringSync(content);
}
