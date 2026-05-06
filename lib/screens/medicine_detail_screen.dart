import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import '../services/notification_service.dart';
import '../utils/app_colors.dart';
import 'add_medicine_screen.dart';

class MedicineDetailScreen extends StatefulWidget {
  final Map<String, dynamic> medicine;

  const MedicineDetailScreen({super.key, required this.medicine});

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  late Map<String, dynamic> _medicine;
  
  @override
  void initState() {
    super.initState();
    _medicine = Map.from(widget.medicine);
  }

  Future<void> _updateMedicine() async {
    await DBHelper.updateMedicine(_medicine['id'], _medicine);
    setState(() {}); // Re-render
  }

  Future<void> _reloadMedicine() async {
    final all = await DBHelper.getMedicines();
    try {
      final updated = all.firstWhere((m) => m['id'] == _medicine['id']);
      setState(() {
        _medicine = Map.from(updated);
      });
    } catch (e) {
      // Not found, maybe deleted
    }
  }

  void _editMedicine() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddMedicineScreen(medicine: _medicine)),
    );
    if (result == true) {
      _reloadMedicine();
    }
  }

  void _deleteMedicine() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medicine'),
        content: Text('Are you sure you want to delete ${_medicine['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await NotificationService().cancelMedicineReminders(_medicine['id']);
              await DBHelper.deleteMedicine(_medicine['id']);
              if (mounted) {
                Navigator.pop(context); // close dialog
                Navigator.pop(context, true); // go back to list
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }

  void _confirmTaken() {
    final qty = (_medicine['quantity'] as num?)?.toInt() ?? 0;
    if (qty > 0) {
      _medicine['quantity'] = qty - 1;
      _medicine['lastTaken'] = DateTime.now().toIso8601String();
      _updateMedicine();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as taken! Quantity decreased.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Out of stock! Please restock.')));
    }
  }

  void _restock() {
    showDialog(
      context: context,
      builder: (context) {
        final qtyController = TextEditingController();
        return AlertDialog(
          title: const Text('Restock Medicine'),
          content: TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantity to add',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final addedQty = int.tryParse(qtyController.text) ?? 0;
                if (addedQty > 0) {
                  final current = (_medicine['quantity'] as num?)?.toInt() ?? 0;
                  _medicine['quantity'] = current + addedQty;
                  _updateMedicine();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $addedQty units!')));
                }
              },
              child: const Text('Restock'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRegular = _medicine['category'] == 'regular';
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        title: Text(_medicine['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
            onPressed: _editMedicine,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete',
            onPressed: _deleteMedicine,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: isRegular ? AppColors.iconBlue.withValues(alpha: 0.2) : AppColors.iconOrange.withValues(alpha: 0.2),
                    child: Icon(
                      Icons.medication,
                      color: isRegular ? AppColors.iconBlue : AppColors.iconOrange,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(_medicine['name'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isRegular ? AppColors.iconBlue.withValues(alpha: 0.1) : AppColors.iconOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isRegular ? 'Regular Use' : 'Occasional Use',
                      style: TextStyle(
                        color: isRegular ? AppColors.iconBlue : AppColors.iconOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            _buildInfoCard('Stock Information', [
              _buildInfoRow('Current Quantity', '${_medicine['quantity']} units', Icons.inventory_2_outlined),
              _buildInfoRow(
                'Manufacturer',
                (_medicine['manufacturer']?.toString() ?? '').isEmpty ? 'N/A' : _medicine['manufacturer'].toString(),
                Icons.business,
              ),
              _buildInfoRow('Expiry Date', _medicine['expiryDate'] ?? 'N/A', Icons.event_busy, valueColor: Colors.redAccent),
              if (_medicine['lastTaken'] != null && _medicine['lastTaken'].toString().isNotEmpty)
                _buildInfoRow('Last Taken', _formatDate(_medicine['lastTaken']), Icons.history, valueColor: Colors.green),
            ]),
            
            if (isRegular) ...[
              const SizedBox(height: 16),
              _buildInfoCard('Dosage details', [
                _buildInfoRow('Frequency', '${_medicine['perDayFrequency']} times per day', Icons.repeat),
                _buildInfoRow('Timings', _medicine['timings']?.toString() ?? '—', Icons.access_time),
                _buildInfoRow(
                  'Reminder', 
                  _medicine['reminderAdvance'] == null || _medicine['reminderAdvance'] == 0 
                      ? 'None' 
                      : '${_medicine['reminderAdvance']} min before', 
                  Icons.notifications_active_outlined
                ),
              ]),
            ],
            
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _confirmTaken,
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: const Text('Confirm Taken', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _restock,
                    icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                    label: const Text('Restock', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textGrey, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: AppColors.textGrey, fontSize: 14)),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: valueColor ?? Colors.black87)),
        ],
      ),
    );
  }
}
