import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class ReminderItem {
  final String id;
  final String title;
  final String frequency;
  final String preferredDay;
  final String preferredTime;
  final String vendorName;
  bool isEnabled;

  ReminderItem({
    required this.id,
    required this.title,
    required this.frequency,
    required this.preferredDay,
    required this.preferredTime,
    required this.vendorName,
    this.isEnabled = true,
  });
}

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({Key? key}) : super(key: key);

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final List<ReminderItem> _reminders = [
    ReminderItem(
      id: '1',
      title: 'Weekly Newspaper Collection',
      frequency: 'Every Week',
      preferredDay: 'Sunday',
      preferredTime: '10:00 AM - 12:00 PM',
      vendorName: 'Ramesh Kumar (Green Recyclers)',
      isEnabled: true,
    ),
    ReminderItem(
      id: '2',
      title: 'Bi-Weekly Cardboard & Plastic',
      frequency: 'Every 2 Weeks',
      preferredDay: '1st & 3rd Saturday',
      preferredTime: '02:00 PM - 04:00 PM',
      vendorName: 'Ramesh Kumar (Green Recyclers)',
      isEnabled: true,
    ),
    ReminderItem(
      id: '3',
      title: 'Monthly E-Waste & Metal Cleanout',
      frequency: 'Monthly',
      preferredDay: 'Last Sunday',
      preferredTime: '11:00 AM - 01:00 PM',
      vendorName: 'Vijay Scrap Traders',
      isEnabled: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pickup Reminders'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alarm_on_rounded, color: AppColors.primary, size: 32),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Never Miss a Scrap Day',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Set recurring reminders for regular scrap collections from your preferred Kabadiwala.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Active Reminders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            ..._reminders.map((reminder) => _buildReminderCard(reminder)).toList(),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: () {
                _showAddReminderSheet(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('Schedule New Reminder'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(ReminderItem reminder) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: AppColors.surface,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    reminder.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: reminder.isEnabled ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ),
                Switch(
                  value: reminder.isEnabled,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() {
                      reminder.isEnabled = val;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.repeat_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '${reminder.frequency} • ${reminder.preferredDay}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  reminder.preferredTime,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.storefront_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  reminder.vendorName,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: AppColors.border),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: reminder.isEnabled
                      ? () {
                          Navigator.of(context).pushNamed('/select-material');
                        }
                      : null,
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Request Pickup Now'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddReminderSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Schedule Reminder',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Reminder Name',
                  hintText: 'e.g. Newspaper & Cardboard Routine',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: 'Every Week',
                decoration: const InputDecoration(labelText: 'Frequency'),
                items: const [
                  DropdownMenuItem(value: 'Every Week', child: Text('Every Week', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'Every 2 Weeks', child: Text('Every 2 Weeks', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'Monthly', child: Text('Monthly', maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) {},
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: 'Sunday',
                decoration: const InputDecoration(labelText: 'Preferred Day'),
                items: const [
                  DropdownMenuItem(value: 'Sunday', child: Text('Sunday', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'Saturday', child: Text('Saturday', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'Wednesday', child: Text('Wednesday', maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) {},
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reminder set successfully!')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Save Reminder'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
