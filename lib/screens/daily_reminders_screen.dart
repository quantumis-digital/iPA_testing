import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import '../services/notification_service.dart';
import '../utils/app_colors.dart';

// ── Day helpers ──────────────────────────────────────────────────────────────
const _dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

List<int> _parseDays(String raw) {
  if (raw == 'everyday') return [];
  return raw
      .split(',')
      .map((s) => int.tryParse(s.trim()) ?? 0)
      .where((d) => d >= 1 && d <= 7)
      .toList();
}

String _encodeDays(List<int> days) {
  if (days.isEmpty || days.length == 7) return 'everyday';
  final sorted = days.toList()..sort();
  return sorted.join(',');
}

String _daysLabel(String raw) {
  if (raw == 'everyday') return 'Every Day';
  final days = _parseDays(raw);
  if (days.length == 7) return 'Every Day';
  return days.map((d) => _dayNames[d]).join(', ');
}

String _formatTime(int hour, int minute) {
  final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  final ampm = hour >= 12 ? 'PM' : 'AM';
  return '$h:${minute.toString().padLeft(2, '0')} $ampm';
}

// ── Accent colours for reminder cards ───────────────────────────────────────
const _cardAccents = [
  Color(0xFF5856D6),
  Color(0xFF0A84FF),
  Color(0xFF34C759),
  Color(0xFFFF9500),
  Color(0xFFFF2D55),
  Color(0xFF00C6FF),
  Color(0xFFAF52DE),
];

Color _accentFor(int id) => _cardAccents[id % _cardAccents.length];

// ── Main screen ──────────────────────────────────────────────────────────────
class DailyRemindersScreen extends StatefulWidget {
  const DailyRemindersScreen({super.key});

  @override
  State<DailyRemindersScreen> createState() => _DailyRemindersScreenState();
}

