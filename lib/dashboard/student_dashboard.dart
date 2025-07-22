// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/language_provider.dart';
import '../loginpage.dart';
import '../Student/student_groups_page.dart';
import '../Student/student_appointments_page.dart';
import '../notifications_page.dart';
import '../Doctor/examined_patients_page.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late DatabaseReference _userRef;
  late DatabaseReference _notificationsRef;

  String _userName = '';
  String _userImageUrl = '';
  List<Map<String, dynamic>> assignedPatients = [];
  List<Map<String, dynamic>> notifications = [];
  bool _isLoading = true;
  bool _hasError = false;
  final int _retryCount = 0;
  final int _maxRetries = 3;

  bool hasNewNotification = false;

  final Map<String, Map<String, String>> _translations = {
    'student_dashboard': {'ar': 'لوحة الطالب', 'en': 'Student Dashboard'},
    'view_examinations': {'ar': 'عرض الفحوصات', 'en': 'View Examinations'},
    'examine_patient': {'ar': 'فحص المريض', 'en': 'Examine Patient'},
    'notifications': {'ar': 'الإشعارات', 'en': 'Notifications'},
    'student': {'ar': 'طالب', 'en': 'Student'},
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
    'no_notifications': {'ar': 'لا توجد إشعارات', 'en': 'No notifications'},
    'close': {'ar': 'إغلاق', 'en': 'Close'},
    'my_appointments': {'ar': 'مواعيدي', 'en': 'My Appointments'},
  };

  @override
  void initState() {
    super.initState();
    // تم إزالة تعيين اللغة الافتراضية للإنجليزية عند فتح لوحة الطالب
    _initializeReferences();
    _setupRealtimeListener();
    _loadData();
    _listenForNotifications();
  }

  void _initializeReferences() {
    final user = _auth.currentUser;
    if (user != null) {
      _userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      _notificationsRef =
          FirebaseDatabase.instance.ref('notifications/${user.uid}');
    }
  }

  void _setupRealtimeListener() {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _userName = _translate(context, 'student');
        _isLoading = false;
      });
      return;
    }

    _userRef.onValue.listen((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists) {
        setState(() {
          _userName = _translate(context, 'student');
          _isLoading = false;
          _hasError = false;
        });
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
      _updateUserData(data);
    }, onError: (error) {
      debugPrint('Realtime listener error: $error');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    });

    // Listen for notifications
    _notificationsRef.onValue.listen((event) {
      final snapshot = event.snapshot;
      if (snapshot.exists) {
        setState(() {
          notifications = _parseSnapshot(snapshot);
        });
      }
    });
  }

  Future<void> _loadData() async {
    try {
      //final patientsSnapshot = await _patientsRef.orderByChild('assignedStudentId').equalTo(_auth.currentUser?.uid).get();
      final notificationsSnapshot = await _notificationsRef.get();

      setState(() {
        //assignedPatients = _parseSnapshot(patientsSnapshot);
        notifications = _parseSnapshot(notificationsSnapshot);
        _hasError = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() {
        _hasError = true;
      });
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

  void _updateUserData(Map<dynamic, dynamic> data) {
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

    setState(() {
      _userName =
          fullName.isNotEmpty ? fullName : _translate(context, 'student');
      _userImageUrl =
          imageData.isNotEmpty ? 'data:image/jpeg;base64,$imageData' : '';
      _isLoading = false;
      _hasError = false;
    });
  }

  String _translate(BuildContext context, String key) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    return _translations[key]![languageProvider.currentLocale.languageCode] ??
        '';
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
    if (!mounted) return;
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
              bannerMsg += '\n${data['message']}';
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

    return Directionality(
      textDirection: _isArabic(context) ? TextDirection.rtl : TextDirection.ltr,
      // ignore: deprecated_member_use
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
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
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
              )
            ],
          ),
          // Add drawer for large screens
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(color: primaryColor),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _userImageUrl.isNotEmpty
                          ? CircleAvatar(
                              radius: 32,
                              backgroundColor: Colors.white,
                              child: ClipOval(
                                child: Image.memory(
                                  base64Decode(_userImageUrl
                                      .replaceFirst('data:image/jpeg;base64,', '')),
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          : CircleAvatar(
                              radius: 32,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.person,
                                size: 32,
                                color: accentColor,
                              ),
                            ),
                      const SizedBox(height: 10),
                      Text(
                        _userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _translate(context, 'student'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // الرئيسية أول عنصر
                ListTile(
                  leading: Icon(Icons.home, color: primaryColor),
                  title: Text(_translate(context, 'home')),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StudentDashboard(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.assignment, color: primaryColor),
                  title: Text(_translate(context, 'view_examinations')),
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ExaminedPatientsPage()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.medical_services, color: Colors.green),
                  title: Text(_translate(context, 'examine_patient')),
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const StudentGroupsPage()));
                  },
                ),
                // زر مواعيدي بدلاً من زر الإشعارات
                ListTile(
                  leading: const Icon(Icons.calendar_today, color: Colors.orange),
                  title: Text(_translate(context, 'my_appointments')),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StudentAppointmentsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          endDrawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(color: primaryColor),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _userImageUrl.isNotEmpty
                          ? CircleAvatar(
                              radius: 32,
                              backgroundColor: Colors.white,
                              child: ClipOval(
                                child: Image.memory(
                                  base64Decode(_userImageUrl
                                      .replaceFirst('data:image/jpeg;base64,', '')),
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          : CircleAvatar(
                              radius: 32,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.person,
                                size: 32,
                                color: accentColor,
                              ),
                            ),
                      const SizedBox(height: 10),
                      Text(
                        _userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _translate(context, 'student'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.assignment, color: primaryColor),
                  title: Text(_translate(context, 'view_examinations')),
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ExaminedPatientsPage()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.medical_services, color: Colors.green),
                  title: Text(_translate(context, 'examine_patient')),
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const StudentGroupsPage()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications, color: Colors.orange),
                  title: Text(_translate(context, 'notifications')),
                  onTap: () {
                    _showNotificationsDialog(context);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.home, color: primaryColor),
                  title: Text(_translate(context, 'home')),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StudentDashboard(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          body: Builder(
            builder: (context) {
              // استقبال رسالة من صفحة الإشعارات
              Future.microtask(() {
                final args = ModalRoute.of(context)?.settings.arguments;
                if (args is Map && args['showBanner'] == true) {
                  showDashboardBanner(args['bannerMessage'] ?? 'تمت قراءة الإشعار بنجاح');
                }
              });
              return _buildBody(context);
            },
          ),
          // bottomNavigationBar: _buildBottomNavigation(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
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
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _loadData();
                _setupRealtimeListener();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                _translate(context, 'retry'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            if (_retryCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '($_retryCount/$_maxRetries)',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      );
    }

    // فحص حالة الحساب
    final user = _auth.currentUser;
    if (user != null) {
      // سنستخدم FutureBuilder لجلب isActive مباشرة من الداتا
      return FutureBuilder<DataSnapshot>(
        future: _userRef.get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData && snapshot.data != null) {
            final data = snapshot.data!.value as Map<dynamic, dynamic>?;
            final isActive = data != null && (data['isActive'] == true || data['isActive'] == 1);
            if (!isActive) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.block, color: Colors.red, size: 60),
                      SizedBox(height: 24),
                      Text(
                        'يرجى مراجعة إدارة عيادات الأسنان في الجامعة لتفعيل حسابك.',
                        style: TextStyle(fontSize: 20, color: Colors.red, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
          }
          final mediaQuery = MediaQuery.of(context);
          final isSmallScreen = mediaQuery.size.width < 350;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final gridCount = isWide ? 4 : (constraints.maxWidth > 600 ? 3 : 2);
              // No ConstrainedBox or Center, let it fill the screen on large displays
              return Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                    ),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: mediaQuery.padding.bottom + 20),
                    child: Column(
                      children: [
                        // User info section
                        Container(
                          margin: const EdgeInsets.all(20),
                          height: isSmallScreen ? 180 : 200,
                          decoration: BoxDecoration(
                            image: const DecorationImage(
                              image: AssetImage('lib/assets/backgrownd.png'),
                              fit: BoxFit.cover,
                            ),
                            color: const Color(0x4D000000),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: const [
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
                                    _userImageUrl.isNotEmpty
                                        ? CircleAvatar(
                                            radius: isSmallScreen ? 30 : 40,
                                            backgroundColor: Colors.white.withAlpha((0.8 * 255).toInt()),
                                            child: ClipOval(
                                              child: Image.memory(
                                                base64Decode(_userImageUrl.replaceFirst('data:image/jpeg;base64,', '')),
                                                width: isSmallScreen ? 60 : 80,
                                                height: isSmallScreen ? 60 : 80,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          )
                                        : CircleAvatar(
                                            radius: isSmallScreen ? 30 : 40,
                                            backgroundColor: Colors.white.withAlpha((0.8 * 255).toInt()),
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
                                      _translate(context, 'student'),
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
                          child: GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: gridCount,
                            crossAxisSpacing: 15,
                            mainAxisSpacing: 15,
                            childAspectRatio: 1.1,
                            children: [
                              _buildFeatureBox(
                                context,
                                Icons.assignment,
                                _translate(context, 'view_examinations'),
                                primaryColor,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ExaminedPatientsPage(),
                                    ),
                                  );
                                },
                              ),
                              _buildFeatureBox(
                                context,
                                Icons.medical_services,
                                _translate(context, 'examine_patient'),
                                Colors.green,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const StudentGroupsPage(),
                                    ),
                                  );
                                },
                              ),
                              _buildFeatureBox(
                                context,
                                Icons.calendar_today,
                                _translate(context, 'my_appointments'),
                                Colors.orange,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const StudentAppointmentsPage(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    // ...existing code for the normal dashboard body if user is null...
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 350;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        final gridCount = isWide ? 4 : (constraints.maxWidth > 600 ? 3 : 2);
        // No ConstrainedBox or Center, let it fill the screen on large displays
        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.only(bottom: mediaQuery.padding.bottom + 20),
              child: Column(
                children: [
                  // User info section
                  Container(
                    margin: const EdgeInsets.all(20),
                    height: isSmallScreen ? 180 : 200,
                    decoration: BoxDecoration(
                      image: const DecorationImage(
                        image: AssetImage('lib/assets/backgrownd.png'),
                        fit: BoxFit.cover,
                      ),
                      color: const Color(0x4D000000),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: const [
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
                              _userImageUrl.isNotEmpty
                                  ? CircleAvatar(
                                      radius: isSmallScreen ? 30 : 40,
                                      backgroundColor: Colors.white.withAlpha((0.8 * 255).toInt()),
                                      child: ClipOval(
                                        child: Image.memory(
                                          base64Decode(_userImageUrl.replaceFirst('data:image/jpeg;base64,', '')),
                                          width: isSmallScreen ? 60 : 80,
                                          height: isSmallScreen ? 60 : 80,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    )
                                  : CircleAvatar(
                                      radius: isSmallScreen ? 30 : 40,
                                      backgroundColor: Colors.white.withAlpha((0.8 * 255).toInt()),
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
                                _translate(context, 'student'),
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
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: gridCount,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 1.1,
                      children: [
                        _buildFeatureBox(
                          context,
                          Icons.assignment,
                          _translate(context, 'view_examinations'),
                          primaryColor,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ExaminedPatientsPage(),
                              ),
                            );
                          },
                        ),
                        _buildFeatureBox(
                          context,
                          Icons.medical_services,
                          _translate(context, 'examine_patient'),
                          Colors.green,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const StudentGroupsPage(),
                              ),
                            );
                          },
                        ),
                        _buildFeatureBox(
                          context,
                          Icons.calendar_today,
                          _translate(context, 'my_appointments'),
                          Colors.orange,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const StudentAppointmentsPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showNotificationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_translate(context, 'notifications')),
          content: notifications.isEmpty
              ? Text(_translate(context, 'no_notifications'))
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return ListTile(
                        leading: const Icon(Icons.notifications),
                        title: Text(notification['title'] ?? ''),
                        subtitle: Text(notification['message'] ?? ''),
                        trailing: Text(notification['date'] ?? ''),
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_translate(context, 'close')),
            ),
          ],
        );
      },
    );
  }

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
                      color: color.withAlpha(25),
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

  // Widget _buildBottomNavigation(BuildContext context) {
  //   final mediaQuery = MediaQuery.of(context);
  //   final isSmallScreen = mediaQuery.size.width < 350;
  //   final isArabic = _isArabic(context);

  //   return Container(
  //     decoration: BoxDecoration(
  //       border:
  //           Border(top: BorderSide(color: Colors.grey.shade300, width: 0.5)),
  //     ),
  //     child: SafeArea(
  //       top: false,
  //       child: SizedBox(
  //         height: 60 + mediaQuery.padding.bottom,
  //         child: Padding(
  //           padding: EdgeInsets.only(bottom: mediaQuery.padding.bottom),
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //             children: [
  //               _buildBottomNavItem(
  //                   context, Icons.home, 'home', isSmallScreen, isArabic),
  //               _buildBottomNavItem(context, Icons.settings, 'settings',
  //                   isSmallScreen, isArabic),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildBottomNavItem(
  //   BuildContext context,
  //   IconData icon,
  //   String labelKey,
  //   bool isSmallScreen,
  //   bool isArabic,
  // ) {
  //   final text = _translate(context, labelKey);

  //   return Expanded(
  //     child: Material(
  //       color: Colors.transparent,
  //       child: InkWell(
  //         onTap: () {
  //           // Handle navigation
  //         },
  //         child: Container(
  //           padding: const EdgeInsets.symmetric(vertical: 6),
  //           child: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             mainAxisAlignment: MainAxisAlignment.center,
  //             children: [
  //               Icon(
  //                 icon,
  //                 size: isSmallScreen ? 20 : 24,
  //                 color: primaryColor,
  //               ),
  //               const SizedBox(height: 2),
  //               Text(
  //                 text,
  //                 style: TextStyle(
  //                   fontSize: isArabic
  //                       ? (isSmallScreen ? 8 : 10)
  //                       : (isSmallScreen ? 9 : 11),
  //                   color: primaryColor,
  //                 ),
  //                 maxLines: 1,
  //                 overflow: TextOverflow.ellipsis,
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }
}
