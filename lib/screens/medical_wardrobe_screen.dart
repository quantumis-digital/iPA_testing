import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import '../utils/app_colors.dart';
import 'add_medicine_screen.dart';
import 'medicine_detail_screen.dart';
import '../services/notification_service.dart';
import 'water_reminder_screen.dart';

class MedicalWardrobeScreen extends StatefulWidget {
  const MedicalWardrobeScreen({super.key});

  @override
  State<MedicalWardrobeScreen> createState() => _MedicalWardrobeScreenState();
}

class _MedicalWardrobeScreenState extends State<MedicalWardrobeScreen> {
  List<Map<String, dynamic>> _medicines = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _waterEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
    _loadWaterStatus();
  }

  Future<void> _loadWaterStatus() async {
    final v = await DBHelper.getSetting('water_enabled');
    if (mounted) setState(() => _waterEnabled = v == 'true');
  }

  Future<void> _loadMedicines() async {
    setState(() => _isLoading = true);
    if (_searchQuery.isEmpty) {
      _medicines = await DBHelper.getMedicines();
    } else {
      _medicines = await DBHelper.searchMedicines(_searchQuery);
    }
    setState(() => _isLoading = false);
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _loadMedicines();
  }

  Future<void> _deleteMedicine(int id) async {
    await NotificationService().cancelMedicineReminders(id);
    await DBHelper.deleteMedicine(id);
    _loadMedicines();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        title: const Text('Medical Wardrobe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.primaryBlue,
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: TextField(
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: AppColors.textGrey.withValues(alpha: 0.5)),
                  hintText: 'Search medicines...',
                  hintStyle: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
          // ── Water Reminder Banner ───────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0055FF), Color(0xFF00C6FF)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A84FF).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WaterReminderScreen()),
                  );
                  _loadWaterStatus();
                },
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.water_drop, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Water Reminder',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _waterEnabled ? 'Active · Tap to manage' : 'Set up hydration reminders',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _waterEnabled ? Icons.notifications_active : Icons.notifications_none,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _waterEnabled ? 'On' : 'Off',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── Medicine List ───────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _medicines.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.medical_services_outlined, size: 80, color: AppColors.textGrey.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text('No medicines found', style: TextStyle(color: AppColors.textGrey, fontSize: 18)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _medicines.length,
                        itemBuilder: (context, index) {
                          final medicine = _medicines[index];
                          final isRegular = medicine['category'] == 'regular';
                          return Dismissible(
                            key: Key(medicine['id'].toString()),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.red,
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (direction) => _deleteMedicine(medicine['id']),
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              elevation: 2,
                              shadowColor: Colors.black.withValues(alpha: 0.05),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: isRegular ? AppColors.iconBlue.withValues(alpha: 0.2) : AppColors.iconOrange.withValues(alpha: 0.2),
                                  child: Icon(
                                    Icons.medication,
                                    color: isRegular ? AppColors.iconBlue : AppColors.iconOrange,
                                    size: 30,
                                  ),
                                ),
                                title: Text(
                                  medicine['name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Qty: ${medicine['quantity']}', style: const TextStyle(color: Colors.black87)),
                                      if (isRegular)
                                        Text('Freq: ${medicine['perDayFrequency']} times/day', style: const TextStyle(color: Colors.grey)),
                                      Text('Expiry: ${medicine['expiryDate'] ?? "N/A"}', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                                      if (isRegular && (medicine['reminderAdvance'] ?? 0) > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.notifications_active, size: 12, color: Colors.green),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Reminder: ${medicine['reminderAdvance']} min before',
                                                style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isRegular ? AppColors.iconBlue.withValues(alpha: 0.1) : AppColors.iconOrange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isRegular ? 'Regular' : 'Occasional',
                                    style: TextStyle(
                                      color: isRegular ? AppColors.iconBlue : AppColors.iconOrange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => MedicineDetailScreen(medicine: medicine)),
                                  );
                                  _loadMedicines(); // Refresh stock
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddMedicineScreen()),
          );
          _loadMedicines(); // Refresh after adding
        },
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Medicine', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
