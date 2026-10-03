import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../models/gate_pass.dart';
import '../../repositories/gate_pass_repository.dart';
import '../../repositories/user_profile_repository.dart';

class GatePassScreen extends StatefulWidget {
  final GatePass? gatePass;

  const GatePassScreen({super.key, this.gatePass});

  @override
  State<GatePassScreen> createState() => _GatePassScreenState();
}

class _GatePassScreenState extends State<GatePassScreen> {
  final GatePassRepository _repository = GatePassRepository();
  final UserProfileRepository _profileRepo = UserProfileRepository();

  @override
  void initState() {
    super.initState();
    _repository.addListener(_onRepoChange);
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepoChange);
    super.dispose();
  }

  void _onRepoChange() {
    if (mounted) setState(() {});
  }

  void _shareViaWhatsApp(GatePass pass) {
    final text = pass.whatsappShareText;
    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Gate Pass details copied to clipboard & formatted for WhatsApp!'),
        action: SnackBarAction(
          label: 'Paste in WhatsApp',
          textColor: AppColors.limeBackground,
          onPressed: () {},
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pass = widget.gatePass ?? _repository.activePass;

    if (pass == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Society Gate Pass')),
        body: const Center(child: Text('No active gate pass')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Security Gate Pass'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () => _shareViaWhatsApp(pass),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Official Society Passcard Ticket Container
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.cardBorder, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A134233),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Pass Top Banner (Pine Forest)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.shield_outlined, color: AppColors.limeBackground, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'SOCIETY GATE PASS',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                pass.status,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          pass.passId,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.limeBackground,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Authorized Scrap Collector Entry',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),

                  // Verification PIN Code Banner
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    color: AppColors.primarySoft,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'SECURITY GUARD VERIFICATION PIN',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Show PIN to gate security guard',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            pass.pinCode,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.limeBackground,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Pass Detail Rows
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildDetailRow(Icons.person, 'Collector Name', pass.collectorName),
                        const SizedBox(height: 14),
                        _buildDetailRow(Icons.phone, 'Collector Contact', pass.collectorPhone),
                        const SizedBox(height: 14),
                        _buildDetailRow(Icons.directions_car, 'Vehicle / Cart No.', pass.vehicleNumber),
                        const SizedBox(height: 14),
                        _buildDetailRow(Icons.home_work, 'Destination Address', pass.societyAddress),
                        const SizedBox(height: 14),
                        _buildDetailRow(Icons.access_time_filled, 'Scheduled Time', '${pass.entryDate}\n${pass.timeWindow}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Share via WhatsApp Primary Button
            ElevatedButton.icon(
              onPressed: () => _shareViaWhatsApp(pass),
              icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
              label: const Text('Share Gate Pass via WhatsApp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366), // WhatsApp Brand Green
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () {
                _showSchedulePassSheet(context);
              },
              icon: const Icon(Icons.add_moderator_rounded),
              label: const Text('Schedule New Gate Pass'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSchedulePassSheet(BuildContext context) {
    final profile = _profileRepo.profile;
    final nameCtrl = TextEditingController(text: 'Ramesh Kumar (Green Recyclers)');
    final phoneCtrl = TextEditingController(text: '+91 98765 43210');
    final vehicleCtrl = TextEditingController(text: 'MH-12-AB-3456');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Schedule Gate Pass',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Collector Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Collector Phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: vehicleCtrl,
                decoration: const InputDecoration(labelText: 'Vehicle / Handcart No.'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final newPass = _repository.createPass(
                    collectorName: nameCtrl.text.trim(),
                    collectorPhone: phoneCtrl.text.trim(),
                    vehicleNumber: vehicleCtrl.text.trim(),
                    residentName: profile.name,
                    residentPhone: profile.phone,
                    societyAddress: profile.fullAddress,
                    entryDate: 'Today, Oct 4, 2026',
                    timeWindow: '04:00 PM - 05:00 PM',
                  );
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gate Pass ${newPass.passId} created!')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Generate Gate Pass'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
