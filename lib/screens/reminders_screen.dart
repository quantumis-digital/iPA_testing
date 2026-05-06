import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import '../utils/app_colors.dart';
import 'add_item_screen.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Map<String, dynamic>> _reminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    final allItems = await DBHelper.getAllItems();
    
    List<Map<String, dynamic>> upcomingReminders = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var item in allItems) {
      if (item['expiryDate'] != null && item['expiryDate'].toString().isNotEmpty) {
        final expDate = DateTime.tryParse(item['expiryDate'].toString());
        if (expDate != null) {
          final targetDate = DateTime(expDate.year, expDate.month, expDate.day);
          final diff = targetDate.difference(today).inDays;

          // Exclude already expired items as requested
          if (diff >= 0) {
            upcomingReminders.add({
              ...item,
              'daysLeft': diff,
            });
          }
        }
      }
    }

    // Sort by days left (ascending)
    upcomingReminders.sort((a, b) => (a['daysLeft'] as int).compareTo(b['daysLeft'] as int));

    setState(() {
      _reminders = upcomingReminders;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        title: const Text('Reminders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.iconOrange,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reminders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 80, color: AppColors.textGrey.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('No upcoming expiries!', style: TextStyle(color: AppColors.textGrey, fontSize: 18)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _reminders.length,
                  itemBuilder: (context, index) {
                    final item = _reminders[index];
                    final daysLeft = item['daysLeft'] as int;
                    
                    Color badgeColor;
                    String badgeText;
                    if (daysLeft == 0) {
                      badgeColor = Colors.orange.shade800;
                      badgeText = 'Expires Today';
                    } else if (daysLeft <= 3) {
                      badgeColor = Colors.orange;
                      badgeText = 'Expires in $daysLeft days';
                    } else {
                      badgeColor = Colors.green;
                      badgeText = 'Expires in $daysLeft days';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.notifications_active_outlined, color: badgeColor),
                        ),
                        title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${item['category'] ?? 'Item'} • ${item['roomName'] ?? ''}'),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.event_busy, size: 14, color: badgeColor),
                                    const SizedBox(width: 4),
                                    Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddItemScreen(
                                houseId: item['houseId'],
                                roomName: item['roomName'],
                                existingItem: item,
                  isViewOnly: true,
                              ),
                            ),
                          );
                          if (result == true) {
                            _loadReminders();
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
