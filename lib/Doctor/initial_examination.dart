// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:xml/xml.dart';
import 'svg.dart';
import 'ScreeningForm.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'active_case_counter.dart';

class InitialExamination extends StatefulWidget {
  final Map<String, dynamic>? patientData;
  final int? age;
  final String doctorId;
  final String patientId; // أضف هذا المتغير

  const InitialExamination({
    super.key,
    this.patientData,
    this.age,
    required this.doctorId,
    required this.patientId, // أضف هنا أيضاً
  });

  @override
  State<InitialExamination> createState() => _InitialExaminationState();
}

class _InitialExaminationState extends State<InitialExamination> with SingleTickerProviderStateMixin {
  Future<void> _saveTabIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('initial_exam_tab_index', index);
  }

  Future<void> _loadTabIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt('initial_exam_tab_index');
    if (savedIndex != null && savedIndex >= 0 && savedIndex < _tabController.length) {
      _tabController.index = savedIndex;
    }
  }
  // جميع دوال البناء يجب أن تكون هنا قبل buildScreeningFormTab وbuildClinicalExaminationTab
  Widget _buildScreeningFormTab() {
    return ScreeningForm(
      patientData: widget.patientData,
      age: widget.age,
      // تمرير بيانات الفحص السابقة إن وجدت
      initialData: _screeningData,
      onSave: (screeningData) {
        setState(() {
          _screeningData = screeningData;
        });
        _onExamChanged();
      },
    );
  }

  Widget _buildClinicalExaminationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.patientData != null) _buildPatientInfo(),
            _buildSection('Extraoral Examination', [
              _buildRadioGroup(
                title: 'TMJ',
                options: ['Normal', 'Deviation of mandible', 'Tenderness on palpation', 'Clicking sounds'],
                key: 'tmj',
              ),
              _buildRadioGroup(
                title: 'Lymph node of head and neck',
                options: ['Normal', 'Tender', 'Enlarged'],
                key: 'lymphNode',
              ),
              _buildRadioGroup(
                title: 'Patient profile',
                options: ['Straight', 'Convex', 'Concave'],
                key: 'patientProfile',
              ),
              _buildRadioGroup(
                title: 'Lip Competency',
                options: ['Competent', 'Incompetent', 'Potentially competent'],
                key: 'lipCompetency',
              ),
            ]),
            _buildSection('Intraoral Examination', [
              _buildRadioGroup(
                title: 'Incisal classification',
                options: ['Class I', 'Class II Div 1', 'Class II Div 2', 'Class III'],
                key: 'incisalClassification',
              ),
              _buildRadioGroup(
                title: 'Overjet',
                options: ['Normal', 'Increased', 'Decreased'],
                key: 'overjet',
              ),
              _buildRadioGroup(
                title: 'Overbite',
                options: ['Normal', 'Increased', 'Decreased'],
                key: 'overbite',
              ),
            ]),
            _buildSection('Soft Tissue Examination', [
              _buildRadioGroup(
                title: 'Hard Palate',
                options: ['Normal', 'Tori', 'Stomatitis', 'Ulcers', 'Red lesions'],
                key: 'hardPalate',
              ),
              _buildRadioGroup(
                title: 'Buccal mucosa',
                options: ['Normal', 'Pigmentation', 'Ulceration', 'Linea alba'],
                key: 'buccalMucosa',
              ),
              _buildRadioGroup(
                title: 'Floor of mouth',
                options: ['Normal', 'High frenum', 'Wharton\'s duct stenosis'],
                key: 'floorOfMouth',
              ),
              _buildRadioGroup(
                title: 'In full edentulous Arch the ridge is',
                options: ['Flappy', 'Severely resorbed', 'Well-developed ridge'],
                key: 'edentulousRidge',
              ),
            ]),
            _buildSection('Periodontal Chart (BPE)', [
              _buildPeriodontalChart(),
            ]),
            _buildSection('Dental Chart', [
              _buildDentalChart(),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Initial Examination'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Screening Form'),
            Tab(text: 'Clinical Examination'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _submitExamination,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScreeningFormTab(),
          _buildClinicalExaminationTab(),
        ],
      ),
    );
  }
  late TabController _tabController;
  final Map<String, dynamic> _examData = {
    'tmj': 'Normal',
    'lymphNode': 'Normal',
    'patientProfile': 'Straight',
    'lipCompetency': 'Competent',
    'incisalClassification': 'Class I',
    'overjet': 'Normal',
    'overbite': 'Normal',
    'hardPalate': 'Normal',
    'buccalMucosa': 'Normal',
    'floorOfMouth': 'Normal',
    'edentulousRidge': 'Well-developed ridge',
    'periodontalRisk': 'Low',
    'periodontalChart': {
      'Upper right posterior': 0,
      'Upper anterior': 0,
      'Upper left posterior': 0,
      'Lower right posterior': 0,
      'Lower anterior': 0,
      'Lower left posterior': 0,
    },
    'dentalChart': {
      'selectedTeeth': <String>[],
      'teethConditions': <String, String>{},
    }
  };

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  Map<String, Color> _teethColors = {};
  Map<String, dynamic>? _screeningData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTabIndex();
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _saveTabIndex(_tabController.index);
      }
    });
    _loadLocalExamData();
    // تحميل بيانات الفحص السابق إن وجدت
    _loadPreviousExaminationIfExists();
    // لا تعتمد على patientData['id'] نهائياً، فقط تحقق من widget.patientId
    assert(widget.patientId.isNotEmpty, 'patientId (user id) must not be empty');
    if (widget.patientData != null && widget.patientData!['dentalChart'] != null) {
      final dentalChart = widget.patientData!['dentalChart'] as Map<String, dynamic>?;
      if (dentalChart != null) {
        final selectedTeeth = dentalChart['selectedTeeth'] as List<dynamic>?;
        if (selectedTeeth != null) {
          _examData['dentalChart']['selectedTeeth'] = selectedTeeth.map((e) => e.toString()).toList();
        }

        final conditions = dentalChart['teethConditions'] as Map<String, dynamic>?;
        if (conditions != null) {
          _teethColors = conditions.map((key, value) {
            if (value != null) {
              return MapEntry(key, Color(int.parse(value.toString(), radix: 16)));
            }
            return MapEntry(key, Colors.white);
          });
        }
      }
    }
  }

  // دالة لتحميل بيانات الفحص السابق من Firebase
  Future<void> _loadPreviousExaminationIfExists() async {
    try {
      final snapshot = await _database.child('examinations').child(widget.patientId).get();
      if (snapshot.exists) {
        final dataRaw = snapshot.value;
        final Map<String, dynamic> data = dataRaw is Map<String, dynamic>
            ? dataRaw
            : Map<String, dynamic>.from(dataRaw as Map);
        if (data['examData'] != null) {
          final examDataRaw = data['examData'];
          final loadedExamData = examDataRaw is Map<String, dynamic>
              ? examDataRaw
              : Map<String, dynamic>.from(examDataRaw as Map);

          // تحديث selectedTeeth وteethConditions
          List<String> loadedSelectedTeeth = [];
          Map<String, Color> loadedTeethColors = {};
          if (loadedExamData['dentalChart'] != null && loadedExamData['dentalChart'] is Map) {
            final dentalChart = loadedExamData['dentalChart'] as Map;
            // selectedTeeth
            if (dentalChart['selectedTeeth'] is List) {
              loadedSelectedTeeth = (dentalChart['selectedTeeth'] as List).map((e) => e.toString()).toList();
            }
            // teethConditions
            if (dentalChart['teethConditions'] != null) {
              final teethCondsRaw = dentalChart['teethConditions'];
              final teethConds = teethCondsRaw is Map<String, dynamic>
                  ? teethCondsRaw
                  : Map<String, dynamic>.from(teethCondsRaw as Map);
              // إذا كانت القيمة اسم مرض، حولها إلى لون
              final diseaseColorMap = {
                'Mobile Tooth': 0xFF1976D2,
                'Unrestorable Tooth': 0xFFD32F2F,
                'Supernumerary': 0xFF7B1FA2,
                'Tender to Percussion': 0xFFFFA000,
                'Root Canal Therapy': 0xFF388E3C,
                'Over Retained': 0xFF0097A7,
                'Caries': 0xFF795548,
                'Missing Tooth': 0xFF616161,
                'Filling': 0xFFFFD600,
                'Crown': 0xFFFF7043,
                'Implant': 0xFF43A047,
              };
              teethConds.forEach((key, value) {
                if (value is String && diseaseColorMap.containsKey(value)) {
                  loadedTeethColors[key.toString()] = Color(diseaseColorMap[value]!);
                } else if (value is String && value.length == 6 && int.tryParse(value, radix: 16) != null) {
                  loadedTeethColors[key.toString()] = Color(int.parse(value, radix: 16) + 0xFF000000);
                }
              });
            }
          }

          if (!mounted) return;
          setState(() {
            _examData.clear();
            // تحويل جميع الحقول الفرعية إلى Map<String, dynamic> إذا لزم الأمر
            loadedExamData['periodontalChart'] =
                loadedExamData['periodontalChart'] is Map<String, dynamic>
                    ? loadedExamData['periodontalChart']
                    : Map<String, dynamic>.from(loadedExamData['periodontalChart'] as Map);
            if (loadedExamData['dentalChart'] != null) {
              loadedExamData['dentalChart'] =
                  loadedExamData['dentalChart'] is Map<String, dynamic>
                      ? loadedExamData['dentalChart']
                      : Map<String, dynamic>.from(loadedExamData['dentalChart'] as Map);
              if (loadedExamData['dentalChart']['teethConditions'] != null) {
                loadedExamData['dentalChart']['teethConditions'] =
                    loadedExamData['dentalChart']['teethConditions'] is Map<String, dynamic>
                        ? loadedExamData['dentalChart']['teethConditions']
                        : Map<String, dynamic>.from(loadedExamData['dentalChart']['teethConditions'] as Map);
              }
              // تحديث selectedTeeth
              loadedExamData['dentalChart']['selectedTeeth'] = loadedSelectedTeeth;
            }
            _examData.addAll(loadedExamData);
            if (loadedTeethColors.isNotEmpty) {
              _teethColors = loadedTeethColors;
            }
          });
          _onExamChanged();
        }
        if (data['screening'] != null) {
          final screeningRaw = data['screening'];
          final screening = screeningRaw is Map<String, dynamic>
              ? screeningRaw
              : Map<String, dynamic>.from(screeningRaw as Map);
          if (!mounted) return;
          setState(() {
            _screeningData = screening;
          });
          _onExamChanged();
        }
      }
    } catch (e) {
      debugPrint('Error loading previous examination: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalExamData() async {
    final prefs = await SharedPreferences.getInstance();
    final examDataStr = prefs.getString('initial_exam_data');
    final screeningDataStr = prefs.getString('initial_screening_data');
    if (examDataStr != null) {
      setState(() {
        _examData.clear();
        _examData.addAll(jsonDecode(examDataStr));
      });
    }
    if (screeningDataStr != null) {
      setState(() {
        _screeningData = jsonDecode(screeningDataStr);
      });
    }
  }

  Future<void> _saveLocalExamData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('initial_exam_data', jsonEncode(_examData));
    if (_screeningData != null) {
      await prefs.setString('initial_screening_data', jsonEncode(_screeningData));
    }
  }

  void _onExamChanged() {
    _saveLocalExamData();
  }

  void _updateExamData(String key, dynamic value) {
    setState(() => _examData[key] = value);
    _onExamChanged();
  }

  void _updateChart(String area, int value) {
    setState(() => _examData['periodontalChart'][area] = value);
    _onExamChanged();
  }

  void _updateDentalChart(List<String> selectedTeeth) {
    setState(() {
      if (_examData['dentalChart'] == null || _examData['dentalChart'] is! Map) {
        _examData['dentalChart'] = <String, dynamic>{
          'selectedTeeth': <String>[],
          'teethConditions': <String, String>{},
        };
      } else if (_examData['dentalChart'] is! Map<String, dynamic>) {
        _examData['dentalChart'] = Map<String, dynamic>.from(_examData['dentalChart'] as Map);
      }
      final Map<String, dynamic> dentalChart = _examData['dentalChart'] as Map<String, dynamic>;
      // حفظ جميع الأسنان المحددة
      dentalChart['selectedTeeth'] = selectedTeeth;
      // حفظ اسم المرض فقط للأسنان التي تم تحديد حالة لها
      final diseaseColorMap = {
        '1976d2': 'Mobile Tooth',
        'd32f2f': 'Unrestorable Tooth',
        '7b1fa2': 'Supernumerary',
        'ffa000': 'Tender to Percussion',
        '388e3c': 'Root Canal Therapy',
        '0097a7': 'Over Retained',
        '795548': 'Caries',
        '616161': 'Missing Tooth',
        'ffd600': 'Filling',
        'ff7043': 'Crown',
        '43a047': 'Implant',
      };
      final Map<String, String> teethConditions = {};
      _teethColors.forEach((tooth, value) {
        if (selectedTeeth.contains(tooth)) {
          // ignore: deprecated_member_use
          final hex = value.value.toRadixString(16).padLeft(8, '0').substring(2);
          final disease = diseaseColorMap[hex] ?? hex;
          teethConditions[tooth] = disease;
        }
      });
      dentalChart['teethConditions'] = teethConditions;
    });
    _onExamChanged();
  }

  Widget _buildPatientInfo() {
    final p = widget.patientData;
    if (p == null) return const SizedBox.shrink();

    // بناء الاسم الرباعي مع إظهار الاسم الثالث حتى لو كان فارغًا
    final firstName = (p['firstName'] ?? '').toString().trim();
    final fatherName = (p['fatherName'] ?? '').toString().trim();
    final grandFatherName = (p['grandfatherName'] ?? '').toString().trim();
    final familyName = (p['familyName'] ?? '').toString().trim();
    final fullName = [firstName, fatherName, grandFatherName, familyName].join(' ').replaceAll(RegExp(' +'), ' ').trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fullName.isNotEmpty)
              Text('اسم المريض: $fullName'),
            if (widget.age != null) Text('العمر: ${widget.age}'),
            if (p['gender'] != null) Text('الجنس: ${p['gender']}'),
            if (p['phone'] != null) Text('رقم الهاتف: ${p['phone']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );

  Widget _buildRadioGroup({
    required String title,
    required List<String> options,
    required String key,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ...options.map((option) => RadioListTile<String>(
        title: Text(option),
        value: option,
        groupValue: _examData[key] as String? ?? '',
        onChanged: (v) => v != null ? _updateExamData(key, v) : null,
      )),
    ],
  );

  Widget _buildPeriodontalChart() => Column(
    children: [
      ...(_examData['periodontalChart'] as Map<String, dynamic>).entries.map((entry) => Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.key),
              Row(children: List.generate(5, (index) => Expanded(
                child: RadioListTile<int>(
                  title: Text('$index'),
                  value: index,
                  groupValue: entry.value as int? ?? 0,
                  onChanged: (v) => v != null ? _updateChart(entry.key, v) : null,
                ),
              ))),
            ],
          ),
        ),
      )),
      _buildRadioGroup(
        title: 'The periodontal risk assessment',
        options: ['Low', 'Moderate', 'High'],
        key: 'periodontalRisk',
      ),
    ],
  );

  Widget _buildDentalChart() => Column(
    children: [
      SizedBox(
        height: 600,
        child: FittedBox(
          fit: BoxFit.contain,
          child: TeethSelector(
            age: widget.age,
            onChange: (selectedTeeth) {
              _updateDentalChart(selectedTeeth.cast<String>());
            },
            initiallySelected: (() {
              final chart = _examData['dentalChart'];
              if (chart is Map && chart['selectedTeeth'] is List) {
                return (chart['selectedTeeth'] as List).cast<String>();
              }
              return <String>[];
            })(),
            colorized: Map<String, Color>.from(_teethColors),
            onColorUpdate: (colors) {
              setState(() {
                _teethColors = Map<String, Color>.from(colors);
              });
              _onExamChanged();
            },
          ),
        ),
      ),
      const SizedBox(height: 16),
      _buildTeethConditionsLegend(),
    ],
  );

  Widget _buildTeethConditionsLegend() {
    final conditions = {
      'Mobile Tooth': const Color(0xFF1976D2),         // Blue
      'Unrestorable Tooth': const Color(0xFFD32F2F),  // Red
      'Supernumerary': const Color(0xFF7B1FA2),       // Purple
      'Tender to Percussion': const Color(0xFFFFA000),// Orange
      'Root Canal Therapy': const Color(0xFF388E3C),  // Green
      'Over Retained': const Color(0xFF0097A7),       // Cyan
      'Caries': const Color(0xFF795548),              // Brown
      'Missing Tooth': const Color(0xFF616161),       // Grey
      'Filling': const Color(0xFFFFD600),             // Yellow
      'Crown': const Color(0xFFFF7043),               // Deep Orange
      'Implant': const Color(0xFF43A047),             // Dark Green
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: conditions.entries.map((entry) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: entry.value,
                  border: Border.all(color: Colors.grey),
                ),
              ),
              const SizedBox(width: 8),
              Text(entry.key),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Future<void> _submitExamination() async {
    try {
      // استخدم دومًا معرف المستخدم الحقيقي الممرر عبر widget.patientId
      final patientId = widget.patientId;
      debugPrint('Submitting examination for patientId: $patientId');
      if (patientId.isEmpty) {
        throw Exception('Patient ID is empty');
      }
      // أضف userId داخل examData وأضف id أيضاً
      final Map<String, dynamic> examDataWithId = Map<String, dynamic>.from(_examData);
      examDataWithId['userId'] = patientId;
      examDataWithId['id'] = patientId; // إضافة id
      final examRecord = {
        'patientId': patientId,
        'id': patientId, // إضافة id في السجل الرئيسي أيضاً
        'doctorId': widget.doctorId,
        'timestamp': ServerValue.timestamp,
        'examData': examDataWithId,
        'screening': _screeningData,
      };
      // احفظ الفحص مباشرة تحت examinations/{patientId} (فحص واحد فقط لكل مريض)
      await _database.child('examinations').child(patientId).set(examRecord);

      // حذف بيانات الفحص المحفوظة محليًا بعد الحفظ على الداتا بيس
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('initial_exam_data');
      await prefs.remove('initial_screening_data');

      // حذف المريض من قائمة الانتظار بعد الحفظ باستخدام waitingListId الصحيح
      String? waitingListId;
      if (widget.patientData != null && widget.patientData!['id'] != null && widget.patientData!['id'].toString().isNotEmpty) {
        waitingListId = widget.patientData!['id'].toString();
      } else {
        waitingListId = patientId;
      }
      await FirebaseDatabase.instance.ref('waitingList').child(waitingListId).remove();

      if (!mounted) return;

      // بعد الحفظ، أظهر دايالوج فيه خيارين: توزيع تلقائي أو محجوز
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('إسناد المريض للطالب'),
          content: const Text('هل تريد توزيع المريض تلقائيًا على طالب المادة الأقل حالات أم حجزه لطالب معين؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('manual'),
              child: const Text('محجوز'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('auto'),
              child: const Text('توزيع تلقائي'),
            ),
          ],
        ),
      );

      if (result == 'auto') {
        // جلب قائمة المواد (courseId واسم المادة) من studyGroups
        final courses = await _fetchCourses();
        if (!mounted) return;
        if (courses.isEmpty) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('لا توجد مواد متاحة'),
              content: const Text('لم يتم العثور على مواد في قاعدة البيانات. يرجى إضافة مواد أولاً.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          );
          return;
        }
        String? selectedCourseId;
        selectedCourseId = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('اختر المادة'),
            content: SizedBox(
              width: 300,
              child: ListView(
                shrinkWrap: true,
                children: courses.map((course) => ListTile(
                  title: Text((course['name'] ?? course['id'] ?? '').toString()),
                  onTap: () => Navigator.of(context).pop(course['id']),
                )).toList(),
              ),
            ),
          ),
        );
        if (selectedCourseId != null) {
          // ignore: duplicate_ignore
          // ignore: use_build_context_synchronously
          final assigned = await _assignPatientToStudentAuto(context, patientId, selectedCourseId);
          if (!mounted) return;
          if (assigned) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم توزيع المريض تلقائيًا على الطالب الأقل حالات.')),
            );
            Navigator.pop(context);
          }
          // إذا لم يتم التوزيع (assigned == false)، لا تغلق الصفحة ولا تظهر رسالة نجاح، فقط رسالة عدم وجود طالب متاح ستظهر من داخل الدالة
        }
      } else {
        // إذا لم يكن تلقائي (محجوز أو إلغاء)، فقط احفظ الحالة واغلق الصفحة
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: e.toString()}')),
      );
    }
  }

  // جلب المواد من جدول studyGroups في قاعدة البيانات
  // تم حذف دالة _fetchSubjects لأنها لم تعد مستخدمة

  // جلب قائمة المواد (courseId واسم المادة) من studyGroups
  Future<List<Map<String, String>>> _fetchCourses() async {
    final snapshot = await FirebaseDatabase.instance.ref('studyGroups').get();
    final data = snapshot.value;
    final List<Map<String, String>> courses = [];
    final Set<String> seenIds = {};
    if (data is Map) {
      for (final entry in data.entries) {
        final group = entry.value;
        if (group is Map && group['courseId'] != null) {
          final id = group['courseId'].toString();
          // استخدم courseName إذا وجد، وإلا subject، وإلا id
          String name = '';
          if (group['courseName'] != null && group['courseName'].toString().trim().isNotEmpty) {
            name = group['courseName'].toString();
          } else if (group['subject'] != null && group['subject'].toString().trim().isNotEmpty) {
            name = group['subject'].toString();
          } else {
            name = id;
          }
          if (!seenIds.contains(id)) {
            courses.add({'id': id, 'name': name});
            seenIds.add(id);
          }
        }
      }
    }
    return courses;
  }
  }

  // توزيع تلقائي: إيجاد الطالب الأقل حالات في المادة وإسناد المريض له
  Future<bool> _assignPatientToStudentAuto(BuildContext context, String patientId, String subject) async {
    // جلب جميع الشعب التي تحتوي على نفس المادة (courseId)
    final studyGroupsSnap = await FirebaseDatabase.instance.ref('studyGroups').get();
    final studyGroups = studyGroupsSnap.value as Map<dynamic, dynamic>?;
    if (studyGroups == null) return false;
    // جمع كل الطلاب في جميع الشعب التي تحتوي على نفس المادة
    final Set<String> studentIds = {};
    for (final entry in studyGroups.entries) {
      final group = entry.value;
      if (group is Map && group['courseId'] != null && group['courseId'].toString() == subject && group['students'] is Map) {
        final studentsMap = group['students'] as Map;
        for (final sid in studentsMap.keys) {
          studentIds.add(sid.toString());
        }
      }
    }
    if (studentIds.isEmpty) return false;

    // جلب جميع الحالات من paedodonticsCases و surgeryCases
    final paedoSnap = await FirebaseDatabase.instance.ref('paedodonticsCases').get();
    final surgerySnap = await FirebaseDatabase.instance.ref('surgeryCases').get();
    final paedoCases = paedoSnap.value as Map<dynamic, dynamic>? ?? {};
    final surgeryCases = surgerySnap.value as Map<dynamic, dynamic>? ?? {};

    // جلب allowNewCase لكل طالب في المادة
    final allowSnap = await FirebaseDatabase.instance.ref('student_case_flags/$subject').get();
    final allowMap = allowSnap.value as Map<dynamic, dynamic>? ?? {};
    List<String> eligible = [];
    for (final sid in studentIds) {
      final flag = allowMap[sid]?.toString();
      if (flag == '1') eligible.add(sid);
    }
    // إذا لم يوجد أي طالب allowNewCase=1، لا توزع الحالة وأظهر رسالة
    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد أي طالب متاح لاستلام حالة جديدة في هذه المادة حالياً.')),
      );
      return false;
    }

    String? minStudentId;
    int minCount = 999999;
    for (final sid in eligible) {
      int count = 0;
      count += countActiveCasesForStudentInCourse(paedoCases, sid, subject);
      count += countActiveCasesForStudentInCourse(surgeryCases, sid, subject);
      if (count < minCount) {
        minCount = count;
        minStudentId = sid;
      }
    }
    if (minStudentId != null) {
      // إسناد المريض لهذا الطالب بقيمة true فقط (بدون تفاصيل)
      await FirebaseDatabase.instance.ref('student_patients').child(minStudentId).child(patientId).set(true);
      // ضبط allowNewCase=0 لهذا الطالب في هذه المادة
      await FirebaseDatabase.instance.ref('student_case_flags/$subject/$minStudentId').set(0);
      return true;
    }
    return false;
  }
