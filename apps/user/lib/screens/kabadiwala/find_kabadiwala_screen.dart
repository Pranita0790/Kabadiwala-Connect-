import 'package:flutter/material.dart';
import '../../widgets/demo_screen.dart';

class FindKabadiwalaScreen extends StatefulWidget {
  final String title;

  const FindKabadiwalaScreen({super.key, this.title = 'Find Kabadiwala'});

  @override
  State<FindKabadiwalaScreen> createState() => _FindKabadiwalaScreenState();
}

class _FindKabadiwalaScreenState extends State<FindKabadiwalaScreen> {
  @override
  Widget build(BuildContext context) {
    return DemoScreen(
      title: widget.title,
      intro: 'Nearby recycling partners accepting e-waste.',
      icon: Icons.location_on,
      actionLabel: 'View map',
      items: const [
        DemoScreenItem(icon: Icons.store, title: 'Ramesh Scrap Centre', subtitle: 'Open today · 1.2 km away', trailing: '4.8 ★'),
        DemoScreenItem(icon: Icons.store, title: 'Green Earth Recyclers', subtitle: 'Open today · 2.5 km away', trailing: '4.6 ★'),
        DemoScreenItem(icon: Icons.store, title: 'City E-waste Hub', subtitle: 'Open until 5:00 PM · 3.1 km away', trailing: '4.5 ★'),
      ],
    );
  }
}
