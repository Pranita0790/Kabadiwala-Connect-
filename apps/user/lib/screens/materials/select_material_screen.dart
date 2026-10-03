import 'package:flutter/material.dart';

class SelectMaterialScreen extends StatefulWidget {
  const SelectMaterialScreen({super.key});

  @override
  State<SelectMaterialScreen> createState() => _SelectMaterialScreenState();
}

class _SelectMaterialScreenState extends State<SelectMaterialScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Materials'),
      ),
      body: const Center(
        child: Text(
          'Select Materials',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
