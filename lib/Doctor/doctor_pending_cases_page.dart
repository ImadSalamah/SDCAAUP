import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Doctor/doctor_sidebar.dart';
import '../forms/paedodontics_form.dart'; // استيراد الفورم من المسار الصحيح
import '../forms/surgery_form.dart'; // استيراد الفورم الجراحة من المسار الصحيح
import '../providers/language_provider.dart';

class DoctorPendingCasesPage extends StatefulWidget {
  const DoctorPendingCasesPage({super.key});

  @override
  State<DoctorPendingCasesPage> createState() => _DoctorPendingCasesPageState();
}

class _DoctorPendingCasesPageState extends State<DoctorPendingCasesPage> {
  final DatabaseReference db = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> pendingCases = [];
  bool isLoading = true;
  String? _doctorName;
  String? _doctorImageUrl;

  @override
  void initState() {
    super.initState();
    _loadPendingCases();
    _loadDoctorInfo();
  }

  Future<void> _loadDoctorInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot = await db.child('users/${user.uid}').get();
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

  Future<void> _loadPendingCases() async {
    setState(() => isLoading = true);

    // جلب جميع المستخدمين: المفتاح هو UID
    final usersSnap = await db.child('users').get();
    Map<String, String> studentIdToName = {};

    if (usersSnap.exists && usersSnap.value is Map) {
      final usersMap = usersSnap.value as Map;
      for (var userEntry in usersMap.entries) {
        final uid = userEntry.key.toString();
        final user = userEntry.value;
        if (user is Map) {
          String fullName = '';
          if (user['fullName'] != null && user['fullName'].toString().trim().isNotEmpty) {
            fullName = user['fullName'].toString().trim();
          } else {
            fullName = [
              user['firstName'],
              user['fatherName'],
              user['grandfatherName'],
              user['familyName'],
            ].where((e) => e != null && e.toString().trim().isNotEmpty)
             .map((e) => e.toString().trim())
             .join(' ');
          }
          studentIdToName[uid] = fullName.isNotEmpty ? fullName : uid;
        }
      }
    }

    // جلب الحالات المعلقة من paedodonticsCases
    final snapshot = await db.child('paedodonticsCases').orderByChild('status').equalTo('pending').get();
    final List<Map<String, dynamic>> cases = [];
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      for (var entry in data.entries) {
        final caseData = Map<String, dynamic>.from(entry.value as Map);
        caseData['key'] = entry.key;
        if (caseData['studentId'] != null) {
          final sid = caseData['studentId'].toString();
          caseData['studentName'] = studentIdToName[sid] ?? sid;
        }
        cases.add(caseData);
      }
    }

    // جلب الحالات المعلقة من جميع pendingCases (كل المجموعات والطلاب)
    final pendingCasesSnap = await db.child('pendingCases').get();
    if (pendingCasesSnap.exists && pendingCasesSnap.value is Map) {
      final groupsMap = pendingCasesSnap.value as Map;
      for (var groupEntry in groupsMap.entries) {
        final groupId = groupEntry.key.toString();
        final studentsMap = groupEntry.value;
        if (studentsMap is Map) {
          for (var studentEntry in studentsMap.entries) {
            final studentId = studentEntry.key.toString();
            final studentCasesMap = studentEntry.value;
            if (studentCasesMap is Map) {
              for (var caseEntry in studentCasesMap.entries) {
                final caseKey = caseEntry.key.toString();
                final caseDataRaw = caseEntry.value;
                if (caseDataRaw is Map) {
                  final caseData = Map<String, dynamic>.from(caseDataRaw);
                  caseData['key'] = caseKey;
                  caseData['groupId'] = groupId;
                  caseData['studentId'] = studentId;
                  if (caseData['status'] == 'pending') {
                    caseData['studentName'] = studentIdToName[studentId] ?? studentId;
                    cases.add(caseData);
                  }
                }
              }
            }
          }
        }
      }
    }

