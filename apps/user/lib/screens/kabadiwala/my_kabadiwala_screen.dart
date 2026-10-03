import 'package:flutter/material.dart';
import '../../widgets/demo_screen.dart';

class MyKabadiwalaScreen extends StatefulWidget {
  const MyKabadiwalaScreen({super.key});

  @override
  State<MyKabadiwalaScreen> createState() => _MyKabadiwalaScreenState();
}

class _MyKabadiwalaScreenState extends State<MyKabadiwalaScreen> {
  @override
  Widget build(BuildContext context) {
    return const DemoScreen(
      title: 'My Kabadiwala',
      intro: 'Your connected local recycling partner.',
      icon: Icons.storefront,
      items: [
        DemoScreenItem(icon: Icons.person, title: 'Ramesh Scrap Centre', subtitle: 'Demo partner · 1.2 km away'),
        DemoScreenItem(icon: Icons.schedule, title: 'Pickup hours', subtitle: 'Today, 10:00 AM – 6:00 PM'),
        DemoScreenItem(icon: Icons.phone, title: 'Contact', subtitle: 'Contact details appear after connection'),
      ],
    );
  }
}
