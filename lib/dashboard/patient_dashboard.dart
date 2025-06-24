import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/language_provider.dart';
import '../loginpage.dart';
import '../notifications_page.dart';
import '../patient/patient_prescriptions_page.dart';
import '../patient/patient_profile_page.dart';
import '../patient/patient_appointments_page.dart';
import '../patient/patient_sidebar.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late DatabaseReference _patientRef;

  String _patientName = '';
  String _patientImageUrl = '';
  bool _isLoading = true;
  bool _hasError = false;
  final int _retryCount = 0;
  final int _maxRetries = 3;

  bool hasNewNotification = false;

  final Map<String, Map<String, String>> _translations = {
    'patient': {'ar': 'مريض', 'en': 'Patient'},
    'medical_records': {'ar': 'السجلات الطبية', 'en': 'Medical Records'},
    'appointments': {'ar': 'المواعيد', 'en': 'Appointments'},
    'prescriptions': {'ar': 'الوصفات الطبية', 'en': 'Prescriptions'},
    'profile': {'ar': 'الملف الشخصي', 'en': 'Profile'},
    'home': {'ar': 'الرئيسية', 'en': 'Home'},
    'history': {'ar': 'السجل', 'en': 'History'},
    'notifications': {'ar': 'الإشعارات', 'en': 'Notifications'},
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
    'logout_error': {'ar': 'خطأ في تسجيل الخروج', 'en': 'Logout error'},
  };

  @override
  void initState() {
    super.initState();
    _initializePatientReference();
    _setupRealtimeListener();
    _listenForNotifications();
    final user = _auth.currentUser;
    debugPrint("Current patient UID: ${user?.uid}");

    // التحقق من حالة المستخدم عند التحميل
    if (_auth.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _redirectToLogin();
      });
    }
  }

  void _initializePatientReference() {
    final user = _auth.currentUser;
    if (user != null) {
      _patientRef = FirebaseDatabase.instance.ref('users/${user.uid}');
    }
  }

  void _setupRealtimeListener() {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _patientName = _translate(context, 'patient');
        _isLoading = false;
      });
      return;
    }

    _patientRef.onValue.listen((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists) {
        setState(() {
          _patientName = _translate(context, 'patient');
          _isLoading = false;
          _hasError = false;
        });
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
      _updatePatientData(data);
    }, onError: (error) {
      debugPrint('Realtime listener error: $error');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    });
  }

  void _updatePatientData(Map<dynamic, dynamic> data) {
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
      _patientName =
          fullName.isNotEmpty ? fullName : _translate(context, 'patient');
      _patientImageUrl =
          imageData.isNotEmpty ? 'data:image/jpeg;base64,$imageData' : '';
      _isLoading = false;
      _hasError = false;
    });
  }

  Future<void> _loadPatientDataOnce() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _patientName = _translate(context, 'patient');
          _isLoading = false;
        });
        return;
      }

      final snapshot = await _patientRef.get();

      if (!snapshot.exists) {
        if (!mounted) return;
        setState(() {
          _patientName = _translate(context, 'patient');
          _isLoading = false;
        });
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
      if (!mounted) return;
      _updatePatientData(data);
    } catch (e) {
      debugPrint('Error loading patient data: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_translate(context, 'error_loading_data')),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      _redirectToLogin();
    } catch (e) {
      debugPrint('Error signing out: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_translate(context, 'logout_error')),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _redirectToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
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

  void _handleSidebarNavigation(String route) {
    if (ModalRoute.of(context)?.settings.name == route) return;
    switch (route) {
      case '/patient_dashboard':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PatientDashboard()),
        );
        break;
      case '/medical_records':
        _navigateTo(context, '/medical_records');
        break;
      case '/patient_appointments':
        final user = _auth.currentUser;
        if (user != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PatientAppointmentsPage(
                patientUid: user.uid,
                patientName: _patientName,
              ),
            ),
          );
        }
        break;
      case '/patient_prescriptions':
        final user = _auth.currentUser;
        if (user != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PatientPrescriptionsPage(patientId: user.uid),
            ),
          );
        }
        break;
      case '/patient_profile':
        _patientRef.get().then((snapshot) {
          final data = Map<String, dynamic>.from(snapshot.value as Map);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PatientProfilePage(
                patientData: data,
                patientImageUrl: _patientImageUrl,
              ),
            ),
          );
        });
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 350;

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
                onPressed: _signOut,
                icon: const Icon(Icons.logout, color: Colors.white),
              )
            ],
          ),
          drawer: PatientSidebar(
            onNavigate: _handleSidebarNavigation,
            currentRoute: ModalRoute.of(context)?.settings.name ?? '/patient_dashboard',
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
          bottomNavigationBar: _buildBottomNavigation(context),
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
              onPressed: _loadPatientDataOnce,
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
        future: _patientRef.get(),
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
                                _patientImageUrl.isNotEmpty
                                    ? CircleAvatar(
                                        radius: isSmallScreen ? 30 : 40,
                                        backgroundColor:
                                            Colors.white.withValues(alpha: 0.8),
                                        child: ClipOval(
                                          child: Image.memory(
                                            base64.decode(
                                                _patientImageUrl.replaceFirst(
                                                    'data:image/jpeg;base64,', '')),
                                            width: isSmallScreen ? 60 : 80,
                                            height: isSmallScreen ? 60 : 80,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      )
                                    : CircleAvatar(
                                        radius: isSmallScreen ? 30 : 40,
                                        backgroundColor:
                                            Colors.white.withValues(alpha: 0.8),
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
                                    _patientName,
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
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        childAspectRatio: 1.1,
                        children: [
                          _buildFeatureBox(
                            context,
                            Icons.medical_services,
                            _translate(context, 'medical_records'),
                            primaryColor,
                            () => _navigateTo(context, '/medical_records'),
                          ),
                          _buildFeatureBox(
                            context,
                            Icons.calendar_today,
                            _translate(context, 'appointments'),
                            Colors.green,
                            () {
                              final user = _auth.currentUser;
                              if (user != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PatientAppointmentsPage(
                                      patientUid: user.uid,
                                      patientName: _patientName,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                          _buildFeatureBox(
                            context,
                            Icons.medication,
                            _translate(context, 'prescriptions'),
                            Colors.orange,
                            () {
                              final user = _auth.currentUser;
                              if (user != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PatientPrescriptionsPage(patientId: user.uid),
                                  ),
                                );
                              }
                            },
                          ),
                          _buildFeatureBox(
                            context,
                            Icons.person,
                            _translate(context, 'profile'),
                            Colors.purple,
                            () async {
                              final snapshot = await _patientRef.get();
                              final data = Map<String, dynamic>.from(snapshot.value as Map);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PatientProfilePage(
                                    patientData: data,
                                    patientImageUrl: _patientImageUrl,
                                  ),
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

    // ...existing code for the normal dashboard body if user is null...
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 350;

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
                          _patientImageUrl.isNotEmpty
                              ? CircleAvatar(
                                  radius: isSmallScreen ? 30 : 40,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.8),
                                  child: ClipOval(
                                    child: Image.memory(
                                      base64.decode(
                                          _patientImageUrl.replaceFirst(
                                              'data:image/jpeg;base64,', '')),
                                      width: isSmallScreen ? 60 : 80,
                                      height: isSmallScreen ? 60 : 80,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              : CircleAvatar(
                                  radius: isSmallScreen ? 30 : 40,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.8),
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
                              _patientName,
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.1,
                  children: [
                    _buildFeatureBox(
                      context,
                      Icons.medical_services,
                      _translate(context, 'medical_records'),
                      primaryColor,
                      () => _navigateTo(context, '/medical_records'),
                    ),
                    _buildFeatureBox(
                      context,
                      Icons.calendar_today,
                      _translate(context, 'appointments'),
                      Colors.green,
                      () {
                        final user = _auth.currentUser;
                        if (user != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PatientAppointmentsPage(
                                patientUid: user.uid,
                                patientName: _patientName,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    _buildFeatureBox(
                      context,
                      Icons.medication,
                      _translate(context, 'prescriptions'),
                      Colors.orange,
                      () {
                        final user = _auth.currentUser;
                        if (user != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PatientPrescriptionsPage(patientId: user.uid),
                            ),
                          );
                        }
                      },
                    ),
                    _buildFeatureBox(
                      context,
                      Icons.person,
                      _translate(context, 'profile'),
                      Colors.purple,
                      () async {
                        final snapshot = await _patientRef.get();
                        final data = Map<String, dynamic>.from(snapshot.value as Map);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PatientProfilePage(
                              patientData: data,
                              patientImageUrl: _patientImageUrl,
                            ),
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
  }

  Widget _buildFeatureBox(
    BuildContext context,
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    final isSmallScreen = MediaQuery.of(context).size.width < 350;

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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: isSmallScreen ? 24 : 30,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
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
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 350;
    final isArabic = _isArabic(context);

    return Container(
      decoration: BoxDecoration(
        border:
            Border(top: BorderSide(color: Colors.grey.shade300, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60 + mediaQuery.padding.bottom,
          child: Padding(
            padding: EdgeInsets.only(bottom: mediaQuery.padding.bottom),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBottomNavItem(
                    context, Icons.home, 'home', isSmallScreen, isArabic),
                _buildBottomNavItem(
                    context, Icons.history, 'history', isSmallScreen, isArabic),
                _buildBottomNavItem(context, Icons.settings, 'settings',
                    isSmallScreen, isArabic),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(
    BuildContext context,
    IconData icon,
    String labelKey,
    bool isSmallScreen,
    bool isArabic,
  ) {
    final text = _translate(context, labelKey);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Handle navigation
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: isSmallScreen ? 20 : 24,
                  color: primaryColor,
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: isArabic
                        ? (isSmallScreen ? 8 : 10)
                        : (isSmallScreen ? 9 : 11),
                    color: primaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, String route) {
    Navigator.pushNamed(context, route);
  }
}
