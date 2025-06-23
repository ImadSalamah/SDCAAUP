import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/language_provider.dart';
import '../dashboard/security_dashboard.dart';
import '../security/search_patient_security.dart';
import '../security/face_recognition_online_page.dart';

class SecuritySidebar extends StatelessWidget {
  final Function(int)? onItemSelected;
  final int selectedIndex;
  final String? userName;
  final String? userImageUrl;

  const SecuritySidebar({
    Key? key,
    this.onItemSelected,
    this.selectedIndex = 0,
    this.userName,
    this.userImageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.currentLocale.languageCode == 'ar';
    final List<_SidebarItem> items = [
      _SidebarItem(
        icon: Icons.home,
        label: isArabic ? 'الرئيسية' : 'Home',
        pageBuilder: (context) => const SecurityDashboard(),
      ),
      _SidebarItem(
        icon: Icons.search,
        label: isArabic ? 'بحث عن مريض' : 'Patient Search',
        pageBuilder: (context) => const SearchPatientSecurityPage(),
      ),
      _SidebarItem(
        icon: Icons.face,
        label: isArabic ? 'التعرف على الوجه' : 'Face Recognition',
        pageBuilder: (context) => const FaceRecognitionOnlinePage(),
      ),
    ];

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: const Color(0xFF2A7A94),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (userImageUrl != null && userImageUrl!.isNotEmpty)
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      child: ClipOval(
                        child: Image.memory(
                          base64Decode(userImageUrl!.replaceFirst('data:image/jpeg;base64,', '')),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 40, color: Color(0xFF2A7A94)),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    userName ?? (isArabic ? 'ضابط أمن' : 'Security Officer'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: Icon(
                    item.icon,
                    color: selectedIndex == index
                        ? const Color(0xFF2A7A94)
                        : Colors.grey,
                  ),
                  title: Text(
                    item.label,
                    style: TextStyle(
                      color: selectedIndex == index
                          ? const Color(0xFF2A7A94)
                          : Colors.black,
                      fontWeight: selectedIndex == index
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  selected: selectedIndex == index,
                  onTap: () {
                    if (onItemSelected != null) {
                      onItemSelected!(index);
                    }
                    // تفعيل التنقل الفعلي بدون routes
                    if (items[index].pageBuilder != null) {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => items[index].pageBuilder!(context)),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem {
  final IconData icon;
  final String label;
  final WidgetBuilder? pageBuilder;

  _SidebarItem({required this.icon, required this.label, this.pageBuilder});
}
