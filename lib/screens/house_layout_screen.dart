import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../services/db_helper.dart';
import 'room_items_screen.dart';

class RoomBlock {
  final int id;
  final String name;
  final IconData icon;
  Offset position;

  RoomBlock({
    required this.id,
    required this.name,
    required this.icon,
    required this.position,
  });
}

class HouseLayoutScreen extends StatefulWidget {
  final int houseId;
  final String title;
  final int bedrooms;
  final int bathrooms;
  final int halls;
  final int kitchens;

  const HouseLayoutScreen({
    super.key,
    required this.houseId,
    required this.title,
    required this.bedrooms,
    required this.bathrooms,
    required this.halls,
    required this.kitchens,
  });

  @override
  State<HouseLayoutScreen> createState() => _HouseLayoutScreenState();
}

class _HouseLayoutScreenState extends State<HouseLayoutScreen> {
  final List<RoomBlock> _rooms = [];

  @override
  void initState() {
    super.initState();
    _initializeRooms();
  }

  void _initializeRooms() {
    int idCounter = 1;
    double currentY = 50.0;
    double currentX = 50.0;

    void addRooms(int count, String name, IconData icon) {
      for (int i = 0; i < count; i++) {
        _rooms.add(RoomBlock(
          id: idCounter++,
          name: count > 1 ? '$name ${i + 1}' : name,
          icon: icon,
          position: Offset(currentX, currentY),
        ));
        
        currentX += 120.0;
        if (currentX > 250.0) {
          currentX = 50.0;
          currentY += 120.0;
        }
      }
    }

    addRooms(widget.halls, 'Hall', Icons.weekend_outlined);
    addRooms(widget.kitchens, 'Kitchen', Icons.kitchen_outlined);
    addRooms(widget.bedrooms, 'Bedroom', Icons.bed_outlined);
    addRooms(widget.bathrooms, 'Bathroom', Icons.bathtub_outlined);
  }

  void _navigateToRoom(RoomBlock room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoomItemsScreen(
          houseId: widget.houseId,
          roomName: room.name,
        ),
      ),
    );
  }

  void _showUniversalSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _UniversalSearchSheet(houseId: widget.houseId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: _showUniversalSearch,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.black),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Long press and drag blocks to rearrange the layout. Tap to enter.')),
              );
            },
          )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Background grid pattern for a blueprint feel
              Positioned.fill(
                child: CustomPaint(
                  painter: GridPainter(),
                ),
              ),
              // Rooms
              ..._rooms.map((room) {
                return Positioned(
                  left: room.position.dx,
                  top: room.position.dy,
                  child: GestureDetector(
                    onTap: () => _navigateToRoom(room),
                    child: Draggable<RoomBlock>(
                      data: room,
                      feedback: Material(
                        color: Colors.transparent,
                        child: _buildRoomBlock(room, isDragging: true),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: _buildRoomBlock(room),
                      ),
                      onDragEnd: (details) {
                        setState(() {
                          final RenderBox renderBox = context.findRenderObject() as RenderBox;
                          final localPos = renderBox.globalToLocal(details.offset);
                          double dx = localPos.dx;
                          double dy = localPos.dy - Scaffold.of(context).appBarMaxHeight!;
                          dx = dx.clamp(0.0, constraints.maxWidth - 100);
                          dy = dy.clamp(0.0, constraints.maxHeight - 100);
                          room.position = Offset(dx, dy);
                        });
                      },
                      child: _buildRoomBlock(room),
                    ),
                  ),
                );
              }),
            ],
          );
        }
      ),
    );
  }

  Widget _buildRoomBlock(RoomBlock room, {bool isDragging = false}) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: isDragging ? 0.8 : 0.3),
          width: isDragging ? 3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDragging ? 0.15 : 0.05),
            blurRadius: isDragging ? 15 : 5,
            spreadRadius: isDragging ? 2 : 0,
            offset: Offset(0, isDragging ? 8 : 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(room.icon, size: 36, color: AppColors.primaryBlue),
          const SizedBox(height: 8),
          Text(
            room.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _UniversalSearchSheet extends StatefulWidget {
  final int houseId;
  const _UniversalSearchSheet({required this.houseId});

  @override
  State<_UniversalSearchSheet> createState() => _UniversalSearchSheetState();
}

class _UniversalSearchSheetState extends State<_UniversalSearchSheet> {
  String _query = '';
  List<Map<String, dynamic>> _results = [];

  String _itemDateSuffix(Map<String, dynamic> item) {
    String fmt(dynamic v) {
      if (v == null) return '';
      final s = v.toString().trim();
      if (s.isEmpty) return '';
      final d = DateTime.tryParse(s);
      if (d == null) return '';
      return '${d.day}/${d.month}/${d.year}';
    }

    final p = fmt(item['purchaseDate']);
    final e = fmt(item['expiryDate']);
    final bits = <String>[];
    if (p.isNotEmpty) bits.add('Bought $p');
    if (e.isNotEmpty) bits.add('Expires $e');
    if (bits.isEmpty) return '';
    return '\n${bits.join(' · ')}';
  }

  void _searchItems(String query) async {
    if (query.isEmpty) {
      setState(() {
        _query = query;
        _results = [];
      });
      return;
    }
    final results = await DBHelper.searchItemsInHouse(widget.houseId, query);
    setState(() {
      _query = query;
      _results = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search items in this house...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: _searchItems,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty ? 'Type to search...' : 'No items found',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      return Card(
                        elevation: 0,
                        color: Colors.grey.shade100,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'In: ${item['roomName']} • ${item['location']}${_itemDateSuffix(item)}',
                            maxLines: 4,
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RoomItemsScreen(
                                  houseId: widget.houseId,
                                  roomName: item['roomName'],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;

    const double step = 20.0;

    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

