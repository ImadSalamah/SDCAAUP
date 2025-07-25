// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../Doctor/doctor_sidebar.dart';


class ClinicalProceduresForm extends StatefulWidget {
  final String uid;
  const ClinicalProceduresForm({super.key, required this.uid});

  @override
  State<ClinicalProceduresForm> createState() => _ClinicalProceduresFormState();
}

class _ClinicalProceduresFormState extends State<ClinicalProceduresForm> {
  final DatabaseReference _clinicalProceduresRef = FirebaseDatabase.instance.ref('clinical_procedures');
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dateOfOperationController = TextEditingController();
  final TextEditingController _typeOfOperationController = TextEditingController();
  final TextEditingController _toothNoController = TextEditingController();
  String? _selectedClinic;
  final TextEditingController _studentNameController = TextEditingController();
  final TextEditingController _supervisorNameController = TextEditingController();
  final TextEditingController _dateOfSecondVisitController = TextEditingController();
  List<Map<String, dynamic>> _students = [];
  String _studentSearchQuery = '';
  // متغيرات المريض
  final TextEditingController _patientNameController = TextEditingController();
  String _patientSearchQuery = '';
  List<Map<String, dynamic>> _patients = [];
  @override
  void initState() {
    super.initState();
    _loadStudents();
    _fetchCurrentDoctorName();
    _loadPatients();
  }

  Future<void> _loadStudents() async {
    final usersSnapshot = await _usersRef.get();
    final users = usersSnapshot.value as Map<dynamic, dynamic>?;
    if (users == null) return;
    final students = <Map<String, dynamic>>[];
    final patients = <Map<String, dynamic>>[];
    users.forEach((key, value) {
      final map = Map<String, dynamic>.from(value);
      final role = map['role']?.toString() ?? map['type']?.toString();
      if (role == 'dental_student') {
        students.add({...map, 'id': key});
      } else {
        patients.add({...map, 'id': key});
      }
    });
    setState(() {
      _students = students;
      _patients = patients;
    });
  }

  // تحميل المرضى (كل المستخدمين ما عدا الطلاب)
  Future<void> _loadPatients() async {
    final usersSnapshot = await _usersRef.get();
    final users = usersSnapshot.value as Map<dynamic, dynamic>?;
    if (users == null) return;
    final patients = <Map<String, dynamic>>[];
    users.forEach((key, value) {
      final map = Map<String, dynamic>.from(value);
      final role = map['role']?.toString() ?? map['type']?.toString();
      if (role != 'dental_student') {
        patients.add({...map, 'id': key});
      }
    });
    setState(() {
      _patients = patients;
    });
  }

  String _getFullName(Map<String, dynamic> user) {
    final first = user['firstName']?.toString().trim() ?? '';
    final father = user['fatherName']?.toString().trim() ?? '';
    final grandfather = user['grandfatherName']?.toString().trim() ?? '';
    final family = user['familyName']?.toString().trim() ?? '';
    return [first, father, grandfather, family].where((e) => e.isNotEmpty).join(' ');
  }

  List<Map<String, dynamic>> get _filteredStudents {
    if (_studentSearchQuery.isEmpty) return _students;
    final query = _studentSearchQuery.toLowerCase();
    return _students.where((student) {
      final fullName = _getFullName(student).toLowerCase();
      final universityId = (student['universityId'] ?? student['studentId'] ?? '').toString().toLowerCase();
      return fullName.contains(query) || universityId.contains(query);
    }).toList();
  }

  // فلترة المرضى حسب البحث
  List<Map<String, dynamic>> get _filteredPatients {
    if (_patientSearchQuery.isEmpty) return _patients;
    final query = _patientSearchQuery.toLowerCase();
    return _patients.where((patient) {
      final fullName = _getFullName(patient).toLowerCase();
      final idNumber = (patient['idNumber'] ?? '').toString().toLowerCase();
      return fullName.contains(query) || idNumber.contains(query);
    }).toList();
  }
  // اسم الدكتور الحالي
  String? _currentDoctorName;

  Future<void> _fetchCurrentDoctorName() async {
    // جلب اسم الدكتور باستخدام uid الممرر للصفحة
    try {
      final doctorSnapshot = await _usersRef.child(widget.uid).get();
      if (doctorSnapshot.exists) {
        final doctorData = doctorSnapshot.value as Map<dynamic, dynamic>?;
        if (doctorData != null) {
          final fullName = doctorData['fullName']?.toString().trim() ?? '';
          setState(() {
            _currentDoctorName = fullName;
            _supervisorNameController.text = _currentDoctorName!;
          });
        }
      } else {
        setState(() {
          _currentDoctorName = '';
          _supervisorNameController.text = '';
        });
      }
    } catch (e) {
      // في حال وجود خطأ، لا تفعل شيء
    }
  }

