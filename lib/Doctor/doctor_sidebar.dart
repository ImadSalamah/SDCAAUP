import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../Shared/waiting_list_page.dart';
import '../Doctor/doctor_pending_cases_page.dart';
import '../Doctor/groups_page.dart';
import '../Doctor/examined_patients_page.dart';
import '../dashboard/doctor_dashboard.dart';

class DoctorSidebar extends StatelessWidget {
  final Color primaryColor;
  final Color accentColor;
  final String? userName;
  final String? userImageUrl;
  final VoidCallback? onLogout;
  final BuildContext parentContext;
  final bool collapsed;
  final String Function(BuildContext, String) translate;

  const DoctorSidebar({
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

  @override
  Widget build(BuildContext context) {
    double sidebarWidth = collapsed ? 60 : 260;
    if (MediaQuery.of(context).size.width < 700 && !collapsed) {
      sidebarWidth = 200;
    }
    final isDrawer = Scaffold.maybeOf(context)?.isDrawerOpen ?? false;
    const textColor = Colors.white;
    return Drawer(
      child: Container(
        width: sidebarWidth,
        color: Colors.white,
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
                      userName ?? translate(context, 'supervisor'),
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
                      translate(context, 'supervisor'),
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
            _buildSidebarItem(context, icon: Icons.home, label: 'الرئيسية', onTap: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                parentContext,
                MaterialPageRoute(builder: (_) => const SupervisorDashboard()),
                (route) => false,
              );
            }),
            _buildSidebarItem(context, icon: Icons.list_alt, label: 'قائمة الانتظار', onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                parentContext,
                MaterialPageRoute(builder: (_) => const WaitingListPage(userRole: 'doctor')),
              );
            }),
            _buildSidebarItem(context, icon: Icons.school, label: 'تقييم الطلاب', onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                parentContext,
                MaterialPageRoute(builder: (_) => const DoctorPendingCasesPage()),
              );
            }),
            _buildSidebarItem(context, icon: Icons.group, label: 'مجموعات الإشراف', onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                parentContext,
                MaterialPageRoute(builder: (_) => const DoctorGroupsPage()),
              );
            }),
            _buildSidebarItem(context, icon: Icons.check_circle, label: 'المرضى المفحوصين', onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                parentContext,
                MaterialPageRoute(builder: (_) => const ExaminedPatientsPage()),
              );
            }),
            const Divider(),
            _buildSidebarItem(context, icon: Icons.logout, label: 'تسجيل الخروج', onTap: onLogout, iconColor: Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(BuildContext context, {required IconData icon, required String label, VoidCallback? onTap, Color? iconColor}) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? primaryColor),
      title: collapsed ? null : Text(label),
      onTap: onTap,
      contentPadding: collapsed ? const EdgeInsets.symmetric(horizontal: 12) : null,
      minLeadingWidth: 0,
      horizontalTitleGap: collapsed ? 0 : null,
    );
  }
}
