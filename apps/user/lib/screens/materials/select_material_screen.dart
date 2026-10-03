import 'package:flutter/material.dart';
import '../../widgets/demo_screen.dart';

class SelectMaterialScreen extends StatefulWidget {
  const SelectMaterialScreen({super.key});

  @override
  State<SelectMaterialScreen> createState() => _SelectMaterialScreenState();
}

class _SelectMaterialScreenState extends State<SelectMaterialScreen> {
  @override
  Widget build(BuildContext context) {
    return const DemoScreen(
      title: 'Sell Scrap',
      intro: 'Choose materials to prepare a pickup request.',
      icon: Icons.recycling,
      actionLabel: 'Continue',
      items: [
        DemoScreenItem(icon: Icons.phone_android, title: 'Mobile phones', subtitle: 'Old or damaged phones', trailing: '₹180/kg'),
        DemoScreenItem(icon: Icons.computer, title: 'Computer parts', subtitle: 'Boards, cables and accessories', trailing: '₹260/kg'),
        DemoScreenItem(icon: Icons.battery_full, title: 'Batteries', subtitle: 'Keep separate from other items', trailing: '₹90/kg'),
      ],
    );
  }
}
