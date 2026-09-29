// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Marathi (`mr`).
class AppLocalizationsMr extends AppLocalizations {
  AppLocalizationsMr([String locale = 'mr']) : super(locale);

  @override
  String get appTitle => 'कबाडीवाला कनेक्ट';

  @override
  String get home => 'होम';

  @override
  String get createLot => 'नवीन माल नोंदवा';

  @override
  String get camera => 'कॅमेरा';

  @override
  String get takePhoto => 'फोटो काढा';

  @override
  String get takePhotoPrompt => 'मालाचा फोटो काढा किंवा निवडा';

  @override
  String get retake => 'पुन्हा घ्या';

  @override
  String get retakePhoto => 'दुसरा फोटो काढा';

  @override
  String get chooseGallery => 'गॅलरीतून निवडा';

  @override
  String get continueToDetails => 'पुढे जा';

  @override
  String get skipPhoto => 'फोटो न घेता पुढे जा';

  @override
  String get material => 'मालाचा प्रकार';

  @override
  String get selectCategory => 'मालाचा प्रकार निवडा';

  @override
  String get weight => 'वजन';

  @override
  String get enterWeight => 'वजन प्रविष्ट करा (किलो)';

  @override
  String get condition => 'स्थिती';

  @override
  String get selectCondition => 'मालाची स्थिती निवडा';

  @override
  String get conditionGood => 'चालू (चांगली)';

  @override
  String get conditionAverage => 'मध्यम (वापरलेले)';

  @override
  String get conditionScrap => 'स्क्रॅप (तुटलेले)';

  @override
  String get save => 'जतन करा';

  @override
  String get saveLot => 'माल जतन करा';

  @override
  String get priceBoard => 'दर फलक';

  @override
  String get indicativePrice => 'अंदाजे दर';

  @override
  String get listen => 'ऐका';

  @override
  String get listening => 'आवाज सुरू आहे...';

  @override
  String get earnings => 'कमाई';

  @override
  String get earningsLedger => 'कमाईचे खाते';

  @override
  String get totalEarnings => 'एकूण कमाई';

  @override
  String get currentMonthEarnings => 'या महिन्याची कमाई';

  @override
  String get paid => 'भरणा झाला';

  @override
  String get pending => 'प्रलंबित';

  @override
  String get paymentStatus => 'पेमेंट स्थिती';

  @override
  String get offline => 'ऑफलाइन';

  @override
  String get offlineModeActive =>
      'ऑफलाइन मोड सक्रिय • माल SQLite मध्ये जतन आहे';

  @override
  String get onlineConnected => 'ऑनलाइन • स्वयंचलित क्लाउड सिंक सुरू आहे';

  @override
  String get noInternet => 'इंटरनेट नाही';

  @override
  String get waitingForInternet => 'इंटरनेटची प्रतीक्षा आहे';

  @override
  String get synced => 'सिंक झाले';

  @override
  String get syncing => 'सिंक होत आहे...';

  @override
  String get failed => 'अयशस्वी';

  @override
  String get syncFailed => 'सिंक अयशस्वी';

  @override
  String get pendingSync => 'सिंक बाकी';

  @override
  String get retry => 'पुन्हा प्रयत्न करा';

  @override
  String get retrySync => 'पुन्हा प्रयत्न करा';

  @override
  String get syncNow => 'आता सिंक करा';

  @override
  String get lastUpdated => 'शेवटचे अपडेट';

  @override
  String get updatedToday => 'आज अपडेट केले';

  @override
  String get noTransactions => 'अद्याप कोणतेही व्यवहार नोंदवलेले नाहीत.';

  @override
  String get noLots =>
      'अद्याप कोणताही माल नोंदवलेला नाही.\n\"नवीन माल नोंदवा\" वर टॅप करा.';

  @override
  String get recordedLots => 'नोंदवलेला माल';

  @override
  String get source => 'स्रोत';

  @override
  String get location => 'ठिकाण';

  @override
  String get finalAmount => 'अंतिम रक्कम';

  @override
  String get recycler => 'रिसायकलर';

  @override
  String get refreshPrices => 'दर रिफ्रेश करा';

