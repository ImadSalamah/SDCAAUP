import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Doctor/doctor_sidebar.dart';

class DoctorGroupsPage extends StatefulWidget {
  const DoctorGroupsPage({super.key});

  @override
  State<DoctorGroupsPage> createState() => _DoctorGroupsPageState();
}

class _DoctorGroupsPageState extends State<DoctorGroupsPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;
  String? _doctorName;
  String? _doctorImageUrl;

  @override
  void initState() {
    super.initState();
    _loadGroups();
    _loadDoctorInfo();
  }

  Future<void> _loadDoctorInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot = await _dbRef.child('users/${user.uid}').get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final firstName = data['firstName']?.toString().trim() ?? '';
      final fatherName = data['fatherName']?.toString().trim() ?? '';
      final grandfatherName = data['grandfatherName']?.toString().trim() ?? '';
      final familyName = data['familyName']?.toString().trim() ?? '';
      final fullName = [firstName, fatherName, grandfatherName, familyName].where((e) => e.isNotEmpty).join(' ');
      final imageData = data['image']?.toString() ?? '';
      setState(() {
        _doctorName = fullName.isNotEmpty ? fullName : null;
        _doctorImageUrl = imageData.isNotEmpty ? 'data:image/jpeg;base64,$imageData' : null;
      });
    }
  }

  Future<void> _loadGroups() async {
    final snapshot = await _dbRef.child('studyGroups').get();
    final List<Map<String, dynamic>> groups = [];
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        groups.add({'id': key, ...Map<String, dynamic>.from(value as Map)});
      });
    }
    setState(() {
      _groups = groups;
      _isLoading = false;
    });
  }

  void _openGroupMarks(Map<String, dynamic> group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupMarksPage(
          group: group,
          subject: group['courseType'] ?? 'paedodontics',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLargeScreen = MediaQuery.of(context).size.width >= 900;
    const Color primaryColor = Color(0xFF2A7A94);
    const Color accentColor = Color(0xFF4AB8D8);
    const Color backgroundColor = Colors.white;
    const Color cardColor = Colors.white;
    const Color borderColor = Color(0xFFEEEEEE);
    const Color textPrimary = Color(0xFF333333);
    const Color textSecondary = Color(0xFF666666);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          title: const Text(
            'شعب الإشراف',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
              letterSpacing: 1.2,
            ),
          ),
          backgroundColor: primaryColor,
          elevation: 2,
          iconTheme: const IconThemeData(color: Colors.white),
          automaticallyImplyLeading: false,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.menu, size: 28),
            onPressed: () {
              if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
                Navigator.of(context).pop();
              } else {
                _scaffoldKey.currentState?.openDrawer();
              }
            },
          ),
        ),
      ),
      drawer: !isLargeScreen
          ? DoctorSidebar(
              primaryColor: primaryColor,
              accentColor: accentColor,
              userName: _doctorName ?? '',
              userImageUrl: _doctorImageUrl,
              translate: (ctx, key) => key,
              parentContext: context,
            )
          : null,
      body: Stack(
        children: [
          if (isLargeScreen)
            Container(
              width: 260,
              child: DoctorSidebar(
                primaryColor: primaryColor,
                accentColor: accentColor,
                userName: _doctorName ?? '',
                userImageUrl: _doctorImageUrl,
                translate: (ctx, key) => key,
                collapsed: true,
                parentContext: context,
              ),
            ),
          Padding(
            padding: EdgeInsets.only(right: isLargeScreen ? 260 : 0, top: 24, left: 24, bottom: 24),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _groups.isEmpty
                    ? const Center(child: Text('لا يوجد شعب إشراف حالياً', style: TextStyle(color: textSecondary, fontSize: 18)))
                    : ListView.builder(
                        itemCount: _groups.length,
                        itemBuilder: (context, index) {
                          final group = _groups[index];
                          return Card(
                            color: cardColor,
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: borderColor, width: 1),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              title: Text(
                                group['courseName'] ?? 'بدون اسم',
                                style: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              subtitle: Text(
                                'الشعبة: ${group['groupNumber'] ?? ''}',
                                style: const TextStyle(color: textSecondary, fontSize: 15),
                              ),
                              trailing: Container(
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(8),
                                child: const Icon(Icons.arrow_forward_ios, color: accentColor, size: 20),
                              ),
                              onTap: () => _openGroupMarks(group),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class GroupMarksPage extends StatefulWidget {
  final Map<String, dynamic> group;
  final String subject;
  const GroupMarksPage({required this.group, required this.subject, super.key});

  @override
  State<GroupMarksPage> createState() => _GroupMarksPageState();
}

class _GroupMarksPageState extends State<GroupMarksPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;
  late String _selectedSubject;

  // تعريف الحالات حسب رقم المادة (مطابق لتعريف cases_screen.dart)
  final Map<String, List<Map<String, dynamic>>> courseCases = {
    '080114140': [
      for (int i = 1; i <= 3; i++) {'type': 'history', 'number': i},
      for (int i = 1; i <= 6; i++) {'type': 'fissure', 'number': i},
    ],
    '080114141': [
      for (int i = 1; i <= 4; i++) {'type': 'simpleSurgery', 'number': i},
    ],
    // أضف مواد أخرى هنا بنفس الطريقة
  };

  @override
  void initState() {
    super.initState();
    _selectedSubject = widget.subject;
    _loadStudentsAndCases();
  }

  Future<void> _loadStudentsAndCases() async {
    final groupId = widget.group['id'];
    final groupDataSnap = await _dbRef.child('studyGroups').child(groupId).get();
    final studentsMap = groupDataSnap.child('students').value as Map<dynamic, dynamic>? ?? {};
    final List<Map<String, dynamic>> students = [];
    // تحديد رقم المادة
    final courseId = widget.group['courseId'] ?? widget.group['courseType'] ?? '080114140';
    for (final entry in studentsMap.entries) {
      final studentId = entry.key;
      final studentSnap = await _dbRef.child('users').child(studentId).get();
      final studentData = studentSnap.value as Map<dynamic, dynamic>? ?? {};
      String studentName = studentData['fullName'] ?? studentData['name'] ?? '';
      if (studentName.isEmpty) {
        studentName = entry.value['fullName'] ?? entry.value['name'] ?? '';
      }
      List<Map<String, dynamic>> cases = [];
      if (courseId == '080114140') {
        final casesSnap = await _dbRef.child('paedodonticsCases').orderByChild('studentId').equalTo(studentId).get();
        if (casesSnap.exists) {
          final allCases = casesSnap.value as Map<dynamic, dynamic>;
          allCases.forEach((caseKey, caseData) {
            if (caseData['groupId'] == groupId) {
              cases.add({...Map<String, dynamic>.from(caseData), 'id': caseKey});
            }
          });
        }
      } else if (courseId == '080114141') {
        final casesSnap = await _dbRef.child('surgeryCases').orderByChild('studentId').equalTo(studentId).get();
        if (casesSnap.exists) {
          final allCases = casesSnap.value as Map<dynamic, dynamic>;
          allCases.forEach((caseKey, caseData) {
            if (caseData['groupId'] == groupId) {
              cases.add({...Map<String, dynamic>.from(caseData), 'id': caseKey});
            }
          });
        }
      }
      // أضف مواد أخرى هنا حسب الحاجة
      students.add({
        'id': studentId,
        'name': studentName,
        'cases': cases,
      });
    }
    students.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    setState(() {
      _students = students;
      _isLoading = false;
    });
  }

  Map<String, dynamic>? findCase(List<Map<String, dynamic>> cases, String type, int number) {
    // دعم الحالات التي status = 'graded' أو 'pending' (لعرض كل الحالات التي تم تقييمها أو بانتظار التقييم)
    final filtered = cases.where((c) => c['caseType'] == type && c['caseNumber'].toString() == number.toString());
    // إذا لم توجد graded، جرب pending (لعرضها مؤقتاً)
    final graded = filtered.where((c) => c['status'] == 'graded' && c['caseType'] != null);
    if (graded.isNotEmpty) {
      graded.toList().sort((a, b) {
        final ma = a['doctorGrade'] ?? a['mark'] ?? a['grade'] ?? 0;
        final mb = b['doctorGrade'] ?? b['mark'] ?? b['grade'] ?? 0;
        return mb.compareTo(ma);
      });
      return graded.first;
    }
    // دعم عرض pending إذا لم توجد graded (اختياري)
    final pending = filtered.where((c) => c['status'] == 'pending' && c['caseType'] != null);
    if (pending.isNotEmpty) {
      return pending.first;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // تحديد رقم المادة
    final courseId = widget.group['courseId'] ?? widget.group['courseType'] ?? '080114140';
    final caseList = courseCases[courseId] ?? [];
    return Scaffold(
      appBar: AppBar(
        title: Text('علامات الشعبة: ${widget.group['groupNumber'] ?? ''}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('الطالب')),
                  ...caseList.map((t) => DataColumn(label: Text(_getCaseLabel(t)))),
                ],
                rows: _students.map((student) {
                  final cases = student['cases'] as List<Map<String, dynamic>>;
                  List<DataCell> cells = [
                    DataCell(Text(student['name'] ?? '')),
                  ];
                  for (final t in caseList) {
                    final type = t['type'] as String;
                    final number = t['number'] as int;
                    final caseData = findCase(cases, type, number);
                    String mark = '-';
                    if (caseData != null) {
                      final status = caseData['status'];
                      final m = caseData['doctorGrade'] ?? caseData['mark'] ?? caseData['grade'];
                      if (status == 'graded' && m != null && m.toString().isNotEmpty) {
                        mark = m.toString();
                      }
                    }
                    cells.add(DataCell(Text(mark)));
                  }
                  return DataRow(cells: cells);
                }).toList(),
              ),
            ),
    );
  }

  String _getCaseLabel(Map<String, dynamic> t) {
    if (t['type'] == 'history') return 'تاريخ وفحص #${t['number']}';
    if (t['type'] == 'fissure') return 'سد شقوق #${t['number']}';
    if (t['type'] == 'simpleSurgery') return 'حالة جراحية #${t['number']}';
    // أضف أنواع أخرى هنا حسب الحاجة
    return '${t['type']} #${t['number']}';
  }
}
