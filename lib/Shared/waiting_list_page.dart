// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/secretary_provider.dart';
import '../Doctor/initial_examination.dart';
import '../Doctor/doctor_sidebar.dart';
import '../Secretry/secretary_sidebar.dart';
import 'dart:async';

class WaitingListPage extends StatefulWidget {
  final String userRole;

  const WaitingListPage({super.key, required this.userRole});

  @override
  State<WaitingListPage> createState() => _WaitingListPageState();
}

class _WaitingListPageState extends State<WaitingListPage> {
  final Color primaryColor = const Color(0xFF2A7A94);
  late DatabaseReference _waitingListRef;
  late DatabaseReference _usersRef;
  List<Map<String, dynamic>> waitingList = [];
  bool _isLoading = true;
  bool _hasError = false;
  Timer? _nightlyCleanupTimer;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredWaitingList = [];
  StreamSubscription? _waitingListSubscription;
  StreamSubscription? _usersSubscription;

  String? _doctorName;
  String? _doctorImageUrl;

  final Map<String, Map<String, String>> _translations = {
    'waiting_list': {'ar': 'قائمة الانتظار', 'en': 'Waiting List'},
    'name': {'ar': 'الاسم', 'en': 'Name'},
    'phone': {'ar': 'الهاتف', 'en': 'Phone'},
    'age': {'ar': 'العمر', 'en': 'Age'},
    'years': {'ar': 'سنة', 'en': 'years'},
    'months': {'ar': 'شهر', 'en': 'months'},
    'days': {'ar': 'يوم', 'en': 'days'},
    'remove_from_waiting_list': {
      'ar': 'إزالة من الانتظار',
      'en': 'Remove from Waiting List'
    },
    'no_patients': {'ar': 'لا يوجد مرضى', 'en': 'No patients found'},
    'error_loading': {
      'ar': 'خطأ في تحميل البيانات',
      'en': 'Error loading data'
    },
    'retry': {'ar': 'إعادة المحاولة', 'en': 'Retry'},
    'age_unknown': {'ar': 'العمر غير معروف', 'en': 'Age unknown'},
    'next_step': {
      'ar': 'انتقل للفحص الأولي',
      'en': 'Go to Initial Examination'
    },
    'all_removed_at_11pm': {
      'ar': 'تم إزالة جميع المرضى في الساعة 11 مساءً',
      'en': 'All patients removed at 11 PM'
    },
    'error_moving': {'ar': 'خطأ في نقل المريض', 'en': 'Error moving patient'},
    'doctor_not_logged_in': {
      'ar': 'يجب تسجيل دخول الطبيب أولاً',
      'en': 'Doctor must be logged in'
    },
    'unknown': {'ar': 'غير معروف', 'en': 'Unknown'},
    'no_number': {'ar': 'بدون رقم', 'en': 'No number'},
    'search_hint': {
      'ar': 'ابحث بالاسم أو رقم الهاتف...',
      'en': 'Search by name or phone...'
    },
    'students_evaluation': {'ar': 'تقييم الطلاب', 'en': 'Students Evaluation'},
    'supervision_groups': {'ar': 'شعب الإشراف', 'en': 'Supervision Groups'},
    'examined_patients': {'ar': 'المرضى المفحوصين', 'en': 'Examined Patients'},
    'signing_out': {'ar': 'تسجيل الخروج', 'en': 'Sign out'},
    'home': {'ar': 'الرئيسية', 'en': 'Home'},
  };

  @override
  void initState() {
    super.initState();
    _initializeReferences();
    _setupRealtimeListeners();
    _scheduleNightlyCleanup();
    _searchController.addListener(_filterWaitingList);
    if (widget.userRole == 'doctor') {
      _loadDoctorInfo();
    }
    // لا داعي لتحميل بيانات السكرتيرة هنا، سيتم أخذها من SecretaryProvider
  }

