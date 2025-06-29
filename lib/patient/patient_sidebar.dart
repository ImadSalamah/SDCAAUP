import 'package:flutter/material.dart';
import '../providers/language_provider.dart';
import 'package:provider/provider.dart';
import '../loginpage.dart';
import 'dart:convert';
import '../providers/patient_provider.dart';

class PatientSidebar extends StatelessWidget {
  final Function(String route) onNavigate;
  final String currentRoute;

  const PatientSidebar({
    Key? key,
    required this.onNavigate,
    required this.currentRoute,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final patientProvider = Provider.of<PatientProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.currentLocale.languageCode == 'ar';
    final primaryColor = const Color(0xFF2A7A94);
    final patientName = patientProvider.fullName;
    final patientImageUrl = patientProvider.imageBase64;

    return Drawer(
      child: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: primaryColor),
              currentAccountPicture: patientImageUrl.isNotEmpty
                  ? _buildSafeAvatar(patientImageUrl)
                  : const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, color: Color(0xFF2A7A94), size: 36),
                    ),
              accountName: Text(
                patientName.isNotEmpty ? patientName : (isArabic ? 'مريض' : 'Patient'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
              accountEmail: null,
            ),
            _buildSidebarItem(
              context,
              icon: Icons.dashboard,
              label: isArabic ? 'الرئيسية' : 'Dashboard',
              route: '/patient_dashboard',
            ),
            _buildSidebarItem(
              context,
              icon: Icons.medical_services,
              label: isArabic ? 'السجلات الطبية' : 'Medical Records',
              route: '/medical_records',
            ),
            _buildSidebarItem(
              context,
              icon: Icons.calendar_today,
              label: isArabic ? 'المواعيد' : 'Appointments',
              route: '/patient_appointments',
            ),
            _buildSidebarItem(
              context,
              icon: Icons.medication,
              label: isArabic ? 'الوصفات الطبية' : 'Prescriptions',
              route: '/patient_prescriptions',
            ),
            _buildSidebarItem(
              context,
              icon: Icons.person,
              label: isArabic ? 'الملف الشخصي' : 'Profile',
              route: '/patient_profile',
            ),
            const Divider(),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(BuildContext context,
      {required IconData icon, required String label, required String route}) {
    final isSelected = ModalRoute.of(context)?.settings.name == route || currentRoute == route;
    final primaryColor = const Color(0xFF2A7A94);
    return ListTile(
      leading: Icon(icon, color: isSelected ? primaryColor : null),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? primaryColor : null,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onTap: () {
        Navigator.pop(context);
        onNavigate(route);
      },
    );
  }

  Widget _buildSafeAvatar(String base64String) {
    try {
      final bytes = base64.decode(_cleanBase64(base64String));
      return CircleAvatar(
        backgroundColor: Colors.white,
        child: ClipOval(
          child: Image.memory(
            bytes,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
          ),
        ),
      );
    } catch (e) {
      return const CircleAvatar(
        backgroundColor: Colors.white,
        child: Icon(Icons.person, color: Color(0xFF2A7A94), size: 36),
      );
    }
  }
}

String _cleanBase64(String base64String) {
  // يزيل أي بادئة data:image/*;base64, إن وجدت
  final regex = RegExp(r'^data:image\/[^;]+;base64,');
  return base64String.replaceFirst(regex, '');
}
