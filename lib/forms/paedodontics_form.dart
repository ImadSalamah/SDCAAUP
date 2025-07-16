// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaedodonticsForm extends StatefulWidget {
  final String groupId;
  final int caseNumber;
  final Map<String, dynamic> patient;
  final String? courseId;
  final Function(int? doctorGrade)? onSave;
  final String? caseType;
  final Map<String, dynamic>? initialData;

  const PaedodonticsForm({
    super.key,
    required this.groupId,
    required this.caseNumber,
    required this.patient,
    this.courseId,
    this.onSave,
    this.caseType,
    this.initialData,
  });

  @override
  State<PaedodonticsForm> createState() => _PaedodonticsFormState();
}

class _PaedodonticsFormState extends State<PaedodonticsForm> {
  bool isSubmitting = false;
  String? lastSubmittedCaseKey;
  String? lastCaseStatus;
  int? lastCaseMark;
  String? lastDoctorComment;

  String guardianName = '';
  String patientAddress = '';
  String patientPhone = '';
  String? diagnosis = '';

  final _formKey = GlobalKey<FormState>();

  final TextEditingController guardianNameController = TextEditingController();
  final TextEditingController patientAddressController = TextEditingController();
  final TextEditingController patientPhoneController = TextEditingController();
  final TextEditingController diagnosisController = TextEditingController();
  final TextEditingController _doctorMarkController = TextEditingController();
  final TextEditingController _doctorNoteController = TextEditingController();

  // New controllers and variables for additional fields
  final TextEditingController chiefComplaintController = TextEditingController();
  final TextEditingController historyOfComplaintController = TextEditingController();
  final TextEditingController dentalHistoryController = TextEditingController();
  final TextEditingController socialHistoryController = TextEditingController();
  final TextEditingController extraOralExamController = TextEditingController();
  final TextEditingController intraOralSoftTissueController = TextEditingController();
  final TextEditingController plaqueIndexController = TextEditingController();
  
  final TextEditingController radiographsFindingsController = TextEditingController();
  // Controllers for new fields
  final TextEditingController crossbiteController = TextEditingController();
  final TextEditingController oralHabitsController = TextEditingController();
  // Controllers for missing fields
  final TextEditingController overjetController = TextEditingController();
  final TextEditingController overbiteController = TextEditingController();
  final TextEditingController radiographicCariesController = TextEditingController();
  final TextEditingController radiographicSupernumerariesController = TextEditingController();
  final TextEditingController radiographicMissingTeethController = TextEditingController();
  final TextEditingController radiographicPeriapicalLesionsController = TextEditingController();
  final TextEditingController radiographicInterradicularLesionsController = TextEditingController();

  // Hospitalization
  String? hospitalization = 'No';
  TextEditingController hospitalizationDateController = TextEditingController();
  TextEditingController hospitalizationReasonController = TextEditingController();
  TextEditingController hospitalizationMedicationController = TextEditingController();
  DateTime? hospitalizationDate;

  // Medical History options
  final List<String> medicalHistoryOptions = [
    'Blood disorder',
    'Asthma',
    'Cardiac disease',
    'Allergy to',
    'Endocrine',
    'Others',
  ];
  List<String> selectedMedicalHistory = [];

  // Oral Hygiene Level
  String? oralHygieneLevel = 'Good';

  // Molar Relationships
  String? molarRelationshipPrimaryRight = 'Normal';
  String? molarRelationshipPrimaryLeft = 'Normal';
  String? molarRelationshipPermanentRight = 'Normal';
  String? molarRelationshipPermanentLeft = 'Normal';
  final List<String> molarOptions = ['Normal', 'Mesial', 'Distal'];

  // Primate Space / Midline Deviation
  String primateSpaceValue = 'Upper';
  String midlineDeviation = 'No';

  // Canine Palpable
  String caninePalpable = 'No';
  // شبكة مربعات Canine (ترقيم أسنان دائم مع فراغ في المنتصف)
  final List<String> canineGridLabels = [
    '17','16','15','14','13','12','11','', '21','22','23','24','25','26','27',
    '47','46','45','44','43','42','41','', '31','32','33','34','35','36','37',
  ];
  List<bool> canineGridSelected = List.filled(30, false);

  // Radiographs
  bool radiographsTaken = false;

  // متغير لحقل other في medical history
  bool showOtherMedical = false;
  final TextEditingController otherMedicalController = TextEditingController();

  // Plaque index table controllers
  late List<List<TextEditingController>> plaqueIndexControllers;

  // خيارات الأشعة
  bool radiographPeriapical = false;
  bool radiographOcclusalU = false;
  bool radiographOcclusalL = false;
  bool radiographBitewingR = false;
  bool radiographBitewingL = false;
  bool radiographOPG = false;

  // Controller for Other Investigations
  final TextEditingController otherInvestigationsController = TextEditingController();

  // Controller for Periapical details
  final TextEditingController periapicalDetailsController = TextEditingController();