// نهاية كلاس _InitialExaminationState

// نهاية كلاس _InitialExaminationState

class TeethSelector extends StatefulWidget {
  final int? age;
  final bool multiSelect;
  final Color selectedColor;
  final Color unselectedColor;
  final Color tooltipColor;
  final List<String> initiallySelected;
  final Map<String, Color> colorized;
  final Map<String, Color> strokedColorized;
  final Color defaultStrokeColor;
  final Map<String, double> strokeWidth;
  final double defaultStrokeWidth;
  final String leftString;
  final String rightString;
  final bool showPermanent;
  final void Function(List<String> selected) onChange;
  final void Function(Map<String, Color> colors) onColorUpdate;
  final String Function(String isoString)? notation;
  final TextStyle? textStyle;
  final TextStyle? tooltipTextStyle;

  const TeethSelector({
    super.key,
    this.age,
    this.multiSelect = true,
    this.selectedColor = Colors.blue,
    this.unselectedColor = Colors.grey,
    this.tooltipColor = Colors.black,
    this.initiallySelected = const [],
    this.colorized = const {},
    this.strokedColorized = const {},
    this.defaultStrokeColor = Colors.transparent,
    this.strokeWidth = const {},
    this.defaultStrokeWidth = 1,
    this.notation,
    this.showPermanent = true,
    this.leftString = "Left",
    this.rightString = "Right",
    this.textStyle,
    this.tooltipTextStyle,
    required this.onChange,
    required this.onColorUpdate,
  });

