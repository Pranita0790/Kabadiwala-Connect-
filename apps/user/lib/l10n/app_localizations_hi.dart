// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'कबाड़ीवाला कनेक्ट';

  @override
  String get home => 'होम';

  @override
  String get createLot => 'नया माल जोड़ें';

  @override
  String get camera => 'कैमरा';

  @override
  String get takePhoto => 'फोटो खींचें';

  @override
  String get takePhotoPrompt => 'माल की फोटो खींचें या चुनें';

  @override
  String get retake => 'पुनः लें';

  @override
  String get retakePhoto => 'दूसरी फोटो लें';

  @override
  String get chooseGallery => 'गैलरी से चुनें';

  @override
  String get continueToDetails => 'आगे बढ़ें';

  @override
  String get skipPhoto => 'बिना फोटो आगे बढ़ें';

  @override
  String get material => 'सामग्री / माल';

  @override
  String get selectCategory => 'माल का प्रकार चुनें';

  @override
  String get weight => 'वजन';

  @override
  String get enterWeight => 'वजन दर्ज करें (किग्रा)';

  @override
  String get condition => 'हालत / स्थिति';

  @override
  String get selectCondition => 'माल की हालत चुनें';

  @override
  String get conditionGood => 'चालू (अच्छा)';

  @override
  String get conditionAverage => 'मध्यम (पुराना)';

  @override
  String get conditionScrap => 'कबाड़ (टूटा हुआ)';

  @override
  String get save => 'सुरक्षित करें';

  @override
  String get saveLot => 'माल सुरक्षित करें';

  @override
  String get priceBoard => 'भाव बोर्ड';

  @override
  String get indicativePrice => 'अनुमानित भाव';

  @override
  String get listen => 'सुनें';

  @override
  String get listening => 'आवाज़ बज रही है...';

  @override
  String get earnings => 'कमाई';

  @override
  String get earningsLedger => 'कमाई का खाता';

  @override
  String get totalEarnings => 'कुल कमाई';

  @override
  String get currentMonthEarnings => 'इस महीने की कमाई';

  @override
  String get paid => 'भुगतान प्राप्त';

  @override
  String get pending => 'बाकी';

  @override
  String get paymentStatus => 'भुगतान स्थिति';

  @override
  String get offline => 'ऑफ़लाइन';

  @override
  String get offlineModeActive =>
      'ऑफ़लाइन मोड सक्रिय • माल SQLite में सुरक्षित है';

  @override
  String get onlineConnected => 'ऑनलाइन • स्वतः क्लाउड सिंक चालू है';

  @override
  String get noInternet => 'इंटरनेट नहीं है';

  @override
  String get waitingForInternet => 'इंटरनेट की प्रतीक्षा है';

  @override
  String get synced => 'सिंक हो गया';

  @override
  String get syncing => 'सिंक हो रहा है...';

  @override
  String get failed => 'विफल';

  @override
  String get syncFailed => 'सिंक विफल';

  @override
  String get pendingSync => 'सिंक बाकी';

  @override
  String get retry => 'पुनः प्रयास करें';

  @override
  String get retrySync => 'पुनः प्रयास करें';

  @override
  String get syncNow => 'अभी सिंक करें';

  @override
  String get lastUpdated => 'अंतिम अपडेट';

  @override
  String get updatedToday => 'आज अपडेट किया गया';

  @override
  String get noTransactions => 'अभी कोई लेन-देन दर्ज नहीं हुआ है।';

  @override
  String get noLots =>
      'कोई माल दर्ज नहीं हुआ है।\n\"नया माल जोड़ें\" पर टैप करें।';

  @override
  String get recordedLots => 'दर्ज माल';

  @override
  String get source => 'स्रोत';

  @override
  String get location => 'स्थान';

  @override
  String get finalAmount => 'अंतिम राशि';

  @override
  String get recycler => 'रिसायकलर';

  @override
  String get refreshPrices => 'भाव ताज़ा करें';

  @override
  String get refreshLedger => 'खाता ताज़ा करें';

  @override
  String get allTransactions => 'सभी लेन-देन';

  @override
  String get all => 'सभी';

  @override
  String get indicativeRates => 'अनुमानित बाजार भाव';

  @override
  String get liveRates => 'ताज़ा बाजार भाव';

  @override
  String get cachedOfflineRates => 'ऑफ़लाइन सुरक्षित भाव (SQLite)';

  @override
  String get cachedOfflineLedger => 'ऑफ़लाइन सुरक्षित खाता (SQLite)';

  @override
  String get liveLedger => 'ताज़ा लेन-देन';

  @override
  String get optionalNotes => 'अतिरिक्त जानकारी (वैकल्पिक)';

  @override
  String get notesHint => 'जैसे: तांबे का तार बंडल, 2 मॉनिटर';

  @override
  String get analyzingAi => 'एआई से फोटो की जांच हो रही है...';

  @override
  String get suggestedAi => 'एआई द्वारा सुझाया गया';

  @override
  String get validWeightError => 'कृपया सही वजन दर्ज करें (> 0 किग्रा)';

  @override
  String get lotSavedSuccess => 'माल स्थानीय डेटाबेस में सुरक्षित हो गया!';

  @override
  String get language => 'भाषा';

  @override
  String get categoryPcb => 'मदरबोर्ड / पीसीबी (Motherboard)';

  @override
  String get categoryCopper => 'तांबे का तार (Copper Wire)';

  @override
  String get categoryBattery => 'बैटरी (Battery)';

  @override
  String get categoryDisplay => 'मॉनिटर और स्क्रीन (Display)';

  @override
  String get categoryAppliances => 'बिजली उपकरण (Appliances)';

  @override
  String get categoryMixed => 'मिश्रित ई-कचरा (Mixed E-Waste)';

  @override
  String get lotDetails => 'माल का विवरण';

  @override
  String get handoverToRecycler => 'रिसायकलर को सौंपें';

  @override
  String get selectRecycler => 'अधिकृत रिसायकलर चुनें';

  @override
  String get authorizedRecycler => 'अधिकृत रिसायकलर';

  @override
  String get confirmHandover => 'माल सौंपें और भुगतान दर्ज करें';

  @override
  String get handoverSuccess => 'माल सफलतापूर्वक सौंप दिया गया!';

  @override
  String get viewInLedger => 'कमाई खाते में देखें';

  @override
  String get checkPriceBoard => 'बाजार भाव बोर्ड देखें';

  @override
  String get estimatedValue => 'अनुमानित मूल्य';

  @override
  String get transactionStatus => 'लेन-देन स्थिति';

  @override
  String get completed => 'पूर्ण';

  @override
  String get handoverSummary => 'हस्तांतरण सारांश';

  @override
  String get lotStatus => 'माल की स्थिति';

  @override
  String get welcomeBack => 'वापसी पर स्वागत है';

  @override
  String get namaste => 'नमस्ते 👋';

  @override
  String get loginPrompt => 'कबाडीवाला कनेक्ट जारी रखने के लिए लॉगिन करें';

  @override
  String get loginSubtitle =>
      'ओटीपी प्राप्त करने के लिए अपना मोबाइल नंबर दर्ज करें';

  @override
  String get mobileNumber => 'मोबाइल नंबर';

  @override
  String get enterMobileNumber => '10-अंकों का मोबाइल नंबर दर्ज करें';

  @override
  String get getOtp => 'ओटीपी प्राप्त करें';

  @override
  String get demoNumberHint => 'डेमो: डेमो नंबर भरने के लिए टैप करें';

  @override
  String get validMobileError =>
      'कृपया एक मान्य 10-अंकों का मोबाइल नंबर दर्ज करें';

  @override
  String get verifyMobile => 'मोबाइल नंबर सत्यापित करें';

  @override
  String get otpSentTo => 'इस नंबर पर भेजा गया 6-अंकों का ओटीपी दर्ज करें:';

  @override
  String get enterOtp => '6-अंकों का ओटीपी दर्ज करें';

  @override
  String get demoOtpHide => 'डेमो ओटीपी: 123456';

  @override
  String get resendOtp => 'ओटीपी पुनः भेजें';

  @override
  String get resendIn => 'पुनः भेजें';

  @override
  String get seconds => 'सेकंड';

  @override
  String get changeNumber => 'मोबाइल नंबर बदलें';

  @override
  String get verifyAndContinue => 'सत्यापित करें और आगे बढ़ें';

  @override
  String get otpMustBe6Digits => 'कृपया ओटीपी के सभी 6 अंक दर्ज करें';

  @override
  String get incorrectOtp =>
      'गलत ओटीपी। कृपया पुनः प्रयास करें या 123456 का उपयोग करें';

  @override
  String get completeProfile => 'अपनी प्रोफ़ाइल पूरी करें';

  @override
  String get profileSetupSubtitle => 'शुरू करने के लिए बस कुछ बुनियादी जानकारी';

  @override
  String get fullName => 'पूरा नाम';

  @override
  String get enterFullName => 'अपना नाम दर्ज करें (उदा. रमेश शिंदे)';

  @override
  String get nameRequiredError => 'कृपया अपना पूरा नाम दर्ज करें';

  @override
  String get cityArea => 'क्षेत्र / शहर';

  @override
  String get enterCityArea => 'अपना क्षेत्र या शहर दर्ज करें (उदा. पुणे)';

  @override
  String get cityRequiredError => 'कृपया अपना क्षेत्र या शहर दर्ज करें';

  @override
  String get whatDoYouDo => 'आपकी भूमिका क्या है?';

  @override
  String get scrapCollector => 'कबाडीवाला / संग्राहक';

  @override
  String get scrapCollectorDesc => 'ई-कचरा और भंगार सामग्री एकत्रित करता है';

  @override
  String get recyclerRole => 'रिसायकलर';

  @override
  String get recyclerRoleDesc => 'अधिकृत रिसायकलिंग केंद्र या भागीदार';

  @override
  String get addPhoto => 'फोटो जोड़ें';

  @override
  String get changePhoto => 'फोटो बदलें';

  @override
  String get saveAndContinue => 'सहेजें और आगे बढ़ें';

  @override
  String get welcomeOnboarding => 'कबाडीवाला कनेक्ट में आपका स्वागत है 👋';

  @override
  String get onboardingSubtitle =>
      'आपके भंगार संग्रह को प्रबंधित करने के लिए सब कुछ एक ही स्थान पर।';

  @override
  String get onboardingStep1Title => 'सामग्री लॉट बनाएं';

  @override
  String get onboardingStep1Desc =>
      'वजन, फोटो और स्थिति के साथ ई-कचरा सामग्री दर्ज करें।';

  @override
  String get onboardingStep2Title => 'बाजार दर देखें';

  @override
  String get onboardingStep2Desc =>
      'ऑडियो सहायता के साथ वास्तविक और ऑफ़लाइन बाजार दर देखें।';

  @override
  String get onboardingStep3Title => 'रिसायकलर खोजें';

  @override
  String get onboardingStep3Desc =>
      'निकटतम प्रमाणित रिसायकलर केंद्रों से आसानी से जुड़ें।';

  @override
  String get onboardingStep4Title => 'कमाई का हिसाब रखें';

  @override
  String get onboardingStep4Desc =>
      'सभी बिक्री और भुगतानों का तुरंत डिजिटल खाता बनाए रखें।';

  @override
  String get onboardingStep5Title => 'सुरक्षित क्यूआर हस्तांतरण';

  @override
  String get onboardingStep5Desc =>
      'प्रमाणित डिजिटल क्यूआर कोड के साथ सामग्री सुरक्षित रूप से सौंपें।';

  @override
  String get getStarted => 'शुरू करें';

  @override
  String get skip => 'छोड़ें';

  @override
  String get profile => 'प्रोफ़ाइल';

  @override
  String get editProfile => 'प्रोफ़ाइल संपादित करें';

  @override
  String get saveChanges => 'बदलाव सहेजें';

  @override
  String get profileUpdated => 'प्रोफ़ाइल सफलतापूर्वक अपडेट हो गई!';

  @override
  String get verifiedMobile => 'सत्यापित मोबाइल';

  @override
  String get cannotEditPhone =>
      'मोबाइल नंबर सत्यापित है और इस खाते से जुड़ा हुआ है।';

  @override
  String get helpSupport => 'सहायता और समर्थन';

  @override
  String get helpline => 'कबाडीवाला हेल्पलाइन';

  @override
  String get helplineDesc =>
      'टोल-फ्री कलेक्टर सहायता: 1800-267-3329 (सुबह 9 से शाम 7 बजे)';

  @override
  String get callHelpline => 'हेल्पलाइन पर कॉल करें (1800-267-3329)';

  @override
  String get logout => 'लॉगआउट';

  @override
  String get logoutConfirmTitle => 'लॉगआउट की पुष्टि';

  @override
  String get logoutConfirmMessage =>
      'क्या आप निश्चित रूप से लॉगआउट करना चाहते हैं? दोबारा लॉगिन करने के लिए आपको अपने मोबाइल नंबर की आवश्यकता होगी।';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get loggedInSuccess => 'आप सफलतापूर्वक लॉगिन हो गए हैं।';

  @override
  String get chooseFromGallery => 'गैलरी से चुनें';

  @override
  String get takeCameraPhoto => 'कैमरे से फोटो लें';

  @override
  String get removePhoto => 'फोटो हटाएं';

  @override
  String get selectLanguage => 'भाषा चुनें';

  @override
  String get collectorRoleBadge => 'कबाडीवाला / संग्राहक';

  @override
  String get recyclerRoleBadge => 'रिसायकलर';

  @override
  String get welcomeLandingTitle => 'कबाड़ीवाला कनेक्ट में आपका स्वागत है';

  @override
  String get welcomeLandingSubtitle =>
      'अपने कबाड़ को आसानी से बेचें, ट्रैक करें और प्रबंधित करें।';

  @override
  String get login => 'लॉगिन करें';

  @override
  String get createAccount => 'खाता बनाएं';

  @override
  String get joinKabadiwala => 'कबाड़ीवाला कनेक्ट से जुड़ें';

  @override
  String get createYourAccount => 'अपना खाता बनाएं 👋';

  @override
  String get welcomeBackLogin => 'वापसी पर स्वागत है 👋';

  @override
  String get loginToContinue => 'कबाड़ीवाला कनेक्ट जारी रखने के लिए लॉगिन करें';

  @override
  String get password => 'पासवर्ड';

  @override
  String get enterPassword => 'पासवर्ड दर्ज करें';

  @override
  String get confirmPassword => 'पासवर्ड की पुष्टि करें';

  @override
  String get enterConfirmPassword => 'पासवर्ड दोबारा दर्ज करें';

  @override
  String get showPassword => 'पासवर्ड दिखाएं';

  @override
  String get hidePassword => 'पासवर्ड छुपाएं';

  @override
  String get passwordLengthError => 'पासवर्ड कम से कम 6 अक्षरों का होना चाहिए।';

  @override
  String get passwordsDoNotMatch => 'पासवर्ड मेल नहीं खाते।';

  @override
  String get dontHaveAccount => 'क्या आपका खाता नहीं है?';

  @override
  String get alreadyHaveAccount => 'क्या आपके पास पहले से खाता है?';

  @override
  String get accountAlreadyExists =>
      'इस मोबाइल नंबर वाला खाता पहले से मौजूद है। कृपया लॉगिन करें।';

  @override
  String get invalidCredentialsError => 'मोबाइल नंबर या पासवर्ड गलत है।';

  @override
  String get signUpOtpSubtitle =>
      'अपना पंजीकरण पूरा करने के लिए अपने मोबाइल नंबर पर भेजा गया ओटीपी दर्ज करें।';

  @override
  String get verifyMobileNumber => 'अपना मोबाइल नंबर सत्यापित करें';
}
