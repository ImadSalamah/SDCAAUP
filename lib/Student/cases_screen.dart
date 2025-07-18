// ignore_for_file: deprecated_member_use, unnecessary_to_list_in_spreads, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../forms/paedodontics_form.dart';
import '../forms/surgery_form.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../dashboard/student_dashboard.dart';

class CasesScreen extends StatefulWidget {
  final String groupId;
  final String courseId;
  final String courseName;
  final int requiredCases;

  const CasesScreen({
    required this.groupId,
    required this.courseId,
    required this.courseName,
    required this.requiredCases,
    super.key,
  });

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _submittedCases = [];
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Map<String, dynamic>? _selectedPatient;

  // قائمة المواد ومتطلباتها (ثابتة في الكود)
  final Map<String, List<Map<String, dynamic>>> _courseCases = {
    // طب أسنان الأطفال
    '080114140': [
      for (int i = 1; i <= 3; i++) {'type': 'history', 'number': i},
      for (int i = 1; i <= 6; i++) {'type': 'fissure', 'number': i},
    ],
    // مثال: مادة جراحة الفم
    '080114141': [
      for (int i = 1; i <= 4; i++) {'type': 'simpleSurgery', 'number': i},
    ],
    // أضف مواد أخرى هنا بنفس الطريقة
  };

  List<Map<String, dynamic>> get _currentCourseCases => _courseCases[widget.courseId] ?? [];

  @override
  void initState() {
    super.initState();
    _loadSubmittedCases();
  }

