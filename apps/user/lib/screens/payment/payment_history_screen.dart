import 'package:flutter/material.dart';
import '../../widgets/demo_screen.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return const DemoScreen(
      title: 'Payment History',
      intro: 'Example payment records for your collections.',
      icon: Icons.account_balance_wallet,
      items: [
        DemoScreenItem(icon: Icons.payments, title: 'E-waste pickup', subtitle: '18 Sep 2026 · Demo payment', trailing: '₹1,250'),
        DemoScreenItem(icon: Icons.payments, title: 'Mixed scrap', subtitle: '04 Sep 2026 · Demo payment', trailing: '₹640'),
      ],
    );
  }
}
