import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import 'inventory_list_screen.dart';
import 'add_item_screen.dart';
import '../services/notification_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _searchResults = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await DBHelper.getAllItems();
    setState(() {
      _allItems = items;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> _filterByRoom(String roomType) {
    return _allItems.where((item) => (item['roomName']?.toString().toLowerCase() ?? '').contains(roomType.toLowerCase())).toList();
  }

  List<Map<String, dynamic>> _filterByCategory(String category) {
    return _allItems.where((item) => (item['category']?.toString().toLowerCase() ?? '') == category.toLowerCase()).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _searchResults = [];
      } else {
        _searchResults = _allItems.where((item) {
          final name = item['name']?.toString().toLowerCase() ?? '';
          return name.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _deleteItem(int id) async {
    await NotificationService().cancelItemReminder(id);
    await DBHelper.deleteItem(id);
    await _loadItems();
    _onSearchChanged(_searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final kitchenItems = _filterByRoom('Kitchen');
    final bedroomItems = _filterByRoom('Bedroom');
    final bathroomItems = _filterByRoom('Bathroom');
    final hallItems = _filterByRoom('Hall');
    final groceryItems = _filterByCategory('Grocery');

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        title: const Text('Inventory', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  hintText: 'Search entire inventory...',
                  hintStyle: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
          Expanded(
            child: _searchQuery.isEmpty
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    physics: const BouncingScrollPhysics(),
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildInventoryTile(context, AppStrings.inventoryBedrooms, Icons.bed_outlined, AppColors.iconBlue, bedroomItems.length, 'bedroom', false),
                        _buildInventoryTile(context, AppStrings.inventoryKitchens, Icons.kitchen_outlined, AppColors.iconOrange, kitchenItems.length, 'kitchen', false),
                        _buildInventoryTile(context, AppStrings.inventoryBathrooms, Icons.bathtub_outlined, AppColors.iconGreen, bathroomItems.length, 'bathroom', false),
                        _buildInventoryTile(context, AppStrings.inventoryHalls, Icons.weekend_outlined, AppColors.iconRed, hallItems.length, 'hall', false),
                        _buildInventoryTile(context, AppStrings.inventoryGroceries, Icons.shopping_basket_outlined, Colors.teal, groceryItems.length, 'grocery', false),
                        _buildInventoryTile(context, AppStrings.inventoryAllItems, Icons.inventory_2_outlined, AppColors.primaryBlue, _allItems.length, 'all', true),
                      ],
                    ),
                  )
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: AppColors.textGrey.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No items found for "$_searchQuery"', style: TextStyle(color: AppColors.textGrey, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
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
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () async {
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
                      await _loadItems();
                      _onSearchChanged(_searchQuery);
                    }
                  },
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
                await _loadItems();
                _onSearchChanged(_searchQuery);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildInventoryTile(BuildContext context, String title, IconData icon, Color color, int count, String filterType, bool isReadOnly) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => InventoryListScreen(
            title: title, 
            filterType: filterType, 
            isReadOnly: isReadOnly
          )),
        ).then((_) => _loadItems()); // Reload on return in case of changes
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(AppStrings.itemCountText(count), style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