  @override
  String get refreshLedger => 'खाते रिफ्रेश करा';

  @override
  String get allTransactions => 'सर्व व्यवहार';

  @override
  String get all => 'सर्व';

  @override
  String get indicativeRates => 'अंदाजे बाजार दर';

  @override
  String get liveRates => 'ताजे बाजार दर';

  @override
  String get cachedOfflineRates => 'ऑफलाइन जतन केलेले दर (SQLite)';

  @override
  String get cachedOfflineLedger => 'ऑफलाइन जतन केलेले खाते (SQLite)';

  @override
  String get liveLedger => 'ताजे व्यवहार';

  @override
  String get optionalNotes => 'अधिक माहिती (पर्यायी)';

  @override
  String get notesHint => 'उदा. तांब्याची तार बंडल, 2 मॉनिटर';

  @override
  String get analyzingAi => 'एआय द्वारे फोटो तपासला जात आहे...';

  @override
  String get suggestedAi => 'एआय द्वारे सुचवलेले';

  @override
  String get validWeightError => 'कृपया योग्य वजन प्रविष्ट करा (> 0 किलो)';

  @override
  String get lotSavedSuccess => 'माल स्थानिक डेटाबेसमध्ये जतन झाला!';

  @override
  String get language => 'भाषा';

  @override
  String get categoryPcb => 'मदरबोर्ड / पीसीबी (Motherboard)';

  @override
  String get categoryCopper => 'तांब्याची तार (Copper Wire)';

  @override
  String get categoryBattery => 'बॅटरी (Battery)';

  @override
  String get categoryDisplay => 'मॉनिटर आणि स्क्रीन (Display)';

  @override
  String get categoryAppliances => 'विद्युत उपकरणे (Appliances)';

  @override
  String get categoryMixed => 'मिश्र ई-कचरा (Mixed E-Waste)';

  @override
  String get lotDetails => 'मालाचा तपशील';

  @override
  String get handoverToRecycler => 'रिसायकलरला माल द्या';

  @override
  String get selectRecycler => 'अधिकृत रिसायकलर निवडा';

  @override
  String get authorizedRecycler => 'अधिकृत रिसायकलर';

  @override
  String get confirmHandover => 'माल देणे व पेमेंट निश्चित करा';

  @override
  String get handoverSuccess => 'माल यशस्वीरित्या देण्यात आला!';

  @override
  String get viewInLedger => 'कमाईच्या खात्यात पहा';

  @override
  String get checkPriceBoard => 'बाजार दर फलक पहा';

  @override
  String get estimatedValue => 'अंदाजे मूल्य';

  @override
  String get transactionStatus => 'व्यवहार स्थिती';

  @override
  String get completed => 'पूर्ण';

  @override
  String get handoverSummary => 'हस्तांतरण सारांश';

  @override
  String get lotStatus => 'मालाची स्थिती';

  @override
  String get welcomeBack => 'पुन्हा स्वागत आहे';

  @override
  String get namaste => 'नमस्ते 👋';

  @override
  String get loginPrompt =>
      'कबाडीवाला कनेक्ट वापरणे सुरू ठेवण्यासाठी लॉगिन करा';

  @override
  String get loginSubtitle => 'ओटीपी मिळवण्यासाठी तुमचा मोबाइल नंबर टाका';

  @override
  String get mobileNumber => 'मोबाइल नंबर';

  @override
  String get enterMobileNumber => '10-अंकी मोबाइल नंबर टाका';

  @override
  String get getOtp => 'ओटीपी मिळवा';

  @override
  String get demoNumberHint => 'डेमो: डेमो नंबर भरण्यासाठी टॅप करा';

  @override
  String get validMobileError => 'कृपया वैध 10-अंकी मोबाइल नंबर टाका';

  @override
  String get verifyMobile => 'मोबाइल नंबर पडताळा';

  @override
  String get otpSentTo => 'या क्रमांकावर पाठवलेला 6-अंकी ओटीपी टाका:';

  @override
  String get enterOtp => '6-अंकी ओटीपी टाका';

