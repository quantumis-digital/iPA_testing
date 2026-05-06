import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../services/db_helper.dart';
import 'house_layout_screen.dart';

/// Compact layout tag, e.g. [2b3H1k] → 2 bedrooms, 3 halls, 1 kitchen.
String formatHouseLayoutCode(int bedrooms, int halls, int kitchens) {
  return '${bedrooms}b${halls}H${kitchens}k';
}

class FindThingsScreen extends StatefulWidget {
  const FindThingsScreen({super.key});

  @override
  State<FindThingsScreen> createState() => _FindThingsScreenState();
}

class _FindThingsScreenState extends State<FindThingsScreen> {
  List<Map<String, dynamic>> _customHouses = [];

  @override
  void initState() {
    super.initState();
    _loadHouses();
  }

  Future<void> _loadHouses() async {
    final houses = await DBHelper.getHouses();
    setState(() {
      _customHouses = houses;
    });
  }

  void _navigateToLayout(BuildContext context, int houseId, String title, int bed, int bath, int hall, int kitchen) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HouseLayoutScreen(
          houseId: houseId,
          title: title,
          bedrooms: bed,
          bathrooms: bath,
          halls: hall,
          kitchens: kitchen,
        ),
      ),
    );
  }

  void _showCustomHouseDialog(BuildContext screenContext) {
    final nameController = TextEditingController();
    final bedController = TextEditingController(text: '1');
    final bathController = TextEditingController(text: '1');
    final hallController = TextEditingController(text: '1');
    final kitchenController = TextEditingController(text: '1');

    showDialog(
      context: screenContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, setDialogState) {
            int parseCount(TextEditingController c, int fallback) {
              final n = int.tryParse(c.text.trim());
              if (n == null || n < 1) return fallback;
              return n;
            }

            final bed = parseCount(bedController, 1);
            final bath = parseCount(bathController, 1);
            final hall = parseCount(hallController, 1);
            final kitchen = parseCount(kitchenController, 1);
            final code = formatHouseLayoutCode(bed, hall, kitchen);
            final nameTrim = nameController.text.trim();
            final previewTitle = nameTrim.isEmpty ? 'Custom House $code' : '$nameTrim $code';

            void onCountChanged() => setDialogState(() {});

            return AlertDialog(
              title: const Text('Custom House Details'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'House Name (optional)',
                        hintText: 'e.g. Lake View',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 8),
                    _buildDialogNumberField(bedController, 'Bedrooms', onCountChanged),
                    _buildDialogNumberField(bathController, 'Bathrooms', onCountChanged),
                    _buildDialogNumberField(hallController, 'Halls', onCountChanged),
                    _buildDialogNumberField(kitchenController, 'Kitchens', onCountChanged),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.iconBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Layout code',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            code,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$bed bed · $bath bath · $hall hall · $kitchen kitchen',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    nameController.dispose();
                    bedController.dispose();
                    bathController.dispose();
                    hallController.dispose();
                    kitchenController.dispose();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                  onPressed: () async {
                    final id = await DBHelper.insertHouse({
                      'title': previewTitle,
                      'bedrooms': bed,
                      'bathrooms': bath,
                      'halls': hall,
                      'kitchens': kitchen,
                    });
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    nameController.dispose();
                    bedController.dispose();
                    bathController.dispose();
                    hallController.dispose();
                    kitchenController.dispose();
                    _loadHouses();
                    if (!screenContext.mounted) return;
                    _navigateToLayout(screenContext, id, previewTitle, bed, bath, hall, kitchen);
                  },
                  child: const Text('Create', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDialogNumberField(TextEditingController controller, String label, VoidCallback onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        onChanged: (_) => onChanged(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Find My Things',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.shade200,
            height: 1.0,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search for an item (e.g. Passport)',
                  hintStyle: TextStyle(color: Colors.black38),
                  prefixIcon: Icon(Icons.search, color: Colors.black38),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Select House Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildHouseTypeCard(
                    '1 BHK',
                    onTap: () => _navigateToLayout(context, -1, '1 BHK Layout', 1, 1, 1, 1),
                  ),
                  _buildHouseTypeCard(
                    '2 BHK',
                    onTap: () => _navigateToLayout(context, -2, '2 BHK Layout', 2, 2, 1, 1),
                  ),
                  _buildHouseTypeCard(
                    '3 BHK',
                    onTap: () => _navigateToLayout(context, -3, '3 BHK Layout', 3, 3, 1, 1),
                  ),
                  ..._customHouses.map((house) {
                    return _buildHouseTypeCard(
                      house['title'],
                      icon: Icons.holiday_village_outlined,
                      onTap: () => _navigateToLayout(
                        context,
                        house['id'],
                        house['title'],
                        house['bedrooms'],
                        house['bathrooms'],
                        house['halls'],
                        house['kitchens'],
                      ),
                    );
                  }),
                  _buildHouseTypeCard(
                    'Create Custom House',
                    icon: Icons.add_home_outlined,
                    onTap: () => _showCustomHouseDialog(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHouseTypeCard(String title, {IconData icon = Icons.home_outlined, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FE), 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.iconBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

