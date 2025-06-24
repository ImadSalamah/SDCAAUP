import 'dart:convert';
import 'package:flutter/material.dart';
import 'patient_sidebar.dart';
import '../dashboard/patient_dashboard.dart';
import 'patient_appointments_page.dart';
import 'patient_prescriptions_page.dart';
import 'package:firebase_database/firebase_database.dart';

class PatientProfilePage extends StatelessWidget {
  final Map<String, dynamic> patientData;
  final String patientImageUrl;

  const PatientProfilePage({
    Key? key,
    required this.patientData,
    required this.patientImageUrl,
  }) : super(key: key);

  void _handleSidebarNavigation(BuildContext context, String route) async {
    if (ModalRoute.of(context)?.settings.name == route) return;
    switch (route) {
      case '/patient_dashboard':
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const PatientDashboard()),
          (route) => false,
        );
        break;
      case '/medical_records':
        Navigator.pushNamed(context, '/medical_records');
        break;
      case '/patient_appointments':
        // جلب اسم المريض من البيانات الحالية
        String patientName = '';
        if (patientData.isNotEmpty) {
          final firstName = patientData['firstName']?.toString().trim() ?? '';
          final fatherName = patientData['fatherName']?.toString().trim() ?? '';
          final grandfatherName = patientData['grandfatherName']?.toString().trim() ?? '';
          final familyName = patientData['familyName']?.toString().trim() ?? '';
          patientName = [firstName, fatherName, grandfatherName, familyName].where((e) => e.isNotEmpty).join(' ');
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientAppointmentsPage(
              patientUid: patientData['uid'] ?? '',
              patientName: patientName,
            ),
          ),
        );
        break;
      case '/patient_prescriptions':
        // جلب uid من قاعدة البيانات إذا لم يكن موجودًا في patientData
        String patientId = patientData['uid']?.toString() ?? '';
        if (patientId.isEmpty && patientData['phone'] != null) {
          // ابحث عن uid باستخدام رقم الهاتف
          final usersRef = FirebaseDatabase.instance.ref('users');
          final usersSnap = await usersRef.get();
          if (usersSnap.exists && usersSnap.value != null) {
            final usersMap = Map<String, dynamic>.from(usersSnap.value as Map);
            usersMap.forEach((uid, user) {
              if (user is Map && user['phone'] == patientData['phone']) {
                patientId = uid;
              }
            });
          }
        }
        if (patientId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يوجد رقم تعريف للمريض!')),
          );
          break;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientPrescriptionsPage(
              patientId: patientId,
            ),
          ),
        );
        break;
      case '/patient_profile':
        // إذا لم تكن البيانات متوفرة، جلبها من قاعدة البيانات
        Map<String, dynamic> data = patientData;
        String imageUrl = patientImageUrl;
        if ((data['uid'] == null || data['uid'].toString().isEmpty) && data['phone'] != null) {
          final usersRef = FirebaseDatabase.instance.ref('users');
          final usersSnap = await usersRef.get();
          if (usersSnap.exists && usersSnap.value != null) {
            final usersMap = Map<String, dynamic>.from(usersSnap.value as Map);
            usersMap.forEach((uid, user) {
              if (user is Map && user['phone'] == data['phone']) {
                data = Map<String, dynamic>.from(user);
                data['uid'] = uid;
                final imageData = user['image']?.toString() ?? '';
                if (imageData.isNotEmpty) {
                  imageUrl = 'data:image/jpeg;base64,$imageData';
                }
              }
            });
          }
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientProfilePage(
              patientData: data,
              patientImageUrl: imageUrl,
            ),
          ),
        );
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 350;
    final String fullName = [
      patientData['firstName'] ?? '',
      patientData['fatherName'] ?? '',
      patientData['grandfatherName'] ?? '',
      patientData['familyName'] ?? '',
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2A7A94),
        elevation: 0,
      ),
      drawer: PatientSidebar(
        onNavigate: (route) => _handleSidebarNavigation(context, route),
        currentRoute: '/patient_profile',
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFe0f7fa), Color(0xFFffffff)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: patientImageUrl.isNotEmpty
                    ? CircleAvatar(
                        radius: isSmallScreen ? 48 : 64,
                        backgroundColor: Colors.grey.shade200,
                        child: ClipOval(
                          child: Image.memory(
                            base64.decode(patientImageUrl.replaceFirst('data:image/jpeg;base64,', '')),
                            width: isSmallScreen ? 96 : 128,
                            height: isSmallScreen ? 96 : 128,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    : CircleAvatar(
                        radius: isSmallScreen ? 48 : 64,
                        backgroundColor: Colors.grey.shade200,
                        child: const Icon(Icons.person, size: 60, color: Colors.blueGrey),
                      ),
              ),
              const SizedBox(height: 18),
              Text(
                fullName,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2A7A94)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Divider(thickness: 1.2, color: Colors.grey.shade300, height: 32),
              _buildInfoCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final infoList = [
      {'label': isArabic ? 'رقم الهاتف' : 'Phone Number', 'value': patientData['phone']},
      {'label': isArabic ? 'البريد الإلكتروني' : 'Email', 'value': patientData['email']},
      {'label': isArabic ? 'رقم الهوية' : 'ID Number', 'value': patientData['idNumber']},
      {'label': isArabic ? 'تاريخ الميلاد' : 'Birth Date', 'value': patientData['birthDate']},
      {'label': isArabic ? 'الجنس' : 'Gender', 'value': patientData['gender']},
      {'label': isArabic ? 'العنوان' : 'Address', 'value': patientData['address']},
    ];
    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Column(
          children: infoList
              .map((item) => _buildInfoRow(item['label'] as String, item['value']))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return const SizedBox.shrink();
    String displayValue = value.toString();
    String iconLabel = label;
    if (label == 'Phone Number' || label == 'رقم الهاتف') iconLabel = 'رقم الهاتف';
    if (label == 'Email' || label == 'البريد الإلكتروني') iconLabel = 'البريد الإلكتروني';
    if (label == 'ID Number' || label == 'رقم الهوية') iconLabel = 'رقم الهوية';
    if (label == 'Birth Date' || label == 'تاريخ الميلاد') iconLabel = 'تاريخ الميلاد';
    if (label == 'Gender' || label == 'الجنس') iconLabel = 'الجنس';
    if (label == 'Address' || label == 'العنوان') iconLabel = 'العنوان';
    if (iconLabel == 'تاريخ الميلاد') {
      try {
        final date = DateTime.tryParse(displayValue);
        if (date != null) {
          displayValue = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
        } else if (RegExp(r'^\d{8,}').hasMatch(displayValue)) {
          final timestamp = int.tryParse(displayValue);
          if (timestamp != null) {
            final dateFromMillis = DateTime.fromMillisecondsSinceEpoch(timestamp);
            displayValue = '${dateFromMillis.day.toString().padLeft(2, '0')}/${dateFromMillis.month.toString().padLeft(2, '0')}/${dateFromMillis.year}';
          }
        }
      } catch (_) {}
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Icon(_getIconForLabel(iconLabel), color: const Color(0xFF2A7A94), size: 22),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              displayValue,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForLabel(String label) {
    switch (label) {
      case 'رقم الهوية':
        return Icons.badge;
      case 'رقم الهاتف':
        return Icons.phone;
      case 'البريد الإلكتروني':
        return Icons.email;
      case 'تاريخ الميلاد':
        return Icons.cake;
      case 'الجنس':
        return Icons.wc;
      case 'العنوان':
        return Icons.location_on;
      default:
        return Icons.info_outline;
    }
  }
}
