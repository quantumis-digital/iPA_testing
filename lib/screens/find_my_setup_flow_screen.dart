import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/db_helper.dart';
import '../utils/app_colors.dart';
import '../utils/item_image_storage.dart';
import 'home_screen.dart';

class FindMySetupFlowScreen extends StatefulWidget {
  const FindMySetupFlowScreen({super.key});

  @override
  State<FindMySetupFlowScreen> createState() => _FindMySetupFlowScreenState();
}

class _FindMySetupFlowScreenState extends State<FindMySetupFlowScreen> {
  final Map<String, int> _counts = {
    'Hall': 1,
    'Bedroom': 1,
    'Kitchen': 1,
    'Bathroom': 1,
    'Others': 0,
  };

  final List<_RoomPhotoEntry> _roomsToCapture = [];
  int _photoIndex = 0;
  bool _saving = false;
  int _step = 0;

  void _buildRoomCaptureQueue() {
    _roomsToCapture.clear();
    int order = 0;
    for (final roomType in ['Hall', 'Bedroom', 'Kitchen', 'Bathroom', 'Others']) {
      final count = _counts[roomType] ?? 0;
      for (int i = 0; i < count; i++) {
        final name = count == 1 ? roomType : '$roomType ${i + 1}';
        _roomsToCapture.add(_RoomPhotoEntry(roomName: name, sortOrder: order++));
      }
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (file == null) return;
    final savedPath = await persistPickedImage(file.path);
    if (savedPath == null) return;
    setState(() {
      _roomsToCapture[_photoIndex].photoPath = savedPath;
    });
  }

  Future<void> _finishSetup() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final hallCount = _counts['Hall'] ?? 0;
      final bedroomCount = _counts['Bedroom'] ?? 0;
      final kitchenCount = _counts['Kitchen'] ?? 0;
      final bathroomCount = _counts['Bathroom'] ?? 0;

      final houseId = await DBHelper.insertHouse({
        'title': 'My Home',
        'bedrooms': bedroomCount,
        'bathrooms': bathroomCount,
        'halls': hallCount,
        'kitchens': kitchenCount,
      });

      await DBHelper.replaceRoomPhotosForHouse(
        houseId,
        _roomsToCapture
            .where((entry) => entry.photoPath != null)
            .map(
              (entry) => {
                'roomName': entry.roomName,
                'photoPath': entry.photoPath!,
                'sortOrder': entry.sortOrder,
              },
            )
            .toList(),
      );
      await DBHelper.setFindMySetupCompleted(true);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildWelcomeStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, size: 40, color: AppColors.iconOrange),
          ),
          const SizedBox(height: 32),
          const Text(
            'Welcome to KOFO',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              color: Color(0xFF06194A),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Your smart home organizer. Let's arrange your space together.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              height: 1.4,
              color: AppColors.primaryBlue.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 52),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: () => setState(() => _step = 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06194A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text(
                'Get Started',
                style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configure Your Home',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Color(0xFF06194A)),
          ),
          const SizedBox(height: 8),
          Text(
            'How many rooms are we organizing today?',
            style: TextStyle(fontSize: 20, color: AppColors.primaryBlue.withValues(alpha: 0.72)),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                _countCard('Hall', Icons.weekend_outlined),
                _countCard('Bedroom', Icons.bed_outlined),
                _countCard('Kitchen', Icons.kitchen_outlined),
                _countCard('Bathroom', Icons.bathtub_outlined),
                _countCard('Others', Icons.dashboard_outlined),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                _buildRoomCaptureQueue();
                setState(() {
                  _photoIndex = 0;
                  _step = 2;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.iconOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text(
                'Continue to Photos',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countCard(String roomType, IconData icon) {
    final value = _counts[roomType] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.iconOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.iconOrange),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              roomType == 'Others' ? 'Other Spaces' : '${roomType}s',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: Color(0xFF06194A)),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF2F5FB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      final min = roomType == 'Others' ? 0 : 1;
                      _counts[roomType] = (value - 1).clamp(min, 10);
                    });
                  },
                  icon: const Icon(Icons.remove, color: Color(0xFF9AA9C1)),
                ),
                Text('$value', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => setState(() => _counts[roomType] = (value + 1).clamp(0, 10)),
                  icon: const Icon(Icons.add, color: Color(0xFF9AA9C1)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoStep() {
    if (_roomsToCapture.isEmpty) {
      return const SizedBox.shrink();
    }
    final current = _roomsToCapture[_photoIndex];
    final progress = (_photoIndex + 1) / _roomsToCapture.length;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _step = 1),
                icon: const Icon(Icons.arrow_back, color: Color(0xFF6A7B98)),
              ),
              const SizedBox(width: 10),
              Text(
                'Room ${_photoIndex + 1} of ${_roomsToCapture.length}',
                style: const TextStyle(
                  color: Color(0xFF8A99B0),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: const Color(0xFFE6ECF5),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.iconOrange),
            ),
          ),
          const SizedBox(height: 36),
          Text(
            current.roomName,
            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: Color(0xFF06194A)),
          ),
          const SizedBox(height: 8),
          Text(
            'Capture a clear photo of this space',
            style: TextStyle(fontSize: 20, color: AppColors.primaryBlue.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFD8DFEA), width: 2, strokeAlign: BorderSide.strokeAlignInside),
              ),
              child: current.photoPath == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: AppColors.iconOrange.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_outlined, color: AppColors.iconOrange, size: 44),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: 220,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _pickPhoto,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF06194A),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                              ),
                              child: const Text(
                                'Take Photo',
                                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.file(
                        File(current.photoPath!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          if (current.photoPath != null)
            TextButton(
              onPressed: _pickPhoto,
              child: const Text('Retake photo', style: TextStyle(fontSize: 16, color: AppColors.iconOrange)),
            ),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: current.photoPath == null
                  ? null
                  : () async {
                      if (_photoIndex < _roomsToCapture.length - 1) {
                        setState(() => _photoIndex += 1);
                        return;
                      }
                      await _finishSetup();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: current.photoPath == null ? Colors.grey.shade300 : AppColors.iconOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text(
                _photoIndex == _roomsToCapture.length - 1
                    ? (_saving ? 'Saving...' : 'Finish Setup')
                    : 'Next Room',
                style: TextStyle(
                  color: current.photoPath == null ? Colors.grey.shade600 : Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFB),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: _step == 0
              ? _buildWelcomeStep()
              : _step == 1
                  ? _buildCountStep()
                  : _buildPhotoStep(),
        ),
      ),
    );
  }
}

class _RoomPhotoEntry {
  final String roomName;
  final int sortOrder;
  String? photoPath;

  _RoomPhotoEntry({
    required this.roomName,
    required this.sortOrder,
  });
}
