import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/language_provider.dart';
import '../loginpage.dart';
import '../Shared/patient_files.dart';
import '../Shared/waiting_list_page.dart';
import '../Shared/add_patient_page.dart';
import '../Secretry/account_approv.dart';
import '../Secretry/secretary_sidebar.dart';
import 'package:flutter/foundation.dart'; // للكشف عن الويب
import '../notifications_page.dart';

class SecretaryDashboard extends StatefulWidget {
  const SecretaryDashboard({super.key});

  @override
  State<SecretaryDashboard> createState() => _SecretaryDashboardState();
}

class _SecretaryDashboardState extends State<SecretaryDashboard> {
  Widget _buildFeatureBox(
    BuildContext context,
    IconData icon,
    String title,
    Color color, {
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    final width = MediaQuery.of(context).size.width;
    final isSmallScreen = width < 350;
    final isTablet = width >= 600 && width <= 900;
    final isWide = width > 900;

    return Material(
      borderRadius: BorderRadius.circular(15),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 18 : 12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: isSmallScreen
                          ? 24
                          : (isWide ? 40 : (isTablet ? 40 : 30)),
                      color: color,
                    ),
                  ),
                  SizedBox(height: isWide ? 16 : (isTablet ? 16 : 8)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: isSmallScreen
                            ? 14
                            : (isWide ? 18 : (isTablet ? 18 : 16)),
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (badgeCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late DatabaseReference _userRef;
  late DatabaseReference _patientsRef;
  late DatabaseReference _pendingAccountsRef;

  String _userName = '';
  String _userImageUrl = '';
  Uint8List? _userImageBytes;
  List<Map<String, dynamic>> waitingList = [];
  List<Map<String, dynamic>> pendingAccounts = [];
  bool _isLoading = true;
  bool _hasError = false;
  final int _retryCount = 0;
  final int _maxRetries = 3;

  bool hasNewNotification = false;

  final Map<String, Map<String, String>> _translations = {
    'secretary_dashboard': {
      'ar': 'لوحة السكرتارية',
      'en': 'Secretary Dashboard'
    },
    'patient_files': {'ar': 'ملفات المرضى', 'en': 'Patient Files'},
    'add_patient': {'ar': 'إضافة مريض', 'en': 'Add Patient'},
    'approve_accounts': {
      'ar': 'الموافقة على الحسابات',
      'en': 'Approve Accounts'
    },
    'waiting_list': {'ar': 'قائمة الانتظار', 'en': 'Waiting List'},
    'secretary': {'ar': 'سكرتير', 'en': 'Secretary'},
    'home': {'ar': 'الرئيسية', 'en': 'Home'},
    'settings': {'ar': 'الإعدادات', 'en': 'Settings'},
    'app_name': {
      'ar': 'عيادات أسنان الجامعة العربية الأمريكية',
      'en': 'Arab American University Dental Clinics'
    },
    'error_loading_data': {
      'ar': 'حدث خطأ في تحميل البيانات',
      'en': 'Error loading data'
    },
    'retry': {'ar': 'إعادة المحاولة', 'en': 'Retry'},
    'no_internet': {
      'ar': 'لا يوجد اتصال بالإنترنت',
      'en': 'No internet connection'
    },
    'server_error': {'ar': 'خطأ في السيرفر', 'en': 'Server error'},
  };

  @override
  void initState() {
    super.initState();
    _initializeReferences();
    _setupRealtimeListener();
    _loadData();
    _listenForNotifications();
  }

  void _initializeReferences() {
    final user = _auth.currentUser;
    if (user != null) {
      _userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
    }
    _patientsRef = FirebaseDatabase.instance.ref('patients');
    _pendingAccountsRef = FirebaseDatabase.instance.ref('pendingAccounts');
  }

  void _setupRealtimeListener() {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _userName = _translate(context, 'secretary');
          _isLoading = false;
          _hasError = false;
        });
      }
      return;
    }

