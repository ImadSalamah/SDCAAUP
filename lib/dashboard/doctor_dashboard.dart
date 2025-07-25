import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/language_provider.dart';
import '../loginpage.dart';
import '../Shared/waiting_list_page.dart';
import '../Doctor/doctor_pending_cases_page.dart';
import '../Doctor/groups_page.dart';
import '../Doctor/examined_patients_page.dart';
import '../Doctor/doctor_sidebar.dart';
import '../notifications_page.dart';
import '../Doctor/prescription_page.dart';
import '../Doctor/doctor_xray_request_page.dart';
import '../Doctor/assign_patients_to_student_page.dart';
import '../forms/clinical_procedures_form.dart';


class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late DatabaseReference _supervisorRef;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _supervisorName = '';
  String _supervisorImageUrl = '';
  bool _isLoading = true;
  bool _hasError = false;
  final int _retryCount = 0;
  final int _maxRetries = 3;
  bool _isSidebarVisible = false;

  bool hasNewNotification = false;

  final Map<String, Map<String, String>> _translations = {
    'supervisor': {'ar': 'مشرف', 'en': 'Supervisor'},
    'initial_examination': {'ar': 'الفحص الأولي', 'en': 'Initial Examination'},
    'students_evaluation': {'ar': 'تقييم الطلاب', 'en': 'Students Evaluation'},
    'waiting_list': {'ar': 'قائمة الانتظار', 'en': 'Waiting List'},
    'appointments': {'ar': 'المواعيد', 'en': 'Appointments'},
    'reports': {'ar': 'التقارير', 'en': 'Reports'},
    'profile': {'ar': 'الملف الشخصي', 'en': 'Profile'},
    'history': {'ar': 'السجل', 'en': 'History'},
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
    'signing_out': {'ar': 'تسجيل الخروج', 'en': 'Sign out'},
    'sign_out_error': {'ar': 'خطأ في تسجيل الخروج', 'en': 'Sign out error'},
    'supervision_groups': {'ar': 'شعب الإشراف', 'en': 'Supervision Groups'},
    'examined_patients': {'ar': 'المرضى المفحوصين', 'en': 'Examined Patients'},
    'prescription': {'ar': 'وصفة طبية', 'en': 'Prescription'},
    'xray_request': {'ar': 'طلب أشعة', 'en': 'X-ray Request'},
    'home': {'ar': 'الرئيسية', 'en': 'Home'},
    'show_sidebar': {'ar': 'إظهار القائمة', 'en': 'Show Sidebar'},
    'hide_sidebar': {'ar': 'إخفاء القائمة', 'en': 'Hide Sidebar'},
    'assign_patients_to_students': {'ar': 'تعيين مرضى للطلاب', 'en': 'Assign Patients to Students'},
  };

  @override
  void initState() {
    // تم إزالة تعيين اللغة الافتراضية للإنجليزية عند فتح الشاشة
    super.initState();
    _initializeSupervisorReference();
    _setupRealtimeListener();
    _listenForNotifications();
    final user = _auth.currentUser;
    debugPrint("Current user UID: ${user?.uid}");
  }

  void _initializeSupervisorReference() {
    final user = _auth.currentUser;
    if (user != null) {
      _supervisorRef = FirebaseDatabase.instance.ref('users/${user.uid}');
    }
  }

  void _setupRealtimeListener() {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _supervisorName = _translate(context, 'supervisor');
        _isLoading = false;
      });
      return;
    }

    _supervisorRef.onValue.listen((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists) {
        setState(() {
          _supervisorName = _translate(context, 'supervisor');
          _isLoading = false;
          _hasError = false;
        });
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
      _updateSupervisorData(data);
    }, onError: (error) {
      debugPrint('Realtime listener error: $error');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    });
  }

  void _updateSupervisorData(Map<dynamic, dynamic> data) {
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
      _supervisorName = fullName.isNotEmpty
          ? _isArabic(context) ? "د. $fullName" : "د. $fullName"
          : _translate(context, 'supervisor');
      _supervisorImageUrl =
          imageData.isNotEmpty ? 'data:image/jpeg;base64,$imageData' : '';
      _isLoading = false;
      _hasError = false;
    });
  }

  Future<void> _loadSupervisorDataOnce() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _supervisorName = _translate(context, 'supervisor');
          _isLoading = false;
        });
        return;
      }

      final snapshot = await _supervisorRef.get();
      if (!mounted) return;

      if (!snapshot.exists) {
        setState(() {
          _supervisorName = _translate(context, 'supervisor');
          _isLoading = false;
        });
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
      _updateSupervisorData(data);
    } catch (e) {
      debugPrint('Error loading supervisor data: $e');
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

  void showDashboardBanner(String message, {Color backgroundColor = Colors.green}) {
    ScaffoldMessenger.of(context).clearMaterialBanners();
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: backgroundColor,
        actions: [
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).clearMaterialBanners(),
            child: Text(
              _translate(context, 'close'),
              style: const TextStyle(color: Colors.white),
            ),
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
          showDashboardBanner(
            data['title'] != null ? '${data['title']}\n${data['message'] ?? ''}' : _translate(context, 'new_notification'),
            backgroundColor: Colors.blue.shade700,
          );
        }
      }
    });
  }

  String _translate(BuildContext context, String key) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    return _translations[key]?[languageProvider.currentLocale.languageCode] ?? key;
  }

  bool _isArabic(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    return languageProvider.currentLocale.languageCode == 'ar';
  }

  String _getErrorMessage() {
    return _translate(context, 'error_loading_data');
  }

  Future<void> _signOut() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(_translate(context, 'signing_out')),
              ],
            ),
          );
        },
      );

      await _auth.signOut();
      if (!mounted) return;

      Navigator.of(context).pop();
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_translate(context, 'sign_out_error')}: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 350;
    final isLargeScreen = mediaQuery.size.width >= 900;

    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        ScaffoldMessenger.of(context).clearMaterialBanners();
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
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
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              if (isLargeScreen) {
                setState(() {
                  _isSidebarVisible = !_isSidebarVisible;
                });
              } else {
                _scaffoldKey.currentState?.openDrawer();
              }
            },
            tooltip: _isSidebarVisible
                ? _translate(context, 'hide_sidebar')
                : _translate(context, 'show_sidebar'),
          ),
          actions: [
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
              icon: const Icon(Icons.language, color: Colors.white),
              onPressed: () => languageProvider.toggleLanguage(),
            ),
            IconButton(
              onPressed: _signOut,
              icon: const Icon(Icons.logout, color: Colors.white),
            )
          ],
        ),
        drawer: !isLargeScreen
            ? DoctorSidebar(
                primaryColor: primaryColor,
                accentColor: accentColor,
                userName: _supervisorName,
                userImageUrl: _supervisorImageUrl,
                onLogout: _signOut,
                parentContext: context,
                translate: _translate,
                doctorUid: FirebaseAuth.instance.currentUser?.uid ?? '',
              )
            : null,
        body: Stack(
          children: [
            if (isLargeScreen && _isSidebarVisible)
              Directionality(
                textDirection: _isArabic(context) ? TextDirection.rtl : TextDirection.ltr,
                child: SizedBox(
                  width: 260,
                  child: DoctorSidebar(
                    primaryColor: primaryColor,
                    accentColor: accentColor,
                    userName: _supervisorName,
                    userImageUrl: _supervisorImageUrl,
                    onLogout: _signOut,
                    parentContext: context,
                    collapsed: false,
                    translate: _translate,
                    doctorUid: FirebaseAuth.instance.currentUser?.uid ?? '',
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(
                left: (isLargeScreen && _isSidebarVisible && !_isArabic(context)) ? 260 : 0,
                right: (isLargeScreen && _isSidebarVisible && _isArabic(context)) ? 260 : 0,
              ),
              child: Directionality(
                textDirection: _isArabic(context) ? TextDirection.rtl : TextDirection.ltr,
                child: _buildBody(context),
              ),
            ),
          ],
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
              onPressed: _loadSupervisorDataOnce,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
        future: _supervisorRef.get(),
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

          // ...existing code for dashboard body...
          final mediaQuery = MediaQuery.of(context);

          final features = [
            {
              'icon': Icons.list_alt,
              'title': _translate(context, 'waiting_list'),
              'color': primaryColor,
              'onTap': () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WaitingListPage(userRole: 'doctor'),
                  ),
                );
              }
            },
            {
              'icon': Icons.medical_information,
              'title': _isArabic(context) ? 'نموذج الإجراءات السريرية' : 'Clinical Procedures Form',
              'color': Colors.redAccent,
              'onTap': () {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ClinicalProceduresForm(uid: user.uid),
                    ),
                  );
                }
              }
            },
            {
              'icon': Icons.school,
              'title': _translate(context, 'students_evaluation'),
              'color': Colors.green,
              'onTap': () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const DoctorPendingCasesPage()),
                );
              }
            },
            {
              'icon': Icons.group,
              'title': _translate(context, 'supervision_groups'),
              'color': Colors.blue,
              'onTap': () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DoctorGroupsPage(),
                  ),
                );
              }
            },
            {
              'icon': Icons.check_circle,
              'title': _translate(context, 'examined_patients'),
              'color': Colors.teal,
              'onTap': () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ExaminedPatientsPage(),
                  ),
                );
              }
            },
            {
              'icon': Icons.medical_services,
              'title': _translate(context, 'prescription'),
              'color': Colors.deepPurple,
              'onTap': () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PrescriptionPage(
                      isArabic: _isArabic(context),
                    ),
                  ),
                );
              }
            },
            {
              'icon': Icons.camera_alt,
              'title': _translate(context, 'xray_request'),
              'color': Colors.orange,
              'onTap': () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DoctorXrayRequestPage(),
                  ),
                );
              }
            },
            {
              'icon': Icons.assignment_ind,
              'title': _translate(context, 'assign_patients_to_students'),
              'color': Colors.indigo,
              'onTap': () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AssignPatientsToStudentPage(),
                  ),
                );
              }
            },
          ];

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isSmallScreen = width < 350;
              final isWide = width > 900;
              final isTablet = width >= 600 && width <= 900;
              final crossAxisCount = isWide ? 4 : (isTablet ? 3 : 2);
              final gridChildAspectRatio = isWide ? 1.1 : (isTablet ? 1.2 : 1.1);

              return Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                    ),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: mediaQuery.padding.bottom + (isSmallScreen ? 10 : 20),
                    ),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          height: isSmallScreen ? 210 : (isWide ? 210 : (isTablet ? 250 : 230)),
                          decoration: BoxDecoration(
                            image: const DecorationImage(
                              image: AssetImage('lib/assets/backgrownd.png'),
                              fit: BoxFit.fill,
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
                                    _supervisorImageUrl.isNotEmpty
                                        ? CircleAvatar(
                                            radius: isSmallScreen
                                                ? 30
                                                : (isWide ? 55 : (isTablet ? 45 : 40)),
                                            backgroundColor:
                                                Colors.white.withAlpha(204),
                                            child: ClipOval(
                                              child: Image.memory(
                                                base64Decode(_supervisorImageUrl.replaceFirst('data:image/jpeg;base64,', '')),
                                                width: isSmallScreen
                                                    ? 60
                                                    : (isWide ? 110 : (isTablet ? 90 : 80)),
                                                height: isSmallScreen
                                                    ? 60
                                                    : (isWide ? 110 : (isTablet ? 90 : 80)),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          )
                                        : CircleAvatar(
                                            radius: isSmallScreen
                                                ? 30
                                                : (isWide ? 55 : (isTablet ? 45 : 40)),
                                            backgroundColor:
                                                Colors.white.withAlpha(204),
                                            child: Icon(
                                              Icons.person,
                                              size: isSmallScreen
                                                  ? 30
                                                  : (isWide ? 55 : (isTablet ? 45 : 40)),
                                              color: accentColor,
                                            ),
                                          ),
                                    SizedBox(height: isWide ? 30 : (isTablet ? 25 : 15)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(
                                        _supervisorName,
                                        style: TextStyle(
                                          fontSize: isSmallScreen
                                              ? 16
                                              : (isWide ? 28 : (isTablet ? 22 : 20)),
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
                          child: GridView.builder(
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
                                feature['onTap'] as VoidCallback,
                              );
                            },
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

    final features = [
      {
        'icon': Icons.list_alt,
        'title': _translate(context, 'waiting_list'),
        'color': primaryColor,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const WaitingListPage(userRole: 'doctor'),
            ),
          );
        }
      },
      
      {
        'icon': Icons.medical_information,
        'title': _isArabic(context) ? 'نموذج الإجراءات السريرية' : 'Clinical Procedures Form',
        'color': Colors.redAccent,
        'onTap': () {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ClinicalProceduresForm(uid: user.uid),
              ),
            );
          }
        }
      },
      {
        'icon': Icons.medical_information,
        'title': _isArabic(context) ? 'نموذج الإجراءات السريرية' : 'Clinical Procedures Form',
        'color': Colors.redAccent,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  return ClinicalProceduresForm(uid: user.uid);
                } else {
                  return const SizedBox();
                }
              },
            ),
          );
        }
      },
      {
        'icon': Icons.school,
        'title': _translate(context, 'students_evaluation'),
        'color': Colors.green,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const DoctorPendingCasesPage()),
          );
        }
      },
      {
        'icon': Icons.group,
        'title': _translate(context, 'supervision_groups'),
        'color': Colors.blue,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DoctorGroupsPage(),
            ),
          );
        }
      },
      {
        'icon': Icons.check_circle,
        'title': _translate(context, 'examined_patients'),
        'color': Colors.teal,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ExaminedPatientsPage(),
            ),
          );
        }
      },
      {
        'icon': Icons.medical_services,
        'title': _translate(context, 'prescription'),
        'color': Colors.deepPurple,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PrescriptionPage(
                isArabic: _isArabic(context),
              ),
            ),
          );
        }
      },
      {
        'icon': Icons.camera_alt,
        'title': _translate(context, 'xray_request'),
        'color': Colors.orange,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DoctorXrayRequestPage(),
            ),
          );
        }
      },
      {
        'icon': Icons.assignment_ind,
        'title': _translate(context, 'assign_patients_to_students'),
        'color': Colors.indigo,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AssignPatientsToStudentPage(),
            ),
          );
        }
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isSmallScreen = width < 350;
        final isWide = width > 900;
        final isTablet = width >= 600 && width <= 900;
        final crossAxisCount = isWide ? 4 : (isTablet ? 3 : 2);
        final gridChildAspectRatio = isWide ? 1.1 : (isTablet ? 1.2 : 1.1);

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: mediaQuery.padding.bottom + (isSmallScreen ? 10 : 20),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(20),
                    height: isSmallScreen ? 180 : (isWide ? 240 : (isTablet ? 220 : 200)),
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
                              _supervisorImageUrl.isNotEmpty
                                  ? CircleAvatar(
                                      radius: isSmallScreen
                                          ? 30
                                          : (isWide ? 55 : (isTablet ? 45 : 40)),
                                      backgroundColor:
                                          Colors.white.withAlpha(204),
                                      child: ClipOval(
                                        child: Image.memory(
                                          base64Decode(_supervisorImageUrl.replaceFirst('data:image/jpeg;base64,', '')),
                                          width: isSmallScreen
                                              ? 60
                                              : (isWide ? 110 : (isTablet ? 90 : 80)),
                                          height: isSmallScreen
                                              ? 60
                                              : (isWide ? 110 : (isTablet ? 90 : 80)),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    )
                                  : CircleAvatar(
                                      radius: isSmallScreen
                                          ? 30
                                          : (isWide ? 55 : (isTablet ? 45 : 40)),
                                      backgroundColor:
                                          Colors.white.withAlpha(204),
                                      child: Icon(
                                        Icons.person,
                                        size: isSmallScreen
                                            ? 30
                                            : (isWide ? 55 : (isTablet ? 45 : 40)),
                                        color: accentColor,
                                      ),
                                    ),
                              SizedBox(height: isWide ? 30 : (isTablet ? 25 : 15)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  _supervisorName,
                                  style: TextStyle(
                                    fontSize: isSmallScreen
                                        ? 16
                                        : (isWide ? 28 : (isTablet ? 22 : 20)),
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
                    child: GridView.builder(
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
                          feature['onTap'] as VoidCallback,
                        );
                      },
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

  Widget _buildFeatureBox(
    BuildContext context,
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    final width = MediaQuery.of(context).size.width;
    final isSmallScreen = width < 350;
    final isTablet = width >= 600;

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
                padding: EdgeInsets.all(isTablet ? 18 : 12),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: isSmallScreen
                      ? 24
                      : (isTablet ? 40 : 30),
                  color: color,
                ),
              ),
              SizedBox(height: isTablet ? 16 : 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isSmallScreen
                        ? 14
                        : (isTablet ? 18 : 16),
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

}