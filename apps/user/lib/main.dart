import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'models/sell_request.dart';
import 'models/vendor.dart';
import 'models/payment_record.dart';
import 'models/gate_pass.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/sell/select_material_screen.dart';
import 'screens/sell/create_request_screen.dart';
import 'screens/sell/request_status_screen.dart';
import 'screens/vendor/nearby_vendors_screen.dart';
import 'screens/vendor/vendor_details_screen.dart';
import 'screens/pickup/pickup_details_screen.dart';
import 'screens/pickup/scrap_collection_screen.dart';
import 'screens/payment/amount_calculation_screen.dart';
import 'screens/payment/payment_result_screen.dart';
import 'screens/payment/payment_history_screen.dart';
import 'screens/my_kabadiwala/my_kabadiwala_screen.dart';
import 'screens/my_kabadiwala/reminders_screen.dart';
import 'screens/my_kabadiwala/collection_history_screen.dart';
import 'screens/profile/user_profile_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/gate_pass/gate_pass_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KabadiwalaUserApp());
}

class KabadiwalaUserApp extends StatelessWidget {
  const KabadiwalaUserApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kabadiwala Connect - Customer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
          case '/splash':
            return MaterialPageRoute(builder: (_) => const SplashScreen());

          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());

          case '/signup':
            return MaterialPageRoute(builder: (_) => const SignupScreen());

          case '/home':
            return MaterialPageRoute(builder: (_) => const HomeScreen());

          case '/select-material':
            final arg = settings.arguments;
            final vendor = arg is Vendor ? arg : null;
            final category = arg is String ? arg : null;
            return MaterialPageRoute(
              builder: (_) => SelectMaterialScreen(
                selectedVendor: vendor,
                initialCategory: category,
              ),
            );

          case '/create-request':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => CreateRequestScreen(
                selectedMaterialNames: args?['materials'] as List<String>?,
                assignedVendor: args?['vendor'] as Vendor?,
              ),
            );

          case '/request-status':
            final request = settings.arguments as SellRequest?;
            return MaterialPageRoute(
              builder: (_) => RequestStatusScreen(request: request),
            );

          case '/nearby-vendors':
            final category = settings.arguments as String?;
            return MaterialPageRoute(
              builder: (_) => NearbyVendorsScreen(initialCategory: category),
            );

          case '/vendor-details':
            final vendor = settings.arguments as Vendor?;
            return MaterialPageRoute(
              builder: (_) => VendorDetailsScreen(vendor: vendor),
            );

          case '/pickup-details':
            final request = settings.arguments as SellRequest?;
            return MaterialPageRoute(
              builder: (_) => PickupDetailsScreen(request: request),
            );

          case '/scrap-collection':
            final request = settings.arguments as SellRequest?;
            return MaterialPageRoute(
              builder: (_) => ScrapCollectionScreen(request: request),
            );

          case '/amount-calculation':
            final request = settings.arguments as SellRequest?;
            return MaterialPageRoute(
              builder: (_) => AmountCalculationScreen(request: request),
            );

          case '/payment-result':
            final payment = settings.arguments as PaymentRecord?;
            return MaterialPageRoute(
              builder: (_) => PaymentResultScreen(payment: payment),
            );

          case '/payment-history':
            return MaterialPageRoute(builder: (_) => const PaymentHistoryScreen());

          case '/my-kabadiwala':
            return MaterialPageRoute(builder: (_) => const MyKabadiwalaScreen());

          case '/reminders':
            return MaterialPageRoute(builder: (_) => const RemindersScreen());

          case '/collection-history':
            return MaterialPageRoute(builder: (_) => const CollectionHistoryScreen());

          case '/profile':
            return MaterialPageRoute(builder: (_) => const UserProfileScreen());

          case '/edit-profile':
            return MaterialPageRoute(builder: (_) => const EditProfileScreen());

          case '/gate-pass':
            final pass = settings.arguments as GatePass?;
            return MaterialPageRoute(builder: (_) => GatePassScreen(gatePass: pass));

          default:
            return MaterialPageRoute(builder: (_) => const HomeScreen());
        }
      },
    );
  }
}
