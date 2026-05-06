import 'dart:io';

import 'package:flutter/material.dart';

import '../services/db_helper.dart';
import '../utils/app_colors.dart';

class HouseMapScreen extends StatefulWidget {
  const HouseMapScreen({super.key});

  @override
  State<HouseMapScreen> createState() => _HouseMapScreenState();
}

class _HouseMapScreenState extends State<HouseMapScreen> {
  bool _loading = true;
  String _title = 'My Home Map';
  List<Map<String, dynamic>> _photos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final house = await DBHelper.getPrimaryHouse();
    if (house == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _photos = [];
        });
      }
      return;
    }

    final photos = await DBHelper.getRoomPhotosForHouse(house['id'] as int);
    if (!mounted) return;
    setState(() {
      _title = '${house['title'] ?? 'My Home'} Map';
      _photos = photos;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        title: Text(_title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
              ? Center(
                  child: Text(
                    'No room photos available yet.',
                    style: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.8), fontSize: 16),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.15)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.map_outlined, color: AppColors.primaryBlue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tap a room to view it full-screen and navigate your house visually.',
                              style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0C2A4A)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _photos.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.95,
                        ),
                        itemBuilder: (context, index) {
                          final entry = _photos[index];
                          return _MapRoomCard(
                            roomName: entry['roomName']?.toString() ?? 'Room',
                            photoPath: entry['photoPath']?.toString() ?? '',
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _MapRoomCard extends StatelessWidget {
  final String roomName;
  final String photoPath;

  const _MapRoomCard({
    required this.roomName,
    required this.photoPath,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _RoomPhotoViewer(roomName: roomName, photoPath: photoPath),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.file(
                  File(photoPath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stackTrace) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                roomName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF12284A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomPhotoViewer extends StatelessWidget {
  final String roomName;
  final String photoPath;

  const _RoomPhotoViewer({
    required this.roomName,
    required this.photoPath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(roomName),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: InteractiveViewer(
        maxScale: 4,
        child: Center(
          child: Image.file(File(photoPath), fit: BoxFit.contain),
        ),
      ),
    );
  }
}