  final Map<String, Map<String, String>> _translations = {
    'clinical_requirements': {'ar': 'المتطلبات السريرية', 'en': 'Clinical Requirements'},
    'history_title': {'ar': 'أخذ التاريخ والفحص والتخطيط', 'en': 'History taking, examination, & treatment planning'},
    'history_required': {'ar': 'المطلوب: 3 حالات', 'en': 'Required: 3 cases'},
    'fissure_title': {'ar': 'سد الشقوق', 'en': 'Fissure sealants'},
    'fissure_required': {'ar': 'المطلوب: 6 حالات', 'en': 'Required: 6 cases'},
    'guardian_name': {'ar': 'اسم ولي الأمر', 'en': "Guardian's Name"},
    'patient_address': {'ar': 'عنوان المريض', 'en': 'Patient Address'},
    'patient_phone': {'ar': 'رقم هاتف المريض', 'en': 'Patient Phone'},
    'send_case': {'ar': 'إرسال الحالة', 'en': 'Submit Case'},
    'last_case_graded': {'ar': 'تم تقييم آخر حالة', 'en': 'Last case graded'},
    'last_case_pending': {'ar': 'آخر حالة قيد المراجعة من الدكتور', 'en': 'Last case pending review'},
    'last_case_rejected': {'ar': 'آخر حالة بحاجة لتعديل', 'en': 'Last case needs revision'},
    'mark': {'ar': 'العلامة', 'en': 'Mark'},
    'doctor_note': {'ar': 'ملاحظة الدكتور', 'en': 'Doctor Note'},
    'no_mark': {'ar': 'بدون علامة', 'en': 'No mark'},
    'submit_success': {'ar': 'تم إرسال الحالة للدكتور المشرف', 'en': 'Case submitted to supervisor'},
    'must_login': {'ar': 'يجب تسجيل الدخول', 'en': 'You must login'},
  };

  String _translate(String key) {
    final locale = Localizations.localeOf(context).languageCode;
    return _translations[key]?[locale] ?? _translations[key]?['en'] ?? key;
  }

  String get _caseTypeLabel {
    switch (widget.caseType) {
      case 'history':
        return _translate('history_title');
      case 'fissure':
        return _translate('fissure_title');
      default:
        return widget.caseType ?? '';
    }
  }

