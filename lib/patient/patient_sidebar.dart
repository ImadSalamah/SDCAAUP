import 'package:flutter/material.dart';
import '../providers/language_provider.dart';
import 'package:provider/provider.dart';
import '../loginpage.dart';

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
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.currentLocale.languageCode == 'ar';
    final primaryColor = const Color(0xFF2A7A94);

    return Drawer(
      child: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: primaryColor,
              ),
              child: Center(
                child: Text(
                  isArabic
                      ? 'مرحبا بك في لوحة المريض'
                      : 'Welcome to Patient Panel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
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
}
