import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import '../services/notification_service.dart';
import 'add_item_screen.dart';

class InventoryListScreen extends StatefulWidget {
  final String title;
  final String filterType;
  final bool isReadOnly;

  const InventoryListScreen({
    super.key,
    required this.title,
    required this.filterType,
    required this.isReadOnly,
  });

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final all = await DBHelper.getAllItems();
    
    List<Map<String, dynamic>> filtered;
    if (widget.filterType == 'all') {
      filtered = all;
    } else if (widget.filterType == 'grocery') {
      filtered = all.where((item) => (item['category']?.toString().toLowerCase() ?? '') == 'grocery').toList();
    } else {
      filtered = all.where((item) => (item['roomName']?.toString().toLowerCase() ?? '').contains(widget.filterType)).toList();
    }

    _allItems = filtered;
    _applySearch();
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredItems = List.from(_allItems);
    } else {
      _filteredItems = _allItems.where((item) {
        final name = item['name']?.toString().toLowerCase() ?? '';
        return name.contains(_searchQuery.toLowerCase());
      }).toList();
    }
    setState(() => _isLoading = false);
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _applySearch();
  }

  Future<void> _deleteItem(int id) async {
    await NotificationService().cancelItemReminder(id);
    await DBHelper.deleteItem(id);
    _loadItems();
  }

  void _editItem(Map<String, dynamic> item) async {
    if (widget.isReadOnly) return;
    
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
      _loadItems();
    }
  }

  Future<void> _navigateToAddItem() async {
    final houses = await DBHelper.getHouses();
    if (houses.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create a house layout first.')),
      );
      return;
    }
    
    final houseId = houses.first['id'] as int;
    
    String defaultRoomName = 'General';
    String? initialCategory;
    
    if (widget.filterType == 'kitchen') {
      defaultRoomName = 'Kitchen 1';
    } else if (widget.filterType == 'bedroom') {
      defaultRoomName = 'Bedroom 1';
    } else if (widget.filterType == 'bathroom') {
      defaultRoomName = 'Bathroom 1';
    } else if (widget.filterType == 'hall') {
      defaultRoomName = 'Hall 1';
    } else if (widget.filterType == 'grocery') {
      defaultRoomName = 'Groceries';
      initialCategory = 'Grocery';
    }
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddItemScreen(
          houseId: houseId,
          roomName: defaultRoomName,
          initialCategory: initialCategory,
        ),
      ),
    );
    
    if (result == true) {
      _loadItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryBlue,
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
                  hintText: AppStrings.searchInventoryHint,
                  hintStyle: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 80, color: AppColors.textGrey.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text(AppStrings.noItemsIn(widget.title), style: TextStyle(color: AppColors.textGrey, fontSize: 18)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          Widget? expiryBadge;
                          if (item['expiryDate'] != null && item['expiryDate'].toString().isNotEmpty) {
                            final expDate = DateTime.tryParse(item['expiryDate'].toString());
                            if (expDate != null) {
                              final now = DateTime.now();
                              final targetDate = DateTime(expDate.year, expDate.month, expDate.day);
                              final diff = targetDate.difference(DateTime(now.year, now.month, now.day)).inDays;
                              
                              Color badgeColor;
                              String badgeText;
                              if (diff < 0) {
                                badgeColor = Colors.red.shade800;
                                badgeText = 'Expired';
                              } else if (diff == 0) {
                                badgeColor = Colors.orange.shade800;
                                badgeText = 'Expires Today';
                              } else if (diff <= 3) {
                                badgeColor = Colors.orange;
                                badgeText = 'Expires in $diff days';
                              } else {
                                badgeColor = Colors.green;
                                badgeText = 'Expires in $diff days';
                              }

                              expiryBadge = Container(
                                margin: const EdgeInsets.only(top: 8),
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
                              );
                            }
                          }
                          
                          Widget card = Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shadowColor: Colors.black.withValues(alpha: 0.05),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.iconBlue.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.label_outline, color: AppColors.primaryBlue),
                              ),
                              title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(AppStrings.roomPrefix(item['roomName']?.toString() ?? '')),
                                    Text(AppStrings.locationPrefix(item['location']?.toString() ?? '')),
                                    if (item['category'] != null && item['category'].toString().isNotEmpty) 
                                      Text(AppStrings.categoryPrefix(item['category'].toString())),
                                    if (expiryBadge != null) expiryBadge,
                                  ],
                                ),
                              ),
                              trailing: widget.isReadOnly ? null : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _editItem(item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Item'),
                                          content: Text('Are you sure you want to delete ${item['name']}?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        _deleteItem(item['id']);
                                      }
                                    },
                                  ),
                                ],
                              ),
                              onTap: () => _editItem(item),
                            ),
                          );

                          if (widget.isReadOnly) {
                            return card;
                          }

                          return Dismissible(
                            key: Key(item['id'].toString()),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (direction) => _deleteItem(item['id']),
                            child: card,
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: widget.isReadOnly
          ? null
          : FloatingActionButton(
              onPressed: _navigateToAddItem,
              backgroundColor: AppColors.primaryBlue,
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }
}
