import 'package:flutter/material.dart';

class MyKabadiwalaScreen extends StatefulWidget {
  const MyKabadiwalaScreen({super.key});

  @override
  State<MyKabadiwalaScreen> createState() => _MyKabadiwalaScreenState();
}

class _MyKabadiwalaScreenState extends State<MyKabadiwalaScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Kabadiwala'),
      ),
      body: const Center(
        child: Text(
          'My Kabadiwala',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
