import 'package:flutter/material.dart';
import '../widgets/home_menu_card.dart';
import '../utils/app_colors.dart';
import '../services/db_helper.dart';
import 'find_things_screen.dart';
import 'house_layout_screen.dart';
import 'medical_wardrobe_screen.dart';
import 'inventory_screen.dart';
import 'reminders_screen.dart';
import 'house_map_screen.dart';
import 'daily_reminders_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopSection(context),
            const SizedBox(height: 24),
            Expanded(
              child: _buildMenuSection(context),
            ),
            _buildFooter(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 16.0, bottom: 32.0),
      decoration: const BoxDecoration(
        color: AppColors.primaryBlue,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HouseMapScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(100),
                  child: const Icon(
                    Icons.map_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Home Organizer',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          HomeMenuCard(
            icon: Icons.search,
            title: 'Find My Things',
            subtitle: 'Locate items in your home',
            iconBackgroundColor: AppColors.iconBlue,
            onTap: () => _openFindMyThings(context),
          ),
          HomeMenuCard(
            icon: Icons.notifications_none_outlined,
            title: 'Reminders',
            subtitle: 'Set and manage reminders',
            iconBackgroundColor: AppColors.iconOrange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RemindersScreen()),
              );
            },
          ),
          HomeMenuCard(
            icon: Icons.medical_services_outlined,
            title: 'Medical Wardrobe',
            subtitle: 'Track medicines & expiry',
            iconBackgroundColor: AppColors.iconRed,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MedicalWardrobeScreen()),
              );
            },
          ),
          HomeMenuCard(
            icon: Icons.inventory_2_outlined,
            title: 'Inventory',
            subtitle: 'Manage household items',
            iconBackgroundColor: AppColors.iconGreen,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InventoryScreen()),
              );
            },
          ),
          HomeMenuCard(
            icon: Icons.alarm_outlined,
            title: 'Daily Reminders',
            subtitle: 'Set and manage daily tasks',
            iconBackgroundColor: const Color(0xFF5856D6),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DailyRemindersScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Navigates directly to the primary house layout if one exists from the
  /// onboarding setup. Falls back to the manual template-selection screen
  /// only when no house has been configured yet.
  Future<void> _openFindMyThings(BuildContext context) async {
    final house = await DBHelper.getPrimaryHouse();
    if (!context.mounted) return;

    if (house != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HouseLayoutScreen(
            houseId: house['id'] as int,
            title: (house['title'] as String?) ?? 'My Home',
            bedrooms: (house['bedrooms'] as int?) ?? 1,
            bathrooms: (house['bathrooms'] as int?) ?? 1,
            halls: (house['halls'] as int?) ?? 1,
            kitchens: (house['kitchens'] as int?) ?? 1,
          ),
        ),
      );
    } else {
      // No house configured yet — show manual selection as fallback.
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FindThingsScreen()),
      );
    }
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Text(
        '"A place for everything, and everything in its place."',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textGrey.withValues(alpha: 0.6),
          fontStyle: FontStyle.italic,
          fontSize: 12,
        ),
      ),
    );
  }
}

