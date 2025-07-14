import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../loginpage.dart';
import '../radiology/xray_request_list_page.dart';
import '../radiology/radiology_sidebar.dart';

class RadiologyDashboard extends StatefulWidget {
  const RadiologyDashboard({super.key});

  @override
  State<RadiologyDashboard> createState() => _RadiologyDashboardState();
}

class _RadiologyDashboardState extends State<RadiologyDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late DatabaseReference _waitingListRef;
  late DatabaseReference _xrayWaitingListRef;
  List<Map<String, dynamic>> waitingPatients = [];
  List<Map<String, dynamic>> xrayWaitingPatients = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _userName = '';
  String _userImageUrl = '';
  bool isSidebarOpen = false;
  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);

  // قاموس النصوص متعدد اللغات
  final Map<String, Map<String, String>> localizedStrings = {
    'app_name': {
      'ar': 'عيادات أسنان الجامعة العربية الأمريكية',
      'en': 'Arab American University Dental Clinics',
    },
    'dashboard_title': {
      'ar': 'الرئيسية',
      'en': 'Home',
    },
    'waiting_list': {
      'ar': 'قائمة الانتظار',
      'en': 'Waiting List',
    },
    'change_language': {
      'ar': 'تغيير اللغة',
      'en': 'Change Language',
    },
    'logout': {
      'ar': 'تسجيل الخروج',
      'en': 'Logout',
    },
    'xray_technician': {
      'ar': 'فني الأشعة',
      'en': 'Radiology Technician',
    },
    'patient_details': {
      'ar': 'تفاصيل المريض',
      'en': 'Patient Details',
    },
    'patient_name': {
      'ar': 'اسم المريض',
      'en': 'Patient Name',
    },
    'file_number': {
      'ar': 'رقم الملف',
      'en': 'File Number',
    },
    // أضف المزيد حسب الحاجة
  };

  @override
  void initState() {
    super.initState();
    // Set language to English when entering radiology dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      if (!languageProvider.isEnglish) {
        languageProvider.toggleLanguage();
      }
    });
    _waitingListRef = FirebaseDatabase.instance.ref('radiology_waiting_list');
    _xrayWaitingListRef = FirebaseDatabase.instance.ref('xray_waiting_list');
    _loadUserData();
    _loadWaitingPatients();
    _loadXrayWaitingPatients();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
    final snapshot = await userRef.get();
    if (!snapshot.exists) return;
    final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
    final firstName = data['firstName']?.toString().trim() ?? '';
    final fatherName = data['fatherName']?.toString().trim() ?? '';
    final grandfatherName = data['grandfatherName']?.toString().trim() ?? '';
    final familyName = data['familyName']?.toString().trim() ?? '';
    final fullName = [firstName, fatherName, grandfatherName, familyName].where((e) => e.isNotEmpty).join(' ');
    final imageData = data['image']?.toString() ?? '';
    setState(() {
      _userName = fullName.isNotEmpty ? fullName : 'فني الأشعة';
      _userImageUrl = imageData.isNotEmpty ? 'data:image/jpeg;base64,$imageData' : '';
    });
  }

  Future<void> _loadWaitingPatients() async {
    try {
      final snapshot = await _waitingListRef.get();
      if (!snapshot.exists) {
        setState(() {
          waitingPatients = [];
          _isLoading = false;
        });
        return;
      }
      final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
      final List<Map<String, dynamic>> patients = [];
      data.forEach((key, value) {
        if (value is Map<dynamic, dynamic>) {
          patients.add({
            'id': key,
            ...Map<String, dynamic>.from(value),
          });
        }
      });
      setState(() {
        waitingPatients = patients;
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadXrayWaitingPatients() async {
    try {
      final snapshot = await _xrayWaitingListRef.get();
      if (!snapshot.exists) {
        setState(() {
          xrayWaitingPatients = [];
        });
        return;
      }
      final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
      final List<Map<String, dynamic>> patients = [];
      data.forEach((key, value) {
        if (value is Map<dynamic, dynamic>) {
          patients.add({
            'id': key,
            ...Map<String, dynamic>.from(value),
          });
        }
      });
      setState(() {
        xrayWaitingPatients = patients;
      });
    } catch (e) {
      // يمكن إضافة معالجة أخطاء 
      //نا إذا لزم الأمر
    }
  }

  Widget _buildUserInfoCard(BuildContext context, bool isSmallScreen, String lang, Map<String, Map<String, String>> localizedStrings) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 900;
    final isTablet = width >= 600 && width <= 900;
    return Container(
      margin: const EdgeInsets.all(20),
      width: double.infinity, // يأخذ كل عرض الشاشة
      height: isSmallScreen
          ? 180
          : (isWide ? 240 : (isTablet ? 220 : 200)), // الطول متغير حسب حجم الشاشة
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
                        radius: isSmallScreen
                            ? 30
                            : (isWide ? 55 : (isTablet ? 45 : 40)),
                        backgroundColor: Colors.white.withOpacity(0.8),
                        child: ClipOval(
                          child: Image.memory(
                            base64Decode(_userImageUrl.replaceFirst('data:image/jpeg;base64,', '')),
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
                        backgroundColor: Colors.white.withOpacity(0.8),
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
                    _userName,
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
                SizedBox(height: isWide ? 10 : 5),
                Text(
                  localizedStrings['xray_technician']?[lang] ?? '',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : (isWide ? 20 : (isTablet ? 18 : 16)),
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
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
    Color color,
    VoidCallback onTap,
  ) {
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
        ),
      ),
    );
  }

  Widget _buildMainFeatures(BuildContext context, String lang, Map<String, Map<String, String>> localizedStrings) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final isSmallScreen = width < 350;
    final isWide = width > 900;
    final isTablet = width >= 600 && width <= 900;
    final crossAxisCount = isWide ? 4 : (isTablet ? 3 : 2);
    final gridChildAspectRatio = isWide ? 1.1 : (isTablet ? 1.2 : 1.1);

    final features = [
      {
        'icon': Icons.list_alt,
        'title': localizedStrings['waiting_list']?[lang] ?? '',
        'color': primaryColor,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const XrayRequestListPage(),
            ),
          );
        }
      },
      // يمكنك إضافة المزيد من الكبسات هنا إذا أردت
    ];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              double maxWidth = MediaQuery.of(context).size.width;
              if (maxWidth > 600) {
                maxWidth = 400;
              } else if (maxWidth > 400) {
                maxWidth = 340;
              } else {
                maxWidth = maxWidth - 40; // padding
              }
              int crossAxisCount = features.length > 1 ? 2 : 1;
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                ),
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
              );
            },
          ),
        ],
      ),
    );
  }

  void _showPatientDialog(Map<String, dynamic> patient, String lang, Map<String, Map<String, String>> localizedStrings) async {
    String selectedTooth = '';
    File? xrayImage;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(localizedStrings['patient_details']?[lang] ?? ''),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${localizedStrings['patient_name']?[lang] ?? ''}: ${patient['name'] ?? ''}'),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedTooth.isNotEmpty ? selectedTooth : null,
                      items: List.generate(32, (i) => (i+1).toString())
                          .map((tooth) => DropdownMenuItem(
                                value: tooth,
                                child: Text('السن رقم $tooth'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedTooth = val ?? '';
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'اختر السن المطلوب تصويره',
                      ),
                    ),
                    const SizedBox(height: 10),
                    xrayImage != null
                        ? Image.file(xrayImage!, height: 100)
                        : const Text('لم يتم اختيار صورة'),
                    ElevatedButton(
                      onPressed: () async {
                        final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          setState(() {
                            xrayImage = File(picked.path);
                          });
                        }
                      },
                      child: const Text('رفع صورة الأشعة'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إغلاق'),
                ),
                ElevatedButton(
                  onPressed: selectedTooth.isNotEmpty && xrayImage != null
                      ? () async {
                          final bytes = await xrayImage!.readAsBytes();
                          final base64Image = base64Encode(bytes);
                          await _waitingListRef.child(patient['id']).update({
                            'xrayImage': base64Image,
                            'tooth': selectedTooth,
                            'status': 'done',
                          });
                          Navigator.pop(context);
                          _loadWaitingPatients();
                        }
                      : null,
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final lang = languageProvider.currentLocale.languageCode;
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 350;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return Directionality(
          textDirection: languageProvider.currentLocale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: Text(localizedStrings['app_name']?[lang] ?? ''),
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
                IconButton(
                  icon: const Icon(Icons.language, color: Colors.white),
                  onPressed: () {
                    languageProvider.toggleLanguage();
                  },
                  tooltip: localizedStrings['change_language']?[lang] ?? '',
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: () async {
                    await _auth.signOut();
                    if (!mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                    );
                  },
                ),
              ],
            ),
            body: Stack(
              children: [
                Positioned.fill(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _hasError
                          ? const Center(child: Text('حدث خطأ أثناء تحميل البيانات'))
                          : Center(
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isWide ? 0 : 0,
                                    vertical: 20,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildUserInfoCard(context, isSmallScreen, lang, localizedStrings),
                                      _buildMainFeatures(context, lang, localizedStrings),
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics: NeverScrollableScrollPhysics(),
                                        itemCount: waitingPatients.length,
                                        itemBuilder: (context, index) {
                                          final patient = waitingPatients[index];
                                          return Card(
                                            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                                            child: ListTile(
                                              title: Text(patient['name'] ?? (localizedStrings['patient_name']?[lang] ?? '')),
                                              subtitle: Text('${localizedStrings['file_number']?[lang] ?? ''}: ${patient['fileNumber'] ?? ''}'),
                                              trailing: const Icon(Icons.arrow_forward_ios),
                                              onTap: () => _showPatientDialog(patient, lang, localizedStrings),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                ),
                if (isSidebarOpen) ...[
                  // طبقة شفافة تغطي الشاشة وتغلق السايد بار عند الضغط
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          isSidebarOpen = false;
                        });
                      },
                      child: Container(
                        color: Colors.black.withOpacity(0.1), // طبقة شفافة
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: lang == 'ar' ? 0 : null,
                    left: lang == 'ar' ? null : 0,
                    child: RadiologySidebar(
                      onClose: () {
                        setState(() {
                          isSidebarOpen = false;
                        });
                      },
                      onHome: () {
                        setState(() {
                          isSidebarOpen = false;
                        });
                        // يمكنك إضافة التنقل هنا
                      },
                      onWaitingList: () {
                        setState(() {
                          isSidebarOpen = false;
                        });
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const XrayRequestListPage(),
                          ),
                        );
                      },
                      primaryColor: primaryColor,
                      accentColor: accentColor,
                      userName: _userName,
                      userImageUrl: _userImageUrl,
                      collapsed: false,
                      parentContext: context,
                      lang: lang,
                      localizedStrings: localizedStrings,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
