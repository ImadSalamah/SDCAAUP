import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cases_screen.dart';
import 'student_sidebar.dart';

void main() {
  runApp(const MaterialApp(
    home: StudentGroupsPage(),
  ));
}

class StudentGroupsPage extends StatefulWidget {
  const StudentGroupsPage({super.key});

  @override
  StudentGroupsPageState createState() => StudentGroupsPageState();
}

class StudentGroupsPageState extends State<StudentGroupsPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _studentGroups = [];
  String? _studentName;
  String? _studentImageUrl;

  @override
  void initState() {
    super.initState();
    _loadStudentInfo();
    _loadStudentGroups();
  }

  Future<void> _loadStudentInfo() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final snapshot = await _dbRef.child('users/${user.uid}').get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        // بناء الاسم الرباعي
        final firstName = data['firstName'] ?? '';
        final fatherName = data['fatherName'] ?? '';
        final grandfatherName = data['grandfatherName'] ?? '';
        final familyName = data['familyName'] ?? '';
        final fullName = [firstName, fatherName, grandfatherName, familyName]
            .where((part) => part.toString().isNotEmpty)
            .join(' ');
        setState(() {
          _studentName = fullName.isNotEmpty ? fullName : 'الطالب';
          _studentImageUrl = data['imageUrl'] ?? null;
        });
      }
    } catch (e) {
      setState(() {
        _studentName = 'الطالب';
        _studentImageUrl = null;
      });
    }
  }

  Future<void> _loadStudentGroups() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _dbRef.child('studyGroups').get();
      if (snapshot.exists) {
        final allGroups = snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> groups = [];

        allGroups.forEach((groupId, groupData) {
          final students =
              groupData['students'] as Map<dynamic, dynamic>? ?? {};
          if (students.containsKey(user.uid)) {
            groups.add({
              'id': groupId.toString(),
              'groupNumber':
                  groupData['groupNumber']?.toString() ?? 'غير معروف',
              'courseId': groupData['courseId']?.toString() ?? '',
              'courseName': groupData['courseName']?.toString() ?? 'غير معروف',
              'requiredCases': groupData['requiredCases'] ?? 3,
            });
          }
        });

        setState(() {
          _studentGroups = groups;
        });
      }
    } catch (e) {
      setState(() {});
    }
  }

  void _navigateToLogbook(BuildContext context, Map<String, dynamic> group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CasesScreen(
          groupId: group['id'],
          courseId: group['courseId'],
          courseName: group['courseName'],
          requiredCases: group['requiredCases'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF2A7A94);
    final Color accentColor = const Color(0xFF4AB8D8);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('شعبي الدراسية', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        centerTitle: true,
        leading: isRtl
            ? Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : null,
        actions: !isRtl
            ? [
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
              ]
            : null,
      ),
      drawer: StudentSidebar(
        studentName: _studentName,
        studentImageUrl: _studentImageUrl,
      ),
      body: _studentGroups.isEmpty
          ? const Center(child: Text('لا توجد شعب مسجلة لك'))
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _studentGroups.length,
              itemBuilder: (context, index) {
                final group = _studentGroups[index];
                return Card(
                  color: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: accentColor,
                      child: Icon(Icons.group, color: Colors.white),
                    ),
                    title: Text(group['courseName'], style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                    subtitle: Text('الشعبة ${group['groupNumber']}', style: TextStyle(color: Colors.grey[700])),
                    trailing: const Icon(Icons.arrow_forward, color: Colors.grey),
                    onTap: () => _navigateToLogbook(context, group),
                  ),
                );
              },
            ),
    );
  }
}