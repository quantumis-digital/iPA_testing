import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import '../services/notification_service.dart';

class WaterReminderScreen extends StatefulWidget {
  const WaterReminderScreen({super.key});

  @override
  State<WaterReminderScreen> createState() => _WaterReminderScreenState();
}

class _WaterReminderScreenState extends State<WaterReminderScreen> {
  bool _enabled = false;
  int _intervalHours = 2;
  double _goalLiters = 2.0;
  TimeOfDay _startTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 21, minute: 0);
  bool _everyday = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await DBHelper.getSetting('water_enabled');
    final interval = await DBHelper.getSetting('water_interval_hours');
    final goal = await DBHelper.getSetting('water_goal_liters');
    final startHour = await DBHelper.getSetting('water_start_hour');
    final startMin = await DBHelper.getSetting('water_start_minute');
    final endHour = await DBHelper.getSetting('water_end_hour');
    final endMin = await DBHelper.getSetting('water_end_minute');
    final everyday = await DBHelper.getSetting('water_everyday');
    setState(() {
      _enabled = enabled == 'true';
      _intervalHours = int.tryParse(interval ?? '2') ?? 2;
      _goalLiters = double.tryParse(goal ?? '2.0') ?? 2.0;
      _startTime = TimeOfDay(
        hour: int.tryParse(startHour ?? '7') ?? 7,
        minute: int.tryParse(startMin ?? '0') ?? 0,
      );
      _endTime = TimeOfDay(
        hour: int.tryParse(endHour ?? '21') ?? 21,
        minute: int.tryParse(endMin ?? '0') ?? 0,
      );
      _everyday = (everyday ?? 'true') != 'false';
      _loading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await DBHelper.setSetting('water_enabled', _enabled ? 'true' : 'false');
      await DBHelper.setSetting('water_interval_hours', _intervalHours.toString());
      await DBHelper.setSetting('water_goal_liters', _goalLiters.toStringAsFixed(1));
      await DBHelper.setSetting('water_start_hour', _startTime.hour.toString());
      await DBHelper.setSetting('water_start_minute', _startTime.minute.toString());
      await DBHelper.setSetting('water_end_hour', _endTime.hour.toString());
      await DBHelper.setSetting('water_end_minute', _endTime.minute.toString());
      await DBHelper.setSetting('water_everyday', _everyday ? 'true' : 'false');

      if (_enabled) {
        await NotificationService().scheduleWaterReminders(
          startTime: _startTime,
          endTime: _endTime,
          intervalHours: _intervalHours,
          goalLiters: _goalLiters,
          everyday: _everyday,
        );
      } else {
        await NotificationService().cancelWaterReminders();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_enabled ? '💧 Water reminders scheduled!' : 'Water reminders turned off'),
          backgroundColor: _enabled ? const Color(0xFF0A84FF) : Colors.grey.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int get _slotCount {
    final startMins = _startTime.hour * 60 + _startTime.minute;
    final endMins = _endTime.hour * 60 + _endTime.minute;
    if (endMins <= startMins || _intervalHours == 0) return 0;
    return ((endMins - startMins) / (_intervalHours * 60)).floor() + 1;
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour;
    final min = t.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$min $ampm';
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF0A84FF)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => isStart ? _startTime = picked : _endTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FF),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero Header ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            backgroundColor: const Color(0xFF0A84FF),
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Water Reminder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0055FF), Color(0xFF00C6FF)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 72, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.water_drop, color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _enabled ? 'Active · $_slotCount reminders/day' : 'Currently off',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _statPill('${_goalLiters.toStringAsFixed(1)}L', 'Goal'),
                            const SizedBox(width: 10),
                            _statPill('Every ${_intervalHours}h', 'Interval'),
                            const SizedBox(width: 10),
                            _statPill('${_slotCount}x', 'Per Day'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Settings Cards ───────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Enable Toggle
                _card(
                  child: Row(
                    children: [
                      _iconBox(
                        Icons.notifications_active_outlined,
                        _enabled ? const Color(0xFF0A84FF) : Colors.grey,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Enable Reminders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(
                              _enabled ? 'Reminders are active' : 'Tap to activate',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _enabled,
                        activeColor: const Color(0xFF0A84FF),
                        onChanged: (v) => setState(() => _enabled = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Daily Goal Slider
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _iconBox(Icons.water_drop_outlined, const Color(0xFF0A84FF)),
                          const SizedBox(width: 16),
                          const Text('Daily Water Goal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text(
                            '${_goalLiters.toStringAsFixed(1)} L',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0A84FF)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 6,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                        ),
                        child: Slider(
                          value: _goalLiters,
                          min: 0.5,
                          max: 5.0,
                          divisions: 18,
                          activeColor: const Color(0xFF0A84FF),
                          inactiveColor: const Color(0xFF0A84FF).withValues(alpha: 0.15),
                          label: '${_goalLiters.toStringAsFixed(1)} L',
                          onChanged: (v) => setState(() => _goalLiters = v),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('0.5 L', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                          Text('5.0 L', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Interval Selector
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _iconBox(Icons.timer_outlined, const Color(0xFF5856D6)),
                          const SizedBox(width: 16),
                          const Text('Reminder Interval', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [1, 2, 3, 4, 6].map((h) {
                          final sel = _intervalHours == h;
                          return GestureDetector(
                            onTap: () => setState(() => _intervalHours = h),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                              decoration: BoxDecoration(
                                color: sel ? const Color(0xFF5856D6) : const Color(0xFF5856D6).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${h}h',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: sel ? Colors.white : const Color(0xFF5856D6),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Time Window
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _iconBox(Icons.schedule_outlined, const Color(0xFF34C759)),
                          const SizedBox(width: 16),
                          const Text('Active Time Window', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _timeTile('Start', _startTime, () => _pickTime(isStart: true))),
                          Container(width: 1, height: 56, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 16)),
                          Expanded(child: _timeTile('End', _endTime, () => _pickTime(isStart: false))),
                        ],
                      ),
                      if (_slotCount > 0) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF34C759).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 14, color: Color(0xFF34C759)),
                              const SizedBox(width: 8),
                              Text(
                                '$_slotCount reminders/day · ${(_goalLiters * 1000 / _slotCount).round()} ml each',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF34C759), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Repeat Option
                _card(
                  child: Row(
                    children: [
                      _iconBox(Icons.repeat_outlined, const Color(0xFFFF9500)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Repeat Schedule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(
                              _everyday ? 'Repeats every day' : 'Only for today',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFF9500).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            _repeatBtn('Today', !_everyday, () => setState(() => _everyday = false)),
                            _repeatBtn('Every Day', _everyday, () => setState(() => _everyday = true)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A84FF),
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Save & Apply',
                            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statPill(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _timeTile(String label, TimeOfDay time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 6),
          Text(_formatTime(time), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF0A84FF))),
          const SizedBox(height: 4),
          Text('Tap to change', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _repeatBtn(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF9500) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : const Color(0xFFFF9500),
          ),
        ),
      ),
    );
  }
}
