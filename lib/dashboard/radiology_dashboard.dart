import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../loginpage.dart';

class RadiologyDashboard extends StatefulWidget {
  const RadiologyDashboard({super.key});

  @override
  State<RadiologyDashboard> createState() => _RadiologyDashboardState();
}

class _RadiologyDashboardState extends State<RadiologyDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late DatabaseReference _waitingListRef;
  List<Map<String, dynamic>> waitingPatients = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _userName = '';
  String _userImageUrl = '';
  bool isSidebarOpen = false;
  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);

  @override
  void initState() {
    super.initState();
    _waitingListRef = FirebaseDatabase.instance.ref('radiology_waiting_list');
    _loadUserData();
    _loadWaitingPatients();
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

  void _showPatientDialog(Map<String, dynamic> patient) async {
    String selectedTooth = '';
    File? xrayImage;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('تفاصيل المريض'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('اسم المريض: ${patient['name'] ?? ''}'),
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

  Widget _buildUserInfoCard(BuildContext context, bool isSmallScreen) {
    return Container(
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
                        backgroundColor: Colors.white.withOpacity(0.8),
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
                        backgroundColor: Colors.white.withOpacity(0.8),
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
                  'فني الأشعة',
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
    );
  }

  Widget _buildFeatureButton(BuildContext context, IconData icon, String title, Color color, {required VoidCallback onTap}) {
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
          width: isSmallScreen ? 120 : 140,
          height: isSmallScreen ? 90 : 110,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
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

  Widget _buildMainFeatures(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 12,
        children: [
          _buildFeatureButton(
            context,
            Icons.list_alt,
            'قائمة الانتظار',
            primaryColor,
            onTap: () {
              // Scroll to waiting list section or just do nothing (already visible)
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 350;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxContentWidth = 700.0;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text('داشبورد فني الأشعة'),
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
                    // تغيير اللغة عبر Provider<LanguageProvider>
                    final provider = Provider.of<LanguageProvider>(context, listen: false);
                    provider.toggleLanguage();
                  },
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
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: maxContentWidth),
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.only(bottom: mediaQuery.padding.bottom + 20),
                                  child: Column(
                                    children: [
                                      _buildUserInfoCard(context, isSmallScreen),
                                      _buildMainFeatures(context),
                                      Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: waitingPatients.length,
                                          itemBuilder: (context, index) {
                                            final patient = waitingPatients[index];
                                            return Card(
                                              margin: const EdgeInsets.symmetric(vertical: 8),
                                              child: ListTile(
                                                title: Text(patient['name'] ?? 'بدون اسم'),
                                                subtitle: Text('رقم الملف: ${patient['fileNumber'] ?? ''}'),
                                                trailing: const Icon(Icons.arrow_forward_ios),
                                                onTap: () => _showPatientDialog(patient),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                ),
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
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () {},
                          child: SizedBox(
                            width: 260,
                            height: double.infinity,
                            child: Material(
                              elevation: 8,
                              child: Stack(
                                children: [
                                  // يمكن إضافة شريط جانبي مخصص هنا لاحقًا
                                  Positioned(
                                    top: 8,
                                    right: 0,
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
}