  bool _isDoctorView() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    // يمكنك تعديل هذا الشرط حسب طريقة تخزينك لدور المستخدم في قاعدة البيانات
    return ModalRoute.of(context)?.settings.name?.toLowerCase().contains('doctor') == true;
  }

  // دالة تتحقق من دور المستخدم من قاعدة البيانات
  Future<bool> _isDoctor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final db = FirebaseDatabase.instance.ref();
    final snapshot = await db.child('users').child(user.uid).child('role').get();
    return snapshot.exists && snapshot.value == 'doctor';
  }

  Future<void> _loadCurrentCase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final db = FirebaseDatabase.instance.ref('paedodonticsCases');
    final snapshot = await db.orderByChild('studentId').equalTo(user.uid).get();

    if (snapshot.exists) {
      final cases = snapshot.value as Map<dynamic, dynamic>;
      MapEntry<dynamic, dynamic>? latestEntry;
      int latestTimestamp = 0;
      for (final entry in cases.entries) {
        final caseData = entry.value;
        if (caseData['caseNumber'] == widget.caseNumber &&
            caseData['caseType'] == widget.caseType &&
            caseData['groupId'] == widget.groupId) {
          int ts = (caseData['gradedAt'] ?? caseData['submittedAt'] ?? 0) as int;
          if (ts > latestTimestamp) {
            latestTimestamp = ts;
            latestEntry = entry;
          }
        }
      }
      if (latestEntry != null) {
        final caseData = latestEntry.value;
        lastSubmittedCaseKey = latestEntry.key;
        lastCaseStatus = caseData['status'];
        lastCaseMark = caseData['mark'];
        lastDoctorComment = (caseData['rejectionReason'] ?? caseData['doctorComment'] ?? '').toString();
      }
      setState(() {});
    }
  }

  Future<void> submitCase() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isSubmitting = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_translate('must_login'))));
      setState(() => isSubmitting = false);
      return;
    }
    try {
      final db = FirebaseDatabase.instance.ref();
      String studentName = '';
      final userSnapshot = await db.child('users').child(user.uid).get();
      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        studentName = userData['fullName'] ?? userData['name'] ?? user.displayName ?? '';
      } else {
        studentName = user.displayName ?? '';
      }
      final caseData = {
        'studentId': user.uid,
        'studentName': studentName,
        'groupId': widget.groupId,
        'caseNumber': widget.caseNumber,
        'patient': widget.patient,
        if (widget.courseId != null) 'courseId': widget.courseId,
        'caseType': widget.caseType,
        'status': 'pending',
        'mark': null,
        'doctorComment': null,
        'submittedAt': DateTime.now().millisecondsSinceEpoch,
        // جميع الحقول الإضافية:
        'chiefComplaint': chiefComplaintController.text,
        'historyOfComplaint': historyOfComplaintController.text,
        'dentalHistory': dentalHistoryController.text,
        'socialHistory': socialHistoryController.text,
        'medicalHistory': selectedMedicalHistory,
        'otherMedical': otherMedicalController.text,
        'hospitalization': hospitalization,
        'hospitalizationDate': hospitalizationDateController.text,
        'hospitalizationReason': hospitalizationReasonController.text,
        'hospitalizationMedication': hospitalizationMedicationController.text,
        'extraOralExam': extraOralExamController.text,
        'intraOralSoftTissue': intraOralSoftTissueController.text,
        'oralHygieneLevel': oralHygieneLevel,
        'plaqueIndex': plaqueIndexControllers.map((row) => row.map((c) => c.text).toList()).toList(),
        'molarRelationshipPrimaryRight': molarRelationshipPrimaryRight,
        'molarRelationshipPrimaryLeft': molarRelationshipPrimaryLeft,
        'molarRelationshipPermanentRight': molarRelationshipPermanentRight,
        'molarRelationshipPermanentLeft': molarRelationshipPermanentLeft,
        'primateSpace': primateSpaceValue,
        'midlineDeviation': (midlineDeviation == 'Yes' ? 'Yes' : 'No'),
        'caninePalpable': caninePalpable,
        'canineGridLabels': canineGridLabels,
        'canineGridSelected': canineGridSelected,
        'radiographsTaken': radiographsTaken,
        'radiographPeriapical': radiographPeriapical,
        'periapicalDetails': periapicalDetailsController.text,
        'radiographOcclusalU': radiographOcclusalU,
        'radiographOcclusalL': radiographOcclusalL,
        'radiographBitewingR': radiographBitewingR,
        'radiographBitewingL': radiographBitewingL,
        'radiographOPG': radiographOPG,
        'radiographsFindings': radiographsFindingsController.text,
        'crossbite': crossbiteController.text,
        'oralHabits': oralHabitsController.text,
        'overjet': overjetController.text,
        'overbite': overbiteController.text,
        'radiographicCaries': radiographicCariesController.text,
        'radiographicSupernumeraries': radiographicSupernumerariesController.text,
        'radiographicMissingTeeth': radiographicMissingTeethController.text,
        'radiographicPeriapicalLesions': radiographicPeriapicalLesionsController.text,
        'radiographicInterradicularLesions': radiographicInterradicularLesionsController.text,
        'otherInvestigations': otherInvestigationsController.text,
        // أي متغيرات إضافية معرفة في الكلاس
        'showOtherMedical': showOtherMedical,
        'plaqueIndexControllerText': plaqueIndexController.text,
        'molarOptions': molarOptions,
      };
      await db.child('paedodonticsCases').push().set(caseData);
      // تحديث فلاج السماح للطالب بأخذ حالة جديدة في المادة
      if (widget.courseId != null) {
        await db.child('student_case_flags').child(widget.courseId!).child(user.uid).set(1);
      }
      await _loadCurrentCase();
      setState(() => isSubmitting = false);
      if (widget.onSave != null) widget.onSave!(null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_translate('submit_success'))));
    } catch (e) {
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء إرسال الحالة: $e')));
    }
  }

  void _onGradePressed() async {
    if (_doctorMarkController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال العلامة')));
      return;
    }
    final mark = int.tryParse(_doctorMarkController.text);
    if (mark == null || mark < 0 || mark > 35) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('العلامة يجب أن تكون بين 0 و 35')));
      return;
    }
    if (_doctorNoteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ملاحظات الدكتور مطلوبة')));
      return;
    }
    setState(() => isSubmitting = true);
    try {
      final db = FirebaseDatabase.instance.ref();
      await db.child('paedodonticsCases').child(widget.initialData!['key']).update({
        'status': 'graded',
        'mark': mark,
        'doctorGrade': mark,
        'doctorComment': _doctorNoteController.text,
        'diagnosis': diagnosisController.text,
        'gradedAt': DateTime.now().millisecondsSinceEpoch,
      });
      setState(() => isSubmitting = false);
      if (widget.onSave != null) widget.onSave!(mark);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التقييم بنجاح')));
    } catch (e) {
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء حفظ التقييم: $e')));
    }
  }

  void _onRejectPressed() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final TextEditingController reasonController = TextEditingController();
        final TextEditingController noteController = TextEditingController();
        return AlertDialog(
          title: const Text('سبب الرفض'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'يرجى إدخال سبب الرفض'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'ملاحظات الدكتور (إجباري)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty || noteController.text.trim().isEmpty) return;
                Navigator.of(context).pop('${reasonController.text.trim()}||${noteController.text.trim()}');
              },
              child: const Text('رفض'),
            ),
          ],
        );
      },
    );
    if (reason == null || reason.isEmpty || !reason.contains('||')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب إدخال سبب الرفض وملاحظات الدكتور')));
      return;
    }
    final parts = reason.split('||');
    final rejectionReason = parts[0];
    final doctorNote = parts[1];
    setState(() => isSubmitting = true);
    try {
      final db = FirebaseDatabase.instance.ref();
      await db.child('paedodonticsCases').child(widget.initialData!['key']).update({
        'status': 'rejected',
        'doctorComment': doctorNote,
        'rejectionReason': rejectionReason,
        'diagnosis': diagnosisController.text,
        'mark': null,
        'gradedAt': DateTime.now().millisecondsSinceEpoch,
      });
      setState(() => isSubmitting = false);
      if (widget.onSave != null) widget.onSave!(null);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض الحالة وإرجاعها للطالب')));
    } catch (e) {
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء رفض الحالة: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    plaqueIndexControllers = List.generate(2, (_) => List.generate(4, (_) => TextEditingController()));
    if (widget.initialData != null) {
      final data = widget.initialData!;
      guardianNameController.text = data['guardianName'] ?? '';
      patientAddressController.text = data['patientAddress'] ?? '';
      patientPhoneController.text = data['patientPhone'] ?? '';
      diagnosisController.text = data['diagnosis'] ?? '';
      lastCaseStatus = data['status'];
      lastCaseMark = data['doctorGrade'] ?? data['mark'];
      lastDoctorComment = (data['rejectionReason'] ?? data['doctorComment'] ?? '').toString();
      if (data['mark'] != null && _doctorMarkController.text.isEmpty) _doctorMarkController.text = data['mark'].toString();
      if (data['doctorComment'] != null && _doctorNoteController.text.isEmpty) _doctorNoteController.text = data['doctorComment'];
      chiefComplaintController.text = data['chiefComplaint'] ?? '';
      historyOfComplaintController.text = data['historyOfComplaint'] ?? '';
      selectedMedicalHistory = List<String>.from(data['medicalHistory'] ?? []);
      hospitalization = data['hospitalization'] ?? 'No';
      if (data['hospitalizationDate'] != null) {
        try {
          // إذا كان التاريخ مخزن كـ int (millis)
          if (data['hospitalizationDate'] is int) {
            hospitalizationDate = DateTime.fromMillisecondsSinceEpoch(data['hospitalizationDate']);
          } else if (data['hospitalizationDate'] is String && int.tryParse(data['hospitalizationDate']) != null) {
            hospitalizationDate = DateTime.fromMillisecondsSinceEpoch(int.parse(data['hospitalizationDate']));
          } else if (data['hospitalizationDate'] is String) {
            hospitalizationDate = DateTime.tryParse(data['hospitalizationDate']);
          }
          if (hospitalizationDate != null) {
            hospitalizationDateController.text = "${hospitalizationDate!.year}-${hospitalizationDate!.month.toString().padLeft(2, '0')}-${hospitalizationDate!.day.toString().padLeft(2, '0')}";
          } else {
            hospitalizationDateController.text = data['hospitalizationDate'].toString();
          }
        } catch (_) {
          hospitalizationDateController.text = data['hospitalizationDate'].toString();
        }
      }
      hospitalizationReasonController.text = data['hospitalizationReason'] ?? '';
      hospitalizationMedicationController.text = data['hospitalizationMedication'] ?? '';
      dentalHistoryController.text = data['dentalHistory'] ?? '';
      socialHistoryController.text = data['socialHistory'] ?? '';
      extraOralExamController.text = data['extraOralExam'] ?? '';
      intraOralSoftTissueController.text = data['intraOralSoftTissue'] ?? '';
      oralHygieneLevel = data['oralHygieneLevel'] ?? 'Good';
      plaqueIndexController.text = data['plaqueIndex']?.toString() ?? '';
      molarRelationshipPrimaryRight = data['molarRelationshipPrimaryRight'] ?? 'Normal';
      molarRelationshipPrimaryLeft = data['molarRelationshipPrimaryLeft'] ?? 'Normal';
      molarRelationshipPermanentRight = data['molarRelationshipPermanentRight'] ?? 'Normal';
      molarRelationshipPermanentLeft = data['molarRelationshipPermanentLeft'] ?? 'Normal';
      // midlineDeviation: خذ القيمة كما هي من الداتا بيس إذا كانت نص
      if (data['midlineDeviation'] != null) {
        if (data['midlineDeviation'] is bool) {
          midlineDeviation = data['midlineDeviation'] ? 'Yes' : 'No';
        } else {
          midlineDeviation = data['midlineDeviation'].toString();
        }
      }
     
      caninePalpable = data['caninePalpable'] == true ? 'Yes' : 'No';
      // استرجاع قيم radiographs
      radiographPeriapical = data['radiographPeriapical'] == true;
      radiographOcclusalU = data['radiographOcclusalU'] == true;
      radiographOcclusalL = data['radiographOcclusalL'] == true;
      radiographBitewingR = data['radiographBitewingR'] == true;
      radiographBitewingL = data['radiographBitewingL'] == true;
      radiographOPG = data['radiographOPG'] == true;
      radiographsTaken = data['radiographsTaken'] == true;
      radiographsFindingsController.text = data['radiographsFindings'] ?? '';
      primateSpaceValue = data['primateSpace'] ?? 'None';

      // تعبئة قيم plaqueIndexControllers من الداتا بيس إذا كانت موجودة
      if (data['plaqueIndex'] != null && data['plaqueIndex'] is List) {
        final List<dynamic> rows = data['plaqueIndex'];
        for (int i = 0; i < rows.length && i < plaqueIndexControllers.length; i++) {
          final row = rows[i];
          if (row is List) {
            for (int j = 0; j < row.length && j < plaqueIndexControllers[i].length; j++) {
              plaqueIndexControllers[i][j].text = row[j]?.toString() ?? '';
            }
          }
        }
      }
      overjetController.text = data['overjet'] ?? '';
      overbiteController.text = data['overbite'] ?? '';
      crossbiteController.text = data['crossbite'] ?? '';
      oralHabitsController.text = data['oralHabits'] ?? '';
      // استرجاع قيمة caninePalpable
      if (data['caninePalpable'] != null) {
        caninePalpable = data['caninePalpable'].toString();
      }
      // استرجاع قيمة canineGridLabels إذا كانت موجودة
      if (data['canineGridLabels'] != null && data['canineGridLabels'] is List) {
        final List<dynamic> labels = data['canineGridLabels'];
        for (int i = 0; i < labels.length && i < canineGridLabels.length; i++) {
          canineGridLabels[i] = labels[i]?.toString() ?? '';
        }
      }
      // استرجاع قيمة canineGridSelected إذا كانت موجودة
      if (data['canineGridSelected'] != null && data['canineGridSelected'] is List) {
        final List<dynamic> selected = data['canineGridSelected'];
        for (int i = 0; i < selected.length && i < canineGridSelected.length; i++) {
          canineGridSelected[i] = selected[i] == true;
        }
      }
      // استرجاع قيمة otherMedical إذا كانت موجودة
      if (data['otherMedical'] != null && data['otherMedical'].toString().isNotEmpty) {
        otherMedicalController.text = data['otherMedical'];
        showOtherMedical = true;
        if (!selectedMedicalHistory.contains('Others')) {
          selectedMedicalHistory.add('Others');
        }
      }

      // تعبئة radiographic findings من الداتا بيس
      radiographicCariesController.text = data['radiographicCaries'] ?? '';
      radiographicSupernumerariesController.text = data['radiographicSupernumeraries'] ?? '';
      radiographicMissingTeethController.text = data['radiographicMissingTeeth'] ?? '';
      radiographicPeriapicalLesionsController.text = data['radiographicPeriapicalLesions'] ?? '';
      radiographicInterradicularLesionsController.text = data['radiographicInterradicularLesions'] ?? '';
      // تعبئة حقل otherInvestigations من الداتا بيس
      otherInvestigationsController.text = data['otherInvestigations']?.toString() ?? '';
      // استرجاع تفاصيل Periapical إذا كانت موجودة
      if (data['periapicalDetails'] != null) {
        periapicalDetailsController.text = data['periapicalDetails'].toString();
      }
    }
    _loadCurrentCase();
  }

  @override
  void dispose() {
    guardianNameController.dispose();
    patientAddressController.dispose();
    patientPhoneController.dispose();
    diagnosisController.dispose();
    _doctorMarkController.dispose();
    _doctorNoteController.dispose();
    chiefComplaintController.dispose();
    historyOfComplaintController.dispose();
    dentalHistoryController.dispose();
    socialHistoryController.dispose();
    extraOralExamController.dispose();
    intraOralSoftTissueController.dispose();
    plaqueIndexController.dispose();
    radiographsFindingsController.dispose();
    otherMedicalController.dispose();
    hospitalizationDateController.dispose();
    hospitalizationReasonController.dispose();
    hospitalizationMedicationController.dispose();
    crossbiteController.dispose();
    oralHabitsController.dispose();
    otherInvestigationsController.dispose();
    overjetController.dispose();
    overbiteController.dispose();
    radiographicCariesController.dispose();
    radiographicSupernumerariesController.dispose();
    radiographicMissingTeethController.dispose();
    radiographicPeriapicalLesionsController.dispose();
    radiographicInterradicularLesionsController.dispose();
    periapicalDetailsController.dispose();
    for (var row in plaqueIndexControllers) {
      for (var c in row) {
        c.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF2A7A94);

    return Scaffold(
      appBar: AppBar(
        title: Text('$_caseTypeLabel  0{widget.caseNumber}'),
        centerTitle: true,
        backgroundColor: primaryColor, // لون أساسي للخلفية
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
color: primaryColor.withAlpha(15),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // معلومات المريض في الأعلى
                  Card(
                    color: Colors.white,
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person, color: primaryColor),
                              const SizedBox(width: 8),
                              Text(
                                widget.patient['fullName'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.cake, color: primaryColor, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                (() {
                                  // حساب العمر من birthDate إذا وجد
                                  if (widget.patient['birthDate'] != null) {
                                    try {
                                      final birthDateMillis = widget.patient['birthDate'];
                                      final birthDate = DateTime.fromMillisecondsSinceEpoch(birthDateMillis is int ? birthDateMillis : int.parse(birthDateMillis.toString()));
                                      final now = DateTime.now();
                                      int years = now.year - birthDate.year;
                                      if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
                                        years--;
                                      }
                                      return '$years سنة';
                                    } catch (_) {}
                                  }
                                  // إذا لم يوجد birthDate استخدم age
                                  return (widget.patient['age'] != null) ? '${widget.patient['age']} سنة' : '-';
                                })(),
                                style: const TextStyle(fontSize: 15),
                              ),
                              const SizedBox(width: 18),
                              const Icon(Icons.wc, color: primaryColor, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                (widget.patient['gender'] ?? '').toString().toLowerCase() == 'male' ? 'ذكر' : (widget.patient['gender'] ?? '').toString().toLowerCase() == 'female' ? 'أنثى' : '-',
                                style: const TextStyle(fontSize: 15),
                              ),
                              const SizedBox(width: 18),
                              const Icon(Icons.calendar_today, color: primaryColor, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // معلومات الحالة
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: Text(
                      'نوع الحالة: $_caseTypeLabel',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  // حقول النموذج
                  // --- الحقول الإضافية ---
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: chiefComplaintController,
                    decoration: const InputDecoration(
                      labelText: 'Chief Complaint',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: historyOfComplaintController,
                    decoration: const InputDecoration(
                      labelText: 'History of Complaint',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  // Dental History
                  TextFormField(
                    controller: dentalHistoryController,
                    decoration: const InputDecoration(
                      labelText: 'Dental History',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Social History
                  TextFormField(
                    controller: socialHistoryController,
                    decoration: const InputDecoration(
                      labelText: 'Social History',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Medical History (CheckboxListTile) عمودين
                  Container(
                    alignment: Alignment.centerLeft,
                    child: const Text('Medical History', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 4.5,
                    children: [
                      ...medicalHistoryOptions.map((option) => Theme(
                            data: Theme.of(context).copyWith(
                              unselectedWidgetColor: Colors.white, // لون غير محدد أبيض
                              checkboxTheme: CheckboxThemeData(
                                fillColor: WidgetStateProperty.resolveWith<Color>((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return primaryColor; // عند التحديد يصبح اللون الأساسي
                                  }
                                  return Colors.white; // غير محدد أبيض
                                }),
                                checkColor: WidgetStateProperty.all(Colors.white), // لون علامة الصح
                              ),
                            ),
                            child: CheckboxListTile(
                              title: Text(option),
                              value: selectedMedicalHistory.contains(option),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    selectedMedicalHistory.add(option);
                                    if (option == 'Others') showOtherMedical = true;
                                  } else {
                                    selectedMedicalHistory.remove(option);
                                    if (option == 'Others') {
                                      showOtherMedical = false;
                                      otherMedicalController.clear();
                                    }
                                  }
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              tristate: false,
                            ),
                          )),
                    ],
                  ),
                  if (showOtherMedical)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: TextFormField(
                        controller: otherMedicalController,
                        decoration: const InputDecoration(
                          labelText: 'Please specify Other',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (showOtherMedical && (value == null || value.isEmpty)) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),
                  const SizedBox(height: 16), // فراغ بين Medical History و Hospitalization
                  // Hospitalization (RadioListTile)
                  Container(
                    alignment: Alignment.centerLeft,
                    child: const Text('Hospitalization', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Theme(
                    data: Theme.of(context).copyWith(
                      unselectedWidgetColor: primaryColor,
                      radioTheme: RadioThemeData(
                        fillColor: WidgetStateProperty.all(primaryColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Yes'),
                            value: 'Yes',
                            groupValue: hospitalization,
                            onChanged: (val) => setState(() => hospitalization = val),
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('No'),
                            value: 'No',
                            groupValue: hospitalization,
                            onChanged: (val) => setState(() => hospitalization = val),
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hospitalization == 'Yes') ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: hospitalizationDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            hospitalizationDate = picked;
                            hospitalizationDateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                          });
                        }
                      },
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: hospitalizationDateController,
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          validator: (value) {
                            if (hospitalization == 'Yes' && (value == null || value.isEmpty)) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: hospitalizationReasonController,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 2,
                      maxLines: 4,
                      validator: (value) {
                        if (hospitalization == 'Yes' && (value == null || value.isEmpty)) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: hospitalizationMedicationController,
                      decoration: const InputDecoration(
                        labelText: 'Medication',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 2,
                      maxLines: 4,
                      validator: (value) {
                        if (hospitalization == 'Yes' && (value == null || value.isEmpty)) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: extraOralExamController,
                    decoration: const InputDecoration(
                      labelText: 'Extra Oral Exam',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: intraOralSoftTissueController,
                    decoration: const InputDecoration(
                      labelText: 'Intra Oral (Soft Tissue)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Oral Hygiene Level (RadioListTile)
                  Container(
                    alignment: Alignment.centerLeft,
                    child: const Text('Oral Hygiene Level', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Theme(
                    data: Theme.of(context).copyWith(
                      unselectedWidgetColor: primaryColor,
                      radioTheme: RadioThemeData(
                        fillColor: WidgetStateProperty.all(primaryColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Good'),
                            value: 'Good',
                            groupValue: oralHygieneLevel,
                            onChanged: (val) => setState(() => oralHygieneLevel = val),
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Fair'),
                            value: 'Fair',
                            groupValue: oralHygieneLevel,
                            onChanged: (val) => setState(() => oralHygieneLevel = val),
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Poor'),
                            value: 'Poor',
                            groupValue: oralHygieneLevel,
                            onChanged: (val) => setState(() => oralHygieneLevel = val),
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Plaque index table
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade800, width: 1.2),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Table(
                      border: TableBorder(
                        top: BorderSide(color: Colors.grey.shade800, width: 1.5),
                        horizontalInside: BorderSide(color: Colors.grey.shade800, width: 1.2),
                        verticalInside: BorderSide(color: Colors.grey.shade800, width: 1.2),
                        left: BorderSide.none,
                        right: BorderSide.none,
                        bottom: BorderSide.none,
                      ),
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(1.2),
                        2: FlexColumnWidth(1.2),
                        3: FlexColumnWidth(1.2),
                        4: FlexColumnWidth(1.2),
                      },
                      children: [
                        TableRow(
                          children: [
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.fill,
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.all(8),
                                height: 100, // زيادة الارتفاع لمحاكاة الدمج العمودي
                                child: const Text('Plaque index:', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('16', textAlign: TextAlign.center),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('22/62', textAlign: TextAlign.center),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('24/64', textAlign: TextAlign.center),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('Total', textAlign: TextAlign.center),
                            ),
                          ],
                        ),
                        // صفان فارغان للكتابة (بدون عمود أول)
                        for (int i = 0; i < 2; i++)
                          TableRow(
                            children: [
                              const SizedBox(),
                              for (int j = 0; j < 4; j++)
                                Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: TextFormField(
                                    controller: plaqueIndexControllers[i][j],
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                                    ),
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                            ],
                          ),
                        // صف عناوين الأسنان السفلية
                        const TableRow(
                          children: [
                            SizedBox(),
                            Padding(
                              padding: EdgeInsets.all(4),
                              child: Text('44/84', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(4),
                              child: Text('42/82', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: EdgeInsets.all(4),
                              child: Text('36', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            SizedBox(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Molar Relationships (Primary)
                  Container(
                    alignment: Alignment.centerLeft,
                    child: const Text('Molar Relationships (Primary)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Theme(
                    data: Theme.of(context).copyWith(
                      radioTheme: RadioThemeData(
                        fillColor: WidgetStateProperty.all(primaryColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('Right:'),
                        ...molarOptions.map((opt) => Expanded(
                              child: RadioListTile<String>(
                                title: Text(opt),
                                value: opt,
                                groupValue: molarRelationshipPrimaryRight,
                                onChanged: (val) => setState(() => molarRelationshipPrimaryRight = val),
                              ),
                            )),
                      ],
                    ),
                  ),
                  Theme(
                    data: Theme.of(context).copyWith(
                      radioTheme: RadioThemeData(
                        fillColor: WidgetStateProperty.all(primaryColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('Left:'),
                        ...molarOptions.map((opt) => Expanded(
                              child: RadioListTile<String>(
                                title: Text(opt),
                                value: opt,
                                groupValue: molarRelationshipPrimaryLeft,
                                onChanged: (val) => setState(() => molarRelationshipPrimaryLeft = val),
                              ),
                            )),
                      ],
                    ),
                  ),
                  // Molar Relationships (Permanent)
                  Container(
                    alignment: Alignment.centerLeft,
                    child: const Text('Molar Relationships (Permanent)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Theme(
                    data: Theme.of(context).copyWith(
                      radioTheme: RadioThemeData(
                        fillColor: WidgetStateProperty.all(primaryColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('Right:'),
                        ...molarOptions.map((opt) => Expanded(
                              child: RadioListTile<String>(
                                title: Text(opt),
                                value: opt,
                                groupValue: molarRelationshipPermanentRight,
                                onChanged: (val) => setState(() => molarRelationshipPermanentRight = val),
                              ),
                            )),
                      ],
                    ),
                  ),
                  Theme(
                    data: Theme.of(context).copyWith(
                      radioTheme: RadioThemeData(
                        fillColor: WidgetStateProperty.all(primaryColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('Left:'),
                        ...molarOptions.map((opt) => Expanded(
                              child: RadioListTile<String>(
                                title: Text(opt),
                                value: opt,
                                groupValue: molarRelationshipPermanentLeft,
                                onChanged: (val) => setState(() => molarRelationshipPermanentLeft = val),
                              ),
                            )),
                      ],
                    ),
                  ),
                  // Primate Space (Radio buttons: Upper, Lower)
                  Container(
                    alignment: Alignment.centerLeft,
                    child: const Text('Primate Space', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Theme(
                    data: Theme.of(context).copyWith(
                      radioTheme: RadioThemeData(
                        fillColor: WidgetStateProperty.all(primaryColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Upper'),
                            value: 'Upper',
                            groupValue: primateSpaceValue,
                            onChanged: (val) => setState(() => primateSpaceValue = val!),
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Lower'),
                            value: 'Lower',
                            groupValue: primateSpaceValue,
                            onChanged: (val) => setState(() => primateSpaceValue = val!),
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Midline Deviation as Radio Buttons
                  Container(
                    alignment: Alignment.centerLeft,
                    child: const Text('Midline Deviation', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Theme(
                    data: Theme.of(context).copyWith(
                      radioTheme: RadioThemeData(
                        fillColor: WidgetStateProperty.all(primaryColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Yes'),
                            value: 'Yes',
                            groupValue: midlineDeviation,
                            onChanged: (val) => setState(() => midlineDeviation = val!),
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('No'),
                            value: 'No',
                            groupValue: midlineDeviation,
                            onChanged: (val) => setState(() => midlineDeviation = val!),
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Crossbite / Oral Habits / Overjet / Overbite
                 
                  const SizedBox(height: 12),
                  // Overjet & Overbite fields in the same row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: overjetController,
                          decoration: const InputDecoration(
                            labelText: 'Overjet',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: overbiteController,
                          decoration: const InputDecoration(
                            labelText: 'Overbite',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Crossbite & Oral habits fields in the same row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: crossbiteController,
                          decoration: const InputDecoration(
                            labelText: 'Crossbite',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: oralHabitsController,
                          decoration: const InputDecoration(
                            labelText: 'Oral habits',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Canine Palpable
                  Container(
                    alignment: Alignment.centerLeft,
                    child: const Text('Canine Palpable', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Theme(
                    data: Theme.of(context).copyWith(
                      radioTheme: RadioThemeData(
                        fillColor: WidgetStateProperty.all(primaryColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Yes'),
                            value: 'Yes',
                            groupValue: caninePalpable,
                            onChanged: (val) => setState(() => caninePalpable = val!),
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('No'),
                            value: 'No',
                            groupValue: caninePalpable,
                            onChanged: (val) => setState(() => caninePalpable = val!),
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // شبكة مربعات Canine (صفين مع فراغ في المنتصف)
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 15,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 1,
                    ),
                    itemCount: 30,
                    itemBuilder: (context, index) {
                      final label = canineGridLabels[index];
                      if (label == '') {
                        return const SizedBox(); // فراغ في المنتصف
                      }
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            canineGridSelected[index] = !canineGridSelected[index];
                          });
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: canineGridSelected[index] ? primaryColor : Colors.white,
                            border: Border.all(color: primaryColor, width: 1.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: canineGridSelected[index] ? Colors.white : primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Checkboxes للأشعة
                  Container(
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      'Radiographs:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: primaryColor, // اجعل اللون هو اللون الأساسي
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CheckboxListTile(
                                  title: const Text('Periapical'),
                                  value: radiographPeriapical,
                                  onChanged: (val) => setState(() => radiographPeriapical = val ?? false),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                if (radiographPeriapical)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 16, right: 8, bottom: 4),
                                    child: SizedBox(
                                      height: 38,
                                      child: TextFormField(
                                        controller: periapicalDetailsController,
                                        decoration: const InputDecoration(
                                          labelText: 'Details',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('Occlusal (U)'),
                              value: radiographOcclusalU,
                              onChanged: (val) => setState(() => radiographOcclusalU = val ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('Occlusal (L)'),
                              value: radiographOcclusalL,
                              onChanged: (val) => setState(() => radiographOcclusalL = val ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('Bitewing (R)'),
                              value: radiographBitewingR,
                              onChanged: (val) => setState(() => radiographBitewingR = val ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('Bitewing (L)'),
                              value: radiographBitewingL,
                              onChanged: (val) => setState(() => radiographBitewingL = val ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('OPG'),
                              value: radiographOPG,
                              onChanged: (val) => setState(() => radiographOPG = val ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Radiographic Findings section
                  const SizedBox(height: 16),
                  Container(
                    alignment: Alignment.centerLeft,
                    child: const Text('Radiographic Findings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: radiographicCariesController,
                          decoration: const InputDecoration(
                            labelText: 'Caries',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: radiographicSupernumerariesController,
                          decoration: const InputDecoration(
                            labelText: 'Supernumeraries',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: radiographicMissingTeethController,
                          decoration: const InputDecoration(
                            labelText: 'Missing teeth',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: radiographicPeriapicalLesionsController,
                          decoration: const InputDecoration(
                            labelText: 'Periapical lesions',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: radiographicInterradicularLesionsController,
                          decoration: const InputDecoration(
                            labelText: 'Interradicular lesions',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: SizedBox()), // فراغ لتكملة الصف
                    ],
                  ),
                  const SizedBox(height: 16),
                  // --- نهاية الحقول الإضافية ---

                  // Other Investigations section
                  const SizedBox(height: 16),
                  Container(
                    alignment: Alignment.centerLeft,
                    child: const Text('Other Investigations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: otherInvestigationsController,
                    decoration: const InputDecoration(
                      labelText: 'Other Investigations',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),

                  // حالة التقييم - تظهر للجميع
                  if (lastCaseStatus != null) _buildCaseStatusSection(),

                  // حقول التقييم للدكتور تظهر فقط إذا الحالة pending والمستخدم دكتور فعلياً من قاعدة البيانات
                  FutureBuilder<bool>(
                    future: _isDoctor(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done || !snapshot.hasData || !snapshot.data!) {
                        return const SizedBox.shrink();
                      }
                      if (lastCaseStatus == 'pending' && widget.initialData != null) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _doctorMarkController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'العلامة (من 0 إلى 35)',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'الرجاء إدخال العلامة';
                                  final mark = int.tryParse(value);
                                  if (mark == null || mark < 0 || mark > 35) return 'العلامة يجب أن تكون بين 0 و 35';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _doctorNoteController,
                                minLines: 2,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText: 'ملاحظات الدكتور',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.check, color: Colors.white),
                                      label: const Text('إضافة العلامة والموافقة'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: isSubmitting ? null : _onGradePressed,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.close, color: Colors.white),
                                      label: const Text('رفض الحالة'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: isSubmitting ? null : _onRejectPressed,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text('لا يمكن إغلاق النافذة إلا بعد تقييم الحالة أو رفضها مع ذكر السبب.',
                                style: TextStyle(color: Colors.orange, fontSize: 13)),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  // زر الإرسال - يظهر فقط للطالب إذا لم تكن الحالة pending أو graded
                  if (lastCaseStatus != 'pending' && lastCaseStatus != 'graded' && !_isDoctorView())
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: isSubmitting ? null : submitCase,
                        child: isSubmitting
                            ? const CircularProgressIndicator()
                            : Text(
                                _translate('send_case'),
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildCaseStatusSection() {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    String? rejectionReason;

    if (lastCaseStatus == 'graded') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = _translate('last_case_graded');
    } else if (lastCaseStatus == 'pending') {
      statusColor = Colors.orange;
      statusIcon = Icons.access_time;
      statusText = _translate('last_case_pending');
    } else if (lastCaseStatus == 'rejected') {
      statusColor = Colors.red;
      statusIcon = Icons.warning;
      statusText = _translate('last_case_rejected');
      rejectionReason = lastDoctorComment;
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.warning;
      statusText = _translate('last_case_rejected');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: statusColor.withOpacity(0.1),
border: Border.all(color: statusColor.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    fontSize: 16,
                  ),
                ),
              ),
              if (lastCaseStatus == 'graded' && lastCaseMark != null) ...[
                const Spacer(),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '$lastCaseMark',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (lastDoctorComment != null && lastDoctorComment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ملاحظات الدكتور: $lastDoctorComment',
                      style: const TextStyle(color: Colors.blue, fontSize: 15, fontWeight: FontWeight.bold),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (lastCaseStatus == 'rejected' && rejectionReason != null && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سبب الرفض: $rejectionReason',
                      style: const TextStyle(color: Colors.orange, fontSize: 15, fontWeight: FontWeight.bold),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}