import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/material_item.dart';
import '../../models/vendor.dart';
import '../../repositories/sell_request_repository.dart';
import '../../repositories/vendor_repository.dart';
import 'request_status_screen.dart';

class CreateRequestScreen extends StatefulWidget {
  final MaterialItem? selectedMaterial;
  final List<String>? selectedMaterialNames;
  final Vendor? assignedVendor;

  const CreateRequestScreen({
    super.key,
    this.selectedMaterial,
    this.selectedMaterialNames,
    this.assignedVendor,
  });

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final VendorRepository _vendorRepo = VendorRepository();
  final SellRequestRepository _sellRepo = SellRequestRepository();

  late TextEditingController _quantityController;
  late TextEditingController _locationController;
  late TextEditingController _notesController;

  Vendor? _selectedVendor;
  String _selectedTimeSlot = 'Today, 4:00 PM - 6:00 PM';

  final List<String> _timeSlots = [
    'Today, 4:00 PM - 6:00 PM',
    'Tomorrow, 10:00 AM - 12:00 PM',
    'Tomorrow, 2:00 PM - 4:00 PM',
    'Weekend, Morning Slot',
  ];

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '15 - 20 kg');
    _locationController = TextEditingController(text: 'B-402, Green Acres, Andheri East, Mumbai');
    _notesController = TextEditingController();

    _selectedVendor = widget.assignedVendor ?? _vendorRepo.connectedVendor ?? _vendorRepo.allVendors.first;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  MaterialItem get material =>
      widget.selectedMaterial ??
      (widget.selectedMaterialNames != null && widget.selectedMaterialNames!.isNotEmpty
          ? MaterialItem.defaultMaterials.firstWhere(
              (m) => m.name == widget.selectedMaterialNames!.first,
              orElse: () => MaterialItem.defaultMaterials.first,
            )
          : MaterialItem.defaultMaterials.first);

  void _submitRequest() {
    if (!_formKey.currentState!.validate() || _selectedVendor == null) return;

    final newReq = _sellRepo.createRequest(
      materialName: material.name,
      materialCategory: material.category,
      approximateQuantity: _quantityController.text.trim(),
      pickupLocation: _locationController.text.trim(),
      preferredTime: _selectedTimeSlot,
      note: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      vendor: _selectedVendor!,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RequestStatusScreen(requestId: newReq.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendors = _vendorRepo.allVendors;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Sell Request'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Material Header Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primarySoft,
                        child: Icon(material.icon, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              material.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textMain),
                            ),
                            Text(
                              'Category: ${material.category}',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Vendor Selection Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Kabadiwala Vendor',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Vendor>(
                        isExpanded: true,
                        value: _selectedVendor,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Vendor',
                          prefixIcon: Icon(Icons.storefront, color: AppColors.primary),
                        ),
                        items: vendors.map((v) {
                          final rate = v.ratesPerKg[material.category] ?? v.ratesPerKg.values.first;
                          return DropdownMenuItem(
                            value: v,
                            child: Text(
                              '${v.name} (${v.location}) - ₹${rate.toStringAsFixed(0)}/kg',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedVendor = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Request Details Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pickup Information',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Approximate Quantity',
                          hintText: 'e.g., 15 - 20 kg',
                          prefixIcon: Icon(Icons.scale, color: AppColors.primary),
                        ),
                        validator: (val) => (val == null || val.isEmpty) ? 'Please enter approximate quantity' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _locationController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Pickup Address Location',
                          prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.primary),
                        ),
                        validator: (val) => (val == null || val.isEmpty) ? 'Please enter pickup address' : null,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedTimeSlot,
                        decoration: const InputDecoration(
                          labelText: 'Preferred Time Slot',
                          prefixIcon: Icon(Icons.access_time, color: AppColors.primary),
                        ),
                        items: _timeSlots
                            .map((slot) => DropdownMenuItem(
                                  value: slot,
                                  child: Text(slot, maxLines: 1, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedTimeSlot = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Optional Note / Instructions',
                          hintText: 'e.g., Call before arrival / Gate code',
                          prefixIcon: Icon(Icons.note_alt_outlined, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _submitRequest,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Confirm & Send Request'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
