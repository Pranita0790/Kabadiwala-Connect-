import 'package:flutter/material.dart';

class CollectionHistoryScreen extends StatefulWidget {
  const CollectionHistoryScreen({super.key});

  @override
  State<CollectionHistoryScreen> createState() => _CollectionHistoryScreenState();
}

class _CollectionHistoryScreenState extends State<CollectionHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection History'),
      ),
      body: const Center(
        child: Text(
          'Collection History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