class _DailyRemindersScreenState extends State<DailyRemindersScreen> {
  List<Map<String, dynamic>> _reminders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DBHelper.getDailyReminders();
    if (mounted) setState(() { _reminders = rows; _loading = false; });
  }

  // ── Toggle enabled ────────────────────────────────────────────────────────
  Future<void> _toggleEnabled(Map<String, dynamic> r, bool val) async {
    await DBHelper.setDailyReminderEnabled(r['id'] as int, val);
    if (val) {
      await NotificationService().scheduleDailyReminder(
        id: r['id'] as int,
        title: r['title'] as String,
        body: (r['body'] as String?) ?? '',
        time: TimeOfDay(hour: r['hour'] as int, minute: r['minute'] as int),
        weekdays: _parseDays((r['days'] as String?) ?? 'everyday'),
      );
    } else {
      await NotificationService().cancelDailyReminder(r['id'] as int);
    }
    _load();
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<void> _delete(Map<String, dynamic> r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Reminder'),
        content: Text('Remove "${r['title']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await NotificationService().cancelDailyReminder(r['id'] as int);
    await DBHelper.deleteDailyReminder(r['id'] as int);
    _load();
  }

  // ── Open add / edit sheet ─────────────────────────────────────────────────
  void _openSheet({Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReminderSheet(
        existing: existing,
        onSaved: _load,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final activeCount = _reminders.where((r) => (r['enabled'] as int?) == 1).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.primaryBlue,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Daily Reminders',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF06194A), Color(0xFF1E3A8A)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 64, 24, 20),
                    child: Row(
                      children: [
                        _statChip('${_reminders.length}', 'Total'),
                        const SizedBox(width: 12),
                        _statChip('$activeCount', 'Active'),
                        const SizedBox(width: 12),
                        _statChip('${_reminders.length - activeCount}', 'Paused'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Body
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_reminders.isEmpty)
            SliverFillRemaining(
              child: _emptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _ReminderCard(
                    reminder: _reminders[i],
                    accent: _accentFor(_reminders[i]['id'] as int),
                    onToggle: (v) => _toggleEnabled(_reminders[i], v),
                    onEdit: () => _openSheet(existing: _reminders[i]),
                    onDelete: () => _delete(_reminders[i]),
                  ),
                  childCount: _reminders.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(),
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add_alarm, color: Colors.white),
        label: const Text('New Reminder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _statChip(String value, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
          ],
        ),
      );

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.alarm_outlined,
                  size: 64, color: AppColors.primaryBlue.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 20),
            const Text('No reminders yet',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Text('Tap the button below to create your first reminder',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          ],
        ),
      );
}

// ── Reminder card ────────────────────────────────────────────────────────────
class _ReminderCard extends StatelessWidget {
  final Map<String, dynamic> reminder;
  final Color accent;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReminderCard({
    required this.reminder,
    required this.accent,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = (reminder['enabled'] as int?) == 1;
    final timeStr = _formatTime(reminder['hour'] as int, reminder['minute'] as int);
    final daysStr = _daysLabel((reminder['days'] as String?) ?? 'everyday');
    final body = (reminder['body'] as String?) ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: enabled ? accent : Colors.grey.shade300, width: 4)),
        boxShadow: [
          BoxShadow(
              color: enabled
                  ? accent.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: Row(
              children: [
                // Time block
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: enabled ? accent.withValues(alpha: 0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(timeStr.split(' ')[0],
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: enabled ? accent : Colors.grey)),
                      Text(timeStr.split(' ')[1],
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: enabled ? accent : Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Text info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reminder['title'] as String,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: enabled ? const Color(0xFF1E293B) : Colors.grey)),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.repeat, size: 13, color: enabled ? accent : Colors.grey),
                          const SizedBox(width: 4),
                          Text(daysStr,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: enabled ? accent : Colors.grey,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                // Controls
                Column(
                  children: [
                    Switch.adaptive(
                      value: enabled,
                      activeColor: accent,
                      onChanged: onToggle,
                    ),
                    GestureDetector(
                      onTap: onDelete,
                      child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Add / Edit bottom sheet ──────────────────────────────────────────────────
class _ReminderSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;

  const _ReminderSheet({this.existing, required this.onSaved});

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  bool _everyday = true;
  final Set<int> _selectedDays = {};
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final r = widget.existing!;
      _titleCtrl.text = r['title'] as String;
      _bodyCtrl.text = (r['body'] as String?) ?? '';
      _time = TimeOfDay(hour: r['hour'] as int, minute: r['minute'] as int);
      final days = _parseDays((r['days'] as String?) ?? 'everyday');
      _everyday = days.isEmpty;
      _selectedDays.addAll(days);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryBlue),
        ),
        child: child!,
      ),
    );
    if (t != null) setState(() => _time = t);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reminder title')),
      );
      return;
    }
    if (!_everyday && _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day')),
      );
      return;
    }

    setState(() => _saving = true);

    final weekdays = _everyday ? <int>[] : _selectedDays.toList()..sort();
    final daysStr = _encodeDays(weekdays);

    final row = {
      'title': title,
      'body': _bodyCtrl.text.trim(),
      'hour': _time.hour,
      'minute': _time.minute,
      'days': daysStr,
      'enabled': 1,
    };

    int reminderId;
    if (_isEdit) {
      reminderId = widget.existing!['id'] as int;
      await DBHelper.updateDailyReminder(reminderId, row);
    } else {
      reminderId = await DBHelper.insertDailyReminder(row);
    }

    await NotificationService().scheduleDailyReminder(
      id: reminderId,
      title: title,
      body: _bodyCtrl.text.trim(),
      time: _time,
      weekdays: weekdays,
    );

    if (!mounted) return;
    Navigator.pop(context);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPad),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(_isEdit ? 'Edit Reminder' : 'New Reminder',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 20),

            // Title
            TextField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Title *',
                hintText: 'e.g. Take vitamins',
                prefixIcon: const Icon(Icons.title),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Body / Message
            TextField(
              controller: _bodyCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Message (optional)',
                hintText: 'e.g. Don\'t forget your supplements',
                prefixIcon: const Icon(Icons.notes),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Time Picker
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: AppColors.primaryBlue),
                    const SizedBox(width: 12),
                    const Text('Reminder Time',
                        style: TextStyle(fontSize: 15, color: Colors.black54)),
                    const Spacer(),
                    Text(_formatTime(_time.hour, _time.minute),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Everyday toggle
            Row(
              children: [
                const Icon(Icons.repeat, color: AppColors.primaryBlue),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Repeat Every Day',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                Switch.adaptive(
                  value: _everyday,
                  activeColor: AppColors.primaryBlue,
                  onChanged: (v) => setState(() {
                    _everyday = v;
                    if (v) _selectedDays.clear();
                  }),
                ),
              ],
            ),

            // Day selector
            if (!_everyday) ...[
              const SizedBox(height: 8),
              const Text('Select Days',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: List.generate(7, (i) {
                  final day = i + 1;
                  final sel = _selectedDays.contains(day);
                  return GestureDetector(
                    onTap: () => setState(() {
                      sel ? _selectedDays.remove(day) : _selectedDays.add(day);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primaryBlue : AppColors.primaryBlue.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_dayNames[day],
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: sel ? Colors.white : AppColors.primaryBlue)),
                    ),
                  );
                }),
              ),
            ],

            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text(_isEdit ? 'Update Reminder' : 'Save Reminder',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