  @override
  State<TeethSelector> createState() => _TeethSelectorState();
}

class _TeethSelectorState extends State<TeethSelector> {
  late Data data;
  Map<String, Color> localColorized = {};
  Map<String, bool> toothSelection = {};

  @override
  void initState() {
    super.initState();
    data = _loadTeethWithRetry();
    _initializeSelections();
  }

  Data _loadTeethWithRetry() {
    try {
      final loadedData = loadTeeth();
      return loadedData;
    } catch (e) {
      return (size: Size.zero, teeth: {});
    }
  }

  void _initializeSelections() {
    toothSelection = {
      for (var key in data.teeth.keys) key: false
    };

    for (var element in widget.initiallySelected) {
      if (data.teeth.containsKey(element)) {
        toothSelection[element] = true;
      }
    }

    localColorized = Map<String, Color>.from(widget.colorized);
  }

  int _parseToothNumber(String key) => int.tryParse(key) ?? 0;

  bool _isPrimaryTooth(String key) {
    final num = _parseToothNumber(key);
    return (num >= 51 && num <= 55) ||
        (num >= 61 && num <= 65) ||
        (num >= 71 && num <= 75) ||
        (num >= 81 && num <= 85);
  }

  bool _isPermanentTooth(String key) {
    final num = _parseToothNumber(key);
    return (num >= 11 && num <= 18) ||
        (num >= 21 && num <= 28) ||
        (num >= 31 && num <= 38) ||
        (num >= 41 && num <= 48);
  }