  @override
  void dispose() {
    _waitingListSubscription?.cancel();
    _usersSubscription?.cancel();
    _nightlyCleanupTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _initializeReferences() {
    _waitingListRef = FirebaseDatabase.instance.ref('waitingList');
    _usersRef = FirebaseDatabase.instance.ref('users');
  }

  void _setupRealtimeListeners() {
    _usersSubscription = _usersRef.onValue.listen((usersSnapshot) {
      _waitingListSubscription =
          _waitingListRef.onValue.listen((waitingSnapshot) {
        if (usersSnapshot.snapshot.exists && waitingSnapshot.snapshot.exists) {
          final allUsers = _parseUsersSnapshot(usersSnapshot.snapshot);
          setState(() {
            waitingList =
                _parseWaitingSnapshot(waitingSnapshot.snapshot, allUsers);
            _filteredWaitingList = List.from(waitingList);
            _isLoading = false;
            _hasError = false;
          });
        } else {
          setState(() {
            waitingList = [];
            _filteredWaitingList = [];
            _isLoading = false;
            _hasError = false;
          });
        }
      }, onError: (error) {
        debugPrint('Error listening to waiting list: $error');
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      });
    }, onError: (error) {
      debugPrint('Error listening to users: $error');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    });
  }

  List<Map<String, dynamic>> _parseUsersSnapshot(DataSnapshot snapshot) {
    if (!snapshot.exists) return [];
    final List<Map<String, dynamic>> result = [];
    final data = snapshot.value as Map<dynamic, dynamic>? ?? {};

    data.forEach((key, value) {
      if (value is Map<dynamic, dynamic>) {
        final userData = Map<String, dynamic>.from(value);
        userData['id'] = key.toString();
        result.add(userData);
      }
    });
    return result;
  }

  List<Map<String, dynamic>> _parseWaitingSnapshot(
      DataSnapshot snapshot, List<Map<String, dynamic>> allUsers) {
    if (!snapshot.exists) return [];
    final List<Map<String, dynamic>> result = [];
    final data = snapshot.value as Map<dynamic, dynamic>? ?? {};

    data.forEach((key, value) {
      if (value is Map<dynamic, dynamic>) {
        final waitingData = Map<String, dynamic>.from(value);
        waitingData['id'] = key.toString();

        // جلب بيانات المستخدم من جدول users باستخدام userId
        final user = allUsers.firstWhere(
          (u) => u['id'].toString().trim() == waitingData['userId'].toString().trim(),
          orElse: () => {},
        );

        // إذا وجد المستخدم في جدول users، استخدم بياناته
        if (user.isNotEmpty) {
          waitingData['firstName'] = user['firstName']?.toString().trim() ?? '';
          waitingData['fatherName'] = user['fatherName']?.toString().trim() ?? '';
          waitingData['grandfatherName'] = user['grandfatherName']?.toString().trim() ?? '';
          waitingData['familyName'] = user['familyName']?.toString().trim() ?? '';
        } else if (waitingData.containsKey('firstName') && waitingData.containsKey('fatherName') && waitingData.containsKey('grandfatherName') && waitingData.containsKey('familyName')) {
          // إذا كانت الحقول الرباعية موجودة في عنصر قائمة الانتظار، استخدمها كما هي
          waitingData['firstName'] = waitingData['firstName']?.toString().trim() ?? '';
          waitingData['fatherName'] = waitingData['fatherName']?.toString().trim() ?? '';
          waitingData['grandfatherName'] = waitingData['grandfatherName']?.toString().trim() ?? '';
          waitingData['familyName'] = waitingData['familyName']?.toString().trim() ?? '';
        } else {
          // fallback: تقسيم الاسم إذا لم تتوفر الحقول الرباعية
          final nameParts = (waitingData['name']?.toString() ?? '').split(' ');
          waitingData['firstName'] = nameParts.isNotEmpty ? nameParts[0] : '';
          waitingData['fatherName'] = nameParts.length > 1 ? nameParts[1] : '';
          waitingData['grandfatherName'] = nameParts.length > 2 ? nameParts[2] : '';
          waitingData['familyName'] = nameParts.length > 3 ? nameParts[3] : '';
        }
        // تعديل هنا: جلب birthDate من user أو من waitingData إذا كان موجودًا
        waitingData['birthDate'] = user.isNotEmpty
            ? user['birthDate'] ?? waitingData['birthDate'] ?? 0
            : waitingData['birthDate'] ?? 0;
        waitingData['gender'] = user.isNotEmpty ? user['gender']?.toString().trim() ?? '' : '';
        waitingData['phone'] = waitingData['phone'] ?? (user.isNotEmpty ? user['phone']?.toString().trim() ?? '' : '');

        result.add(waitingData);
      }
    });
    return result;
  }

  void _filterWaitingList() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredWaitingList = waitingList.where((patient) {
        final fullName = _getFullName(patient).toLowerCase();
        final phone = patient['phone']?.toString().toLowerCase() ?? '';
        return fullName.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  String _getFullName(Map<String, dynamic> user) {
    return [
      user['firstName'],
      user['fatherName'],
      user['grandfatherName'],
      user['familyName']
    ]
        .where((part) => part != null && part != _translate(context, 'unknown'))
        .join(' ')
        .trim();
  }

  String _translate(BuildContext context, String key) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final langCode = languageProvider.currentLocale.languageCode;
    if (_translations.containsKey(key) && _translations[key]!.containsKey(langCode)) {
      return _translations[key]![langCode] ?? key;
    }
    return key;
  }

  String _calculateAge(BuildContext context, dynamic birthTimestamp) {
    final int timestamp;
    if (birthTimestamp is String) {
      timestamp = int.tryParse(birthTimestamp) ?? 0;
    } else if (birthTimestamp is int) {
      timestamp = birthTimestamp;
    } else {
      timestamp = 0;
    }

    if (timestamp <= 0) return _translate(context, 'age_unknown');

    final birthDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();

    if (birthDate.isAfter(now)) return _translate(context, 'age_unknown');

    final age = now.difference(birthDate);
    final years = age.inDays ~/ 365;
    final months = (age.inDays % 365) ~/ 30;
    final days = (age.inDays % 365) % 30;

    if (years > 0) {
      return '$years ${_translate(context, 'years')}';
    } else if (months > 0) {
      return '$months ${_translate(context, 'months')}';
    } else {
      return '$days ${_translate(context, 'days')}';
    }
  }

  Future<void> _removeFromWaitingList(String userId) async {
    try {
      await _waitingListRef.child(userId).remove();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_translate(context, 'remove_from_waiting_list')),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      debugPrint('Error removing from waiting list: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_translate(context, 'error_loading')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _fetchLatestExamination(String patientId) async {
    try {
      final examinationsRef = FirebaseDatabase.instance.ref('examinations');
      final snapshot = await examinationsRef.get();
      if (!snapshot.exists) return null;
      final data = snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return null;
      Map<String, dynamic>? latestExam;
      int latestTimestamp = 0;
      data.forEach((key, value) {
        if (value is Map<dynamic, dynamic>) {
          final exam = Map<String, dynamic>.from(value);
          if (exam['patientId']?.toString() == patientId) {
            final ts = exam['timestamp'] is int
                ? exam['timestamp'] as int
                : int.tryParse(exam['timestamp']?.toString() ?? '') ?? 0;
            if (ts > latestTimestamp) {
              latestTimestamp = ts;
              latestExam = exam;
            }
          }
        }
      });
      return latestExam;
    } catch (e) {
      debugPrint('Error fetching latest examination: $e');
      return null;
    }
  }

  Future<void> _moveToInitialExamination(
      Map<String, dynamic> patientData) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_translate(context, 'doctor_not_logged_in')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // استخدم id الموجود داخل بيانات المريض كمعرف حقيقي
     String? realUserId = patientData['userId']?.toString();

      if (realUserId == null || realUserId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد userId حقيقي للمريض!')),
        );
        return;
      }
      patientData['authUid'] = realUserId;
      patientData['userId'] = realUserId;

      dynamic birthDateValue = patientData['birthDate'];
      int birthTimestamp = 0;
      if (birthDateValue is String) {
        birthTimestamp = int.tryParse(birthDateValue) ?? 0;
      } else if (birthDateValue is int) {
        birthTimestamp = birthDateValue;
      }

      final birthDate = birthTimestamp > 0
          ? DateTime.fromMillisecondsSinceEpoch(birthTimestamp)
          : null;

      int? ageInYears;
      if (birthDate != null) {
        final now = DateTime.now();
        ageInYears = now.year - birthDate.year;
        if (now.month < birthDate.month ||
            (now.month == birthDate.month && now.day < birthDate.day)) {
          ageInYears--;
        }
      }

      // جلب بيانات الفحص السابقة
      final latestExam = await _fetchLatestExamination(realUserId);
      Map<String, dynamic> patientDataWithExam = Map<String, dynamic>.from(patientData);
      if (latestExam != null && latestExam['examData'] != null) {
        patientDataWithExam['examData'] = latestExam['examData'];
      }

      // لا تحذف من قائمة الانتظار هنا، سيتم الحذف عند الحفظ في الفحص السريري
      if (!mounted) return;

      final String doctorId = user.uid;
      final String patientIdStr = realUserId; // patientId هو id الموجود داخل بيانات المريض
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InitialExamination(
            patientData: patientDataWithExam,
            age: ageInYears,
            doctorId: doctorId,
            patientId: patientIdStr, // patientId هو id الموجود داخل بيانات المريض
          ),
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_translate(context, 'next_step')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error moving to initial examination: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${_translate(context, 'error_moving')}: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeAllFromWaitingList() async {
    try {
      await _waitingListRef.remove();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_translate(context, 'all_removed_at_11pm')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error removing all from waiting list: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_translate(context, 'error_loading')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _scheduleNightlyCleanup() {
    final now = DateTime.now();
    final elevenPM = DateTime(now.year, now.month, now.day, 23, 0, 0);
    final timeUntilElevenPM = elevenPM.isAfter(now)
        ? elevenPM.difference(now)
        : elevenPM.add(const Duration(days: 1)).difference(now);

    _nightlyCleanupTimer = Timer(
      timeUntilElevenPM,
      () {
        _removeAllFromWaitingList();
        _scheduleNightlyCleanup();
      },
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> user, BuildContext context) {
    if (widget.userRole == 'secretary') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _removeFromWaitingList(user['id']),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          child: Text(
            _translate(context, 'remove_from_waiting_list'),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      );
    } else if (widget.userRole == 'doctor') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _moveToInitialExamination(user),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          child: Text(
            _translate(context, 'next_step'),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      );
    }
    return Container();
  }

  Widget _buildWaitingListCard(
      Map<String, dynamic> user, BuildContext context) {
    final fullName = _getFullName(user);
    final phone = user['phone'] ?? _translate(context, 'no_number');
    final ageText = _calculateAge(context, user['birthDate'] ?? 0);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    fullName.isNotEmpty
                        ? fullName
                        : _translate(context, 'name'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.access_time, color: primaryColor),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.phone, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  phone,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.cake, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  ageText,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildActionButtons(user, context),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 50, color: Colors.red),
          const SizedBox(height: 20),
          Text(
            _translate(context, 'error_loading'),
            style: const TextStyle(fontSize: 18, color: Colors.black87),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
              _setupRealtimeListeners();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              _translate(context, 'retry'),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: _translate(context, 'search_hint'),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }

  Future<void> _loadDoctorInfo() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final firstName = data['firstName']?.toString().trim() ?? '';
      final fatherName = data['fatherName']?.toString().trim() ?? '';
      final grandfatherName = data['grandfatherName']?.toString().trim() ?? '';
      final familyName = data['familyName']?.toString().trim() ?? '';
      final fullName = [firstName, fatherName, grandfatherName, familyName].where((e) => e.isNotEmpty).join(' ');
      final imageData = data['image']?.toString() ?? '';
      setState(() {
        _doctorName = fullName.isNotEmpty ? fullName : null;
        _doctorImageUrl = imageData.isNotEmpty ? 'data:image/jpeg;base64,$imageData' : null;
      });
    }
  }

  Widget? _buildSidebar(BuildContext context) {
    if (widget.userRole == 'doctor') {
      return DoctorSidebar(
        primaryColor: primaryColor,
        accentColor: primaryColor,
        userName: _doctorName ?? "دكتور",
        userImageUrl: _doctorImageUrl,
        parentContext: context,
        translate: _translate,
        onLogout: null,
        doctorUid: FirebaseAuth.instance.currentUser?.uid ?? '',
      );
    } else if (widget.userRole == 'secretary') {
      final secretaryProvider = Provider.of<SecretaryProvider>(context);
      return SecretarySidebar(
        primaryColor: primaryColor,
        accentColor: primaryColor,
        userName: secretaryProvider.fullName.isNotEmpty ? secretaryProvider.fullName : "سكرتير",
        userImageUrl: secretaryProvider.imageBase64,
        parentContext: context,
        translate: _translate,
        onLogout: null,
        collapsed: false,
        pendingAccountsCount: 0,
        userRole: 'secretary',
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // توحيد لون الخلفية
      appBar: AppBar(
        title: Text(_translate(context, 'waiting_list'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      drawer: _buildSidebar(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? _buildErrorWidget()
              : Column(
                  children: [
                    _buildSearchField(),
                    Expanded(
                      child: _filteredWaitingList.isEmpty
                          ? Center(
                              child: Text(
                                _translate(context, 'no_patients'),
                                style: const TextStyle(
                                    fontSize: 18, color: Colors.black54),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredWaitingList.length,
                              itemBuilder: (context, index) {
                                return _buildWaitingListCard(
                                    _filteredWaitingList[index], context);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
