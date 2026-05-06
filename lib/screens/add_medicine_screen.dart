import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import '../utils/app_colors.dart';

import '../services/notification_service.dart';

class AddMedicineScreen extends StatefulWidget {
  final Map<String, dynamic>? medicine;
  
  const AddMedicineScreen({super.key, this.medicine});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _manufacturerController = TextEditingController();
  
  String _category = 'occasional'; // 'regular' or 'occasional'
  int _perDayFrequency = 1;
  DateTime? _expiryDate;
  int _reminderAdvance = 0; // 0, 5, 10, or 15 minutes
  
  // Timing variables
  List<TimeOfDay> _timings = [];

  @override
  void initState() {
    super.initState();
    if (widget.medicine != null) {
      final med = widget.medicine!;
      _nameController.text = med['name'] ?? '';
      _quantityController.text = (med['quantity'] ?? 0).toString();
      _manufacturerController.text = med['manufacturer'] ?? '';
      _category = med['category'] ?? 'occasional';
      _perDayFrequency = med['perDayFrequency'] == 0 ? 1 : (med['perDayFrequency'] ?? 1);
      _reminderAdvance = med['reminderAdvance'] ?? 0;
      
      if (med['expiryDate'] != null && med['expiryDate'].toString().isNotEmpty && med['expiryDate'] != 'N/A') {
        try {
          final parts = med['expiryDate'].toString().split('-');
          if (parts.length == 3) {
            _expiryDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          }
        } catch (e) {}
      }

      if (med['timings'] != null && med['timings'].toString().isNotEmpty) {
        final tParts = med['timings'].toString().split(',');
        for (var t in tParts) {
          final hm = t.split(':');
          if (hm.length == 2) {
            _timings.add(TimeOfDay(hour: int.parse(hm[0]), minute: int.parse(hm[1])));
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _manufacturerController.dispose();
    super.dispose();
  }

  Future<void> _selectExpiryDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2040),
    );
    if (picked != null && picked != _expiryDate) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  Future<void> _selectTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _timings.length > index ? _timings[index] : TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (index < _timings.length) {
          _timings[index] = picked;
        } else {
          _timings.add(picked);
        }
      });
    }
  }

  Future<void> _saveMedicine() async {
    if (_formKey.currentState!.validate()) {
      // Basic validation for expiry
      if (_expiryDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an expiry date')));
        return;
      }
      
      // If regular, need timings equal to frequency
      if (_category == 'regular' && _timings.length < _perDayFrequency) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please set all $_perDayFrequency timings')));
         return;
      }

      final timingsStrings = _timings.map((t) => '${t.hour}:${t.minute}').toList().join(',');

      final newMedicine = {
        'name': _nameController.text.trim(),
        'category': _category,
        'quantity': int.tryParse(_quantityController.text) ?? 0,
        'perDayFrequency': _category == 'regular' ? _perDayFrequency : 0,
        'timings': _category == 'regular' ? timingsStrings : '',
        'manufacturer': _manufacturerController.text.trim(),
        'expiryDate': "${_expiryDate!.year}-${_expiryDate!.month.toString().padLeft(2, '0')}-${_expiryDate!.day.toString().padLeft(2, '0')}",
        'imagePath': widget.medicine?['imagePath'] ?? '',
        'lastTaken': widget.medicine?['lastTaken'] ?? '',
        'reminderAdvance': _reminderAdvance,
      };

      int id;
      if (widget.medicine != null) {
        id = widget.medicine!['id'];
        await DBHelper.updateMedicine(id, newMedicine);
      } else {
        id = await DBHelper.insertMedicine(newMedicine);
      }

      // Schedule notifications if regular
      if (_category == 'regular') {
        // Ensure permissions are granted before scheduling
        await NotificationService().requestPermissions();
        
        await NotificationService().scheduleMedicineReminder(
          id: id,
          medicineName: _nameController.text.trim(),
          timings: _timings,
          reminderAdvanceMinutes: _reminderAdvance,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.medicine != null ? 'Medicine updated successfully' : 'Medicine added successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        title: Text(widget.medicine != null ? 'Edit Medicine' : 'Add Medicine', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Medicine Details'),
              _buildTextField(_nameController, 'Medicine Name', Icons.medication_outlined, 'Enter medicine name'),
              const SizedBox(height: 16),
              _buildTextField(_manufacturerController, 'Manufacturer (Optional)', Icons.business, 'Enter manufacturer name', isRequired: false),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(_quantityController, 'Total Qty', Icons.numbers, 'e.g. 20', isNumber: true),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectExpiryDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.textGrey.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _expiryDate == null ? 'Expiry Date' : '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}',
                              style: TextStyle(color: _expiryDate == null ? AppColors.textGrey : Colors.black87),
                            ),
                            Icon(Icons.calendar_today, color: AppColors.primaryBlue, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              _buildSectionTitle('Category'),
              Row(
                children: [
                  Expanded(
                    child: _buildCategoryCard('Occasional', 'Use when needed', Icons.healing, 'occasional', AppColors.iconOrange),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCategoryCard('Regular', 'Daily basis', Icons.event_repeat, 'regular', AppColors.iconBlue),
                  ),
                ],
              ),
              
              if (_category == 'regular') ...[
                const SizedBox(height: 32),
                _buildSectionTitle('Dosage Frequency'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Times per day:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => setState(() { if (_perDayFrequency > 1) _perDayFrequency--; }),
                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.primaryBlue),
                        ),
                        Text('$_perDayFrequency', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(
                          onPressed: () => setState(() { if (_perDayFrequency < 6) _perDayFrequency++; }),
                          icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryBlue),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionTitle('Set Reminders'),
                ...List.generate(_perDayFrequency, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: InkWell(
                      onTap: () => _selectTime(index),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Dose ${index + 1} Time',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Row(
                              children: [
                                Text(
                                  index < _timings.length ? _timings[index].format(context) : 'Select Time',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: index < _timings.length ? AppColors.primaryBlue : AppColors.textGrey,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.access_time, size: 20, color: AppColors.primaryBlue),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
                _buildSectionTitle('Reminder Prior Time'),
                Wrap(
                  spacing: 12,
                  children: [0, 5, 10, 15].map((minutes) {
                    return ChoiceChip(
                      label: Text(minutes == 0 ? 'None' : '$minutes min before'),
                      selected: _reminderAdvance == minutes,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _reminderAdvance = minutes);
                        }
                      },
                      selectedColor: AppColors.primaryBlue,
                      labelStyle: TextStyle(
                        color: _reminderAdvance == minutes ? Colors.white : Colors.black87,
                      ),
                    );
                  }).toList(),
                ),
              ],
              
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveMedicine,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(widget.medicine != null ? 'Save Changes' : 'Add to Wardrobe', style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, String hint, {bool isNumber = false, bool isRequired = true}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: isRequired ? (value) {
        if (value == null || value.trim().isEmpty) {
          return 'This field is required';
        }
        return null;
      } : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textGrey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.textGrey.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.textGrey.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildCategoryCard(String title, String subtitle, IconData icon, String value, Color color) {
    final isSelected = _category == value;
    return GestureDetector(
      onTap: () => setState(() => _category = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppColors.textGrey.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : AppColors.textGrey, size: 32),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? color : Colors.black87)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textGrey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
