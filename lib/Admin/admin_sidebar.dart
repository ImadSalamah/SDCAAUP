import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../dashboard/admin_dashboard.dart';
import '../Admin/add_user_page.dart';
import '../Admin/manage_study_groups_page.dart';
import '../Admin/add_student.dart';
import '../Admin/edit_user_page.dart';
import '../../providers/language_provider.dart';

class AdminSidebar extends StatelessWidget {
  final Color primaryColor;
  final Color accentColor;
  final String? userName;
  final String? userImageUrl;
  final VoidCallback? onLogout;
  final BuildContext parentContext;
  final bool collapsed;
  final String Function(BuildContext, String) translate;

  AdminSidebar({
    super.key,
    required this.primaryColor,
    required this.accentColor,
    this.userName,
    this.userImageUrl,
    this.onLogout,
    required this.parentContext,
    this.collapsed = false,
    required this.translate,
  });

  final Map<String, Map<String, String>> _translations = {
    'admin_dashboard': {'ar': 'لوحة الإدارة', 'en': 'Admin Dashboard'},
    'manage_users': {'ar': 'إدارة المستخدمين', 'en': 'Manage Users'},
    'add_user': {'ar': 'إضافة مستخدم', 'en': 'Add User'},
    'add_user_student': {'ar': 'إضافة طالب طب اسنان', 'en': 'Add Dental Student'},
    'change_permissions': {'ar': 'تغيير الصلاحيات', 'en': 'Change Permissions'},
    'admin': {'ar': 'مدير النظام', 'en': 'System Admin'},
    'home': {'ar': 'الرئيسية', 'en': 'Home'},
    'settings': {'ar': 'الإعدادات', 'en': 'Settings'},
    'logout': {'ar': 'تسجيل الخروج', 'en': 'Logout'},
    'manage_study_groups': {'ar': 'إدارة الشعب الدراسية', 'en': 'Manage Study Groups'},
    // أضف المزيد حسب الحاجة
  };

  String _translate(BuildContext context, String key) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    return _translations[key]?[languageProvider.currentLocale.languageCode] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: primaryColor),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                userImageUrl != null && userImageUrl!.isNotEmpty
                    ? CircleAvatar(
                        radius: collapsed ? 18 : 32,
                        backgroundColor: Colors.white,
                        child: ClipOval(
                          child: Image.memory(
                            // Properly decode base64 string to Uint8List
                            base64Decode(userImageUrl!.replaceFirst('data:image/jpeg;base64,', '')),
                            width: collapsed ? 36 : 64,
                            height: collapsed ? 36 : 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    : CircleAvatar(
                        radius: collapsed ? 18 : 32,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: collapsed ? 18 : 32, color: accentColor),
                      ),
                if (!collapsed) ...[
                  const SizedBox(height: 10),
                  Text(
                    userName ?? translate(context, 'admin'),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    translate(context, 'admin'),
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ],
              ],
            ),
          ),
          _buildSidebarItem(context, icon: Icons.home, label: translate(context, 'home'), onTap: () {
            Navigator.pop(context);
            Navigator.pushAndRemoveUntil(
              parentContext,
              MaterialPageRoute(
                builder: (context) => const AdminDashboard(),
              ),
              (route) => false,
            );
          }),
          _buildSidebarItem(context, icon: Icons.people, label: translate(context, 'manage_users'), onTap: () {
            Navigator.pop(context);
            Navigator.push(
              parentContext,
              MaterialPageRoute(
                builder: (context) => EditUserPage(
                  user: const {},
                  usersList: const [],
                  userName: userName,
                  userImageUrl: userImageUrl,
                  translate: translate,
                  onLogout: onLogout ?? () {},
                ),
              ),
            );
          }),
          _buildSidebarItem(context, icon: Icons.person_add, label: translate(context, 'add_user'), onTap: () {
            Navigator.pop(context);
            Navigator.push(
              parentContext,
              MaterialPageRoute(
                builder: (context) => AddUserPage(
                  userName: userName,
                  userImageUrl: userImageUrl,
                  translate: translate,
                  onLogout: onLogout ?? () {},
                ),
              ),
            );
          }),
          _buildSidebarItem(context, icon: Icons.person_add_alt_1, label: translate(context, 'add_user_student'), onTap: () {
            Navigator.pop(context);
            Navigator.push(
              parentContext,
              MaterialPageRoute(
                builder: (context) => AddDentalStudentPage(
                  userName: userName,
                  userImageUrl: userImageUrl,
                  translate: translate,
                  onLogout: onLogout ?? () {},
                ),
              ),
            );
          }),
          _buildSidebarItem(context, icon: Icons.group, label: _translate(context, 'manage_study_groups'), onTap: () {
            Navigator.pop(context);
            Navigator.push(
              parentContext,
              MaterialPageRoute(
                builder: (context) => AdminManageGroupsPage(
                  userName: userName,
                  userImageUrl: userImageUrl,
                  translate: translate,
                  onLogout: onLogout ?? () {},
                ),
              ),
            );
          }),
          const Divider(),
          // تم حذف عنصر تسجيل الخروج من السايد بار
        ],
      ),
    );
  }

  Widget _buildSidebarItem(BuildContext context, {required IconData icon, required String label, VoidCallback? onTap, Color? iconColor}) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? primaryColor),
      title: collapsed
          ? null
          : Text(
              label,
              style: const TextStyle(color: Colors.black), // لون الخط أسود
            ),
      onTap: onTap,
      contentPadding: collapsed ? const EdgeInsets.symmetric(horizontal: 12) : null,
      minLeadingWidth: 0,
      horizontalTitleGap: collapsed ? 0 : null,
    );
  }
}
