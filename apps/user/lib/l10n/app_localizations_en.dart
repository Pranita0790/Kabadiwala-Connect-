// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Kabadiwala Connect';

  @override
  String get home => 'Home';

  @override
  String get createLot => 'Create Lot';

  @override
  String get camera => 'Camera';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get takePhotoPrompt => 'Take or Choose Material Photo';

  @override
  String get retake => 'Retake';

  @override
  String get retakePhoto => 'Retake Photo';

  @override
  String get chooseGallery => 'Choose from Gallery';

  @override
  String get continueToDetails => 'Continue to Details';

  @override
  String get skipPhoto => 'Skip Photo';

  @override
  String get material => 'Material';

  @override
  String get selectCategory => 'Select Material Category';

  @override
  String get weight => 'Weight';

  @override
  String get enterWeight => 'Enter Weight (kg)';

  @override
  String get condition => 'Condition';

  @override
  String get selectCondition => 'Select Condition';

  @override
  String get conditionGood => 'Working (Good)';

  @override
  String get conditionAverage => 'Used (Average)';

  @override
  String get conditionScrap => 'Scrap (Broken)';

  @override
  String get save => 'Save';

  @override
  String get saveLot => 'Save Lot Locally';

  @override
  String get priceBoard => 'Price Board';

  @override
  String get indicativePrice => 'Indicative Price';

  @override
  String get listen => 'Listen';

  @override
  String get listening => 'Playing Audio...';

  @override
  String get earnings => 'Earnings';

  @override
  String get earningsLedger => 'Earnings Ledger';

  @override
  String get totalEarnings => 'Total Earnings';

  @override
  String get currentMonthEarnings => 'Current Month Earnings';

  @override
  String get paid => 'Paid';

  @override
  String get pending => 'Pending';

  @override
  String get paymentStatus => 'Payment Status';

  @override
  String get offline => 'Offline';

  @override
  String get offlineModeActive => 'Offline Mode Active • Saved in SQLite';

  @override
  String get onlineConnected => 'Online • Synced with Cloud';

  @override
  String get noInternet => 'No Internet';

  @override
  String get waitingForInternet => 'Waiting for internet';

  @override
  String get synced => 'Synced';

  @override
  String get syncing => 'Syncing...';

  @override
  String get failed => 'Failed';

  @override
  String get syncFailed => 'Sync Failed';

  @override
  String get pendingSync => 'Pending Sync';

  @override
  String get retry => 'Retry';

  @override
  String get retrySync => 'Retry Sync';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get lastUpdated => 'Last updated';

  @override
  String get updatedToday => 'Updated today';

  @override
  String get noTransactions => 'No transactions recorded yet.';

  @override
  String get noLots =>
      'No material lots recorded yet.\nTap \"Create Lot\" to start.';

  @override
  String get recordedLots => 'Recorded Lots';

  @override
  String get source => 'Source';

  @override
  String get location => 'Location';

  @override
  String get finalAmount => 'Final Amount';

  @override
  String get recycler => 'Recycler';

  @override
  String get refreshPrices => 'Refresh Rates';

  @override
  String get refreshLedger => 'Refresh Ledger';

  @override
  String get allTransactions => 'All Transactions';

  @override
  String get all => 'All';

  @override
  String get indicativeRates => 'Indicative Market Rates';

  @override
  String get liveRates => 'Live Market Rates';

  @override
  String get cachedOfflineRates => 'Cached Offline Rates (SQLite)';

  @override
  String get cachedOfflineLedger => 'Cached Offline Ledger (SQLite)';

  @override
  String get liveLedger => 'Live Transactions';

  @override
  String get optionalNotes => 'Optional Notes / Details';

  @override
  String get notesHint => 'e.g. Copper wire bundle, 2 CRT monitors';

  @override
  String get analyzingAi => 'Analyzing photo with AI...';

  @override
  String get suggestedAi => 'Suggested by AI';

  @override
  String get validWeightError => 'Please enter a valid weight (> 0 kg)';

  @override
  String get lotSavedSuccess => 'Material lot saved locally in SQLite!';

  @override
  String get language => 'Language';

  @override
  String get categoryPcb => 'Motherboard / PCB';

  @override
  String get categoryCopper => 'Copper Wire';

  @override
  String get categoryBattery => 'Batteries';

  @override
  String get categoryDisplay => 'Monitors & Displays';

  @override
  String get categoryAppliances => 'Heavy Electricals';

  @override
  String get categoryMixed => 'Mixed E-Waste';

  @override
  String get lotDetails => 'Lot Details';

  @override
  String get handoverToRecycler => 'Handover to Recycler';

  @override
  String get selectRecycler => 'Select Authorized Recycler';

  @override
  String get authorizedRecycler => 'Authorized Recycler';

  @override
  String get confirmHandover => 'Confirm Handover & Payment';

  @override
  String get handoverSuccess => 'Material handed over successfully!';

  @override
  String get viewInLedger => 'View in Earnings Ledger';

  @override
  String get checkPriceBoard => 'Check Market Price Board';

  @override
  String get estimatedValue => 'Estimated Value';

  @override
  String get transactionStatus => 'Transaction Status';

  @override
  String get completed => 'Completed';

  @override
  String get handoverSummary => 'Handover Summary';

  @override
  String get lotStatus => 'Lot Status';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get namaste => 'Namaste 👋';

  @override
  String get loginPrompt => 'Login to continue using Kabadiwala Connect';

  @override
  String get loginSubtitle => 'Enter your mobile number to receive OTP';

  @override
  String get mobileNumber => 'Mobile Number';

  @override
  String get enterMobileNumber => 'Enter 10-digit mobile number';

  @override
  String get getOtp => 'Get OTP';

  @override
  String get demoNumberHint => 'Demo: Tap to fill demo number';

  @override
  String get validMobileError => 'Please enter a valid 10-digit mobile number';

  @override
  String get verifyMobile => 'Verify Mobile Number';

  @override
  String get otpSentTo => 'Enter the 6-digit OTP sent to';

  @override
  String get enterOtp => 'Enter 6-digit OTP';

  @override
  String get demoOtpHide => 'Demo OTP: 123456';

  @override
  String get resendOtp => 'Resend OTP';

  @override
  String get resendIn => 'Resend in';

  @override
  String get seconds => 'sec';

  @override
  String get changeNumber => 'Change Mobile Number';

  @override
  String get verifyAndContinue => 'Verify & Continue';

  @override
  String get otpMustBe6Digits => 'Please enter all 6 digits of the OTP';

  @override
  String get incorrectOtp => 'Incorrect OTP. Please try again or use 123456';

  @override
  String get completeProfile => 'Complete Your Profile';

  @override
  String get profileSetupSubtitle => 'Just a few details to get you started';

  @override
  String get fullName => 'Full Name';

  @override
  String get enterFullName => 'Enter your name (e.g. Ramesh Shinde)';

  @override
  String get nameRequiredError => 'Please enter your full name';

  @override
  String get cityArea => 'Area / City';

  @override
  String get enterCityArea => 'Enter your area or city (e.g. Pune)';

  @override
  String get cityRequiredError => 'Please enter your area or city';

  @override
  String get whatDoYouDo => 'What is your role?';

  @override
  String get scrapCollector => 'Scrap Collector';

  @override
  String get scrapCollectorDesc => 'Collects e-waste & scrap materials';

  @override
  String get recyclerRole => 'Recycler';

  @override
  String get recyclerRoleDesc => 'Authorized recycling center or partner';

  @override
  String get addPhoto => 'Add Photo';

  @override
  String get changePhoto => 'Change Photo';

  @override
  String get saveAndContinue => 'Save & Continue';

  @override
  String get welcomeOnboarding => 'Welcome to Kabadiwala Connect 👋';

  @override
  String get onboardingSubtitle =>
      'Everything you need to manage your scrap collection in one place.';

  @override
  String get onboardingStep1Title => 'Create Scrap Lots';

  @override
  String get onboardingStep1Desc =>
      'Record e-waste materials with weights, photos & condition.';

  @override
  String get onboardingStep2Title => 'Check Market Rates';

  @override
  String get onboardingStep2Desc =>
      'View live & offline indicative rates with audio readout.';

  @override
  String get onboardingStep3Title => 'Find Recyclers';

  @override
  String get onboardingStep3Desc =>
      'Locate nearby authorized recycling centers easily.';

  @override
  String get onboardingStep4Title => 'Track Earnings';

  @override
  String get onboardingStep4Desc =>
      'Maintain an instant digital ledger of sales & payouts.';

  @override
  String get onboardingStep5Title => 'Safe QR Handover';

  @override
  String get onboardingStep5Desc =>
      'Hand over scrap safely with verified digital QR codes.';

  @override
  String get getStarted => 'Get Started';

  @override
  String get skip => 'Skip';

  @override
  String get profile => 'Profile';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get profileUpdated => 'Profile updated successfully!';

  @override
  String get verifiedMobile => 'Verified Mobile';

  @override
  String get cannotEditPhone =>
      'Mobile number is verified and linked to this account.';

  @override
  String get helpSupport => 'Help & Support';

  @override
  String get helpline => 'Kabadiwala Helpline';

  @override
  String get helplineDesc =>
      'Toll-free collector assistance: 1800-267-3329 (9 AM - 7 PM)';

  @override
  String get callHelpline => 'Call Helpline (1800-267-3329)';

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirmTitle => 'Logout Confirmation';

  @override
  String get logoutConfirmMessage =>
      'Are you sure you want to logout? You will need to login again with your mobile number.';

  @override
  String get cancel => 'Cancel';

  @override
  String get loggedInSuccess => 'You\'re logged in successfully.';

  @override
  String get chooseFromGallery => 'Choose from Gallery';

  @override
  String get takeCameraPhoto => 'Take Photo with Camera';

  @override
  String get removePhoto => 'Remove Photo';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get collectorRoleBadge => 'Scrap Collector';

  @override
  String get recyclerRoleBadge => 'Recycler';

  @override
  String get welcomeLandingTitle => 'Welcome to Kabadiwala Connect';

  @override
  String get welcomeLandingSubtitle =>
      'Sell, track and manage your scrap easily.';

  @override
  String get login => 'Login';

  @override
  String get createAccount => 'Create Account';

  @override
  String get joinKabadiwala => 'Join Kabadiwala Connect';

  @override
  String get createYourAccount => 'Create your account 👋';

  @override
  String get welcomeBackLogin => 'Welcome back 👋';

  @override
  String get loginToContinue => 'Login to continue to Kabadiwala Connect';

  @override
  String get password => 'Password';

  @override
  String get enterPassword => 'Enter password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get enterConfirmPassword => 'Re-enter password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get passwordLengthError => 'Password must be at least 6 characters.';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match.';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get accountAlreadyExists =>
      'An account with this mobile number already exists. Please login.';

  @override
  String get invalidCredentialsError =>
      'Mobile number or password is incorrect.';

  @override
  String get signUpOtpSubtitle =>
      'Enter the OTP sent to your mobile number to complete your registration.';

  @override
  String get verifyMobileNumber => 'Verify your mobile number';
}