  @override
  Widget build(BuildContext context) {
    if (data.size == Size.zero) {
      return const Center(child: CircularProgressIndicator());
    }

    final bool showPrimary = widget.age != null && widget.age! < 12;
    final visibleTeeth = data.teeth.entries.where((e) =>
    (showPrimary && _isPrimaryTooth(e.key)) ||
        (widget.showPermanent && _isPermanentTooth(e.key))
    ).toList();

    return FittedBox(
      child: SizedBox.fromSize(
        size: Size(data.size.width * 1.5, data.size.height * 1.5),
        child: Stack(
          children: [
            Positioned(
              left: 20,
              top: data.size.height * 0.75 - 16,
              child: Text(
                widget.rightString,
                style: widget.textStyle ?? const TextStyle(fontSize: 16),
              ),
            ),
            Positioned(
              right: 20,
              top: data.size.height * 0.75 - 16,
              child: Text(
                widget.leftString,
                style: widget.textStyle ?? const TextStyle(fontSize: 16),
              ),
            ),

            for (final entry in visibleTeeth)
              _ToothWidget(
                key: ValueKey('tooth-${entry.key}-${toothSelection[entry.key]}'),
                toothKey: entry.key,
                tooth: entry.value,
                isSelected: toothSelection[entry.key] ?? false,
                selectedColor: widget.selectedColor,
                unselectedColor: widget.unselectedColor,
                tooltipColor: widget.tooltipColor,
                tooltipTextStyle: widget.tooltipTextStyle,
                notation: widget.notation,
                customColor: localColorized[entry.key],
                strokeColor: widget.strokedColorized[entry.key] ??
                    widget.defaultStrokeColor,
                strokeWidth: widget.strokeWidth[entry.key] ??
                    widget.defaultStrokeWidth,
                onTap: _handleToothTap,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleToothTap(String key) async {
    final diseaseColors = {
      'Mobile Tooth': const Color(0xFF1976D2),         // Blue
      'Unrestorable Tooth': const Color(0xFFD32F2F),  // Red
      'Supernumerary': const Color(0xFF7B1FA2),       // Purple
      'Tender to Percussion': const Color(0xFFFFA000),// Orange
      'Root Canal Therapy': const Color(0xFF388E3C),  // Green
      'Over Retained': const Color(0xFF0097A7),       // Cyan
      'Caries': const Color(0xFF795548),              // Brown
      'Missing Tooth': const Color(0xFF616161),       // Grey
      'Filling': const Color(0xFFFFD600),             // Yellow
      'Crown': const Color(0xFFFF7043),               // Deep Orange
      'Implant': const Color(0xFF43A047),             // Dark Green
    };

    final selectedDisease = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('اختر الحالة للسن $key'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: diseaseColors.entries.map((entry) {
              return ListTile(
                title: Text(entry.key),
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: entry.value,
                    border: Border.all(color: Colors.grey),
                  ),
                ),
                onTap: () => Navigator.of(context).pop(entry.key),
              );
            }).toList(),
          ),
        ),
      ),
    );

    if (selectedDisease != null) {
      setState(() {
        if (!widget.multiSelect) {
          // Remove unnecessary null check here
          for (var k in toothSelection.keys) {
            toothSelection[k] = false;
          }
        }

        toothSelection[key] = true;
        localColorized[key] = diseaseColors[selectedDisease]!;

        widget.onChange(
            toothSelection.entries
                .where((e) => e.value)
                .map((e) => e.key)
                .toList()
        );

        widget.onColorUpdate(localColorized);
      });
    }
  }
}

class _ToothWidget extends StatelessWidget {
  final String toothKey;
  final Tooth tooth;
  final bool isSelected;
  final Color selectedColor;
  final Color unselectedColor;
  final Color tooltipColor;
  final TextStyle? tooltipTextStyle;
  final String Function(String)? notation;
  final Color? customColor;
  final Color strokeColor;
  final double strokeWidth;
  final Function(String) onTap;