  @override
  String get demoOtpHide => 'डेमो ओटीपी: 123456';

  @override
  String get resendOtp => 'ओटीपी पुन्हा पाठवा';

  @override
  String get resendIn => 'पुन्हा पाठवा';

  @override
  String get seconds => 'सेकंद';

  @override
  String get changeNumber => 'मोबाइल नंबर बदला';

  @override
  String get verifyAndContinue => 'पडताळा आणि पुढे जा';

  @override
  String get otpMustBe6Digits => 'कृपया ओटीपीचे सर्व 6 अंक टाका';

  @override
  String get incorrectOtp =>
      'चुकीचा ओटीपी. कृपया पुन्हा प्रयत्न करा किंवा 123456 वापरा';

  @override
  String get completeProfile => 'तुमचे प्रोफाइल पूर्ण करा';

  @override
  String get profileSetupSubtitle => 'सुरू करण्यासाठी फक्त काही मूलभूत माहिती';

  @override
  String get fullName => 'पूर्ण नाव';

  @override
  String get enterFullName => 'तुमचे नाव टाका (उदा. रमेश शिंदे)';

  @override
  String get nameRequiredError => 'कृपया तुमचे पूर्ण नाव टाका';

  @override
  String get cityArea => 'परिसर / शहर';

  @override
  String get enterCityArea => 'तुमचा परिसर किंवा शहर टाका (उदा. पुणे)';

  @override
  String get cityRequiredError => 'कृपया तुमचा परिसर किंवा शहर टाका';

  @override
  String get whatDoYouDo => 'तुमची भूमिका काय आहे?';

  @override
  String get scrapCollector => 'भंगार वेचक / संग्राहक';

  @override
  String get scrapCollectorDesc => 'ई-कचरा आणि भंगार माल गोळा करतो';

  @override
  String get recyclerRole => 'रिसायकलर';

  @override
  String get recyclerRoleDesc => 'अधिकृत रिसायकलिंग केंद्र किंवा भागीदार';

  @override
  String get addPhoto => 'फोटो जोडा';

  @override
  String get changePhoto => 'फोटो बदला';

  @override
  String get saveAndContinue => 'जतन करा आणि पुढे जा';

  @override
  String get welcomeOnboarding => 'कबाडीवाला कनेक्ट मध्ये आपले स्वागत आहे 👋';

  @override
  String get onboardingSubtitle =>
      'तुमच्या भंगार संकलनाचे व्यवस्थापन करण्यासाठी सर्व काही एकाच ठिकाणी.';

  @override
  String get onboardingStep1Title => 'मालाची नोंद करा';

  @override
  String get onboardingStep1Desc =>
      'वजन, फोटो आणि स्थितीसह ई-कचरा मालाची नोंद करा.';

  @override
  String get onboardingStep2Title => 'बाजार दर तपासा';

  @override
  String get onboardingStep2Desc => 'ऑडिओ वाचनासह थेट आणि ऑफलाइन बाजार दर पहा.';

  @override
  String get onboardingStep3Title => 'रिसायकलर शोधा';

  @override
  String get onboardingStep3Desc =>
      'जवळच्या अधिकृत रिसायकलर्सशी सहज संपर्क साधा.';

  @override
  String get onboardingStep4Title => 'कमाईचा हिशोब ठेवा';

  @override
  String get onboardingStep4Desc =>
      'सर्व व्यवहार आणि कमाईची त्वरित डिजिटल नोंद ठेवा.';

  @override
  String get onboardingStep5Title => 'सुरक्षित क्यूआर हस्तांतरण';

  @override
  String get onboardingStep5Desc =>
      'पडताळणी केलेल्या डिजिटल क्यूआर कोडसह माल सुरक्षितपणे हस्तांतरित करा.';

  @override
  String get getStarted => 'सुरू करा';

  @override
  String get skip => 'वगळा';

  @override
  String get profile => 'प्रोफाइल';

  @override
  String get editProfile => 'प्रोफाइल संपादित करा';

  @override
  String get saveChanges => 'बदल जतन करा';

  @override
  String get profileUpdated => 'प्रोफाइल यशस्वीरित्या अपडेट झाली!';