    _userRef.onValue.listen((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists) {
        if (mounted) {
          setState(() {
            _userName = _translate(context, 'secretary');
            _isLoading = false;
            _hasError = false;
          });
        }
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
      _updateUserData(data);
    }, onError: (error) {
      debugPrint('Realtime listener error: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final patientsSnapshot = await _patientsRef.get();
      final pendingSnapshot = await _pendingAccountsRef.get();

      if (mounted) {
        setState(() {
          waitingList = _parseSnapshot(patientsSnapshot);
          pendingAccounts = _parseSnapshot(pendingSnapshot);
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  List<Map<String, dynamic>> _parseSnapshot(DataSnapshot snapshot) {
    if (!snapshot.exists) return [];

    final List<Map<String, dynamic>> result = [];
    final data = snapshot.value as Map<dynamic, dynamic>? ?? {};

    data.forEach((key, value) {
      if (value is Map<dynamic, dynamic>) {
        result.add(Map<String, dynamic>.from(value));
      }
    });

    return result;
  }

  void _updateUserData(Map<dynamic, dynamic> data) async {
    final firstName = data['firstName']?.toString().trim() ?? '';
    final fatherName = data['fatherName']?.toString().trim() ?? '';
    final grandfatherName = data['grandfatherName']?.toString().trim() ?? '';
    final familyName = data['familyName']?.toString().trim() ?? '';

    final fullName = [
      if (firstName.isNotEmpty) firstName,
      if (fatherName.isNotEmpty) fatherName,
      if (grandfatherName.isNotEmpty) grandfatherName,
      if (familyName.isNotEmpty) familyName,
    ].join(' ');

    final imageData = data['image']?.toString() ?? '';
    Uint8List? imageBytes;
    if (imageData.isNotEmpty) {
      try {
        imageBytes = await compute(_decodeBase64Image, imageData);
      } catch (e) {
        imageBytes = null;
      }
    }

    if (!mounted) return;
    setState(() {
      _userName =
          fullName.isNotEmpty ? fullName : _translate(context, 'secretary');
      _userImageUrl =
          imageData.isNotEmpty ? 'data:image/jpeg;base64,$imageData' : '';
      _userImageBytes = imageBytes;
      _isLoading = false;
      _hasError = false;
    });
  }

  static Uint8List _decodeBase64Image(String base64Str) {
    return base64Decode(base64Str.replaceFirst('data:image/jpeg;base64,', ''));
  }

  String _translate(BuildContext context, String key) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final langCode = languageProvider.currentLocale.languageCode;
    // Defensive: fallback to English or key if missing
    if (_translations.containsKey(key)) {
      final translationsForKey = _translations[key]!;
      if (translationsForKey.containsKey(langCode)) {
        return translationsForKey[langCode]!;
      } else if (translationsForKey.containsKey('en')) {
        return translationsForKey['en']!;
      } else {
        return key;
      }
    } else {
      return key;
    }
  }

  bool _isArabic(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    return languageProvider.currentLocale.languageCode == 'ar';
  }

  String _getErrorMessage() {
    return _translate(context, 'error_loading_data');
  }

  Future<void> _logout() async {
    await _auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  void showDashboardBanner(String message, {Color backgroundColor = Colors.green}) {
    ScaffoldMessenger.of(context).clearMaterialBanners();
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: backgroundColor,
        actions: [
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).clearMaterialBanners(),
            child: const Text('إغلاق', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _listenForNotifications() {
    final user = _auth.currentUser;
    if (user == null) return;
    final notificationsRef = FirebaseDatabase.instance.ref('notifications/${user.uid}');
    notificationsRef.onChildAdded.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null && data['read'] == false) {
        if (mounted) {
          setState(() {
            hasNewNotification = true;
          });
          String bannerMsg;
          if (data['title'] != null) {
            bannerMsg = data['title'].toString();
            if (data['message'] != null && data['message'].toString().trim().isNotEmpty) {
              bannerMsg += '\n' + data['message'].toString();
            }
          } else {
            bannerMsg = 'لديك إشعار جديد';
          }
          showDashboardBanner(
            bannerMsg,
            backgroundColor: Colors.blue.shade700,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 350;
    final isLargeScreen = mediaQuery.size.width >= 800 || kIsWeb;

    return Directionality(
      textDirection: _isArabic(context) ? TextDirection.rtl : TextDirection.ltr,
      child: WillPopScope(
        onWillPop: () async {
          ScaffoldMessenger.of(context).clearMaterialBanners();
          return true;
        },
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: primaryColor,
            title: Text(
              _translate(context, 'app_name'),
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 16 : (isLargeScreen ? 24 : 18),
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            leading: Builder(
              builder: (context) => IconButton(
                icon: Icon(Icons.menu, color: Colors.white),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.language, color: Colors.white),
                onPressed: () => languageProvider.toggleLanguage(),
              ),
              Stack(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.notifications,
                      color: hasNewNotification ? Colors.red : Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        hasNewNotification = false;
                      });
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationsPage()),
                      );
                    },
                  ),
                  if (hasNewNotification)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.white),
              ),
            ],
          ),
          drawer: SecretarySidebar(
            primaryColor: primaryColor,
            accentColor: accentColor,
            userName: _userName.isNotEmpty ? _userName : _translate(context, 'secretary'),
            userImageUrl: (_userImageUrl.isNotEmpty && _userImageBytes != null) ? _userImageUrl : '',
            onLogout: _logout,
            parentContext: context,
            collapsed: false, // Drawer always expanded
            translate: (ctx, key) => _translate(context, key),
            pendingAccountsCount: pendingAccounts.length,
            userRole: 'secretary',
          ),
          body: _buildBody(context, isLargeScreen: isLargeScreen),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, {bool isLargeScreen = false}) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final isSmallScreen = width < 600;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.red),
            const SizedBox(height: 20),
            Text(
              _getErrorMessage(),
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: mediaQuery.padding.bottom + 80,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ...existing user info code...
                Container(
                  margin: const EdgeInsets.all(20),
                  height: isSmallScreen ? 180 : 200,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('lib/assets/backgrownd.png'),
                      fit: BoxFit.cover,
                    ),
                    color: Color(0x4D000000),
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0x33000000),
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _userImageUrl.isNotEmpty && _userImageBytes != null
                                ? CircleAvatar(
                                    radius: isSmallScreen ? 30 : 40,
                                    backgroundColor: Color.fromARGB(
                                      (Colors.white.a * 255.0 * 0.8).round() & 0xff,
                                      (Colors.white.r * 255.0).round() & 0xff,
                                      (Colors.white.g * 255.0).round() & 0xff,
                                      (Colors.white.b * 255.0).round() & 0xff,
                                    ),
                                    child: ClipOval(
                                      child: Image.memory(
                                        _userImageBytes!,
                                        width: isSmallScreen ? 60 : 80,
                                        height: isSmallScreen ? 60 : 80,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  )
                                : CircleAvatar(
                                    radius: isSmallScreen ? 30 : 40,
                                    backgroundColor: Color.fromARGB(
                                      (Colors.white.a * 255.0 * 0.8).round() & 0xff,
                                      (Colors.white.r * 255.0).round() & 0xff,
                                      (Colors.white.g * 255.0).round() & 0xff,
                                      (Colors.white.b * 255.0).round() & 0xff,
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      size: isSmallScreen ? 30 : 40,
                                      color: accentColor,
                                    ),
                                  ),
                            const SizedBox(height: 15),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                _userName,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 16 : 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _translate(context, 'secretary'),
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Main feature boxes
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      // final isSmallScreen = width < 350; // لم يعد مستخدمًا
                      final isWide = width > 900;
                      final isTablet = width >= 600 && width <= 900;
                      final crossAxisCount = isWide ? 4 : (isTablet ? 3 : 2);
                      final gridChildAspectRatio = isWide ? 1.1 : (isTablet ? 1.2 : 1.1);
                      final features = [
                        {
                          'icon': Icons.folder,
                          'title': _translate(context, 'patient_files'),
                          'color': primaryColor,
                          'onTap': () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => PatientFilesPage(userRole: 'secretary')),
                            );
                          }
                        },
                        {
                          'icon': Icons.person_add,
                          'title': _translate(context, 'add_patient'),
                          'color': Colors.green,
                          'onTap': () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const AddPatientPage()),
                            );
                          }
                        },
                        {
                          'icon': Icons.verified_user,
                          'title': _translate(context, 'approve_accounts'),
                          'color': Colors.orange,
                          'badgeCount': pendingAccounts.length,
                          'onTap': () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const AccountApprovalPage()),
                            );
                          }
                        },
                        {
                          'icon': Icons.list_alt,
                          'title': _translate(context, 'waiting_list'),
                          'color': primaryColor,
                          'onTap': () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const WaitingListPage(userRole: 'secretary'),
                              ),
                            );
                          }
                        },
                      ];
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: features.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          childAspectRatio: gridChildAspectRatio,
                        ),
                        itemBuilder: (context, index) {
                          final feature = features[index];
                          return _buildFeatureBox(
                            context,
                            feature['icon'] as IconData,
                            feature['title'] as String,
                            feature['color'] as Color,
                            onTap: feature['onTap'] as VoidCallback,
                            badgeCount: (feature['badgeCount'] as int?) ?? 0,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

}
