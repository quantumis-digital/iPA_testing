import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/app_colors.dart';
import '../utils/item_image_storage.dart';
import '../utils/item_photo_preview.dart';
import '../services/db_helper.dart';
import '../services/notification_service.dart';

class AddItemScreen extends StatefulWidget {
  final int houseId;
  final String roomName;

  /// When set, screen opens in edit mode and updates this row on save.
  final Map<String, dynamic>? existingItem;
  final String? initialCategory;
  final bool isViewOnly;

  const AddItemScreen({
    super.key,
    required this.houseId,
    required this.roomName,
    this.existingItem,
    this.initialCategory,
    this.isViewOnly = false,
  });

  bool get isEdit => existingItem != null;

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  late bool _isViewOnly;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String? _selectedCategory;
  final List<String> _categories = [
    'Documents',
    'Electronics',
    'Furniture',
    'Clothing',
    'Medical',
    'Grocery',
    'Other'
  ];

  DateTime? _purchaseDate;
  DateTime? _expiryDate;
  String? _imagePath;
  int _reminderAdvanceDays = -1;

  @override
  void initState() {
    super.initState();
    _isViewOnly = widget.isViewOnly;
    final ex = widget.existingItem;
    if (ex != null) {
      _nameController.text = ex['name']?.toString() ?? '';
      _locationController.text = ex['location']?.toString() ?? '';
      _selectedCategory = ex['category']?.toString() ?? widget.initialCategory;
      final ps = ex['purchaseDate']?.toString();
      final es = ex['expiryDate']?.toString();
      if (ps != null && ps.isNotEmpty) {
        _purchaseDate = DateTime.tryParse(ps);
      }
      if (es != null && es.isNotEmpty) {
        _expiryDate = DateTime.tryParse(es);
      }
      final img = ex['imagePath']?.toString();
      if (img != null && img.isNotEmpty) {
        _imagePath = img;
      }
      final adv = ex['reminderAdvanceDays'];
      if (adv != null) {
        _reminderAdvanceDays = adv is int ? adv : (adv as num).toInt();
      }
    } else if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photos are available in the Android/iOS app.')),
      );
      return;
    }

    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera access is required to take photos. Please enable it in Settings.')),
        );
        return;
      }
    }

    try {
      final picker = ImagePicker();
      final XFile? x = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (x == null || !mounted) return;
      final saved = await persistPickedImage(x.path);
      if (saved != null) {
        setState(() => _imagePath = saved);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save image')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image error: $e')),
        );
      }
    }
  }

  Future<void> _showImageSourcePicker() async {
    if (_isViewOnly) return;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _saveItem() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category')),
        );
        return;
      }

      final details = {
        'houseId': widget.houseId,
        'roomName': widget.roomName,
        'name': _nameController.text,
        'category': _selectedCategory,
        'location': _locationController.text,
        'purchaseDate': _purchaseDate?.toIso8601String() ?? '',
        'expiryDate': _expiryDate?.toIso8601String() ?? '',
        'imagePath': _imagePath ?? '',
        'reminderAdvanceDays': _reminderAdvanceDays,
      };

      int savedId;
      final ex = widget.existingItem;
      if (ex != null) {
        final id = ex['id'];
        savedId = id is int ? id : (id as num).toInt();
        await DBHelper.updateItem(savedId, details);
      } else {
        savedId = await DBHelper.insertItem(details);
      }

      if (_expiryDate != null && _reminderAdvanceDays >= 0) {
        await NotificationService().requestPermissions();
        await NotificationService().scheduleItemExpiryReminder(
          id: savedId,
          itemName: _nameController.text,
          expiryDate: _expiryDate!,
          advanceDays: _reminderAdvanceDays,
        );
      } else if (ex != null) {
        await NotificationService().cancelItemReminder(savedId);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = itemPhotoPreview(_imagePath, height: 160);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.isEdit ? 'Edit Item' : 'Add Item',
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            physics: const BouncingScrollPhysics(),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (preview != null) ...[
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        preview,
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(() => _imagePath = null),
                              icon: const Icon(Icons.close, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ] else
                    Material(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: _showImageSourcePicker,
                        borderRadius: BorderRadius.circular(20),
                        child: SizedBox(
                          height: 140,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                'Add photo',
                                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined, size: 20),
                          label: const Text('Camera'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined, size: 20),
                          label: const Text('Gallery'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Name Field
              TextFormField(
                controller: _nameController,
                readOnly: _isViewOnly,
                decoration: InputDecoration(
                  labelText: 'Item Name',
                  hintText: 'e.g., Passport',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.label_outline),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 16),

              // Category Dropdown
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedCategory ?? ''),
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
                initialValue: _selectedCategory,
                items: _categories.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: _isViewOnly ? null : (val) {
                  setState(() {
                    _selectedCategory = val;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Location Field
              TextFormField(
                controller: _locationController,
                readOnly: _isViewOnly,
                decoration: InputDecoration(
                  labelText: 'Specific Location',
                  hintText: 'e.g., Top Drawer',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.place_outlined),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please enter a location' : null,
              ),
              const SizedBox(height: 16),

              // Purchase Date Picker
              InkWell(
                onTap: _isViewOnly ? null : () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _purchaseDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) setState(() => _purchaseDate = date);
                },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Purchase Date',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.shopping_bag_outlined),
                  ),
                  child: Text(
                    _purchaseDate == null
                        ? 'Select Purchase Date'
                        : '${_purchaseDate!.day}/${_purchaseDate!.month}/${_purchaseDate!.year}',
                    style: TextStyle(
                      color: _purchaseDate == null ? Colors.grey.shade600 : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Expiry Date Picker
              InkWell(
                onTap: _isViewOnly ? null : () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _expiryDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) setState(() => _expiryDate = date);
                },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Expiry Date',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.event_busy_outlined),
                  ),
                  child: Text(
                    _expiryDate == null
                        ? 'Select Expiry Date'
                        : '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}',
                    style: TextStyle(
                      color: _expiryDate == null ? Colors.grey.shade600 : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              if (_expiryDate != null) ...[
                const SizedBox(height: 16),
                const Text('Expiry Reminder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildReminderChip('None', -1),
                    _buildReminderChip('On Day', 0),
                    _buildReminderChip('1 Day Before', 1),
                    _buildReminderChip('2 Days Before', 2),
                    _buildReminderChip('3 Days Before', 3),
                    _buildReminderChip('1 Week Before', 7),
                  ],
                ),
              ],

              const SizedBox(height: 48),

              // Save Button
              if (!_isViewOnly) SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                  child: Text(
                    widget.isEdit ? 'Update Item' : 'Save Item',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _isViewOnly
          ? FloatingActionButton(
              onPressed: () => setState(() => _isViewOnly = false),
              backgroundColor: AppColors.primaryBlue,
              child: const Icon(Icons.edit, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildReminderChip(String label, int days) {
    final isSelected = _reminderAdvanceDays == days;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: _isViewOnly ? null : (selected) {
        if (selected) setState(() => _reminderAdvanceDays = days);
      },
      selectedColor: AppColors.primaryBlue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
      ),
    );
  }
}
