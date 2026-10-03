import 'package:flutter/material.dart';

class SellRequestSummaryScreen extends StatefulWidget {
  const SellRequestSummaryScreen({super.key});

  @override
  State<SellRequestSummaryScreen> createState() => _SellRequestSummaryScreenState();
}

class _SellRequestSummaryScreenState extends State<SellRequestSummaryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sell Request Summary'),
      ),
      body: const Center(
        child: Text(
          'Sell Request Summary',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