  // تم دمج دالة initState في الأعلى

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF2A7A94);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: const Text('Clinical Procedures Form', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: DoctorSidebar(
        primaryColor: const Color(0xFF2A7A94),
        accentColor: Colors.teal,
        userName: _currentDoctorName ?? '',
        userImageUrl: null,
        onLogout: () {
          // يمكنك تنفيذ تسجيل الخروج هنا
        },
        parentContext: context,
        collapsed: false,
        translate: (ctx, txt) => txt,
        doctorUid: widget.uid,
      ),
      body: Container(
        color: primaryColor.withAlpha(15),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
              // اختيار المريض أولاً
              TextFormField(
                controller: _patientNameController,
                decoration: const InputDecoration(
                  labelText: 'Patient Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                onChanged: (value) {
                  setState(() {
                    _patientSearchQuery = value;
                  });
                },
              ),
              // قائمة اقتراحات المرضى
              if (_patientSearchQuery.isNotEmpty && _filteredPatients.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: _filteredPatients.map((patient) {
                      final name = _getFullName(patient);
                      final idNumber = patient['idNumber'] ?? '';
                      return ListTile(
                        title: Text('${name.isNotEmpty ? name : 'بدون اسم'}${idNumber != '' ? ' - $idNumber' : ''}'),
                        leading: const Icon(Icons.person),
                        onTap: () {
                          setState(() {
                            _patientNameController.text = name.isNotEmpty ? name : 'بدون اسم';
                            _patientSearchQuery = '';
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  FocusScope.of(context).requestFocus(FocusNode());
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    _dateOfOperationController.text = picked.toIso8601String().split('T')[0];
                  }
                },
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _dateOfOperationController,
                    decoration: const InputDecoration(
                      labelText: 'Date of Operation',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _typeOfOperationController,
                decoration: const InputDecoration(
                  labelText: 'Type of Operation',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _toothNoController,
                decoration: const InputDecoration(
                  labelText: 'Tooth No.',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Clinic Name',
                  border: OutlineInputBorder(),
                ),
                value: _selectedClinic,
                items: List.generate(11, (i) {
                  final letter = String.fromCharCode(65 + i); // A-K
                  return DropdownMenuItem(
                    value: letter,
                    child: Text('Clinic $letter'),
                  );
                }),
                onChanged: (val) => setState(() => _selectedClinic = val),
                validator: (value) => value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _studentNameController,
                decoration: const InputDecoration(
                  labelText: 'Student Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                onChanged: (value) {
                  setState(() {
                    _studentSearchQuery = value;
                  });
                },
              ),
              // قائمة اقتراحات الطلاب
              if (_studentSearchQuery.isNotEmpty && _filteredStudents.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: _filteredStudents.map((student) {
                      final name = _getFullName(student);
                      final universityId = student['universityId'] ?? student['studentId'] ?? '';
                      return ListTile(
                        title: Text('${name.isNotEmpty ? name : 'بدون اسم'}${universityId != '' ? ' - $universityId' : ''}'),
                        leading: const Icon(Icons.person),
                        onTap: () {
                          setState(() {
                            _studentNameController.text = name.isNotEmpty ? name : 'بدون اسم';
                            _studentSearchQuery = '';
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 16),
              _currentDoctorName == null
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          CircularProgressIndicator(strokeWidth: 2),
                          SizedBox(width: 12),
                          Text('جاري جلب اسم المشرف...'),
                        ],
                      ),
                    )
                  : TextFormField(
                      controller: _supervisorNameController,
                      decoration: const InputDecoration(
                        labelText: 'Supervisor Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      readOnly: true,
                    ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  FocusScope.of(context).requestFocus(FocusNode());
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    _dateOfSecondVisitController.text = picked.toIso8601String().split('T')[0];
                  }
                },
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _dateOfSecondVisitController,
                    decoration: const InputDecoration(
                      labelText: 'Date of Second Visit',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _currentDoctorName == null || _currentDoctorName!.isEmpty
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            // حفظ بيانات النموذج مع اسم المريض و idNumber و id (users key)
                            final selectedPatient = _patients.firstWhere(
                              (p) => _getFullName(p) == _patientNameController.text,
                              orElse: () => {},
                            );
                            final idNumber = selectedPatient['idNumber'] ?? '';
                            final patientId = selectedPatient['id'] ?? '';
                            final data = {
                              'patientName': _patientNameController.text,
                              'patientIdNumber': idNumber,
                              'patientId': patientId,
                              'dateOfOperation': _dateOfOperationController.text,
                              'typeOfOperation': _typeOfOperationController.text,
                              'toothNo': _toothNoController.text,
                              'clinicName': _selectedClinic ?? '',
                              'studentName': _studentNameController.text,
                              'supervisorName': _supervisorNameController.text,
                              'dateOfSecondVisit': _dateOfSecondVisitController.text,
                              'createdAt': DateTime.now().toIso8601String(),
                            };
                            await _clinicalProceduresRef.push().set(data);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Form submitted and saved!')),
                            );
                            Navigator.of(context).pop();
                          }
                        },
                  child: _currentDoctorName == null || _currentDoctorName!.isEmpty
                      ? const Text('جاري جلب اسم المشرف...', style: TextStyle(fontSize: 16))
                      : const Text('Submit', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
     ), );
  }
}
