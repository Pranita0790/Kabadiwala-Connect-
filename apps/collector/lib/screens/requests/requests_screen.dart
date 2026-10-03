import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/pickup_request.dart';
import '../../repositories/pickup_request_repository.dart';
import 'request_details_screen.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PickupRequestRepository _repository = PickupRequestRepository();
  bool _isLoading = true;
  List<PickupRequest> _allRequests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final reqs = await _repository.getAllRequests();
      if (mounted) {
        setState(() {
          _allRequests = reqs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<PickupRequest> _getFilteredRequests(String tab) {
    if (tab == 'pending') {
      return _allRequests.where((r) => r.status == 'PENDING').toList();
    } else if (tab == 'active') {
      return _allRequests
          .where((r) => r.status == 'ACCEPTED' || r.status == 'ON_MY_WAY' || r.status == 'COLLECTING')
          .toList();
    } else {
      return _allRequests.where((r) => r.status == 'COMPLETED' || r.status == 'REJECTED' || r.status == 'CANCELLED').toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingRequests = _getFilteredRequests('pending');
    final activeRequests = _getFilteredRequests('active');
    final completedRequests = _getFilteredRequests('completed');

    return Scaffold(
      backgroundColor: AppColors.limeBackground,
      appBar: AppBar(
        title: const Text('Pickup Requests'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: 'Pending (${pendingRequests.length})'),
            Tab(text: 'Active (${activeRequests.length})'),
            Tab(text: 'Completed (${completedRequests.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRequestList(pendingRequests, 'No pending pickup requests'),
                  _buildRequestList(activeRequests, 'No active pickup requests'),
                  _buildRequestList(completedRequests, 'No completed pickup requests'),
                ],
              ),
            ),
    );
  }

  Widget _buildRequestList(List<PickupRequest> requests, String emptyText) {
    if (requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: AppColors.primary.withAlpha(120)),
              const SizedBox(height: 16),
              Text(
                emptyText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        return _buildRequestCard(req);
      },
    );
  }

  Widget _buildRequestCard(PickupRequest req) {
    Color statusColor;
    String statusLabel;

    switch (req.status) {
      case 'PENDING':
        statusColor = AppColors.clayOrange;
        statusLabel = 'Pending';
        break;
      case 'ACCEPTED':
        statusColor = Colors.blue;
        statusLabel = 'Accepted';
        break;
      case 'ON_MY_WAY':
        statusColor = Colors.indigo;
        statusLabel = 'On My Way';
        break;
      case 'COLLECTING':
        statusColor = Colors.purple;
        statusLabel = 'Collecting';
        break;
      case 'COMPLETED':
        statusColor = AppColors.secondary;
        statusLabel = 'Completed';
        break;
      default:
        statusColor = AppColors.textMuted;
        statusLabel = req.status;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          final String? updatedStatus = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (context) => RequestDetailsScreen(requestId: req.id),
            ),
          );
          await _loadRequests();
          if (updatedStatus != null) {
            if (updatedStatus == 'ACCEPTED' || updatedStatus == 'ON_MY_WAY' || updatedStatus == 'COLLECTING') {
              _tabController.animateTo(1); // Auto-switch to Active tab
            } else if (updatedStatus == 'COMPLETED') {
              _tabController.animateTo(2); // Auto-switch to Completed tab
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      req.userName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.category_outlined, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${req.materialCategory} • ${req.materialName}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.scale_outlined, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Est. ${req.estimatedWeightKg} kg @ ₹${req.ratePerKg.toStringAsFixed(0)}/kg',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      req.preferredTimeSlot,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppColors.clayOrange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      req.pickupAddress,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
