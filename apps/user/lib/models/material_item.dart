import 'package:flutter/material.dart';

class MaterialItem {
  final String id;
  final String name;
  final String category;
  final IconData icon;
  final String averageRateHint;
  final String description;

  const MaterialItem({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.averageRateHint,
    required this.description,
  });

  double get defaultRatePerKg {
    switch (category.toLowerCase()) {
      case 'paper':
        return 14.0;
      case 'metal':
        return 42.0;
      case 'plastic':
        return 22.0;
      case 'e-waste':
      case 'ewaste':
        return 120.0;
      default:
        return 15.0;
    }
  }

  static List<MaterialItem> get defaultMaterials => const [
        MaterialItem(
          id: 'paper',
          name: 'Paper & Cardboard',
          category: 'Paper',
          icon: Icons.description_outlined,
          averageRateHint: '₹12 - ₹16 / kg',
          description: 'Newspapers, cartons, books, cardboard boxes.',
        ),
        MaterialItem(
          id: 'metal',
          name: 'Metals & Scrap',
          category: 'Metal',
          icon: Icons.build_outlined,
          averageRateHint: '₹35 - ₹450 / kg',
          description: 'Iron, copper wire, aluminum cans, brass fittings.',
        ),
        MaterialItem(
          id: 'plastic',
          name: 'Plastics & PET',
          category: 'Plastic',
          icon: Icons.recycling_outlined,
          averageRateHint: '₹20 - ₹30 / kg',
          description: 'PET bottles, hard plastic containers, buckets.',
        ),
        MaterialItem(
          id: 'ewaste',
          name: 'E-Waste & Electronics',
          category: 'E-waste',
          icon: Icons.devices_outlined,
          averageRateHint: '₹80 - ₹150 / kg',
          description: 'Old laptops, PCBs, mobile batteries, household appliances.',
        ),
        MaterialItem(
          id: 'mixed',
          name: 'Other / Mixed Scrap',
          category: 'Other',
          icon: Icons.widgets_outlined,
          averageRateHint: 'Variable rates',
          description: 'Mixed household waste, glass bottles, rubber scrap.',
        ),
      ];
}
