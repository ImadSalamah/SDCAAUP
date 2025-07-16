// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SurgeryForm extends StatefulWidget {
  final String groupId;
  final int caseNumber;
  final Map<String, dynamic> patient;
  final String? courseId;
  final Function(int? doctorGrade)? onSave;
  final String? caseType;
  final Map<String, dynamic>? initialData;

  const SurgeryForm({
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
  State<SurgeryForm> createState() => _SurgeryFormState();
}

class _SurgeryFormState extends State<SurgeryForm> {
  bool isSubmitting = false;
  String? lastCaseStatus;
  String? gender;

  // إضافة متغيرات للعلامة والملاحظات وحالة التقييم
  String? lastDoctorComment;
  int? lastCaseMark;
  final TextEditingController _doctorMarkController = TextEditingController();
  final TextEditingController _doctorNoteController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController patientNameController = TextEditingController();
  final TextEditingController patientAddressController = TextEditingController();
  final TextEditingController patientPhoneController = TextEditingController();
  final TextEditingController diagnosisController = TextEditingController();

  // دالة تتحقق من دور المستخدم من قاعدة البيانات
  Future<bool> _isDoctor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final db = FirebaseDatabase.instance.ref();
    final snapshot = await db.child('users').child(user.uid).child('role').get();
    return snapshot.exists && snapshot.value == 'doctor';
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      patientNameController.text = data['patientName'] ?? '';
      patientAddressController.text = data['patientAddress'] ?? '';
      patientPhoneController.text = data['patientPhone'] ?? '';
      diagnosisController.text = data['diagnosis'] ?? '';
      lastCaseStatus = data['status'];
      gender = data['gender'];
      lastCaseMark = data['doctorGrade'] ?? data['mark'];
      lastDoctorComment = (data['doctorComment'] ?? '').toString();
      if (data['mark'] != null) _doctorMarkController.text = data['mark'].toString();
      if (data['doctorComment'] != null) _doctorNoteController.text = data['doctorComment'];
    }
  }

  @override
  void dispose() {
    patientNameController.dispose();
    patientAddressController.dispose();
    patientPhoneController.dispose();
    diagnosisController.dispose();
    _doctorMarkController.dispose();
    _doctorNoteController.dispose();
    super.dispose();
  }

  Future<void> submitCase() async {
    if (!_formKey.currentState!.validate()) return;
    if (gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار الجنس')));
      return;
    }
    setState(() => isSubmitting = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب تسجيل الدخول')));
      setState(() => isSubmitting = false);
      return;
    }
    try {
      final db = FirebaseDatabase.instance.ref();
      final caseData = {
        'studentId': user.uid,
        'groupId': widget.groupId,
        'courseId': widget.courseId,
        // ignore: unnecessary_type_check
        'caseNumber': widget.caseNumber is int ? widget.caseNumber : int.tryParse(widget.caseNumber.toString()),
        'caseType': widget.caseType,
        'patient': widget.patient,
        'patientName': patientNameController.text,
        'patientAddress': patientAddressController.text,
        'patientPhone': patientPhoneController.text,
        'diagnosis': diagnosisController.text,
        'gender': gender,
        'status': 'pending',
        'submittedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await db.child('pendingCases')
        .child(widget.groupId)
        .child(user.uid)
        .push()
        .set(caseData);
      setState(() => isSubmitting = false);
      if (widget.onSave != null) widget.onSave!(null);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الحالة للطبيب')));
    } catch (e) {
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء إرسال الحالة: $e')));
    }
  }

  Future<void> _onGradePressed() async {
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
      await db.child('pendingCases')
        .child(widget.groupId)
        .child(widget.initialData!['studentId'])
        .child(widget.initialData!['key'])
        .update({
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

  Widget _buildCaseStatusSection() {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    if (lastCaseStatus == 'graded') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'تم تقييم الحالة';
    } else if (lastCaseStatus == 'pending') {
      statusColor = Colors.orange;
      statusIcon = Icons.access_time;
      statusText = 'الحالة قيد المراجعة';
    } else if (lastCaseStatus == 'rejected') {
      statusColor = Colors.red;
      statusIcon = Icons.warning;
      statusText = 'الحالة بحاجة لتعديل';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.warning;
      statusText = 'الحالة بحاجة لتعديل';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(25),
border: Border.all(color: statusColor.withAlpha(77)),

      ),
      child: Row(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('نموذج جراحة الفم رقم ${widget.caseNumber}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // حالة التقييم - تظهر للجميع
              if (lastCaseStatus != null) _buildCaseStatusSection(),

              // حقول النموذج للطالب فقط (editable إذا لم يكن دكتور)
              FutureBuilder<bool>(
                future: _isDoctor(),
                builder: (context, snapshot) {
                  final isDoctor = snapshot.hasData && snapshot.data == true;
                  final readOnly = isDoctor;
                  return Column(
                    children: [
                      TextFormField(
                        controller: patientNameController,
                        decoration: const InputDecoration(labelText: 'اسم المريض'),
                        readOnly: readOnly,
                        validator: (value) => value?.isEmpty ?? true ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: patientAddressController,
                        decoration: const InputDecoration(labelText: 'عنوان المريض'),
                        readOnly: readOnly,
                        validator: (value) => value?.isEmpty ?? true ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: patientPhoneController,
                        decoration: const InputDecoration(labelText: 'رقم هاتف المريض'),
                        keyboardType: TextInputType.phone,
                        readOnly: readOnly,
                       
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: diagnosisController,
                        decoration: const InputDecoration(labelText: 'التشخيص'),
                        readOnly: readOnly,
                        validator: (value) => value?.isEmpty ?? true ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),
                      const Text('الجنس:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('ذكر'),
                              value: 'ذكر',
                              groupValue: gender,
                              onChanged: readOnly ? null : (val) => setState(() => gender = val),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('أنثى'),
                              value: 'أنثى',
                              groupValue: gender,
                              onChanged: readOnly ? null : (val) => setState(() => gender = val),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),

              // حقول التقييم للدكتور تظهر فقط إذا الحالة pending والمستخدم دكتور فعلياً من قاعدة البيانات
              FutureBuilder<bool>(
                future: _isDoctor(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done || !snapshot.hasData || !snapshot.data!) {
                    return const SizedBox.shrink();
                  }
                  if (lastCaseStatus == 'pending' && widget.initialData != null) {
                    return Column(
                      children: [
                        const Divider(height: 32),
                        const Text('تقييم الدكتور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _doctorMarkController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'العلامة (من 35)',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'الرجاء إدخال العلامة';
                            final mark = int.tryParse(value);
                            if (mark == null || mark < 0 || mark > 35) return 'العلامة يجب أن تكون بين 0 و 35';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _doctorNoteController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات الدكتور (مطلوبة)',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value == null || value.trim().isEmpty ? 'ملاحظات الدكتور مطلوبة' : null,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check),
                                label: const Text('حفظ التقييم'),
                                onPressed: isSubmitting ? null : _onGradePressed,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('لا يمكن إغلاق النافذة إلا بعد تقييم الحالة.',
                          style: TextStyle(color: Colors.orange, fontSize: 13)),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // زر الإرسال - يظهر فقط للطالب إذا لم تكن الحالة pending أو graded
              if (lastCaseStatus != 'pending' && lastCaseStatus != 'graded')
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : submitCase,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isSubmitting) ...[
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Text('حفظ وإرسال للطبيب', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

}