  const _ToothWidget({
    required super.key,
    required this.toothKey,
    required this.tooth,
    required this.isSelected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.tooltipColor,
    this.tooltipTextStyle,
    this.notation,
    this.customColor,
    required this.strokeColor,
    required this.strokeWidth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: Rect.fromLTWH(
        tooth.rect.left * 1.5,
        tooth.rect.top * 1.5,
        tooth.rect.width * 1.5,
        tooth.rect.height * 1.5,
      ),
      child: GestureDetector(
        onTap: () => onTap(toothKey),
        child: Tooltip(
          message: notation == null ? toothKey : notation!(toothKey),
          textStyle: tooltipTextStyle,
          decoration: BoxDecoration(
            color: tooltipColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: ShapeDecoration(
              color: customColor ?? (isSelected ? selectedColor : unselectedColor),
              shape: ToothBorder(
                tooth.path,
                strokeColor: strokeColor,
                strokeWidth: strokeWidth,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Tooth {
  late final Path path;
  late final Rect rect;

  Tooth(Path originalPath) {
    rect = originalPath.getBounds();
    path = originalPath.shift(-rect.topLeft);
  }
}

class ToothBorder extends ShapeBorder {
  final Path path;
  final double strokeWidth;
  final Color strokeColor;

  const ToothBorder(
      this.path, {
        required this.strokeWidth,
        required this.strokeColor,
      });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => getOuterPath(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return rect.topLeft == Offset.zero ? path : path.shift(rect.topLeft);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = strokeColor;
    canvas.drawPath(getOuterPath(rect), paint);
  }

  @override
  ShapeBorder scale(double t) => this;
}

typedef Data = ({Size size, Map<String, Tooth> teeth});

Data loadTeeth() {
  try {
    final doc = XmlDocument.parse(svgString);
    final viewBox = doc.rootElement.getAttribute('viewBox')?.split(' ') ?? ['0','0','0','0'];
    final size = Size(
      double.parse(viewBox[2]),
      double.parse(viewBox[3]),
    );

    final teeth = <String, Tooth>{};
    for (final element in doc.rootElement.findAllElements('path')) {
      final id = element.getAttribute('id');
      final pathData = element.getAttribute('d');
      if (id != null && pathData != null) {
        try {
          teeth[id] = Tooth(parseSvgPathData(pathData));
        } catch (e) {
          debugPrint('Error parsing tooth $id: $e');
        }
      }
    }
    return (size: size, teeth: teeth);
  } catch (e) {
    debugPrint('Error loading SVG: $e');
    return (size: Size.zero, teeth: {});
  }
}