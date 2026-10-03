import 'package:flutter/material.dart';

class SellRequestScreen extends StatefulWidget {
  const SellRequestScreen({super.key});

  @override
  State<SellRequestScreen> createState() => _SellRequestScreenState();
}

class _SellRequestScreenState extends State<SellRequestScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sell Request'),
      ),
      body: const Center(
        child: Text(
          'Sell Request',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
