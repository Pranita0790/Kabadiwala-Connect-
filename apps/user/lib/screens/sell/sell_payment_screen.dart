import 'package:flutter/material.dart';
import '../../models/sell_draft.dart';
import 'receive_upi_payment_screen.dart';

/// Legacy entry — redirects to UPI receive flow (customer gets paid).
class SellPaymentScreen extends StatelessWidget {
  final SellDraft draft;
  final String? existingRequestId;

  const SellPaymentScreen({
    super.key,
    required this.draft,
    this.existingRequestId,
  });

  @override
  Widget build(BuildContext context) {
    return ReceiveUpiPaymentScreen(
      draft: draft,
      existingRequestId: existingRequestId,
    );
  }
}
