import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/customer.dart';
import '../../models/pickup_request.dart';
import '../../repositories/customer_repository.dart';
import '../../services/database_service.dart';
import '../requests/request_details_screen.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final String customerId;

  const CustomerDetailsScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  final CustomerRepository _repository = CustomerRepository();
  final DatabaseService _dbService = DatabaseService();

  bool _isLoading = true;
  Customer? _customer;
  List<PickupRequest> _history = [];

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    final cust = await _repository.getCustomerById(widget.customerId);
    final allReqs = await _dbService.getPickupRequests();
    final userReqs = allReqs.where((r) => r.userId == widget.customerId).toList();

    setState(() {
      _customer = cust;
      _history = userReqs;
      _isLoading = false;
    });
  }

  void _makeCall(String phone) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.phone, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Contact Customer'),
          ],
        ),
        content: Text('Phone number: $phone'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendReminder(String cadence) async {
    final cust = _customer;
    if (cust == null) return;
    final userId = cust.userPublicId ?? cust.id;
    final error = await _repository.sendReminder(
      userId: userId,
      cadence: cadence,
    );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cadence == 'MONTH'
              ? 'Monthly reminder sent to ${cust.name}'
              : 'Weekly reminder sent to ${cust.name}',
        ),
      ),
    );
    _loadDetails();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer Profile')),
        body: const Center(child: Text('Customer details not found')),
      );
    }

    final cust = _customer!;

    return Scaffold(
      backgroundColor: AppColors.limeBackground,
      appBar: AppBar(
        title: const Text('Customer Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        cust.name.isNotEmpty ? cust.name[0].toUpperCase() : 'C',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      cust.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(cust.phone, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    if (cust.isRegular)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.clayOrange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Regular customer',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.clayOrange,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _makeCall(cust.phone),
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text('Call Customer'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Statistics Metrics Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol('Pickups', '${cust.totalPickups}'),
                    Container(height: 40, width: 1, color: AppColors.cardBorder),
                    _buildStatCol('Weight', '${cust.totalWeightKg.toStringAsFixed(1)} kg'),
                    Container(height: 40, width: 1, color: AppColors.cardBorder),
                    _buildStatCol('Total Paid', '₹${cust.totalPaid.toStringAsFixed(0)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scrap reminder',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cust.suggestedCadence == 'MONTH'
                          ? '1 mahina inactive — monthly reminder suggest.'
                          : cust.suggestedCadence == 'WEEK'
                              ? '1 week inactive — weekly reminder suggest.'
                              : 'Send a nudge if raddi / paper / scrap nahi aaya.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _sendReminder('WEEK'),
                            icon: const Icon(Icons.notifications_active_outlined, size: 18),
                            label: const Text('1 week'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _sendReminder('MONTH'),
                            icon: const Icon(Icons.calendar_month_outlined, size: 18),
                            label: const Text('1 month'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Pickup Request History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: 12),

            if (_history.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(
                  child: Text('No past request history recorded.', style: TextStyle(color: AppColors.textMuted)),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final req = _history[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(
                        '${req.materialCategory} • ${req.materialName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                      ),
                      subtitle: Text('Status: ${req.status} • Est. ${req.estimatedWeightKg} kg'),
                      trailing: Text(
                        '₹${req.finalAmount != null ? req.finalAmount!.toStringAsFixed(0) : (req.estimatedWeightKg * req.ratePerKg).toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.clayOrange),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RequestDetailsScreen(requestId: req.id),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCol(String title, String val) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ],
    );
  }
}
