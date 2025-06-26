import 'package:flutter/material.dart';
import '../dashboard/student_dashboard.dart';
import '../notifications_page.dart';
import 'student_appointments_page.dart';
import 'student_groups_page.dart';
import '../Doctor/examined_patients_page.dart';

class StudentSidebar extends StatelessWidget {
  final Color primaryColor;
  final String? studentName;
  final String? studentImageUrl;
  const StudentSidebar({Key? key, this.primaryColor = const Color(0xFF2A7A94), this.studentName, this.studentImageUrl}) : super(key: key);

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
                studentImageUrl != null && studentImageUrl!.isNotEmpty
                    ? CircleAvatar(
                        radius: 32,
                        backgroundImage: NetworkImage(studentImageUrl!),
                      )
                    : CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 40, color: primaryColor),
                      ),
                const SizedBox(height: 10),
                Text(studentName ?? 'الطالب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          // الرئيسية أول عنصر
          ListTile(
            leading: Icon(Icons.home, color: primaryColor),
            title: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'الرئيسية' : 'Home'),
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const StudentDashboard()),
                (route) => false,
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.assignment, color: primaryColor),
            title: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'عرض الفحوصات' : 'View Examinations'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExaminedPatientsPage(
                    studentName: studentName,
                    studentImageUrl: studentImageUrl,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.medical_services, color: Colors.green),
            title: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'فحص المريض' : 'Examine Patient'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => StudentGroupsPage()),
              );
            },
          ),
          // زر مواعيدي
          ListTile(
            leading: Icon(Icons.calendar_today, color: Colors.orange),
            title: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'مواعيدي' : 'My Appointments'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => StudentAppointmentsPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
