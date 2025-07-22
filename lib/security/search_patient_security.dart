// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../security/security_sidebar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'patient_appointments_page.dart'; // تأكد من استيراد صفحة المواعيد
import 'dart:convert';


class SearchPatientSecurityPage extends StatefulWidget {
  const SearchPatientSecurityPage({super.key});

  @override
  State<SearchPatientSecurityPage> createState() => _SearchPatientSecurityPageState();
}

class _SearchPatientSecurityPageState extends State<SearchPatientSecurityPage> {
  final TextEditingController _searchController = TextEditingController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  String _userName = '';
  String _userImageUrl = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadSecurityUserInfo();
  }

  void _onSearchChanged() {
    _searchPatients();
  }

  Future<void> _loadSecurityUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _userName = '';
          _userImageUrl = '';
        });
        return;
      }
      final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      final snapshot = await userRef.get();
      if (!snapshot.exists) {
        setState(() {
          _userName = '';
          _userImageUrl = '';
        });
        return;
      }
      final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
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
        _userName = fullName;
        _userImageUrl = imageData.isNotEmpty ? 'data:image/jpeg;base64,$imageData' : '';
      });
    } catch (e) {
      setState(() {
        _userName = '';
        _userImageUrl = '';
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchPatients() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _results = [];
    });
    try {
      final snapshot = await _database.child('users').once();
      List<Map<String, dynamic>> found = [];
      if (snapshot.snapshot.value != null) {
        final rawData = snapshot.snapshot.value;
        Map<String, dynamic> data;
        if (rawData is Map) {
          data = Map<String, dynamic>.from(rawData);
        } else if (rawData is List) {
          data = {};
          for (int i = 0; i < rawData.length; i++) {
            if (rawData[i] != null) {
              data[i.toString()] = rawData[i];
            }
          }
        } else {
          data = {};
        }
        data.forEach((key, value) {
          final user = Map<String, dynamic>.from(value);
          final fullName = "${user['firstName'] ?? ''} ${user['fatherName'] ?? ''} ${user['grandfatherName'] ?? ''} ${user['familyName'] ?? ''}";
          final fullNameLower = fullName.trim().toLowerCase();
          final idNumber = user['idNumber']?.toString() ?? '';
          if (fullNameLower.contains(query.toLowerCase()) || idNumber.contains(query)) {
            found.add({
              ...user,
              'fullName': fullName.trim(),
              'uid': key
            });
          }
        });
      }
      // جلب جميع المواعيد مرة واحدة
      final appointmentsSnap = await _database.child('appointments').once();
      Map<String, dynamic> allAppointments = {};
      if (appointmentsSnap.snapshot.value != null) {
        allAppointments = Map<String, dynamic>.from(appointmentsSnap.snapshot.value as Map);
      }
      final today = DateTime.now();
      final todayStr = today.toIso8601String().substring(0, 10);
      for (var user in found) {
        final uid = user['uid'];
        final fullName = user['fullName'] ?? '';
        bool hasAppointmentToday = false;
        for (var appt in allAppointments.values) {
          final apptData = Map<String, dynamic>.from(appt);
          String dateStr = apptData['date']?.toString() ?? '';
          String dateOnly = dateStr.contains('T') ? dateStr.split('T')[0] : (dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr);
          if ((apptData['patientUid']?.toString() == uid || apptData['patientName']?.toString() == fullName) && dateOnly == todayStr) {
            hasAppointmentToday = true;
            break;
          }
        }
        user['hasAppointmentToday'] = hasAppointmentToday;
      }
      setState(() {
        _results = found;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء البحث: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.currentLocale.languageCode == 'ar';
    const primaryColor = Color(0xFF2A7A94);
    const accentColor = Color(0xFF4AB8D8);
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 350;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(
          isArabic ? 'بحث عن المرضى' : 'Patient Search',
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      drawer: SecuritySidebar(
        userName: _userName,
        userImageUrl: _userImageUrl,
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: isArabic ? 'ابحث بالاسم أو رقم الهوية' : 'Search by name or ID',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
              ),
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const CircularProgressIndicator(),
            if (!_isLoading && _results.isEmpty && _searchController.text.isNotEmpty)
              Text(isArabic ? 'لا يوجد نتائج' : 'No results'),
            if (!_isLoading && _results.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final user = _results[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: user['image'] != null && user['image'].toString().isNotEmpty
                            ? CircleAvatar(
                                backgroundImage: MemoryImage(
                                  base64Decode(
                                    user['image'].toString().startsWith('data:image')
                                        ? user['image'].toString().split(',').last
                                        : user['image'].toString(),
                                  ),
                                ),
                              backgroundColor: accentColor.withAlpha(51),

                              )
                            : CircleAvatar(
                              backgroundColor: accentColor.withAlpha(51),

                                child: const Icon(Icons.person, color: primaryColor),
                              ),
                        title: Text(
                          user['fullName'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${isArabic ? 'رقم الهوية' : 'ID'}: ${user['idNumber'] ?? ''}',
                        ),
                        trailing: user['hasAppointmentToday'] == true
                            ? Chip(
                                label: Text(
                                  isArabic ? 'لديه موعد اليوم' : 'Has appointment today',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Colors.green,
                              )
                            : Chip(
                                label: Text(
                                  isArabic ? 'لا يوجد موعد اليوم' : 'No appointment today',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Colors.red,
                              ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PatientAppointmentsPage(
                                patientUid: user['uid'],
                                patientName: user['fullName'] ?? '',
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
