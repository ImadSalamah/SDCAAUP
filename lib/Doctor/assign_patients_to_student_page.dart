import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AssignPatientsToStudentPage extends StatefulWidget {
  const AssignPatientsToStudentPage({super.key});

  @override
  State<AssignPatientsToStudentPage> createState() => _AssignPatientsToStudentPageState();
}

class _AssignPatientsToStudentPageState extends State<AssignPatientsToStudentPage> {
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');
  final DatabaseReference _studentPatientsRef = FirebaseDatabase.instance.ref('student_patients');

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _patients = [];
  String? _selectedStudentId;
  Set<String> _selectedPatientIds = {};
  bool _isLoading = true;
  bool _saving = false;
  String _searchQuery = '';
  String _patientSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() { _isLoading = true; });
    final usersSnapshot = await _usersRef.get();
    final users = usersSnapshot.value as Map<dynamic, dynamic>?;
    if (users == null) {
      setState(() { _isLoading = false; });
      return;
    }
    final students = <Map<String, dynamic>>[];
    final allUsers = <Map<String, dynamic>>[];
    users.forEach((key, value) {
      final map = Map<String, dynamic>.from(value);
      final role = map['role']?.toString() ?? map['type']?.toString();
      if (role == 'dental_student') {
        students.add({...map, 'id': key});
      }
      allUsers.add({...map, 'id': key});
    });
    setState(() {
      _students = students;
      _patients = allUsers;
      _isLoading = false;
    });
  }

  Future<void> _loadAssignedPatients(String studentId) async {
    setState(() { _isLoading = true; });
    final snapshot = await _studentPatientsRef.child(studentId).get();
    final data = snapshot.value as Map<dynamic, dynamic>?;
    setState(() {
      _selectedPatientIds = data != null ? data.keys.map((e) => e.toString()).toSet() : {};
      _isLoading = false;
    });
  }

  Future<void> _saveAssignments() async {
    if (_selectedStudentId == null) return;
    setState(() { _saving = true; });
    final updates = <String, dynamic>{};
    for (final patient in _patients) {
      final patientId = patient['id'].toString();
      updates['$_selectedStudentId/$patientId'] = _selectedPatientIds.contains(patientId) ? true : null;
    }
    await _studentPatientsRef.update(updates);
    setState(() { _saving = false; });
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التعيينات بنجاح')));
  }


  String _getFullName(Map<String, dynamic> user) {
    final first = user['firstName']?.toString().trim() ?? '';
    final father = user['fatherName']?.toString().trim() ?? '';
    final grandfather = user['grandfatherName']?.toString().trim() ?? '';
    final family = user['familyName']?.toString().trim() ?? '';
    return [first, father, grandfather, family].where((e) => e.isNotEmpty).join(' ');
  }

  List<Map<String, dynamic>> get _filteredStudents {
    if (_searchQuery.isEmpty) return _students;
    final query = _searchQuery.toLowerCase();
    return _students.where((student) {
      final fullName = _getFullName(student).toLowerCase();
      final universityId = (student['universityId'] ?? student['studentId'] ?? '').toString().toLowerCase();
      return fullName.contains(query) || universityId.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredPatients {
    List<Map<String, dynamic>> filtered;
    if (_patientSearchQuery.isEmpty) {
      filtered = List<Map<String, dynamic>>.from(_patients);
    } else {
      final query = _patientSearchQuery.toLowerCase();
      filtered = _patients.where((p) {
        final name = _getFullName(p).toLowerCase();
        final idNumber = (p['idNumber'] ?? '').toString().toLowerCase();
        return name.contains(query) || idNumber.contains(query);
      }).toList();
    }
    // ترتيب المختارين أولاً
    filtered.sort((a, b) {
      final aSelected = _selectedPatientIds.contains(a['id'].toString()) ? 0 : 1;
      final bSelected = _selectedPatientIds.contains(b['id'].toString()) ? 0 : 1;
      return aSelected.compareTo(bSelected);
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2A7A94);
    final selectedStudent = _students.firstWhere(
      (s) => s['id'] == _selectedStudentId,
      orElse: () => {},
    );
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: primaryColor,
          secondary: Colors.green.shade400,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('تعيين المرضى للطالب'), backgroundColor: primaryColor),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('اختر الطالب:', style: TextStyle(fontWeight: FontWeight.bold)),
                        // زر إزالة جميع التعيينات تم حذفه من صفحة الدكتور
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'ابحث باسم الطالب أو الرقم الجامعي',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                          // إذا الطالب المختار لم يعد موجودًا في نتائج البحث، ألغِ التحديد تلقائيًا
                          if (_selectedStudentId != null && !_filteredStudents.any((s) => s['id'] == _selectedStudentId)) {
                            _selectedStudentId = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _selectedStudentId == null
                          ? ListView(
                              children: _filteredStudents.map((student) {
                                final name = _getFullName(student);
                                final universityId = student['universityId'] ?? student['studentId'] ?? '';
                                return ListTile(
                                  title: Text('${name.isNotEmpty ? name : 'بدون اسم'}${universityId != '' ? ' - $universityId' : ''}'),
                                  leading: const Icon(Icons.person),
                                  onTap: () {
                                    setState(() {
                                      _selectedStudentId = student['id'];
                                    });
                                    _loadAssignedPatients(student['id']);
                                  },
                                );
                              }).toList(),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.arrow_back),
                                      onPressed: () => setState(() => _selectedStudentId = null),
                                    ),
                                    Text(
                                      _getFullName(selectedStudent),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    if ((selectedStudent['universityId'] ?? selectedStudent['studentId']) != null)
                                      Text(
                                        '${selectedStudent['universityId'] ?? selectedStudent['studentId']}',
                                        style: const TextStyle(color: Colors.grey),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TextField(
                                        decoration: InputDecoration(
                                          hintText: 'ابحث عن مريض بالاسم أو رقم الهوية',
                                          prefixIcon: const Icon(Icons.search),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                                        ),
                                        onChanged: (val) => setState(() => _patientSearchQuery = val),
                                      ),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: ListView(
                                          children: _filteredPatients.map((patient) {
                                            final patientId = patient['id'].toString();
                                            final name = _getFullName(patient);
                                            return CheckboxListTile(
                                              value: _selectedPatientIds.contains(patientId),
                                              onChanged: (checked) {
                                                setState(() {
                                                  if (checked == true) {
                                                    _selectedPatientIds.add(patientId);
                                                  } else {
                                                    _selectedPatientIds.remove(patientId);
                                                  }
                                                });
                                              },
                                              title: Text(name.isNotEmpty ? name : 'بدون اسم'),
                                              subtitle: Text('رقم الهوية: ${patient['idNumber'] ?? ''}'),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: ElevatedButton(
                                    onPressed: _saving ? null : _saveAssignments,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: _saving ? const CircularProgressIndicator() : const Text('حفظ التعيينات'),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