  Future<void> _loadSubmittedCases() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      if (widget.courseId == '080114140') {
        final snapshot = await _dbRef
            .child('paedodonticsCases')
            .orderByChild('studentId')
            .equalTo(user.uid)
            .get();
        final List<Map<String, dynamic>> cases = [];
        if (snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          data.forEach((key, value) {
            cases.add({'id': key, ...Map<String, dynamic>.from(value as Map)});
          });
        }
        setState(() {
          _submittedCases = cases;
        });
      } else {
        final snapshot = await _dbRef
            .child('pendingCases')
            .child(widget.groupId)
            .child(user.uid)
            .get();
        final List<Map<String, dynamic>> cases = [];
        if (snapshot.exists) {
          for (var element in snapshot.children) {
            cases.add({
              'id': element.key,
              ...Map<String, dynamic>.from(element.value as Map),
            });
          }
        }
        setState(() {
          _submittedCases = cases;
        });
      }
    } catch (e) {
      debugPrint('Error loading cases: $e');
      setState(() {});
    }
  }

  Future<void> _searchPatients(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final usersSnap = await _dbRef.child('users').get();
      final results = <Map<String, dynamic>>[];
      final seenIds = <String>{};

      if (usersSnap.exists) {
        final allUsers = usersSnap.value as Map<dynamic, dynamic>;
        allUsers.forEach((userId, userData) {
          final user = Map<String, dynamic>.from(userData as Map);
          String fullName = user['fullName']?.toString() ?? '';
          if (fullName.trim().isEmpty) {
            final firstName = user['firstName']?.toString() ?? '';
            final fatherName = user['fatherName']?.toString() ?? '';
            final grandfatherName = user['grandfatherName']?.toString() ?? '';
            final familyName = user['familyName']?.toString() ?? '';
            fullName = [firstName, fatherName, grandfatherName, familyName]
                .where((part) => part.isNotEmpty)
                .join(' ');
          }
          final idNumber = user['idNumber']?.toString() ?? '';
          final studentId = user['studentId']?.toString() ?? '';
          if (fullName.toLowerCase().contains(query.toLowerCase()) ||
              idNumber.contains(query) ||
              studentId.contains(query)) {
            if (!seenIds.contains(idNumber)) {
              results.add({'id': userId, ...user, 'fullName': fullName});
              seenIds.add(idNumber);
            }
          }
        });
      }

      setState(() => _searchResults = results);
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _selectPatient(Map<String, dynamic> patient) {
    setState(() {
      _selectedPatient = patient;
      _searchController.clear();
      _searchResults = [];
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedPatient = null;
    });
  }

  Map<String, Map<int, Map<String, dynamic>>> get _submittedPaedoCasesByTypeAndNumber {
    final map = <String, Map<int, Map<String, dynamic>>>{};
    for (final c in _submittedCases) {
      final type = c['caseType'] ?? c['type'];
      final numberRaw = c['caseNumber'];
      int? number;
      if (numberRaw is int) {
        number = numberRaw;
      } else if (numberRaw is String) {
        number = int.tryParse(numberRaw);
      }
      if (type != null && number != null) {
        map[type] ??= {};
        map[type]![number] = c;
      }
    }
    return map;
  }

  void _addNewPaedoCase(String type, int number) {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار مريض أولاً')),
      );
      return;
    }
    Widget formPage;
    if (widget.courseId == '080114140') {
      formPage = PaedodonticsForm(
        groupId: widget.groupId,
        caseNumber: number,
        patient: _selectedPatient!,
        courseId: widget.courseId,
        onSave: (grade) => _loadSubmittedCases(),
        caseType: type,
      );
    } else if (widget.courseId == '080114141') {
      formPage = SurgeryForm(
        groupId: widget.groupId,
        caseNumber: number,
        patient: _selectedPatient!,
        courseId: widget.courseId,
        onSave: (grade) => _loadSubmittedCases(),
        caseType: type,
      );
    } else {
      formPage = const Scaffold(body: Center(child: Text('لا يوجد فورم لهذه المادة')));
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => formPage,
      ),
    ).then((_) => _clearSelection());
  }

  Widget _buildPaedodonticsCaseCard(
    String type,
    int number,
    Map<String, dynamic>? submitted,
    bool canAdd,
  ) {
    final isCompleted = submitted != null && submitted['status'] == 'graded';
    final isPending = submitted != null && submitted['status'] == 'pending';
    final isRejected = submitted != null && submitted['status'] == 'rejected';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: isCompleted
            ? Colors.blue[50]
            : isPending
                ? Colors.orange[50]
                : isRejected
                    ? Colors.red[50]
                    : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: (isCompleted || isPending || isRejected)
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaedodonticsForm(
                        groupId: widget.groupId,
                        caseNumber: number,
                        patient: submitted['patient'] != null
                            ? Map<String, dynamic>.from(submitted['patient'])
                            : {},
                        courseId: widget.courseId,
                        onSave: (grade) => _loadSubmittedCases(),
                        caseType: type,
                        initialData: submitted,
                      ),
                    ),
                  );
                }
              : canAdd
                  ? () => _addNewPaedoCase(type, number)
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('يجب إكمال الحالة السابقة أولاً')),
                      );
                    },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Row(
              children: [
                Icon(
                  isCompleted
                      ? Icons.assignment_turned_in
                      : isPending
                          ? Icons.hourglass_top
                          : isRejected
                              ? Icons.cancel
                              : Icons.assignment,
                  size: 40,
                  color: isCompleted
                      ? Colors.green
                      : isPending
                          ? Colors.orange
                          : isRejected
                              ? Colors.red
                              : Colors.grey,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (type == 'history'
                                  ? (Localizations.localeOf(context).languageCode == 'ar'
                                      ? 'حالة تاريخ وفحص #$number'
                                      : 'History & Exam Case #$number')
                                  : (Localizations.localeOf(context).languageCode == 'ar'
                                      ? 'حالة سد شقوق #$number'
                                      : 'Fissure Sealant Case #$number')
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          if (isCompleted && submitted['doctorGrade'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.grade,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${submitted['doctorGrade']}',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isCompleted
                            ? 'مكتملة'
                            : isPending
                                ? 'قيد المراجعة'
                                : isRejected
                                    ? 'مرفوضة'
                                    : 'غير مكتملة',
                        style: TextStyle(
                          color: isCompleted
                              ? Colors.green
                              : isPending
                                  ? Colors.orange
                                  : isRejected
                                      ? Colors.red
                                      : Colors.grey,
                        ),
                      ),
                      if (submitted != null && submitted['patientName'] != null)
                        Text('المريض: ${submitted['patientName']}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveBody(BuildContext context, bool isLargeScreen) {
    final courseCases = _currentCourseCases;
    final submittedMap = _submittedPaedoCasesByTypeAndNumber;
    if (courseCases.isNotEmpty) {
      return Row(
        children: [
          if (isLargeScreen)
            Container(
              width: 250,
              color: primaryColor.withOpacity(0.08),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Icon(Icons.assignment, size: 48, color: primaryColor),
                  const SizedBox(height: 10),
                  Text('حالات الطالب',
                      style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.home, color: primaryColor),
                    title: const Text('الرئيسية'),
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const StudentDashboard()),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'ابحث عن مريض (بالاسم أو رقم الهوية)',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _isSearching
                              ? const CircularProgressIndicator()
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: _searchPatients,
                      ),
                      if (_searchResults.isNotEmpty)
                        Container(
                          height: 200,
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final patient = _searchResults[index];
                              return ListTile(
                                title: Text(patient['fullName'] ?? 'غير معروف'),
                                subtitle: Text(
                                    'هوية: ${patient['idNumber'] ?? 'غير معروف'} - جامعي: ${patient['studentId'] ?? 'غير معروف'}'),
                                onTap: () => _selectPatient(patient),
                              );
                            },
                          ),
                        ),
                      if (_selectedPatient != null)
                        Card(
                          margin: const EdgeInsets.only(top: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('المريض المختار:',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: primaryColor)),
                                      Text(_selectedPatient!['fullName'] ?? ''),
                                      Text(
                                          'هوية: ${_selectedPatient!['idNumber'] ?? 'غير معروف'}'),
                                      if (_selectedPatient!['studentId'] != null)
                                        Text(
                                            'جامعي: ${_selectedPatient!['studentId']}'),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: _clearSelection,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: courseCases.length,
                    itemBuilder: (context, index) {
                      final item = courseCases[index];
                      final type = item['type'] as String;
                      final number = item['number'] as int;
                      final submitted = submittedMap[type]?[number];
                      bool canAdd = false;

                      if (submitted == null ||
                          (submitted['status'] != 'graded' &&
                              submitted['status'] != 'pending')) {
                        if (index == 0) {
                          canAdd = true;
                        } else {
                          final prev = courseCases[index - 1];
                          final prevType = prev['type'] as String;
                          final prevNumber = prev['number'] as int;
                          final prevSubmitted = submittedMap[prevType]?[prevNumber];
                          canAdd = prevSubmitted != null &&
                              prevSubmitted['status'] == 'graded';
                        }
                      }

                      return _buildPaedodonticsCaseCard(
                        type,
                        number,
                        submitted,
                        canAdd,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    // في حال لم يتم تعريف المادة
    return const Center(child: Text('لا يوجد متطلبات لهذه المادة'));
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width >= 900;
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    
    return Directionality(
      textDirection: langProvider.currentLocale.languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.courseName, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: primaryColor,
          centerTitle: true,
        ),
        drawer: !isLargeScreen ? _buildDrawer() : null,
        endDrawer: !isLargeScreen && langProvider.currentLocale.languageCode == 'en' 
            ? _buildDrawer() 
            : null,
        body: _buildResponsiveBody(context, isLargeScreen),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: primaryColor),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment, size: 48, color: Colors.white),
                SizedBox(height: 10),
                Text('حالات الطالب',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.home, color: primaryColor),
            title: const Text('الرئيسية'),
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const StudentDashboard()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DynamicFormPage extends StatefulWidget {
  final String groupId;
  final String courseId;
  final int formIndex;
  final Map<String, dynamic> form;
  final Map<String, dynamic>? patient;
  final VoidCallback? onSave;
  const _DynamicFormPage({
    required this.groupId,
    required this.courseId,
    required this.formIndex,
    // ignore: unused_element_parameter
    required this.form, this.patient, this.onSave,
  });

  @override
  State<_DynamicFormPage> createState() => _DynamicFormPageState();
}

class _DynamicFormPageState extends State<_DynamicFormPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _values = {};

  @override
  Widget build(BuildContext context) {
    final fieldsRaw = widget.form['fields'];
    if (fieldsRaw == null || fieldsRaw is! List) {
      debugPrint('Form fields are null or not a List! Value: $fieldsRaw');
      return Scaffold(
        appBar: AppBar(title: Text('تعبئة النموذج رقم ${widget.formIndex + 1}')),
        body: const Center(child: Text('لا يوجد حقول لهذا النموذج')),
      );
    }
    final fields = fieldsRaw;
    
    return Scaffold(
      appBar: AppBar(title: Text('تعبئة النموذج رقم ${widget.formIndex + 1}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (widget.patient != null)
                Card(
                  child: ListTile(
                    title: Text('المريض: ${widget.patient?['fullName'] ?? ''}'),
                    subtitle: Text('هوية: ${widget.patient?['idNumber'] ?? 'غير معروف'}'),
                  ),
                ),
              ...fields.asMap().entries.map<Widget>((entry) {
                final i = entry.key;
                final field = entry.value;
                if (field == null || field is! Map) {
                  debugPrint('Field at index $i is null or not a Map! Value: $field');
                  return const SizedBox.shrink();
                }
                final type = field['type']?.toString() ?? '';
                final label = field['label']?.toString() ?? '';
                if (type.isEmpty || label.isEmpty) {
                  debugPrint('Field at index $i missing type or label! Field: $field');
                  return const SizedBox.shrink();
                }
                
                if (type == 'text') {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: label,
                        border: const OutlineInputBorder(),
                      ),
                      onSaved: (val) => _values[label] = val,
                      validator: (val) => (val == null || val.isEmpty) ? 'مطلوب' : null,
                    ),
                  );
                } else if (type == 'number') {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: label,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onSaved: (val) => _values[label] = val,
                      validator: (val) => (val == null || val.isEmpty) ? 'مطلوب' : null,
                    ),
                  );
                } else if (type == 'checkbox') {
                  final optionsRaw = field['options'];
                  final options = (optionsRaw is List) ? optionsRaw : [];
                  if (options.isEmpty) {
                    debugPrint('Checkbox field at $i has empty or invalid options: $optionsRaw');
                  }
                  final selected = <String>{};
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ...options.map<Widget>((opt) {
                          final optStr = opt?.toString() ?? '';
                          return CheckboxListTile(
                            title: Text(optStr),
                            value: selected.contains(optStr),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  selected.add(optStr);
                                } else {
                                  selected.remove(optStr);
                                }
                                _values[label] = selected.toList();
                              });
                            },
                          );
                        }).toList(),
                      ],
                    ),
                  );
                } else if (type == 'radio') {
                  final optionsRaw = field['options'];
                  final options = (optionsRaw is List) ? optionsRaw : [];
                  if (options.isEmpty) {
                    debugPrint('Radio field at $i has empty or invalid options: $optionsRaw');
                  }
                  String? selected;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ...options.map<Widget>((opt) {
                          final optStr = opt?.toString() ?? '';
                          return RadioListTile<String>(
                            title: Text(optStr),
                            value: optStr,
                            groupValue: selected,
                            onChanged: (val) {
                              setState(() {
                                selected = val;
                                _values[label] = val;
                              });
                            },
                          );
                        }).toList(),
                      ],
                    ),
                  );
                }
                debugPrint('Unknown field type "$type" at $i');
                return const SizedBox.shrink();
              }).toList(),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF2A7A94),
                ),
                child: const Text('حفظ وإرسال للطبيب', 
                    style: TextStyle(fontSize: 18)),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;
                    
                    try {
                      final data = {
                        'studentId': user.uid,
                        'groupId': widget.groupId,
                        'courseId': widget.courseId,
                        'formIndex': widget.formIndex,
                        'fields': _values,
                        'patient': widget.patient,
                        'status': 'pending',
                        'submittedAt': DateTime.now().toIso8601String(),
                      };
                      
                      await FirebaseDatabase.instance
                          .ref()
                          .child('pendingCases')
                          .child(widget.groupId)
                          .child(user.uid)
                          .push()
                          .set(data);
                          
                      if (widget.onSave != null) widget.onSave!();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم إرسال النموذج للطبيب للموافقة والتقييم')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('حدث خطأ: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}