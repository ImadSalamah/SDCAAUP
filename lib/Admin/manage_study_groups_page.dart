import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_sidebar.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class AdminManageGroupsPage extends StatefulWidget {
  final String? userName;
  final String? userImageUrl;
  final String Function(BuildContext, String) translate;
  final VoidCallback onLogout;

  const AdminManageGroupsPage({
    super.key,
    this.userName,
    this.userImageUrl,
    required this.translate,
    required this.onLogout,
  });

  @override
  AdminManageGroupsPageState createState() => AdminManageGroupsPageState();
}

class AdminManageGroupsPageState extends State<AdminManageGroupsPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();
  String? _selectedCourse;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _selectedClinic;
  List<String> _selectedDays = [];
  List<String> _selectedDoctorIds = [];
  List<String> _selectedStudents = [];
  String? _groupNumber;
  String? _editingGroupId;

  bool isSidebarOpen = false;
  bool showSidebarButton = true;

  // قوائم البيانات

  final List<String> _clinics =
      List.generate(11, (index) => 'Clinic ${String.fromCharCode(65 + index)}');
  final List<String> _days = [
    'السبت',
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس'
  ];
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  // استبدل قائمة المواد لتكون ثابتة
  final List<Map<String, dynamic>> _subjects = [
    {'id': '1', 'name': 'Paedodontics I', 'code': '080114140'},
    {'id': '2', 'name': 'Orthodontics', 'code': '080114141'},
  ];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _groupNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDoctors();
    _loadStudents();
    //_loadSubjects(); // لم يعد هناك تحميل ديناميكي
    _searchController.addListener(_filterStudents);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _groupNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    try {
      final snapshot = await _dbRef
          .child('users')
          .orderByChild('role')
          .equalTo('doctor')
          .get();
      if (snapshot.exists) {
        setState(() {
          _doctors = [];
          final data = snapshot.value as Map<dynamic, dynamic>;
          data.forEach((key, value) {
            _doctors.add({
              'id': key.toString(),
              'name': value['fullName']?.toString() ?? 'غير معروف',
              
            });
          });
        });
      }
    } catch (e) {
      debugPrint('Error loading doctors: $e');
    }
  }

  Future<void> _loadStudents() async {
    try {
      final snapshot = await _dbRef.child('students').get();
      if (snapshot.exists) {
        setState(() {
          _allStudents = [];
          _filteredStudents = [];
          final data = snapshot.value as Map<dynamic, dynamic>;
          data.forEach((key, value) {
            _allStudents.add({
              'id': key.toString(),
              'uid': value['uid']?.toString() ?? '',
              'name': value['fullName']?.toString() ?? 'طالب غير معروف',
              'studentId': value['studentId']?.toString() ?? 'غير معروف',
              'email': value['email']?.toString() ?? '',
            });
          });
          _filteredStudents = List.from(_allStudents);
        });
      }
    } catch (e) {
      debugPrint('Error loading students: $e');
    }
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStudents = _allStudents.where((student) {
        final name = student['name'].toString().toLowerCase();
        final studentId = student['studentId'].toString().toLowerCase();
        final email = student['email'].toString().toLowerCase();
        return name.contains(query) ||
            studentId.contains(query) ||
            email.contains(query);
      }).toList();
    });
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _toggleDay(String day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  void _editGroup(Map group, String groupId) {
    setState(() {
      _editingGroupId = groupId;
      _selectedCourse = group['courseName'];
      // دعم أكثر من طبيب
      if (group['doctorIds'] != null && group['doctorIds'] is List) {
        _selectedDoctorIds = List<String>.from(group['doctorIds']);
      } else if (group['doctorId'] != null) {
        _selectedDoctorIds = [group['doctorId']];
      } else {
        _selectedDoctorIds = [];
      }
      _selectedClinic = group['clinic'];

      // تحويل وقت البداية
      final startParts = group['startTime'].toString().split(':');
      _startTime = TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      );

      // تحويل وقت النهاية
      final endParts = group['endTime'].toString().split(':');
      _endTime = TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      );

      _selectedDays = List<String>.from(group['days']);
      _selectedStudents =
          List<String>.from((group['students'] as Map).keys.toList());
      _groupNumber = group['groupNumber'];
      _groupNumberController.text = _groupNumber ?? '';
    });
  }

  Future<bool> _isStudentInAnotherGroup(String studentUid, String courseId, [String? currentGroupId]) async {
    final snapshot = await _dbRef.child('studyGroups').get();
    if (!snapshot.exists) return false;
    final data = snapshot.value as Map<dynamic, dynamic>;
    for (final entry in data.entries) {
      final group = entry.value as Map;
      final groupId = entry.key.toString();
      if (currentGroupId != null && groupId == currentGroupId) continue; // تجاهل الشعبة الحالية عند التعديل
      if ((group['courseId'] == courseId) &&
          (group['students'] as Map?)?.containsKey(studentUid) == true) {
        return true;
      }
    }
    return false;
  }

  Future<void> _saveGroup() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // تحقق من تكرار الطالب في نفس المادة
      final courseId = _selectedCourse!.split('(').last.replaceAll(')', '').trim();
      for (var studentId in _selectedStudents) {
        final student = _allStudents.firstWhere((s) => s['id'] == studentId);
        final studentUid = student['uid'];
        final exists = await _isStudentInAnotherGroup(studentUid, courseId, _editingGroupId);
        if (exists) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('الطالب ${student['name']} مسجل بالفعل في شعبة أخرى لنفس المادة!')),
          );
          return;
        }
      }

      if (_selectedDays.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب اختيار يوم واحد على الأقل')),
        );
        return;
      }

      if (_selectedStudents.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب اختيار طالب واحد على الأقل')),
        );
        return;
      }

      if (_groupNumberController.text.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب إدخال رقم الشعبة')),
        );
        return;
      }

      try {
        final user = _auth.currentUser;
        if (user == null) return;

        // جلب بيانات الأطباء المختارين
        final selectedDoctors = _doctors.where((doc) => _selectedDoctorIds.contains(doc['id'])).toList();
        final doctorNames = selectedDoctors.map((doc) => doc['name']).toList();

        // تحويل الطلاب المختارين إلى Map باستخدام uid
        final studentsMap = {};
        for (var studentId in _selectedStudents) {
          final student = _allStudents.firstWhere((s) => s['id'] == studentId);
          studentsMap[student['uid']] = {
            'name': student['name'],
            'studentId': student['studentId'],
            'email': student['email']
          };
        }

        final groupData = {
          'courseName': _selectedCourse,
          'courseId':
              _selectedCourse!.split('(').last.replaceAll(')', '').trim(),
          'doctorIds': _selectedDoctorIds,
          'doctorNames': doctorNames,
          'startTime':
              '${_startTime!.hour}:${_startTime!.minute.toString().padLeft(2, '0')}',
          'endTime':
              '${_endTime!.hour}:${_endTime!.minute.toString().padLeft(2, '0')}',
          'clinic': _selectedClinic,
          'days': _selectedDays,
          'students': studentsMap,
          'groupNumber': _groupNumberController.text,
          'createdBy': user.uid,
          'updatedAt': DateTime.now().toString(),
        };

        String courseId = _selectedCourse!.split('(').last.replaceAll(')', '').trim();

        // حفظ الشعبة
        if (_editingGroupId == null) {
          groupData['createdAt'] = DateTime.now().toString();
          final newRef = _dbRef.child('studyGroups').push();
          await newRef.set(groupData);
        } else {
          await _dbRef.child('studyGroups/$_editingGroupId').update(groupData);
        }

        // تحديث student_case_flags
        final caseFlagsRef = _dbRef.child('student_case_flags/$courseId');
        final caseFlagsSnapshot = await caseFlagsRef.get();
        Map<dynamic, dynamic> caseFlags = {};
        if (caseFlagsSnapshot.exists) {
          caseFlags = caseFlagsSnapshot.value as Map<dynamic, dynamic>;
        }

        // أضف الطلاب الجدد فقط
        for (var studentId in _selectedStudents) {
          final student = _allStudents.firstWhere((s) => s['id'] == studentId);
          final studentUid = student['uid'];
          if (!caseFlags.containsKey(studentUid)) {
            await caseFlagsRef.child(studentUid).set(1); // القيمة الابتدائية
          }
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_editingGroupId == null
                  ? 'تم إنشاء الشعبة بنجاح'
                  : 'تم تحديث الشعبة بنجاح')),
        );

        // إعادة تعيين الحقول
        _resetForm();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e')),
        );
      }
    }
  }

  Future<void> _deleteGroup(String groupId) async {
    try {
      await _dbRef.child('studyGroups/$groupId').remove();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الشعبة بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الحذف: $e')),
      );
    }
  }

  void _resetForm() {
    setState(() {
      _editingGroupId = null;
      _selectedCourse = null;
      _startTime = null;
      _endTime = null;
      _selectedClinic = null;
      _selectedDays = [];
      _selectedDoctorIds = [];
      _selectedStudents = [];
      _groupNumber = null;
      _groupNumberController.clear();
    });
    _formKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isLargeScreen = constraints.maxWidth >= 900;
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        final isRtl = languageProvider.currentLocale.languageCode == 'ar';
        String titleText = widget.translate(context, 'manage_study_groups_title');
        if (titleText == 'manage_study_groups_title') {
          titleText = isRtl ? 'إدارة الشعب الدراسية' : 'Manage Study Groups';
        }
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(titleText),
            backgroundColor: const Color(0xFF2A7A94),
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            leading: isLargeScreen
                ? (showSidebarButton && !isSidebarOpen
                    ? IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () {
                          setState(() {
                            isSidebarOpen = true;
                            showSidebarButton = false;
                          });
                        },
                      )
                    : null)
                : IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      setState(() {
                        isSidebarOpen = !isSidebarOpen;
                      });
                    },
                  ),
          ),
          body: Row(
            children: [
              if (isLargeScreen && isSidebarOpen)
                Align(
                  alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                  child: SizedBox(
                    width: 260,
                    child: Stack(
                      children: [
                        AdminSidebar(
                          primaryColor: const Color(0xFF2A7A94),
                          accentColor: const Color(0xFF4AB8D8),
                          userName: widget.userName,
                          userImageUrl: widget.userImageUrl,
                          onLogout: widget.onLogout,
                          parentContext: context,
                          translate: widget.translate,
                        ),
                        Positioned(
                          top: 8,
                          right: isRtl ? null : 0,
                          left: isRtl ? 0 : null,
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                isSidebarOpen = false;
                                showSidebarButton = true;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: Stack(
                  children: [
                    Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // رقم الشعبة
                            TextFormField(
                              controller: _groupNumberController,
                              decoration: const InputDecoration(
                                labelText: 'رقم الشعبة',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value?.isEmpty ?? true ? 'مطلوب' : null,
                              onSaved: (value) => _groupNumber = value,
                            ),

                            const SizedBox(height: 20),

                            // اختيار المساق
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'اختر المساق',
                                border: OutlineInputBorder(),
                              ),
                              value: _selectedCourse,
                              items: _subjects.isEmpty
                                  ? [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text('لا يوجد مواد متاحة'),
                                      ),
                                    ]
                                  : _subjects.map<DropdownMenuItem<String>>((subject) {
                                      return DropdownMenuItem<String>(
                                        value: subject['name'] + ' (${subject['code']})',
                                        child: Text(subject['name'] + ' (${subject['code']})',
                                        ),
                                      );
                                    }).toList(),
                              onChanged: _subjects.isEmpty
                                  ? null
                                  : (value) => setState(() => _selectedCourse = value),
                              validator: (value) => value == null ? 'مطلوب' : null,
                              disabledHint: const Text('لا يوجد مواد متاحة'),
                            ),

                            const SizedBox(height: 20),

                            // اختيار الأطباء المشرفين (متعدد)
                            InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'اختر الأطباء المشرفين',
                                border: OutlineInputBorder(),
                              ),
                              child: _doctors.isEmpty
                                  ? const Text('لا يوجد أطباء متاحين')
                                  : Wrap(
                                      spacing: 8.0,
                                      children: _doctors.map((doctor) {
                                        final isSelected = _selectedDoctorIds.contains(doctor['id']);
                                        return FilterChip(
                                          label: Text(doctor['name']),
                                          selected: isSelected,
                                          onSelected: (selected) {
                                            setState(() {
                                              if (selected) {
                                                _selectedDoctorIds.add(doctor['id']);
                                              } else {
                                                _selectedDoctorIds.remove(doctor['id']);
                                              }
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),
                            ),
                            if (_selectedDoctorIds.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'مطلوب',
                                  style: TextStyle(color: Colors.red, fontSize: 12),
                                ),
                              ),

                            const SizedBox(height: 20),

                            // اختيار العيادة (من A إلى K)
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'اختر العيادة',
                                border: OutlineInputBorder(),
                              ),
                              value: _selectedClinic,
                              items: _clinics.map<DropdownMenuItem<String>>((clinic) {
                                return DropdownMenuItem<String>(
                                  value: clinic,
                                  child: Text(clinic),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() => _selectedClinic = value),
                              validator: (value) => value == null ? 'مطلوب' : null,
                            ),

                            const SizedBox(height: 20),

                            // اختيار الوقت
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectTime(context, true),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'وقت البدء',
                                        border: OutlineInputBorder(),
                                      ),
                                      child: Text(
                                        _startTime != null
                                            ? '${_startTime!.hour}:${_startTime!.minute.toString().padLeft(2, '0')}'
                                            : 'اختر الوقت',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectTime(context, false),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'وقت الانتهاء',
                                        border: OutlineInputBorder(),
                                      ),
                                      child: Text(
                                        _endTime != null
                                            ? '${_endTime!.hour}:${_endTime!.minute.toString().padLeft(2, '0')}'
                                            : 'اختر الوقت',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // اختيار الأيام
                            const Text(
                              'أيام المحاضرة:',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8.0,
                              children: _days.map((day) {
                                return FilterChip(
                                  label: Text(day),
                                  selected: _selectedDays.contains(day),
                                  onSelected: (selected) => _toggleDay(day),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 20),

                            // اختيار الطلاب
                            const Text(
                              'اختر الطلاب:',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),

                            // حقل البحث عن الطلاب
                            TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                labelText: 'ابحث عن طالب',
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // قائمة الطلاب مع إمكانية التصفية
                            Container(
                              height: 200,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: _filteredStudents.isEmpty
                                  ? const Center(child: Text('لا توجد نتائج'))
                                  : ListView.builder(
                                      itemCount: _filteredStudents.length,
                                      itemBuilder: (context, index) {
                                        final student = _filteredStudents[index];
                                        return CheckboxListTile(
                                          title: Text('${student['name']}'),
                                          subtitle: Text(
                                              '${student['studentId']} - ${student['email']}'),
                                          value: _selectedStudents.contains(student['id']),
                                          onChanged: (value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedStudents
                                                    .add(student['id'] as String);
                                              } else {
                                                _selectedStudents.remove(student['id']);
                                              }
                                            });
                                          },
                                        );
                                      },
                                    ),
                            ),

                            const SizedBox(height: 30),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                  onPressed: _saveGroup,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 30, vertical: 15),
                                  ),
                                  child: Text(_editingGroupId == null
                                      ? 'إنشاء شعبة'
                                      : 'تحديث الشعبة'),
                                ),
                                if (_editingGroupId != null)
                                  ElevatedButton(
                                    onPressed: _resetForm,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 30, vertical: 15),
                                    ),
                                    child: const Text('إلغاء'),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 40),

                            const Text(
                              'الشعب الحالية:',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),

                            // عرض الشعب الحالية
                            StreamBuilder(
                              stream: _dbRef.child('studyGroups').onValue,
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(child: CircularProgressIndicator());
                                }

                                final data =
                                    snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;
                                if (data == null || data.isEmpty) {
                                  return const Center(child: Text('لا توجد شعب مسجلة'));
                                }

                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: data.length,
                                  itemBuilder: (context, index) {
                                    final key = data.keys.elementAt(index);
                                    final group = data[key] as Map;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      child: ExpansionTile(
                                        title: Text(
                                            'الشعبة ${group['groupNumber']} - ${group['courseName']}'),
                                        subtitle: group['doctorNames'] != null && group['doctorNames'] is List
                                            ? Text('بإشراف: ${(group['doctorNames'] as List).join('، ')}')
                                            : Text('بإشراف د. ${group['doctorName'] ?? ''}'),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.blue),
                                              onPressed: () => _editGroup(group, key),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: () => _deleteGroup(key),
                                            ),
                                          ],
                                        ),
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    'الوقت: ${group['startTime']} - ${group['endTime']}'),
                                                Text(
                                                    'الأيام: ${(group['days'] as List?)?.join('، ') ?? 'غير محدد'}'),
                                                Text('العيادة: ${group['clinic']}'),
                                                const SizedBox(height: 10),
                                                const Text('الطلاب:',
                                                    style: TextStyle(
                                                        fontWeight: FontWeight.bold)),
                                                ...(group['students'] as Map? ?? {})
                                                    .values
                                                    .map<Widget>((student) {
                                                  return Padding(
                                                    padding: const EdgeInsets.symmetric(
                                                        vertical: 4),
                                                    child: Text(
                                                        ' - ${student['name']} (${student['studentId']})'),
                                                  );
                                                }),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!isLargeScreen && isSidebarOpen)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              isSidebarOpen = false;
                            });
                          },
                          child: Container(
                            color: Colors.black.withAlpha(77),

                            alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: () {},
                              child: SizedBox(
                                width: 260,
                                height: double.infinity,
                                child: Material(
                                  elevation: 8,
                                  child: Stack(
                                    children: [
                                      AdminSidebar(
                                        primaryColor: const Color(0xFF2A7A94),
                                        accentColor: const Color(0xFF4AB8D8),
                                        userName: widget.userName,
                                        userImageUrl: widget.userImageUrl,
                                        onLogout: widget.onLogout,
                                        parentContext: context,
                                        translate: widget.translate,
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: isRtl ? null : 0,
                                        left: isRtl ? 0 : null,
                                        child: IconButton(
                                          icon: const Icon(Icons.close),
                                          onPressed: () {
                                            setState(() {
                                              isSidebarOpen = false;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
