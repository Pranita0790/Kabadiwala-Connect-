import 'package:flutter/material.dart';
import '../../widgets/demo_screen.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  @override
  Widget build(BuildContext context) {
    return const DemoScreen(
      title: 'Reminders',
      intro: 'Helpful reminders for your recycling activity.',
      icon: Icons.notifications_active,
      items: [
        DemoScreenItem(icon: Icons.recycling, title: 'Sort your e-waste', subtitle: 'Keep batteries separate before pickup'),
        DemoScreenItem(icon: Icons.calendar_month, title: 'Schedule a pickup', subtitle: 'Choose a convenient collection time'),
      ],
    );
  }
}
