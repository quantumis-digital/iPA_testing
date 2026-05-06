import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/item_photo_preview.dart';
import '../services/db_helper.dart';
import '../services/notification_service.dart';
import 'add_item_screen.dart';

class RoomItemsScreen extends StatefulWidget {
  final int houseId;
  final String roomName;

  const RoomItemsScreen({super.key, required this.houseId, required this.roomName});

  @override
  State<RoomItemsScreen> createState() => _RoomItemsScreenState();
}

class _RoomItemsScreenState extends State<RoomItemsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await DBHelper.getItemsForRoom(widget.houseId, widget.roomName);
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  String? _formatDate(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    final d = DateTime.tryParse(s);
    if (d == null) return s;
    return '${d.day}/${d.month}/${d.year}';
  }

  String _formatDateLabel(dynamic value) => _formatDate(value) ?? 'Not set';

  Future<void> _navigateToAddItem() async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddItemScreen(
          houseId: widget.houseId,
          roomName: widget.roomName,
        ),
      ),
    );

    if (changed == true) {
      _loadItems();
    }
  }

  Future<void> _openEdit(Map<String, dynamic> item) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddItemScreen(
          houseId: widget.houseId,
          roomName: widget.roomName,
          existingItem: item,
                  isViewOnly: true,
        ),
      ),
    );

    if (changed == true) {
      _loadItems();
    }
  }

  void _showItemDetail(Map<String, dynamic> item) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.paddingOf(ctx).bottom;
        final photo = itemPhotoPreview(item['imagePath']?.toString(), height: 200);
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                item['name'] as String? ?? 'Item',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 20),
              _detailRow(Icons.category_outlined, 'Category', '${item['category'] ?? '—'}'),
              _detailRow(Icons.place_outlined, 'Location', '${item['location'] ?? '—'}'),
              _detailRow(
                Icons.shopping_bag_outlined,
                'Purchase date',
                _formatDateLabel(item['purchaseDate']),
              ),
              _detailRow(
                Icons.event_busy_outlined,
                'Expiry date',
                _formatDateLabel(item['expiryDate']),
              ),
              if (photo != null) ...[
                const SizedBox(height: 16),
                photo,
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: BorderSide(color: AppColors.primaryBlue.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.primaryBlue.withValues(alpha: 0.85)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final name = item['name'] as String? ?? 'this item';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item'),
        content: Text('Remove "$name" from ${widget.roomName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final id = item['id'];
    final itemId = id is int ? id : (id as num).toInt();
    await NotificationService().cancelItemReminder(itemId);
    await DBHelper.deleteItem(itemId);
    if (!mounted) return;
    _loadItems();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"$name" removed')),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final purchase = _formatDate(item['purchaseDate']);
    final expiry = _formatDate(item['expiryDate']);
    final dateParts = <String>[];
    if (purchase != null) dateParts.add('Bought: $purchase');
    if (expiry != null) dateParts.add('Expires: $expiry');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(left: 4, right: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getCategoryIcon(item['category'] as String? ?? 'Other'),
                color: AppColors.primaryBlue,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'] as String? ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item['category'] ?? ''} • ${item['location'] ?? ''}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  if (dateParts.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      dateParts.join('   ·   '),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                  _buildExpiryBadge(item['expiryDate']),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility_outlined),
                  color: AppColors.primaryBlue,
                  tooltip: 'View',
                  iconSize: 22,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.zero,
                  onPressed: () => _showItemDetail(item),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  color: Colors.grey.shade800,
                  tooltip: 'Edit',
                  iconSize: 22,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.zero,
                  onPressed: () => _openEdit(item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red.shade400,
                  tooltip: 'Delete',
                  iconSize: 22,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.zero,
                  onPressed: () => _confirmDelete(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${widget.roomName} Items', style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.shade200,
            height: 1.0,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No items in ${widget.roomName} yet',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to add an item',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (context, index) => _buildItemCard(_items[index]),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddItem,
        backgroundColor: AppColors.primaryBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    if (category.contains('Document')) return Icons.description_outlined;
    if (category.contains('Electronic')) return Icons.devices_other_outlined;
    if (category.contains('Furniture')) return Icons.chair_outlined;
    if (category.contains('Clothing')) return Icons.checkroom_outlined;
    if (category.contains('Medical')) return Icons.medical_services_outlined;
    if (category.contains('Grocery')) return Icons.shopping_basket_outlined;
    return Icons.inventory_2_outlined;
  }

  Widget _buildExpiryBadge(dynamic expiryStr) {
    if (expiryStr == null || expiryStr.toString().isEmpty) return const SizedBox.shrink();
    
    final expDate = DateTime.tryParse(expiryStr.toString());
    if (expDate == null) return const SizedBox.shrink();

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

    return Container(
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
