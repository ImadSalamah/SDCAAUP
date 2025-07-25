import 'package:flutter/material.dart';
import '../forms/clinical_procedures_form.dart';
import 'dart:convert';
import '../Shared/waiting_list_page.dart';
import '../Doctor/doctor_pending_cases_page.dart';
import '../Doctor/groups_page.dart';
import '../Doctor/examined_patients_page.dart';
import '../dashboard/doctor_dashboard.dart';
import 'prescription_page.dart';
import 'doctor_xray_request_page.dart';
import '../Doctor/assign_patients_to_student_page.dart';

class DoctorSidebar extends StatelessWidget {
  final Color primaryColor;
  final Color accentColor;
  final String? userName;
  final String? userImageUrl;
  final VoidCallback? onLogout;
  final BuildContext parentContext;
  final bool collapsed;
  final String Function(BuildContext, String) translate;
  final String doctorUid;

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
    required this.doctorUid,
  });

  @override
  Widget build(BuildContext context) {
    // Sidebar labels in both Arabic and English
    final sidebarLabels = [
      {'ar': 'الرئيسية', 'en': 'Home'},
      {'ar': 'قائمة الانتظار', 'en': 'Waiting List'},
      {'ar': 'تقييم الطلاب', 'en': 'Student Evaluation'},
      {'ar': 'مجموعات الإشراف', 'en': 'Supervision Groups'},
      {'ar': 'المرضى المفحوصين', 'en': 'Examined Patients'},
      {'ar': 'تعيين مرضى للطلاب', 'en': 'Assign Patients to Students'},
    ];
    // Detect language (you can adjust this logic as needed)
    final isArabic = Localizations.localeOf(parentContext).languageCode == 'ar';

    double sidebarWidth = collapsed ? 60 : 260;
    if (MediaQuery.of(context).size.width < 700 && !collapsed) {
      sidebarWidth = 200;
    }

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
                  if (userImageUrl != null && userImageUrl!.isNotEmpty)
                    userImageUrl!.startsWith('http') || userImageUrl!.startsWith('https')
                        ? CircleAvatar(
                            radius: collapsed ? 18 : 32,
                            backgroundColor: Colors.white,
                            backgroundImage: NetworkImage(userImageUrl!),
                          )
                        : CircleAvatar(
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
                  else
                    CircleAvatar(
                      radius: collapsed ? 18 : 32,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: collapsed ? 18 : 32, color: accentColor),
                    ),
                  if (!collapsed) ...[
                    const SizedBox(height: 10),
                    Text(
                      userName ?? (isArabic ? 'دكتور' : 'Doctor'),
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
                      isArabic ? 'دكتور' : 'Doctor',
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
            _buildSidebarItem(context, icon: Icons.home, label: isArabic ? sidebarLabels[0]['ar']! : sidebarLabels[0]['en']!, onTap: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                parentContext,
                MaterialPageRoute(builder: (_) => const SupervisorDashboard()),
                (route) => false,
              );
            }),
            _buildSidebarItem(context, icon: Icons.list_alt, label: isArabic ? sidebarLabels[1]['ar']! : sidebarLabels[1]['en']!, onTap: () {
              Navigator.pop(context);
              Navigator.push(
                parentContext,
                MaterialPageRoute(builder: (_) => const WaitingListPage(userRole: 'doctor')),
              );
            }),
            _buildSidebarItem(context, icon: Icons.school, label: isArabic ? sidebarLabels[2]['ar']! : sidebarLabels[2]['en']!, onTap: () {
              Navigator.pop(context);
              Navigator.push(
                parentContext,
                MaterialPageRoute(builder: (_) => const DoctorPendingCasesPage()),
              );
            }),
            _buildSidebarItem(context, icon: Icons.group, label: isArabic ? sidebarLabels[3]['ar']! : sidebarLabels[3]['en']!, onTap: () {
              Navigator.pop(context);
              Navigator.push(
                parentContext,
                MaterialPageRoute(builder: (_) => const DoctorGroupsPage()),
              );
            }),
            _buildSidebarItem(context, icon: Icons.check_circle, label: isArabic ? sidebarLabels[4]['ar']! : sidebarLabels[4]['en']!, onTap: () {
              Navigator.pop(context);
              Navigator.push(
                parentContext,
                MaterialPageRoute(builder: (_) => const ExaminedPatientsPage()),
              );
            }),
            _buildSidebarItem(context, icon: Icons.medical_services, label: isArabic ? 'الوصفة الطبية' : 'Prescription', onTap: () {
              Navigator.pop(context);
              Navigator.push(
                parentContext,
                MaterialPageRoute(builder: (_) => PrescriptionPage(isArabic: isArabic)),
              );
            }),
        
            _buildSidebarItem(context, icon: Icons.medical_information, label: isArabic ? 'نموذج الإجراءات السريرية' : 'Clinical Procedures Form', onTap: () {
              Navigator.pop(context);
              Navigator.push(
                parentContext,
                MaterialPageRoute(builder: (_) => ClinicalProceduresForm(uid: doctorUid)),
              );
            }),
            _buildSidebarItem(context, icon: Icons.wb_iridescent, label: isArabic ? 'طلب أشعة' : 'Radiology Request', onTap: () {
              Navigator.pop(context);
              Navigator.push(
                parentContext,
                MaterialPageRoute(builder: (_) => const DoctorXrayRequestPage()),
              );
            }),
            _buildSidebarItem(context, icon: Icons.assignment_ind, label: isArabic ? 'تعيين مرضى للطلاب' : 'Assign Patients to Students', onTap: () {
            Navigator.pop(context);
            Navigator.push(
                parentContext,
                MaterialPageRoute(builder: (_) => const AssignPatientsToStudentPage()),
            );
        }),
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