  @override
  String get verifiedMobile => 'पडताळलेला मोबाइल';

  @override
  String get cannotEditPhone =>
      'मोबाइल नंबर पडताळलेला आहे आणि या खात्याशी जोडलेला आहे.';

  @override
  String get helpSupport => 'मदत आणि सहकार्य';

  @override
  String get helpline => 'कबाडीवाला हेल्पलाइन';

  @override
  String get helplineDesc =>
      'टोल-फ्री कलेक्टर मदत: 1800-267-3329 (सकाळी 9 ते संध्याकाळी 7)';

  @override
  String get callHelpline => 'हेल्पलाइनवर कॉल करा (1800-267-3329)';

  @override
  String get logout => 'लॉगआउट';

  @override
  String get logoutConfirmTitle => 'लॉगआउटची खात्री';

  @override
  String get logoutConfirmMessage =>
      'तुम्हाला खात्री आहे की तुम्ही लॉगआउट करू इच्छिता? पुन्हा लॉगिन करण्यासाठी तुम्हाला तुमच्या मोबाइल नंबरची आवश्यकता असेल.';

  @override
  String get cancel => 'रद्द करा';

  @override
  String get loggedInSuccess => 'तुम्ही यशस्वीरित्या लॉगिन झाला आहात.';

  @override
  String get chooseFromGallery => 'गॅलरीतून निवडा';

  @override
  String get takeCameraPhoto => 'कॅमेऱ्याने फोटो काढा';

  @override
  String get removePhoto => 'फोटो काढा';

  @override
  String get selectLanguage => 'भाषा निवडा';

  @override
  String get collectorRoleBadge => 'भंगार वेचक / संग्राहक';

  @override
  String get recyclerRoleBadge => 'रिसायकलर';

  @override
  String get welcomeLandingTitle => 'कबाडीवाला कनेक्ट मध्ये आपले स्वागत आहे';

  @override
  String get welcomeLandingSubtitle =>
      'तुमचा भंगार सहजपणे विका, मागोवा घ्या आणि व्यवस्थापित करा.';

  @override
  String get login => 'लॉगिन करा';

  @override
  String get createAccount => 'खाते तयार करा';

  @override
  String get joinKabadiwala => 'कबाडीवाला कनेक्ट मध्ये सामील व्हा';

  @override
  String get createYourAccount => 'आपले खाते तयार करा 👋';

  @override
  String get welcomeBackLogin => 'परत स्वागत आहे 👋';

  @override
  String get loginToContinue => 'कबाडीवाला कनेक्ट सुरू ठेवण्यासाठी लॉगिन करा';

  @override
  String get password => 'पासवर्ड';

  @override
  String get enterPassword => 'पासवर्ड प्रविष्ट करा';

  @override
  String get confirmPassword => 'पासवर्डची पुष्टी करा';

  @override
  String get enterConfirmPassword => 'पासवर्ड पुन्हा प्रविष्ट करा';

  @override
  String get showPassword => 'पासवर्ड दाखवा';

  @override
  String get hidePassword => 'पासवर्ड लपवा';

  @override
  String get passwordLengthError => 'पासवर्ड किमान 6 अक्षरांचा असावा.';

  @override
  String get passwordsDoNotMatch => 'पासवर्ड जुळत नाहीत.';

  @override
  String get dontHaveAccount => 'खाते नाही का?';

  @override
  String get alreadyHaveAccount => 'आधीच खाते आहे का?';

  @override
  String get accountAlreadyExists =>
      'या मोबाइल नंबरचे खाते आधीपासून अस्तित्वात आहे. कृपया लॉगिन करा.';

  @override
  String get invalidCredentialsError => 'मोबाइल नंबर किंवा पासवर्ड चुकीचा आहे.';

  @override
  String get signUpOtpSubtitle =>
      'तुमची नोंदणी पूर्ण करण्यासाठी तुमच्या मोबाइल नंबरवर पाठवलेला OTP प्रविष्ट करा.';

  @override
  String get verifyMobileNumber => 'तुमचा मोबाइल नंबर पडताळा';
}
