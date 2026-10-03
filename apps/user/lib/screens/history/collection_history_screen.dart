import 'package:flutter/material.dart';
import '../../widgets/demo_screen.dart';

class CollectionHistoryScreen extends StatefulWidget {
  const CollectionHistoryScreen({super.key});

  @override
  State<CollectionHistoryScreen> createState() => _CollectionHistoryScreenState();
}

class _CollectionHistoryScreenState extends State<CollectionHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return const DemoScreen(
      title: 'Collection History',
      intro: 'A preview of your recent collections.',
      icon: Icons.history,
      items: [
        DemoScreenItem(icon: Icons.check_circle, title: 'E-waste pickup', subtitle: '18 Sep 2026 · Demo entry', trailing: '12.5 kg'),
        DemoScreenItem(icon: Icons.check_circle, title: 'Mixed scrap', subtitle: '04 Sep 2026 · Demo entry', trailing: '8 kg'),
      ],
    );
  }
}
