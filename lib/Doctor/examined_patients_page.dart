
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import '../../providers/language_provider.dart';
import '../Doctor/doctor_sidebar.dart';
import '../Student/student_sidebar.dart';

Map<String, dynamic> safeConvertMap(dynamic data) {
  if (data == null) return {};
  if (data is Map<String, dynamic>) return data;
  if (data is Map) {
    try {
      return Map<String, dynamic>.from(data);
    } catch (e) {
      debugPrint('Error converting map: $e');
      return {};
    }
  }
  return {};
}

class ExaminedPatientsPage extends StatefulWidget {
  final String? studentName;
  final String? studentImageUrl;
  const ExaminedPatientsPage({super.key, this.studentName, this.studentImageUrl});

  @override
  State<ExaminedPatientsPage> createState() => _ExaminedPatientsPageState();
}

class _ExaminedPatientsPageState extends State<ExaminedPatientsPage> {
  // دالة لجلب جميع الإجراءات السريرية للمريض من قاعدة البيانات
  Future<List<Map<String, dynamic>>> _getClinicalProceduresForPatient(String? patientId) async {
    if (patientId == null || patientId.isEmpty) return [];
    final ref = FirebaseDatabase.instance.ref('clinical_procedures');
    final snapshot = await ref.get();
    if (!snapshot.exists) return [];
    final data = snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) return [];
    final List<Map<String, dynamic>> procedures = [];
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is Map<dynamic, dynamic>) {
        final map = Map<String, dynamic>.from(value);
        if (map['patientId']?.toString() == patientId) {
          procedures.add(map);
        }
      }
    }
    // ترتيب الإجراءات من الأحدث إلى الأقدم حسب تاريخ الإنشاء
    procedures.sort((a, b) {
      final aTime = a['createdAt'] is String ? DateTime.tryParse(a['createdAt'])?.millisecondsSinceEpoch ?? 0 : 0;
      final bTime = b['createdAt'] is String ? DateTime.tryParse(b['createdAt'])?.millisecondsSinceEpoch ?? 0 : 0;
      return bTime.compareTo(aTime);
    });
    return procedures;
  }
  // تعريف الألوان
  static const Color primaryColor = Color(0xFF2A7A94);
  static const Color backgroundColor = Color(0xFFF3F5F7); // رمادي فاتح للخلفية
  static const Color cardColor = Colors.white; // البطاقات تبقى بيضاء
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF666666);
  static const Color borderColor = Color(0xFFEEEEEE);
  static const Color errorColor = Color(0xFFE53935);

  final DatabaseReference _examinationsRef =
      FirebaseDatabase.instance.ref('examinations');
  final DatabaseReference _doctorsRef = FirebaseDatabase.instance.ref('staff');
  final DatabaseReference _patientsRef = FirebaseDatabase.instance.ref('users');

  List<Map<String, dynamic>> _examinedPatients = [];
  bool _isLoading = true;
  bool _hasError = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredExaminations = [];

  String? _doctorName;
  String? _doctorImageUrl;
  String? _userRole;

  final Map<String, Map<String, String>> _translations = {
    'examined_patients': {'ar': 'المرضى المفحوصين', 'en': 'Examined Patients'},
    'name': {'ar': 'الاسم', 'en': 'Name'},
    'phone': {'ar': 'الهاتف', 'en': 'Phone'},
    'age': {'ar': 'العمر', 'en': 'Age'},
    'no_patients': {'ar': 'لا يوجد مرضى مفحوصين', 'en': 'No examined patients'},
    'error_loading': {
      'ar': 'خطأ في تحميل البيانات',
      'en': 'Error loading data'
    },
    'retry': {'ar': 'إعادة المحاولة', 'en': 'Retry'},
    'examination_date': {'ar': 'تاريخ الفحص', 'en': 'Examination Date'},
    'examining_doctor': {'ar': 'الطبيب المختص', 'en': 'Examining Doctor'},
    'examination_details': {'ar': 'تفاصيل الفحص', 'en': 'Examination Details'},
    'back': {'ar': 'رجوع', 'en': 'Back'},
    'gender': {'ar': 'الجنس', 'en': 'Gender'},
    'patient_information': {
      'ar': 'معلومات المريض',
      'en': 'Patient Information'
    },
    'examination_information': {
      'ar': 'معلومات الفحص',
      'en': 'Examination Information'
    },
    'extraoral_examination': {
      'ar': 'الفحص الخارجي',
      'en': 'Extraoral Examination'
    },
    'intraoral_examination': {
      'ar': 'الفحص الداخلي',
      'en': 'Intraoral Examination'
    },
    'soft_tissue_examination': {
      'ar': 'فحص الأنسجة الرخوة',
      'en': 'Soft Tissue Examination'
    },
    'periodontal_chart': {'ar': 'جدول اللثة', 'en': 'Periodontal Chart'},
    'dental_chart': {'ar': 'جدول الأسنان', 'en': 'Dental Chart'},
    'search_hint': {
      'ar': 'ابحث بالاسم أو رقم الهاتف...',
      'en': 'Search by name or phone...'
    },
    'years': {'ar': 'سنة', 'en': 'years'},
    'months': {'ar': 'شهر', 'en': 'months'},
    'days': {'ar': 'يوم', 'en': 'days'},
    'age_unknown': {'ar': 'العمر غير معروف', 'en': 'Age unknown'},
    'unknown': {'ar': 'غير معروف', 'en': 'Unknown'},
    'no_number': {'ar': 'بدون رقم', 'en': 'No number'},
    'switch_to_arabic': {'ar': 'التبديل إلى العربية', 'en': 'Switch to Arabic'},
    'switch_to_english': {
      'ar': 'التبديل إلى الإنجليزية',
      'en': 'Switch to English'
    },
    'caries': {'ar': 'نخر', 'en': 'Caries'},
    'filled': {'ar': 'حشوة', 'en': 'Filled'},
    'root_canal': {'ar': 'معالجة لب', 'en': 'Root Canal'},
    'extraction_needed': {'ar': 'يحتاج خلع', 'en': 'Extraction Needed'},
    'crown': {'ar': 'تاج', 'en': 'Crown'},
    'impacted': {'ar': 'منطمر', 'en': 'Impacted'},
    'missing': {'ar': 'مفقود', 'en': 'Missing'},
    'delete_old_exams': {
      'ar': 'حذف الفحوصات القديمة',
      'en': 'Delete old exams'
    },
    'delete_confirmation': {
      'ar': 'هل تريد حذف الفحوصات القديمة؟',
      'en': 'Delete old examinations?'
    },
    'deleting': {'ar': 'جاري الحذف...', 'en': 'Deleting...'},
    'deleted_success': {
      'ar': 'تم حذف الفحوصات القديمة بنجاح',
      'en': 'Old exams deleted successfully'
    },
    'tooth': {'ar': 'سن', 'en': 'Tooth'},
    'delete_confirmation_message': {
      'ar': 'سيتم حذف جميع الفحوصات القديمة والاحتفاظ بأحدث فحص لكل مريض فقط.',
      'en':
          'All old examinations will be deleted, keeping only the latest exam for each patient.'
    },
  };

  @override
  void initState() {
    super.initState();
    _loadAllExaminations();
    _searchController.addListener(_filterExaminations);
    if (widget.studentName != null || widget.studentImageUrl != null) {
      setState(() {
        _doctorName = widget.studentName;
        _doctorImageUrl = widget.studentImageUrl;
        _userRole = 'dental_student';
      });
    } else {
      _loadDoctorSidebarInfo();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Move _getFullName and _translate above their first usage and ensure they are instance methods
  String _getFullName(Map<String, dynamic> patient) {
    return '${patient['firstName'] ?? ''} ${patient['fatherName'] ?? ''} ${patient['grandfatherName'] ?? ''} ${patient['familyName'] ?? ''}'.trim();
  }

  String _translate(BuildContext context, String key) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    return _translations[key]?[languageProvider.isEnglish ? 'en' : 'ar'] ?? key;
  }



  Future<Set<String>> _getAllowedPatientsForStudent(String studentId) async {
    final ref = FirebaseDatabase.instance.ref('student_patients/$studentId');
    final snapshot = await ref.get();
    final data = snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) {
      debugPrint('No allowed patients for student: $studentId');
      return {};
    }
    final allowed = data.keys.map((e) => e.toString()).toSet();
    debugPrint('Allowed patients for student $studentId: ${allowed.length} => $allowed');
    return allowed;
  }

  Future<void> _loadAllExaminations() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _examinedPatients = [];
      });

      // 1. جلب جميع الفحوصات من examinations (flat + nested)
      final DataSnapshot examinationsSnapshot = await _examinationsRef.get();
      final Map<String, dynamic> examinations = safeConvertMap(examinationsSnapshot.value);
      // 2. جلب جميع الفحوصات من doctorExaminations
      final DataSnapshot doctorExamsSnapshot = await FirebaseDatabase.instance.ref('examinations').get();
      final Map<String, dynamic> doctorExams = safeConvertMap(doctorExamsSnapshot.value);
      // 3. جلب جميع الفحوصات من examinations/examinations (legacy)
      final DataSnapshot legacyExamsSnapshot = await _examinationsRef.child('examinations').get();
      final Map<String, dynamic> legacyExams = safeConvertMap(legacyExamsSnapshot.value);

      // نجمع كل الفحوصات في قائمة واحدة (بدون أي deduplication)
      final List<Map<String, dynamic>> allExaminations = [];

      // Pass 1: nested examinations (examinations/{patientId}/examinations/)
      await Future.forEach(examinations.entries, (entry) async {
        final String parentKey = entry.key;
        final dynamic patientNode = entry.value;
        if (patientNode is Map && patientNode.containsKey('examinations')) {
          final Map<String, dynamic> patientExams = safeConvertMap(patientNode['examinations']);
          for (final examEntry in patientExams.entries) {
            final String examKey = examEntry.key;
            final examData = safeConvertMap(examEntry.value);
            // استخدم patientId من الفحص نفسه إذا وجد، وإلا استخدم parentKey
            final String patientId = examData['patientId']?.toString() ?? parentKey;
            DataSnapshot? patientSnapshot;
            Map<String, dynamic> patientData = {};
            try {
              patientSnapshot = await _patientsRef.child(patientId).get();
              if (patientSnapshot.exists) {
                patientData = safeConvertMap(patientSnapshot.value);
                patientData['id'] = patientId;
              } else {
                // debugPrint('Nested: patientId $patientId not found in users, will show as unknown');
                patientData = {'id': patientId, 'firstName': 'Unknown'};
              }
            } catch (e) {
              // debugPrint('Nested: error loading patientId $patientId: $e');
              patientData = {'id': patientId, 'firstName': 'Unknown'};
            }
            final String? doctorId = examData['doctorId']?.toString();
            // ignore: duplicate_ignore
            // ignore: use_build_context_synchronously
            Map<String, dynamic> doctorData = {'name': _translate(context, 'unknown')};
            if (doctorId != null && doctorId.isNotEmpty) {
              final DataSnapshot doctorSnapshot = await _doctorsRef.child(doctorId).get();
              if (doctorSnapshot.exists) {
                doctorData = safeConvertMap(doctorSnapshot.value);
                // ignore: use_build_context_synchronously
                doctorData['name'] = doctorData['fullName'] ?? _translate(context, 'unknown');
              }
            }
            allExaminations.add({
              'patient': patientData,
              'examination': examData,
              'doctor': doctorData,
              'examinationId': examKey,
              'source': 'nested',
            });
          }
        }
      });

      // Pass 2: flat examinations (examinations/{autoId})
      await Future.forEach(examinations.entries, (entry) async {
        final String key = entry.key;
        final dynamic value = entry.value;
        if (value is Map && value.containsKey('examinations')) {
          // debugPrint('Skip key $key: contains nested examinations');
          return;
        }
        final examData = safeConvertMap(value);
        final String? patientId = examData['patientId']?.toString();
        if (patientId == null || patientId.isEmpty) {
          // debugPrint('Skip key $key: missing patientId');
          return;
        }
        final DataSnapshot patientSnapshot = await _patientsRef.child(patientId).get();
        if (!mounted) return;
        if (!patientSnapshot.exists) {
          // debugPrint('Skip key $key: patientId $patientId not found in users');
          return;
        }
        final Map<String, dynamic> patientData = safeConvertMap(patientSnapshot.value);
        patientData['id'] = patientId;
        final String? doctorId = examData['doctorId']?.toString();
        Map<String, dynamic> doctorData = {'name': _translate(context, 'unknown')};
        if (doctorId != null && doctorId.isNotEmpty) {
          final DataSnapshot doctorSnapshot = await _doctorsRef.child(doctorId).get();
          if (!mounted) return;
          if (doctorSnapshot.exists) {
            doctorData = safeConvertMap(doctorSnapshot.value);
            doctorData['name'] = doctorData['fullName'] ?? _translate(context, 'unknown');
          }
        }
        allExaminations.add({
          'patient': patientData,
          'examination': examData,
          'doctor': doctorData,
          'examinationId': key,
          'source': 'flat',
        });
      });

      // Pass 3: doctorExaminations/{examId}
      await Future.forEach(doctorExams.entries, (entry) async {
        final String examKey = entry.key;
        final examData = safeConvertMap(entry.value);
        final String? patientId = examData['patientId']?.toString();
        if (patientId == null || patientId.isEmpty) return;
        final DataSnapshot patientSnapshot = await _patientsRef.child(patientId).get();
        if (!mounted) return;
        if (!patientSnapshot.exists) return;
        final Map<String, dynamic> patientData = safeConvertMap(patientSnapshot.value);
        patientData['id'] = patientId;
        final String? doctorId = examData['doctorId']?.toString();
        Map<String, dynamic> doctorData = {'name': _translate(context, 'unknown')};
        if (doctorId != null && doctorId.isNotEmpty) {
          final DataSnapshot doctorSnapshot = await _doctorsRef.child(doctorId).get();
          if (!mounted) return;
          if (doctorSnapshot.exists) {
            doctorData = safeConvertMap(doctorSnapshot.value);
            doctorData['name'] = doctorData['fullName'] ?? _translate(context, 'unknown');
          }
        }
        allExaminations.add({
          'patient': patientData,
          'examination': examData,
          'doctor': doctorData,
          'examinationId': examKey,
          'source': 'doctorExaminations',
        });
      });

      // Pass 4: legacy examinations (examinations/examinations/{examId})
      await Future.forEach(legacyExams.entries, (entry) async {
        final String examKey = entry.key;
        final examData = safeConvertMap(entry.value);
        final String? patientId = examData['patientId']?.toString();
        if (patientId == null || patientId.isEmpty) return;
        final DataSnapshot patientSnapshot = await _patientsRef.child(patientId).get();
        if (!mounted) return;
        if (!patientSnapshot.exists) return;
        final Map<String, dynamic> patientData = safeConvertMap(patientSnapshot.value);
        patientData['id'] = patientId;
        final String? doctorId = examData['doctorId']?.toString();
        Map<String, dynamic> doctorData = {'name': _translate(context, 'unknown')};
        if (doctorId != null && doctorId.isNotEmpty) {
          final DataSnapshot doctorSnapshot = await _doctorsRef.child(doctorId).get();
          if (!mounted) return;
          if (doctorSnapshot.exists) {
            doctorData = safeConvertMap(doctorSnapshot.value);
            doctorData['name'] = doctorData['fullName'] ?? _translate(context, 'unknown');
          }
        }
        allExaminations.add({
          'patient': patientData,
          'examination': examData,
          'doctor': doctorData,
          'examinationId': examKey,
          'source': 'legacy',
        });
      });

      // ترتيب النتائج حسب التاريخ
      allExaminations.sort((a, b) {
        final aTime = a['examination']['timestamp'] ?? 0;
        final bTime = b['examination']['timestamp'] ?? 0;
        return bTime.compareTo(aTime);
      });

      // إزالة الدوبليكيت: الاحتفاظ بأحدث فحص فقط لكل مريض
      final Map<String, Map<String, dynamic>> latestExamsByPatient = {};
      for (final exam in allExaminations) {
        final patientId = exam['patient']?['id']?.toString();
        if (patientId == null || patientId.isEmpty) continue;
        final timestamp = exam['examination']?['timestamp'] ?? 0;
        if (!latestExamsByPatient.containsKey(patientId) ||
            (timestamp > (latestExamsByPatient[patientId]?['examination']?['timestamp'] ?? 0))) {
          latestExamsByPatient[patientId] = exam;
        }
      }
      List<Map<String, dynamic>> deduplicatedExaminations = latestExamsByPatient.values.toList();
      deduplicatedExaminations.sort((a, b) {
        final aTime = a['examination']['timestamp'] ?? 0;
        final bTime = b['examination']['timestamp'] ?? 0;
        return bTime.compareTo(aTime);
      });

      // فلترة حسب صلاحيات الطالب
      if (_userRole == 'dental_student') {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final allowedPatients = await _getAllowedPatientsForStudent(user.uid);
          deduplicatedExaminations = deduplicatedExaminations.where((exam) {
            final patientId = exam['patient']?['id']?.toString();
            return patientId != null && allowedPatients.contains(patientId);
          }).toList();
        }
      }

      setState(() {
        _examinedPatients = deduplicatedExaminations;
        _filteredExaminations = List.from(deduplicatedExaminations);
        _isLoading = false;
      });
    } catch (e) {
      // debugPrint('Error loading examinations: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _filterExaminations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredExaminations = _examinedPatients.where((exam) {
        final patient = exam['patient'] as Map<String, dynamic>;
        final fullName = _getFullName(patient).toLowerCase();
        final phone = patient['phone']?.toString().toLowerCase() ?? '';
        return fullName.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  Widget _buildPatientCard(
      Map<String, dynamic> patientExam, BuildContext context) {
    final patient = safeConvertMap(patientExam['patient']);
    final exam = safeConvertMap(patientExam['examination']);
    final doctor = safeConvertMap(patientExam['doctor']);

    final fullName = _getFullName(patient);
    final phone = patient['phone'] ?? _translate(context, 'no_number');
    final age = _calculateAge(context, patient['birthDate']);
    final examDate = exam['timestamp'] != null
        ? DateFormat('yyyy-MM-dd HH:mm')
            .format(DateTime.fromMillisecondsSinceEpoch(exam['timestamp']))
        : _translate(context, 'unknown');

    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        elevation: 2,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderColor, width: 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showPatientDetails(context, patientExam),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        fullName.isNotEmpty
                            ? fullName
                            : _translate(context, 'unknown'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        size: 16, color: textSecondary),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                    Icons.person, '${_translate(context, 'age')}: $age'),
                _buildInfoRow(
                    Icons.phone, '${_translate(context, 'phone')}: $phone'),
                _buildInfoRow(Icons.calendar_today,
                    '${_translate(context, 'examination_date')}: $examDate'),
                _buildInfoRow(Icons.medical_services,
                    '${_translate(context, 'examining_doctor')}: ${doctor['name']}'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  void _showPatientDetails(
      BuildContext context, Map<String, dynamic> patientExam) {
    final patient = safeConvertMap(patientExam['patient']);
    final exam = safeConvertMap(patientExam['examination']);
    final doctor = safeConvertMap(patientExam['doctor']);
    final examData = safeConvertMap(exam['examData'] ?? exam['examData'] ?? {});
    final screeningData = safeConvertMap(exam['screening'] ?? exam['screening'] ?? {});

    final fullName = _getFullName(patient);
    final examDate = (exam['timestamp'] != null && exam['timestamp'] is int)
        ? DateFormat('yyyy-MM-dd HH:mm')
            .format(DateTime.fromMillisecondsSinceEpoch(exam['timestamp'] as int))
        : _translate(context, 'unknown');

    const Color primaryColor = Color(0xFF2A7A94);
    const Color accentColor = Color(0xFF4AB8D8);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: true, // إظهار سهم الرجوع
            title: Text(
              _translate(context, 'examination_details'),
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: primaryColor,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 2,
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                tooltip: 'تصدير PDF',
                onPressed: () async {
                  await _exportPatientReportAsPdf(context, patientExam);
                },
              ),
            ],
          ),
          backgroundColor: backgroundColor,
          drawer: (_userRole == 'dental_student'
              ? StudentSidebar(
                  studentName: _doctorName,
                  studentImageUrl: _doctorImageUrl,
                )
              : DoctorSidebar(
                  primaryColor: primaryColor,
                  accentColor: accentColor,
                  userName: _doctorName ?? '',
                  userImageUrl: _doctorImageUrl,
                  translate: (ctx, key) => key,
                  parentContext: context,
                  doctorUid: FirebaseAuth.instance.currentUser?.uid ?? '',
                )),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailSection(
                  title: _translate(context, 'patient_information'),
                  children: [
                    _buildDetailItem(_translate(context, 'name'), fullName),
                    _buildDetailItem(_translate(context, 'age'),
                        _calculateAge(context, patient['birthDate'])),
                    _buildDetailItem(_translate(context, 'gender'),
                        (patient['gender'] ?? _translate(context, 'unknown')).toString()),
                    _buildDetailItem(_translate(context, 'phone'),
                        (patient['phone'] ?? _translate(context, 'no_number')).toString()),
                  ],
                ),
                _buildDetailSection(
                  title: _translate(context, 'examination_information'),
                  children: [
                    _buildDetailItem(_translate(context, 'examining_doctor'),
                        (doctor['name'] ?? _translate(context, 'unknown')).toString()),
                    _buildDetailItem(
                        _translate(context, 'examination_date'), examDate),
                  ],
                ),
                if (screeningData.isNotEmpty)
                  _buildDetailSection(
                    title: 'Screening Form',
                    children: _buildScreeningDetails(screeningData),
                  ),
                if (examData.isNotEmpty) ...[
                  _buildDetailSection(
                    title: _translate(context, 'extraoral_examination'),
                    children: [
                      _buildDetailItem(
                          'TMJ', (examData['tmj'] ?? 'N/A').toString()),
                      _buildDetailItem('Lymph Node',
                          (examData['lymphNode'] ?? 'N/A').toString()),
                      _buildDetailItem('Patient Profile',
                          (examData['patientProfile'] ?? 'N/A').toString()),
                      _buildDetailItem('Lip Competency',
                          (examData['lipCompetency'] ?? 'N/A').toString()),
                    ],
                  ),
                  _buildDetailSection(
                    title: _translate(context, 'intraoral_examination'),
                    children: [
                      _buildDetailItem(
                          'Incisal Classification',
                          (examData['incisalClassification'] ?? 'N/A').toString()),
                      _buildDetailItem(
                          'Overjet', (examData['overjet'] ?? 'N/A').toString()),
                      _buildDetailItem('Overbite',
                          (examData['overbite'] ?? 'N/A').toString()),
                    ],
                  ),
                  _buildDetailSection(
                    title: _translate(context, 'soft_tissue_examination'),
                    children: [
                      _buildDetailItem('Hard Palate',
                          (examData['hardPalate'] ?? 'N/A').toString()),
                      _buildDetailItem('Buccal Mucosa',
                          (examData['buccalMucosa'] ?? 'N/A').toString()),
                      _buildDetailItem('Floor of Mouth',
                          (examData['floorOfMouth'] ?? 'N/A').toString()),
                      _buildDetailItem('Edentulous Ridge',
                          (examData['edentulousRidge'] ?? 'N/A').toString()),
                    ],
                  ),
                  if (examData['periodontalChart'] != null &&
                      examData['periodontalChart'] is Map)
                    _buildDetailSection(
                      title: _translate(context, 'periodontal_chart'),
                      children: _buildPeriodontalDetails(
                          safeConvertMap(examData['periodontalChart'])),
                    ),
                  if (examData['dentalChart'] != null &&
                      examData['dentalChart'] is Map)
                    _buildDetailSection(
                      title: _translate(context, 'dental_chart'),
                      children: _buildDentalChartDetails(
                          safeConvertMap(examData['dentalChart']), context),
                    ),
                ],
                // إضافة جدول clinical procedures قبل صورة الأشعة
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getClinicalProceduresForPatient(patient['id']?.toString()),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final procedures = snapshot.data;
                    if (procedures == null || procedures.isEmpty) {
                      return const Card(
                        margin: EdgeInsets.all(16),
                        color: cardColor,
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('لا توجد إجراءات سريرية مسجلة لهذا المريض', style: TextStyle(color: errorColor)),
                        ),
                      );
                    }
                    return SizedBox(
                      width: double.infinity,
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                        color: cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: borderColor, width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Clinical Procedures', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 12),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Date')),
                                    DataColumn(label: Text('Type')),
                                    DataColumn(label: Text('Tooth No.')),
                                    DataColumn(label: Text('Clinic')),
                                    DataColumn(label: Text('Student')),
                                    DataColumn(label: Text('Supervisor')),
                                    DataColumn(label: Text('Second Visit')),
                                  ],
                                  rows: procedures.map((proc) => DataRow(cells: [
                                    DataCell(Text(proc['dateOfOperation'] ?? '')),
                                    DataCell(Text(proc['typeOfOperation'] ?? '')),
                                    DataCell(Text(proc['toothNo'] ?? '')),
                                    DataCell(Text(proc['clinicName'] ?? '')),
                                    DataCell(Text(proc['studentName'] ?? '')),
                                    DataCell(Text(proc['supervisorName'] ?? '')),
                                    DataCell(Text(proc['dateOfSecondVisit'] ?? '')),
                                  ])).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // إضافة كارد صورة الأشعة بعد جدول الإجراءات
                _buildXrayImageCard(patientExam, context),
  // دالة لجلب جميع الإجراءات السريرية للمريض من قاعدة البيانات
 ],
            ),
          ),
        ),
      ),
    );
  }

  // دالة تتحقق إذا كان النص عربي
  bool _isArabicText(String text) {
    final arabicRegExp = RegExp(r'[\u0600-\u06FF]');
    return arabicRegExp.hasMatch(text);
  }

  // دالة تولد عنصر نصي مع اتجاه مناسب (تدعم العربي داخل LTR)
  pw.Widget _smartText(String text, pw.TextStyle style) {
    if (_isArabicText(text)) {
      return pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Text(text, style: style),
      );
    } else {
      return pw.Text(text, style: style);
    }
  }

  // دالة تولد Bullet مع اتجاه مناسب (تدعم العربي داخل LTR)

  Future<void> _exportPatientReportAsPdf(BuildContext context, Map<String, dynamic> patientExam) async {
    final patient = safeConvertMap(patientExam['patient']);
    final exam = safeConvertMap(patientExam['examination']);
    final doctor = safeConvertMap(patientExam['doctor']);
    final examData = safeConvertMap(exam['examData'] ?? exam['examData'] ?? {});
    final screeningData = safeConvertMap(exam['screening'] ?? exam['screening'] ?? {});
    final fullName = _getFullName(patient);
    final doctorName = (doctor['name'] ?? '').toString();
    final examDate = (exam['timestamp'] != null && exam['timestamp'] is int)
        ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(exam['timestamp'] as int))
        : _translate(context, 'unknown');
    final pdf = pw.Document();
    final dentalChart = safeConvertMap(examData['dentalChart']);
    final isArabic = !Provider.of<LanguageProvider>(context, listen: false).isEnglish;

    // جلب الإجراءات السريرية
    final clinicalProcedures = await _getClinicalProceduresForPatient(patient['id']?.toString());

    // تحميل خط عربي من المسار الصحيح
    final fontData = await rootBundle.load('assets/Cairo-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);

    // تحميل صورة اللوجو من الأصول
    final logoData = await rootBundle.load('/Users/macbook/Downloads/Senior-main/lib/assets/aauplogo.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    pw.TextStyle style([double size = 14, bool bold = false]) => pw.TextStyle(
      font: ttf,
      fontSize: size,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

    // استخراج corrected_class من بيانات الأشعة
    List<String> xrayCorrectedClasses = [];
    if (exam['xrayImageData'] != null && exam['xrayImageData'] is Map) {
      final xrayData = Map<String, dynamic>.from(exam['xrayImageData']);
      final analysisResult = xrayData['analysisResultJson'];
      if (analysisResult != null && analysisResult is Map && analysisResult['detections'] is List) {
        xrayCorrectedClasses = (analysisResult['detections'] as List)
            .where((d) => d is Map && d['corrected_class'] != null)
            .map<String>((d) => d['corrected_class'].toString())
            .toList();
      }
    }

    pdf.addPage(
      pw.MultiPage(
        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        header: (pw.Context ctx) => pw.Center(
          child: pw.Image(logoImage, width: 160, height: 160, fit: pw.BoxFit.contain),
        ),
        footer: (pw.Context ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            '${isArabic ? 'صفحة' : 'Page'} ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: style(12),
          ),
        ),
        build: (pw.Context ctx) => [
          pw.Center(
            child: _smartText(
              isArabic ? 'تقرير فحص المريض' : 'Patient Examination Report',
              style(28, true),
            ),
          ),
          pw.SizedBox(height: 8),
          if (xrayCorrectedClasses.isNotEmpty)
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _smartText(isArabic ? 'الأسنان المكتشفة من صورة الأشعة:' : 'Detected Teeth from X-ray:', style(16, true)),
                  pw.SizedBox(height: 4),
                  for (final c in xrayCorrectedClasses)
                    _smartText(c, style()),
                ],
              ),
            ),
          _smartText(isArabic ? 'معلومات المريض:' : 'Patient Information:', style(20, true)),
          _smartText('${isArabic ? 'الاسم' : 'Name'}: $fullName', style()),
          _smartText('${isArabic ? 'العمر' : 'Age'}: ${_calculateAge(context, patient['birthDate'])}', style()),
          _smartText('${isArabic ? 'الجنس' : 'Gender'}: ${(patient['gender'] ?? _translate(context, 'unknown')).toString()}', style()),
          _smartText('${isArabic ? 'الهاتف' : 'Phone'}: ${(patient['phone'] ?? _translate(context, 'no_number')).toString()}', style()),
          pw.SizedBox(height: 8),
          _smartText(isArabic ? 'معلومات الفحوصات:' : 'Examination Information:', style(20, true)),
          _smartText('${isArabic ? 'الطبيب المختص' : 'Doctor'}: $doctorName', style()),
          _smartText('${isArabic ? 'تاريخ الفحص' : 'Examination Date'}: $examDate', style()),
          pw.SizedBox(height: 8),
          if (screeningData.isNotEmpty) ...[
            _smartText(isArabic ? 'نموذج التقييم الأولي:' : 'Screening Form:', style(18, true)),
            if (screeningData['chiefComplaint'] != null)
              _smartText('${isArabic ? 'الشكوى الرئيسية' : 'Chief Complaint'}: ${screeningData['chiefComplaint']}', style()),
            if (screeningData['medications'] != null)
              _smartText('${isArabic ? 'الأدوية' : 'Medications'}: ${screeningData['medications']}', style()),
            if (screeningData['positiveAnswersExplanation'] != null)
              _smartText('${isArabic ? 'توضيح الإجابات الإيجابية' : 'Positive Answers Explanation'}: ${screeningData['positiveAnswersExplanation']}', style()),
            if (screeningData['preventiveAdvice'] != null)
              _smartText('${isArabic ? 'النصائح الوقائية' : 'Preventive Advice'}: ${screeningData['preventiveAdvice']}', style()),
            if (screeningData['categories'] != null && screeningData['categories'] is List) ...[
              _smartText(isArabic ? 'تقييم صحة الفم:' : 'Oral Health Assessment:', style(16, true)),
              for (final category in screeningData['categories'])
                if (category is Map && category.containsKey('name') && category.containsKey('score'))
                  _smartText('${category['name']}: ${category['score']}', style()),
            ],
            if (screeningData['totalScore'] != null)
              _smartText('${isArabic ? 'المجموع الكلي' : 'Total Score'}: ${screeningData['totalScore']}', style(16, true)),
          ],
          if (examData.isNotEmpty) ...[
            _smartText(isArabic ? 'تفاصيل الفحص السريري:' : 'Clinical Examination Details:', style(18, true)),
            _smartText('TMJ: ${(examData['tmj'] ?? 'N/A').toString()}', style()),
            _smartText('${isArabic ? 'العقد اللمفاوية' : 'Lymph Node'}: ${(examData['lymphNode'] ?? 'N/A').toString()}', style()),
            _smartText('${isArabic ? 'ملف المريض' : 'Patient Profile'}: ${(examData['patientProfile'] ?? 'N/A').toString()}', style()),
            _smartText('${isArabic ? 'انطباق الشفاه' : 'Lip Competency'}: ${(examData['lipCompetency'] ?? 'N/A').toString()}', style()),
            _smartText('${isArabic ? 'تصنيف القواطع' : 'Incisal Classification'}: ${(examData['incisalClassification'] ?? 'N/A').toString()}', style()),
            _smartText('${isArabic ? 'تراكب أمامي' : 'Overjet'}: ${(examData['overjet'] ?? 'N/A').toString()}', style()),
            _smartText('${isArabic ? 'تراكب عمودي' : 'Overbite'}: ${(examData['overbite'] ?? 'N/A').toString()}', style()),
            _smartText('${isArabic ? 'الحنك الصلب' : 'Hard Palate'}: ${(examData['hardPalate'] ?? 'N/A').toString()}', style()),
            _smartText('${isArabic ? 'الغشاء المخاطي الشدقي' : 'Buccal Mucosa'}: ${(examData['buccalMucosa'] ?? 'N/A').toString()}', style()),
            _smartText('${isArabic ? 'أرضية الفم' : 'Floor of Mouth'}: ${(examData['floorOfMouth'] ?? 'N/A').toString()}', style()),
            _smartText('${isArabic ? 'الحافة عديمة الأسنان' : 'Edentulous Ridge'}: ${(examData['edentulousRidge'] ?? 'N/A').toString()}', style()),
            if (examData['periodontalChart'] != null && examData['periodontalChart'] is Map) ...[
              _smartText(isArabic ? 'جدول اللثة:' : 'Periodontal Chart:', style(16, true)),
              for (final entry in safeConvertMap(examData['periodontalChart']).entries)
                _smartText('${entry.key}: ${entry.value}', style()),
            ],
            if (examData['dentalChart'] != null && examData['dentalChart'] is Map) ...[
              _smartText(isArabic ? 'جدول الأسنان:' : 'Dental Chart:', style(16, true)),
              if (dentalChart['selectedTeeth'] != null && dentalChart['selectedTeeth'] is List)
                _smartText('${isArabic ? 'الأسنان المختارة' : 'Selected Teeth'}: ${(dentalChart['selectedTeeth'] as List).join(", ")}', style()),
              if (dentalChart['teethConditions'] != null && dentalChart['teethConditions'] is Map) ...[
                for (final entry in safeConvertMap(dentalChart['teethConditions']).entries)
                  _smartText('${isArabic ? 'سن' : 'Tooth'} ${entry.key} - ${entry.value}', style()),
              ],
            ],
          ],
          if (clinicalProcedures.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _smartText(isArabic ? 'الإجراءات السريرية:' : 'Clinical Procedures:', style(18, true)),
            pw.Table(
              border: pw.TableBorder.all(),
              defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
              children: [
            pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(isArabic ? 'التاريخ' : 'Date', style: style(12, true))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(isArabic ? 'النوع' : 'Type', style: style(12, true))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(isArabic ? 'رقم السن' : 'Tooth No.', style: style(12, true))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(isArabic ? 'العيادة' : 'Clinic', style: style(12, true))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(isArabic ? 'الطالب' : 'Student', style: style(12, true))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(isArabic ? 'المشرف' : 'Supervisor', style: style(12, true))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(isArabic ? 'زيارة ثانية' : 'Second Visit', style: style(12, true))),
              ],
            ),
            ...clinicalProcedures.map((proc) => pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(proc['dateOfOperation']?.toString() ?? '', style: style(12))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(proc['typeOfOperation']?.toString() ?? '', style: style(12))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(proc['toothNo']?.toString() ?? '', style: style(12))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(proc['clinicName']?.toString() ?? '', style: style(12))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: _smartText(proc['studentName']?.toString() ?? '', style(12))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: _smartText(proc['supervisorName']?.toString() ?? '', style(12))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(proc['dateOfSecondVisit']?.toString() ?? '', style: style(12))),
              ],
            )),
              ],
            ),
          ],
        ],
      ),
    );
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Patient_Report_${fullName.replaceAll(' ', '_')}.pdf',
    );
  }

  // كاش مؤقت لصور الأشعة

  // جلب صورة الأشعة وبيانات التحليل من xray_images حسب patientId أو idNumber

  // كارد صورة الأشعة (يبحث في xray_images)
  Widget _buildXrayImageCard(Map<String, dynamic> patientExam, BuildContext context) {
    final patient = safeConvertMap(patientExam['patient']);
    final String? patientId = patient['id']?.toString();
    final String? idNumber = patient['idNumber']?.toString();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getAllXrayImagesForPatient(patientId, idNumber),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final images = snapshot.data;
        if (images == null || images.isEmpty) {
          return const Card(
            margin: EdgeInsets.all(16),
            color: cardColor,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('لا توجد صور أشعة متوفرة', style: TextStyle(color: errorColor)),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: images.map((img) {
                final String? xrayBase64 = img['xrayImage'];
                final dynamic analysisResult = img['analysisResultJson'];
                final String? type = img['type']?.toString();
                final int? timestamp = img['timestamp'] is int ? img['timestamp'] : int.tryParse(img['timestamp']?.toString() ?? '');
                String dateStr = '';
                if (timestamp != null && timestamp > 0) {
                  dateStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(timestamp));
                }
                List<Widget> formattedDetections = [];
                if (analysisResult != null && analysisResult is Map && analysisResult['detections'] is List) {
                  for (final d in analysisResult['detections']) {
                    if (d is Map && d['corrected_class'] != null) {
                      String label = d['corrected_class'].toString();
                      if (label.contains('_')) {
                        final parts = label.split('_');
                        for (int i = 0; i < parts.length; i++) {
                          if (parts[i].startsWith('Q')) parts[i] = parts[i].substring(1);
                          if (parts[i].startsWith('T')) parts[i] = parts[i].substring(1);
                        }
                        if (parts.length >= 2 && int.tryParse(parts[0]) != null && int.tryParse(parts[1]) != null) {
                          label = parts[0] + parts[1];
                          if (parts.length > 2) {
                            label += '_${parts.sublist(2).join('_')}';
                          }
                        } else {
                          label = parts.join('_');
                        }
                      }
                      double? confidence;
                      if (d['confidence'] != null) {
                        try {
                          confidence = double.tryParse(d['confidence'].toString());
                        } catch (_) {}
                      } else if (d['score'] != null) {
                        try {
                          confidence = double.tryParse(d['score'].toString());
                        } catch (_) {}
                      }
                      Color badgeColor = Colors.grey;
                      if (confidence != null) {
                        if (confidence < 0.5) {
                          badgeColor = Colors.red;
                        } else if (confidence < 0.75) {
                          badgeColor = Colors.amber;
                        } else {
                          badgeColor = Colors.green;
                        }
                      }
                      String percent = confidence != null ? ' (${(confidence * 100).toStringAsFixed(0)}%)' : '';
                      formattedDetections.add(
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label + percent,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }
                  }
                }
                Widget imageWidget;
                try {
                  final bytes = base64Decode(xrayBase64 ?? '');
                  imageWidget = GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return Dialog(
                            backgroundColor: Colors.transparent,
                            child: InteractiveViewer(
                              minScale: 0.5,
                              maxScale: 5,
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth: isWide ? 700 : double.infinity,
                                  maxHeight: isWide ? 700 : double.infinity,
                                ),
                                child: Image.memory(bytes, fit: BoxFit.contain),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    child: Container(
                      width: isWide ? 350 : double.infinity,
                      height: isWide ? 220 : 220,
                      alignment: Alignment.center,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(bytes, fit: BoxFit.cover, width: isWide ? 350 : double.infinity, height: 220),
                      ),
                    ),
                  );
                } catch (e) {
                  imageWidget = const Text('تعذر عرض صورة الأشعة', style: TextStyle(color: errorColor));
                }
                return Card(
                  margin: const EdgeInsets.all(16),
                  color: cardColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                "صور الأشعة",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            imageWidget,
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            if (type != null && type.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('نوع الصورة: $type', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            if (dateStr.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('وقت الإضافة: $dateStr', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ),
                      if (formattedDetections.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('لا توجد نتائج كشف من صورة الأشعة'),
                        ),
                      if (formattedDetections.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('الأسنان المكتشفة من صورة الأشعة:', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Wrap(
                                children: formattedDetections,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  // دالة جديدة لجلب جميع صور الأشعة للمريض
  Future<List<Map<String, dynamic>>> _getAllXrayImagesForPatient(String? patientId, String? idNumber) async {
    final ref = FirebaseDatabase.instance.ref('xray_images');
    final snapshot = await ref.get();
    if (!snapshot.exists) return [];
    final data = snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) return [];
    final List<Map<String, dynamic>> images = [];
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is Map<dynamic, dynamic>) {
        final map = Map<String, dynamic>.from(value);
        if ((patientId != null && map['patientId']?.toString() == patientId) ||
            (idNumber != null && map['idNumber']?.toString() == idNumber)) {
          images.add({
            'xrayImage': map['originalXrayImage']?.toString() ?? map['xrayImage']?.toString(),
            'analysisResultJson': map['analysisResultJson'],
            'type': map['type'],
            'timestamp': map['timestamp'],
          });
        }
      }
    }
    // ترتيب الصور من الأحدث إلى الأقدم حسب الوقت
    images.sort((a, b) {
      final aTime = a['timestamp'] is int ? a['timestamp'] : int.tryParse(a['timestamp']?.toString() ?? '') ?? 0;
      final bTime = b['timestamp'] is int ? b['timestamp'] : int.tryParse(b['timestamp']?.toString() ?? '') ?? 0;
      return bTime.compareTo(aTime);
    });
    return images;
  }

  String _calculateAge(BuildContext context, dynamic birthDateValue) {
    if (birthDateValue == null) return _translate(context, 'age_unknown');
    final int timestamp;
    if (birthDateValue is String) {
      timestamp = int.tryParse(birthDateValue) ?? 0;
    } else if (birthDateValue is int) {
      timestamp = birthDateValue;
    } else {
      timestamp = 0;
    }
    if (timestamp <= 0) return _translate(context, 'age_unknown');
    final birthDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    if (birthDate.isAfter(now)) return _translate(context, 'age_unknown');
    final age = now.difference(birthDate);
    final years = age.inDays ~/ 365;
    final months = (age.inDays % 365) ~/ 30;
    final days = (age.inDays % 365) % 30;
    if (years > 0) {
      return '$years ${_translate(context, 'years')}';
    } else if (months > 0) {
      return '$months ${_translate(context, 'months')}';
    } else {
      return '$days ${_translate(context, 'days')}';
    }
  }

  Future<void> _loadDoctorSidebarInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot = await _patientsRef.child(user.uid).get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final role = data['role']?.toString() ?? data['type']?.toString();
      final firstName = data['firstName']?.toString().trim() ?? '';
      final fatherName = data['fatherName']?.toString().trim() ?? '';
      final grandfatherName = data['grandfatherName']?.toString().trim() ?? '';
      final familyName = data['familyName']?.toString().trim() ?? '';
      final fullName = [firstName, fatherName, grandfatherName, familyName].where((e) => e.isNotEmpty).join(' ');
      if (role == 'dental_student') {
        final imageUrl = data['imageUrl']?.toString() ?? '';
        setState(() {
          _doctorName = fullName.isNotEmpty ? fullName : 'الطالب';
          _doctorImageUrl = imageUrl.isNotEmpty ? imageUrl : null;
          _userRole = role;
        });
      } else {
        final imageData = data['image']?.toString() ?? '';
        setState(() {
          _doctorName = fullName.isNotEmpty ? fullName : null;
          _doctorImageUrl = imageData.isNotEmpty ? 'data:image/jpeg;base64,$imageData' : null;
          _userRole = role;
        });
      }
    } else {
      setState(() {
        _doctorName = null;
        _doctorImageUrl = null;
        _userRole = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Removed unused languageProvider variable
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _translate(context, 'examined_patients'),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAllExaminations,
            tooltip: _translate(context, 'retry'),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      drawer: (_userRole == 'dental_student'
          ? StudentSidebar(
              studentName: _doctorName,
              studentImageUrl: _doctorImageUrl,
            )
          : DoctorSidebar(
              primaryColor: primaryColor,
              accentColor: const Color(0xFF4AB8D8),
              userName: _doctorName ?? '',
              userImageUrl: _doctorImageUrl,
              translate: (ctx, key) => key,
              parentContext: context,
              doctorUid: FirebaseAuth.instance.currentUser?.uid ?? '',
            )),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _translate(context, 'error_loading'),
                        style: const TextStyle(color: errorColor, fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAllExaminations,
                        child: Text(_translate(context, 'retry')),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: _translate(context, 'search_hint'),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _filteredExaminations.length,
                          itemBuilder: (context, index) {
                            final patientExam = _filteredExaminations[index];
                            return _buildPatientCard(patientExam, context);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required List<dynamic> children, // <-- تغيير النوع لدعم List<List<Widget>>
  }) {
    final isScreening = title == 'Screening Form' || title == _translate(context, 'screening_form');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      width: double.infinity,
      constraints: isScreening ? const BoxConstraints(minHeight: 320) : null,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 18),
          if (isScreening && children.length == 2)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children[0] as List<Widget>,
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children[1] as List<Widget>,
                  ),
                ),
              ],
            )
          else ...children.cast<Widget>(),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF666666),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<List<Widget>> _buildScreeningDetails(Map<String, dynamic> screening) {
    final List<Widget> general = [];
    final List<Widget> oral = [];
    void addGeneral(String label, dynamic value) {
      if (value != null && value.toString().isNotEmpty) {
        general.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('$label: ${value.toString()}'),
        ));
      }
    }
    // Removed unused addOral function
    addGeneral('Chief Complaint', screening['chiefComplaint']);
    addGeneral('Medications', screening['medications']);
    addGeneral('Positive Answers Explanation', screening['positiveAnswersExplanation']);
    addGeneral('Preventive Advice', screening['preventiveAdvice']);
    if (screening['categories'] != null && screening['categories'] is List) {
      oral.add(const Text('Oral Health Assessment:', style: TextStyle(fontWeight: FontWeight.bold)));
      for (final category in screening['categories']) {
        if (category is Map && category.containsKey('name') && category.containsKey('score')) {
          oral.add(Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${category['name']}: ${category['score']}'),
          ));
        }
      }
    }
    if (screening['totalScore'] != null && screening['totalScore'].toString().isNotEmpty) {
      oral.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('Total Score: ${screening['totalScore']}', style: const TextStyle(fontWeight: FontWeight.bold)),
      ));
    }
    return [general, oral];
  }

  List<Widget> _buildPeriodontalDetails(Map<String, dynamic> chart) {
    return chart.entries.map((entry) {
      return Text('${entry.key}: ${entry.value.toString()}');
    }).toList();
  }

  List<Widget> _buildDentalChartDetails(Map<String, dynamic> chart, BuildContext context) {
    final List<Widget> widgets = [];
    final Map<String, dynamic> conditions = (chart['teethConditions'] is Map)
        ? safeConvertMap(chart['teethConditions'])
        : {};
    if (conditions.isNotEmpty) {
      widgets.add(const Text('Teeth Conditions:'));
      conditions.forEach((tooth, disease) {
        if (disease is String && disease.isNotEmpty) {
          widgets.add(Text('Tooth $tooth - $disease'));
        } else {
          widgets.add(Text('Tooth $tooth - No condition'));
        }
      });
    } else if (chart['selectedTeeth'] is List && (chart['selectedTeeth'] as List).isNotEmpty) {
      final List selectedTeeth = chart['selectedTeeth'] as List;
      widgets.add(Text('Selected Teeth: ${selectedTeeth.join(", ")}'));
      for (final tooth in selectedTeeth) {
        widgets.add(Text('Tooth $tooth - No condition'));
      }
    }
    return widgets;
  }
}