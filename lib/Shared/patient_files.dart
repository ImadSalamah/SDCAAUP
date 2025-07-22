// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../providers/language_provider.dart';
import '../../providers/secretary_provider.dart';
import '../Secretry/secretary_sidebar.dart';

class PatientFilesPage extends StatefulWidget {
  final String userRole;
  const PatientFilesPage({super.key, required this.userRole});

  @override
  State<PatientFilesPage> createState() => _PatientFilesPageState();
}

class _PatientFilesPageState extends State<PatientFilesPage> {
  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);
  late DatabaseReference _usersRef;
  late DatabaseReference _waitingListRef;
  final FirebaseAuth _auth = FirebaseAuth.instance;


  List<Map<String, dynamic>> allUsers = [];
  List<Map<String, dynamic>> filteredUsers = [];
  List<Map<String, dynamic>> waitingList = [];
  List<Map<String, dynamic>> filteredWaitingList = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  late StreamSubscription<DatabaseEvent> _waitingListSubscription;

  final Map<String, Map<String, String>> _translations = {
    'patient_files': {'ar': 'ملفات المرضى', 'en': 'Patient Files'},
    'waiting_list': {'ar': 'قائمة الانتظار', 'en': 'Waiting List'},
    'all_patients': {'ar': 'جميع المرضى', 'en': 'All Patients'},
    'name': {'ar': 'الاسم', 'en': 'Name'},
    'phone': {'ar': 'الهاتف', 'en': 'Phone'},
    'age': {'ar': 'العمر', 'en': 'Age'},
    'add_to_waiting_list': {'ar': 'إضافة للانتظار', 'en': 'Add to Waiting List'},
    'remove_from_waiting_list': {'ar': 'إزالة من الانتظار', 'en': 'Remove from Waiting List'},
    'no_patients': {'ar': 'لا يوجد مرضى', 'en': 'No patients found'},
    'error_loading': {'ar': 'خطأ في تحميل البيانات', 'en': 'Error loading data'},
    'retry': {'ar': 'إعادة المحاولة', 'en': 'Retry'},
    'age_unknown': {'ar': 'العمر غير معروف', 'en': 'Age unknown'},
    'next_step': {'ar': 'الخطوة التالية', 'en': 'Next Step'},
    'search_hint': {'ar': 'ابحث بالاسم أو رقم الهوية...', 'en': 'Search by name or ID...'},
  };

  @override
  void initState() {
    super.initState();
    _initializeReferences();
    _loadData();
    _searchController.addListener(_filterUsers);
    if (widget.userRole == 'secretary') {
      _loadSecretaryDataToProvider();
    }
    // إضافة مستمع صحيح لقائمة الانتظار
    _waitingListSubscription = _waitingListRef.onValue.listen((event) {
      setState(() {
        waitingList = _parseWaitingSnapshot(event.snapshot);
        filteredWaitingList = List.from(waitingList);
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _waitingListSubscription.cancel(); // إلغاء الاشتراك عند التخلص من الصفحة
    super.dispose();
  }

  void _initializeReferences() {
    _usersRef = FirebaseDatabase.instance.ref('users');
    _waitingListRef = FirebaseDatabase.instance.ref('waitingList');
  }

  Future<void> _loadData() async {
    try {
      final usersSnapshot = await _usersRef.get();
      final waitingSnapshot = await _waitingListRef.get();

      setState(() {
        allUsers = _parseUsersSnapshot(usersSnapshot);
        filteredUsers = List.from(allUsers);
        waitingList = _parseWaitingSnapshot(waitingSnapshot);
        filteredWaitingList = List.from(waitingList);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
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

  List<Map<String, dynamic>> _parseWaitingSnapshot(DataSnapshot snapshot) {
    if (!snapshot.exists) return [];

    final List<Map<String, dynamic>> result = [];
    final data = snapshot.value as Map<dynamic, dynamic>? ?? {};

    data.forEach((key, value) {
      if (value is Map<dynamic, dynamic>) {
        final waitingData = Map<String, dynamic>.from(value);
        // استخدم id الحقيقي للمريض وليس key الخاص بالـ push
        // إذا لم يوجد id في الداتا، استخدم key كحل احتياطي
        waitingData['id'] = value['id']?.toString() ?? key.toString();
        result.add(waitingData);
      }
    });

    return result;
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      filteredUsers = allUsers.where((user) {
        final fullName = _getFullName(user).toLowerCase();
        final userId = user['id']?.toString().toLowerCase() ?? '';
        final phone = user['phone']?.toString().toLowerCase() ?? '';

        return fullName.contains(query) ||
            userId.contains(query) ||
            phone.contains(query);
      }).toList();

      filteredWaitingList = waitingList.where((user) {
        final name = user['name']?.toString().toLowerCase() ?? '';
        final userId = user['id']?.toString().toLowerCase() ?? '';
        final phone = user['phone']?.toString().toLowerCase() ?? '';

        return name.contains(query) ||
            userId.contains(query) ||
            phone.contains(query);
      }).toList();
    });
  }

  DateTime? _parseBirthDate(dynamic birthDateValue) {
    try {
      if (birthDateValue == null) return null;

      final birthDateMillis = birthDateValue is String
          ? int.tryParse(birthDateValue) ?? 0
          : birthDateValue is int
          ? birthDateValue
          : 0;

      if (birthDateMillis <= 0) return null;

      return DateTime.fromMillisecondsSinceEpoch(birthDateMillis);
    } catch (e) {
      debugPrint('Error parsing birth date: $e');
      return null;
    }
  }

  int _calculateAgeFromDate(DateTime birthDate) {
    final currentDate = DateTime.now();
    int age = currentDate.year - birthDate.year;

    if (currentDate.month < birthDate.month ||
        (currentDate.month == birthDate.month &&
            currentDate.day < birthDate.day)) {
      age--;
    }

    return age >= 0 ? age : 0;
  }

  String _formatAge(BuildContext context, dynamic birthDateValue) {
    final birthDate = _parseBirthDate(birthDateValue);
    if (birthDate == null) return _translate(context, 'age_unknown');

    final age = _calculateAgeFromDate(birthDate);
    return '$age ${_translate(context, 'age')}';
  }

  String _translate(BuildContext context, String key) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final langCode = languageProvider.currentLocale.languageCode;
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

  String _getFullName(Map<String, dynamic> user) {
    final firstName = user['firstName']?.toString().trim() ?? '';
    final fatherName = user['fatherName']?.toString().trim() ?? '';
    final grandfatherName = user['grandfatherName']?.toString().trim() ?? '';
    final familyName = user['familyName']?.toString().trim() ?? '';

    return [
      if (firstName.isNotEmpty) firstName,
      if (fatherName.isNotEmpty) fatherName,
      if (grandfatherName.isNotEmpty) grandfatherName,
      if (familyName.isNotEmpty) familyName,
    ].join(' ');
  }

  Future<void> _loadSecretaryDataToProvider() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final snapshot = await _usersRef.child(user.uid).get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final secretaryProvider = Provider.of<SecretaryProvider>(context, listen: false);
      secretaryProvider.setSecretaryData(data);
    }
  }

  // Build the sidebar based on user role
  Widget _buildSidebar(BuildContext context) {
    if (widget.userRole == 'secretary') {
      final secretaryProvider = Provider.of<SecretaryProvider>(context, listen: false);
      return SecretarySidebar(
        primaryColor: primaryColor,
        accentColor: accentColor,
        parentContext: context,
        translate: _translate,
        userRole: widget.userRole,
        userName: secretaryProvider.fullName,
        userImageUrl: secretaryProvider.imageBase64,
      );
    }
    // For other roles, return an empty widget
    return const SizedBox.shrink();
  }

  // Remove a user from the waiting list
  Future<void> _removeFromWaitingList(String userId) async {
    try {
      final snapshot = await _waitingListRef.orderByChild('id').equalTo(userId).get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        for (final entry in data.entries) {
          await _waitingListRef.child(entry.key).remove();
        }
      }
      await _loadData();
    } catch (e) {
      debugPrint('Error removing from waiting list: $e');
    }
  }

  // Add a user to the waiting list
  Future<void> _addToWaitingList(Map<String, dynamic> user) async {
    try {
      // تحقق إذا كان الشخص موجود مسبقًا في قائمة الانتظار
      final alreadyInList = waitingList.any((w) => w['id'] == user['id']);
      if (alreadyInList) {
        // إظهار رسالة للمستخدم
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_translate(context, 'add_to_waiting_list')}: ${_translate(context, 'name')} "${_getFullName(user)}" موجود بالفعل في قائمة الانتظار'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
     final newEntry = {
  'id': user['id'], // هذا هو نفس userId لكن نسميه صراحة
  'userId': user['id'], // ✅ هذا هو المطلوب إضافته
  'name': _getFullName(user),
  'firstName': user['firstName'] ?? '',
  'fatherName': user['fatherName'] ?? '',
  'grandfatherName': user['grandfatherName'] ?? '',
  'familyName': user['familyName'] ?? '',
  'phone': user['phone'] ?? '',
  'birthDate': user['birthDate'] ?? '',
};

      await _waitingListRef.push().set(newEntry);
      await _loadData();
    } catch (e) {
      debugPrint('Error adding to waiting list: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Provider.of<LanguageProvider>(context, listen: false).currentLocale.languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_translate(context, 'patient_files'), style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: primaryColor,
          centerTitle: true,
        ),
        drawer: _buildSidebar(context),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText: _translate(context, 'search_hint'),
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onChanged: (value) => _filterUsers(),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView(
                              children: [
                                Text(_translate(context, 'all_patients'), style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                                const SizedBox(height: 8),
                                ...filteredUsers.map((user) {
                                  final isInWaitingList = waitingList.any((w) => w['id'] == user['id']);
                                  return Card(
                                    color: Colors.white,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: accentColor,
                                        child: const Icon(Icons.person, color: Colors.white),
                                      ),
                                      title: Text(_getFullName(user), style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                                      subtitle: Text('${_translate(context, 'age')}: ${_formatAge(context, user['birthDate'])}'),
                                      trailing: isInWaitingList
                                          ? IconButton(
                                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                                              onPressed: () {
                                                _removeFromWaitingList(user['id']);
                                              },
                                            )
                                          : IconButton(
                                              icon: const Icon(Icons.add, color: Colors.green),
                                              onPressed: () {
                                                _addToWaitingList(user);
                                              },
                                            ),
                                    ),
                                  );
                                }),
                                const SizedBox(height: 24),
                                Text(_translate(context, 'waiting_list'), style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                                const SizedBox(height: 8),
                                ...filteredWaitingList.map((user) => Card(
                                      color: Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      child: ListTile(
                                        leading: const CircleAvatar(
                                          backgroundColor: Colors.orange,
                                          child: Icon(Icons.timer, color: Colors.white),
                                        ),
                                        // عرض الاسم الرباعي الكامل في قائمة الانتظار
                                        title: Text(user['name'] ?? '', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                                        subtitle: Text('${_translate(context, 'phone')}: ${user['phone'] ?? ''}'),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                                          onPressed: () {
                                            _removeFromWaitingList(user['id']);
                                          },
                                        ),
                                      ),
                                    )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}