    setState(() {
      pendingCases = cases;
      isLoading = false;
    });
  }

  Future<void> _approveAndMoveCase(Map<String, dynamic> caseData, dynamic doctorGrade) async {
    final courseId = caseData['courseId'] ?? '080114140';
    final groupId = caseData['groupId'];
    final studentId = caseData['studentId'];
    final caseKey = caseData['key'];
    final baseData = Map<String, dynamic>.from(caseData);
    // تأكيد وجود الحقول المطلوبة
    baseData['groupId'] = groupId;
    baseData['studentId'] = studentId;
    baseData['doctorGrade'] = doctorGrade;
    baseData['status'] = 'graded';
    baseData['gradedAt'] = DateTime.now().toIso8601String();
    if (!baseData.containsKey('caseType') && baseData['type'] != null) {
      baseData['caseType'] = baseData['type'];
    }
    if (!baseData.containsKey('caseNumber') && baseData['number'] != null) {
      baseData['caseNumber'] = baseData['number'];
    }
    // حذف من pendingCases
    await db.child('pendingCases').child(groupId).child(studentId).child(caseKey).remove();
    // إضافة إلى cases حسب المادة (مع تحديث status و doctorGrade)
    if (courseId == '080114140') {
      await db.child('paedodonticsCases').push().set(baseData);
    } else if (courseId == '080114141') {
      await db.child('surgeryCases').push().set(baseData);
    } else {
      await db.child('otherCases').push().set(baseData);
    }
  }

  void _showCaseDialog(Map<String, dynamic> caseData) {
    Widget formPage;
    final courseId = caseData['courseId'] ?? '080114140';
    void onSaveWithMove([dynamic doctorGrade]) async {
      if (doctorGrade != null) {
        await _approveAndMoveCase(caseData, doctorGrade);
      }
      await _loadPendingCases();
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
    }
    if (courseId == '080114140') {
      formPage = PaedodonticsForm(
        groupId: caseData['groupId'],
        caseNumber: caseData['caseNumber'],
        patient: (caseData['patient'] is Map)
            ? Map<String, dynamic>.from(caseData['patient'])
            : {},
        courseId: courseId,
        caseType: caseData['caseType'],
        initialData: caseData,
        onSave: onSaveWithMove,
      );
    } else if (courseId == '080114141') {
      formPage = SurgeryForm(
        groupId: caseData['groupId'],
        caseNumber: caseData['caseNumber'],
        patient: (caseData['patient'] is Map)
            ? Map<String, dynamic>.from(caseData['patient'])
            : {},
        courseId: courseId,
        caseType: caseData['caseType'],
        initialData: caseData,
        onSave: onSaveWithMove,
      );
    } else {
      formPage = const Scaffold(body: Center(child: Text('لا يوجد فورم لهذه المادة')));
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => formPage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF2A7A94);
    const Color accentColor = Color(0xFF4AB8D8);
    final languageProvider = Provider.of<LanguageProvider>(context);
    void logout() {}
    String translate(BuildContext context, String key) {
      final translations = {
        'supervisor': {'ar': 'مشرف', 'en': 'Supervisor'},
        'home': {'ar': 'الرئيسية', 'en': 'Home'},
        'waiting_list': {'ar': 'قائمة الانتظار', 'en': 'Waiting List'},
        'students_evaluation': {'ar': 'تقييم الطلاب', 'en': 'Students Evaluation'},
        'supervision_groups': {'ar': 'شعب الإشراف', 'en': 'Supervision Groups'},
        'examined_patients': {'ar': 'المرضى المفحوصين', 'en': 'Examined Patients'},
        'signing_out': {'ar': 'تسجيل الخروج', 'en': 'Sign out'},
      };
      return translations[key]?[languageProvider.currentLocale.languageCode] ?? key;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.currentLocale.languageCode == 'ar'
              ? 'الحالات المعلقة'
              : 'Pending Cases',
        ),
        backgroundColor: primaryColor, // Set app bar color to primaryColor
      ),
      drawer: DoctorSidebar(
        primaryColor: primaryColor,
        accentColor: accentColor,
        userName: _doctorName ?? '',
        userImageUrl: _doctorImageUrl,
        translate: translate,
        collapsed: false, // Always show labels (expanded)
        onLogout: logout,
        parentContext: context,
      ),
      body: Padding(
        padding: const EdgeInsets.only(right: 0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : pendingCases.isEmpty
                ? const Center(child: Text('لا يوجد حالات معلقة'))
                : ListView.builder(
                    itemCount: pendingCases.length,
                    itemBuilder: (context, index) {
                      final caseData = pendingCases[index];
                      final locked = caseData['_locked'] == true;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: locked ? Colors.grey[200] : null,
                        child: ListTile(
                          title: Text('طالب: ${caseData['studentName'] ?? caseData['studentId']}'),
                          subtitle: Text(
                            'تاريخ الإرسال: ${DateTime.fromMillisecondsSinceEpoch(caseData['submittedAt']).toString().substring(0, 16)}',
                          ),
                          trailing: locked
                              ? const Icon(Icons.lock, color: Colors.grey)
                              : const Icon(Icons.chevron_right),
                          onTap: locked ? null : () => _showCaseDialog(caseData),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
