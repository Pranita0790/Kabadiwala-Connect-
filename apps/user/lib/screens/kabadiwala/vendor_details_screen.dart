import 'package:flutter/material.dart';

class VendorDetailsScreen extends StatefulWidget {
  const VendorDetailsScreen({super.key});

  @override
  State<VendorDetailsScreen> createState() => _VendorDetailsScreenState();
}

class _VendorDetailsScreenState extends State<VendorDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Details'),
      ),
      body: const Center(
        child: Text(
          'Vendor Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
