import 'dart:convert';
import 'package:flutter/material.dart';
import 'patient_sidebar.dart';
import '../dashboard/patient_dashboard.dart';
import 'patient_appointments_page.dart';
import 'patient_prescriptions_page.dart';
import 'package:firebase_database/firebase_database.dart';
import '../providers/patient_provider.dart';
import 'package:provider/provider.dart';

class PatientProfilePage extends StatelessWidget {
  const PatientProfilePage({Key? key}) : super(key: key);

  void _handleSidebarNavigation(BuildContext context, String route) async {
    if (ModalRoute.of(context)?.settings.name == route) return;
    final patientProvider = Provider.of<PatientProvider>(context, listen: false);
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientAppointmentsPage(
              patientUid: patientProvider.uid,
              key: UniqueKey(),
            ),
          ),
        );
        break;
      case '/patient_prescriptions':
        if (patientProvider.uid.isEmpty && patientProvider.phone.isNotEmpty) {
          // ابحث عن uid باستخدام رقم الهاتف
          final usersRef = FirebaseDatabase.instance.ref('users');
          final usersSnap = await usersRef.get();
          String patientId = '';
          if (usersSnap.exists && usersSnap.value != null) {
            final usersMap = Map<String, dynamic>.from(usersSnap.value as Map);
            usersMap.forEach((uid, user) {
              if (user is Map && user['phone'] == patientProvider.phone) {
                patientId = uid;
              }
            });
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
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PatientPrescriptionsPage(
                patientId: patientProvider.uid,
              ),
            ),
          );
        }
        break;
      case '/patient_profile':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PatientProfilePage(),
          ),
        );
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientProvider = Provider.of<PatientProvider>(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 350;
    final String fullName = patientProvider.fullName;
    final String imageBase64 = patientProvider.imageBase64;

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
                child: imageBase64.isNotEmpty
                    ? _buildSafeProfileAvatar(imageBase64, isSmallScreen)
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
    final patientProvider = Provider.of<PatientProvider>(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final infoList = [
      {'label': isArabic ? 'رقم الهاتف' : 'Phone Number', 'value': patientProvider.phone},
      {'label': isArabic ? 'البريد الإلكتروني' : 'Email', 'value': patientProvider.email},
      {'label': isArabic ? 'رقم الهوية' : 'ID Number', 'value': patientProvider.idNumber},
      {'label': isArabic ? 'تاريخ الميلاد' : 'Birth Date', 'value': patientProvider.birthDate},
      {'label': isArabic ? 'الجنس' : 'Gender', 'value': patientProvider.gender},
      {'label': isArabic ? 'العنوان' : 'Address', 'value': patientProvider.address},
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

  // Add this widget to handle invalid base64 gracefully in profile page
  Widget _buildSafeProfileAvatar(String base64String, bool isSmallScreen) {
    try {
      final bytes = base64.decode(_cleanBase64(base64String));
      return CircleAvatar(
        radius: isSmallScreen ? 48 : 64,
        backgroundColor: Colors.grey.shade200,
        child: ClipOval(
          child: Image.memory(
            bytes,
            width: isSmallScreen ? 96 : 128,
            height: isSmallScreen ? 96 : 128,
            fit: BoxFit.cover,
          ),
        ),
      );
    } catch (e) {
      return CircleAvatar(
        radius: isSmallScreen ? 48 : 64,
        backgroundColor: Colors.grey.shade200,
        child: const Icon(Icons.person, size: 60, color: Colors.blueGrey),
      );
    }
  }
}

String _cleanBase64(String base64String) {
  final regex = RegExp(r'^data:image\/[^;]+;base64,');
  return base64String.replaceFirst(regex, '');
}
