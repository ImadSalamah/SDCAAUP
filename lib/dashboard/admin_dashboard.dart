import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../loginpage.dart';
import '../Admin/add_user_page.dart';
import '../Admin/edit_user_page.dart';
import '../Admin/add_student.dart';
import '../Admin/manage_study_groups_page.dart';
import '../Admin/admin_sidebar.dart';
import '../notifications_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);
  final Color webSidebarColor = const Color(0xFFF5F5F5);
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late DatabaseReference _usersRef;
  late DatabaseReference _adminRef;

  String _userName = '';
  String _userImageUrl = '';
  List<Map<String, dynamic>> allUsers = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool isSidebarOpen = false;
  bool hasNewNotification = false;

  final Map<String, Map<String, String>> _translations = {
    'admin_dashboard': {'ar': 'لوحة الإدارة', 'en': 'Admin Dashboard'},
    'manage_users': {'ar': 'إدارة المستخدمين', 'en': 'Manage Users'},
    'add_user': {'ar': 'إضافة مستخدم', 'en': 'Add User'},
    'add_user_student': {'ar': 'إضافة طالب طب اسنان', 'en': 'Add Dental Student'},
    'change_permissions': {'ar': 'تغيير الصلاحيات', 'en': 'Change Permissions'},
    'admin': {'ar': 'مدير النظام', 'en': 'System Admin'},
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
    'logout': {'ar': 'تسجيل الخروج', 'en': 'Logout'},
    'email': {'ar': 'البريد الإلكتروني', 'en': 'Email'},
    'password': {'ar': 'كلمة المرور', 'en': 'Password'},
    'permissions': {'ar': 'الصلاحيات', 'en': 'Permissions'},
    'save': {'ar': 'حفظ', 'en': 'Save'},
    'cancel': {'ar': 'إلغاء', 'en': 'Cancel'},
    'close': {'ar': 'إغلاق', 'en': 'Close'},
    'menu': {'ar': 'القائمة', 'en': 'Menu'},
    'study_groups': {'ar': 'الشعب الدراسية', 'en': 'Study Groups'},
    'manage_study_groups': {
      'ar': 'إدارة الشعب الدراسية',
      'en': 'Manage Study Groups'
    },
    'add_study_group': {'ar': 'إضافة شعبة دراسية', 'en': 'Add Study Group'},
    'edit_study_groups': {
      'ar': 'تعديل الشعب الدراسية',
      'en': 'Edit Study Groups'
    },
  };

  @override
  void initState() {
    super.initState();
    _initializeReferences();
    _loadAdminData();
    _loadAllUsers();
    _listenForNotifications();
  }

  void _initializeReferences() {
    _usersRef = FirebaseDatabase.instance.ref('users');
    final user = _auth.currentUser;
    if (user != null) {
      _adminRef = FirebaseDatabase.instance.ref('users/${user.uid}');
    }
  }

  Future<void> _loadAdminData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _userName = _translate(context, 'admin');
          _isLoading = false;
        });
        return;
      }

      final snapshot = await _adminRef.get();
      if (!mounted) return;
      if (!snapshot.exists) {
        setState(() {
          _userName = _translate(context, 'admin');
          _isLoading = false;
        });
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
      if (!mounted) return;
      _updateUserData(data);
    } catch (e) {
      debugPrint('Error loading admin data: $e');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAllUsers() async {
    try {
      final snapshot = await _usersRef.get();
      if (!snapshot.exists) {
        if (!mounted) return;
        setState(() {
          allUsers = [];
          _isLoading = false;
        });
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
      final List<Map<String, dynamic>> users = [];

      data.forEach((key, value) {
        if (value is Map<dynamic, dynamic>) {
          users.add({
            'uid': key,
            ...Map<String, dynamic>.from(value),
          });
        }
      });

      if (!mounted) return;
      setState(() {
        allUsers = users;
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
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
      _userName = fullName.isNotEmpty ? fullName : _translate(context, 'admin');
      _userImageUrl =
          imageData.isNotEmpty ? 'data:image/jpeg;base64,$imageData' : '';
      _hasError = false;
    });
  }

  String _translate(BuildContext context, String key) {
    final languageProvider =
        Provider.of<LanguageProvider>(context); // listen: true for rebuild
    return _translations[key]?[languageProvider.currentLocale.languageCode] ?? key;
  }

  bool _isArabic(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context); // listen: true for rebuild
    return languageProvider.currentLocale.languageCode == 'ar';
  }

  Future<void> _logout() async {
    await _auth.signOut();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  Widget _buildLanguageButton(BuildContext context) {
    return IconButton(
      icon: Icon(
        _isArabic(context) ? Icons.language : Icons.language,
        color: Colors.white,
      ),
      
      onPressed: () {
        Provider.of<LanguageProvider>(context, listen: false).toggleLanguage();
      },
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return Directionality(
          textDirection: _isArabic(context) ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: Text(_translate(context, 'app_name')),
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  setState(() {
                    isSidebarOpen = !isSidebarOpen;
                  });
                },
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
                _buildLanguageButton(context),
                IconButton(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.white),
                )
              ],
            ),
            body: Stack(
              children: [
                // Main content
                Positioned.fill(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _hasError
                          ? _buildErrorWidget(context)
                          : _buildMainContent(context),
                ),
                // Sidebar overlay
                if (isSidebarOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          isSidebarOpen = false;
                        });
                      },
                      child: Container(
                        color: Colors.black.withOpacity(0.3),
                        alignment: _isArabic(context)
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () {}, // Prevents tap from propagating
                          child: SizedBox(
                            width: 260,
                            height: double.infinity,
                            child: Material(
                              elevation: 8,
                              child: Stack(
                                children: [
                                  AdminSidebar(
                                    primaryColor: primaryColor,
                                    accentColor: accentColor,
                                    userName: _userName,
                                    userImageUrl: _userImageUrl,
                                    onLogout: _logout,
                                    parentContext: context,
                                    translate: _translate,
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: _isArabic(context) ? null : 0,
                                    left: _isArabic(context) ? 0 : null,
                                    child: IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        setState(() {
                                          isSidebarOpen = false;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainContent(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final isSmallScreen = width < 350;
    final isWide = width > 900;
    final isTablet = width >= 600 && width <= 900;
    final gridCount = isWide ? 4 : (isTablet ? 3 : 2);
    final horizontalPadding = isWide ? 60.0 : (isTablet ? 32.0 : 12.0);
    final gridChildAspectRatio = isWide ? 1.1 : (isTablet ? 1.2 : 1.1);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.only(
                left: horizontalPadding,
                right: horizontalPadding,
                bottom: mediaQuery.padding.bottom + (isSmallScreen ? 10 : 20),
              ),
              child: Column(
                children: [
                  _buildUserInfoCard(context, isSmallScreen, isWide, isTablet),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 4,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridCount,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        childAspectRatio: gridChildAspectRatio,
                      ),
                      itemBuilder: (context, index) {
                        final features = [
                          {
                            'icon': Icons.people,
                            'title': _translate(context, 'manage_users'),
                            'color': Colors.blue,
                            'onTap': () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditUserPage(
                                    user: allUsers.isNotEmpty ? allUsers.first : {},
                                    usersList: allUsers,
                                    userName: _userName,
                                    userImageUrl: _userImageUrl,
                                    translate: _translate,
                                    onLogout: _logout,
                                  ),
                                ),
                              );
                            },
                          },
                          {
                            'icon': Icons.person_add,
                            'title': _translate(context, 'add_user'),
                            'color': Colors.green,
                            'onTap': () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddUserPage(
                                    userName: _userName,
                                    userImageUrl: _userImageUrl,
                                    translate: _translate,
                                    onLogout: _logout,
                                  ),
                                ),
                              );
                            },
                          },
                          {
                            'icon': Icons.person_add,
                            'title': _translate(context, 'add_user_student'),
                            'color': Colors.green,
                            'onTap': () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddDentalStudentPage(
                                    userName: _userName,
                                    userImageUrl: _userImageUrl,
                                    translate: _translate,
                                    onLogout: _logout,
                                  ),
                                ),
                              );
                            },
                          },
                          {
                            'icon': Icons.group,
                            'title': _translate(context, 'manage_study_groups'),
                            'color': Colors.green,
                            'onTap': () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AdminManageGroupsPage(
                                    userName: _userName,
                                    userImageUrl: _userImageUrl,
                                    translate: _translate,
                                    onLogout: _logout,
                                  ),
                                ),
                              );
                            },
                          },
                        ];
                        final feature = features[index];
                        return _buildFeatureBox(
                          context,
                          feature['icon'] as IconData,
                          feature['title'] as String,
                          feature['color'] as Color,
                          onTap: feature['onTap'] as VoidCallback,
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

  Widget _buildUserInfoCard(BuildContext context, bool isSmallScreen, bool isWide, bool isTablet) {
    return Container(
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
                _userImageUrl.isNotEmpty
                    ? CircleAvatar(
                        radius: isSmallScreen ? 30 : (isWide ? 55 : (isTablet ? 45 : 40)),
                        backgroundColor: Colors.white.withOpacity(0.8),
                        child: ClipOval(
                          child: Image.memory(
                            base64Decode(_userImageUrl.replaceFirst('data:image/jpeg;base64,', '')),
                            width: isSmallScreen ? 60 : (isWide ? 110 : (isTablet ? 90 : 80)),
                            height: isSmallScreen ? 60 : (isWide ? 110 : (isTablet ? 90 : 80)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    : CircleAvatar(
                        radius: isSmallScreen ? 30 : (isWide ? 55 : (isTablet ? 45 : 40)),
                        backgroundColor: Colors.white.withOpacity(0.8),
                        child: Icon(
                          Icons.person,
                          size: isSmallScreen ? 30 : (isWide ? 55 : (isTablet ? 45 : 40)),
                          color: accentColor,
                        ),
                      ),
                SizedBox(height: isWide ? 30 : (isTablet ? 25 : 15)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    _userName,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : (isWide ? 28 : (isTablet ? 22 : 20)),
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
                  _translate(context, 'admin'),
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : (isWide ? 18 : (isTablet ? 16 : 16)),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 50, color: Colors.red),
          const SizedBox(height: 20),
          Text(
            _translate(context, 'error_loading_data'),
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              _loadAdminData();
              _loadAllUsers();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              _translate(context, 'retry'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBox(
    BuildContext context,
    IconData icon,
    String title,
    Color color, {
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
          child: Column(
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
                  size: isSmallScreen ? 24 : (isTablet ? 40 : (isWide ? 40 : 30)),
                  color: color,
                ),
              ),
              SizedBox(height: isTablet ? 16 : 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : (isTablet ? 18 : (isWide ? 18 : 16)),
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