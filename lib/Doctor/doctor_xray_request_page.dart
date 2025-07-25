import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'doctor_sidebar.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DoctorXrayRequestPage extends StatefulWidget {
  const DoctorXrayRequestPage({super.key});

  @override
  State<DoctorXrayRequestPage> createState() => _DoctorXrayRequestPageState();
}

class _DoctorXrayRequestPageState extends State<DoctorXrayRequestPage> {
  final TextEditingController _patientSearchController = TextEditingController();
  final TextEditingController _toothController = TextEditingController();
  String? _selectedPatientId;
  String? _selectedPatientName;
  String _xrayType = 'single';

  List<Map<String, dynamic>> foundPatients = [];
  int? selectedPatientIndex;
  String? patientError;
  bool isSearchingPatient = false;

  String? _jaw; // الفك
  String? _side; // الجهة
  List<Map<String, String>> groupTeeth = [];

  String? _doctorName;
  String? _doctorImageUrl;

  @override
  void initState() {
    super.initState();
    _loadDoctorInfo();
  }

  Future<void> _loadDoctorInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final db = FirebaseDatabase.instance.ref();
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

  Future<void> searchPatient() async {
    setState(() {
      isSearchingPatient = true;
      foundPatients = [];
      selectedPatientIndex = null;
      patientError = null;
    });
    final db = FirebaseDatabase.instance.ref('users');
    final query = _patientSearchController.text.trim().toLowerCase();
    try {
      final snap = await db.get();
      if (snap.exists) {
        final users = snap.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> matches = [];
        for (final e in users.entries) {
          final data = e.value as Map<dynamic, dynamic>;
          final idNumber = data['idNumber']?.toString() ?? '';
          final firstName = data['firstName']?.toString().toLowerCase() ?? '';
          final familyName = data['familyName']?.toString().toLowerCase() ?? '';
          if (query.isEmpty ||
              idNumber.contains(query) ||
              firstName.contains(query) ||
              familyName.contains(query)) {
            matches.add({
              'uid': e.key,
              ...data,
            });
          }
        }
        if (matches.isNotEmpty) {
          setState(() {
            foundPatients = matches;
            patientError = null;
          });
        } else {
          setState(() {
            patientError = 'لم يتم العثور على مريض';
          });
        }
      } else {
        setState(() {
          patientError = 'لا يوجد مرضى';
        });
      }
    } catch (e) {
      setState(() {
        patientError = e.toString();
      });
    } finally {
      setState(() {
        isSearchingPatient = false;
      });
    }
  }

  Future<void> _submitRequest() async {
    if (_selectedPatientId == null) return;
    if (_xrayType == 'single') {
      if (_jaw == null || _side == null || _toothController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى تعبئة جميع بيانات السن المطلوبة')),
        );
        return;
      }
    }
    if (_xrayType == 'group') {
      if (groupTeeth.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى إضافة سن واحد على الأقل')),
        );
        return;
      }
    }
    final ref = FirebaseDatabase.instance.ref('xray_waiting_list');
    final request = {
      'patientId': _selectedPatientId,
      'patientName': _selectedPatientName,
      'xrayType': _xrayType,
      'jaw': _xrayType == 'single' ? _jaw : null,
      'side': _xrayType == 'single' ? _side : null,
      'tooth': _xrayType == 'single' ? _toothController.text : null,
      'groupTeeth': _xrayType == 'group' ? groupTeeth : null,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'pending',
    };
    await ref.push().set(request);
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الطلب بنجاح')));
    setState(() {
      _selectedPatientId = null;
      _selectedPatientName = null;
      selectedPatientIndex = null;
      _patientSearchController.clear();
      _toothController.clear();
      _xrayType = 'single';
      _jaw = null;
      _side = null;
      groupTeeth.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2A7A94);
    const accentColor = Color(0xFF4AB8D8);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isArabic = languageProvider.currentLocale.languageCode == 'ar';
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        drawer: DoctorSidebar(
          primaryColor: primaryColor,
          accentColor: accentColor,
          userName: _doctorName,
          userImageUrl: _doctorImageUrl,
          parentContext: context,
          collapsed: false,
          translate: (ctx, key) => key,
          doctorUid: FirebaseAuth.instance.currentUser?.uid ?? '',
        ),
        appBar: AppBar(
          backgroundColor: primaryColor,
          title: Text(isArabic ? 'طلب أشعة' : 'Radiology Request'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _patientSearchController,
                        decoration: const InputDecoration(
                          labelText: 'ابحث عن المريض (اسم أو رقم هوية)',
                          prefixIcon: Icon(Icons.person_search),
                        ),
                        onChanged: (_) => searchPatient(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: isSearchingPatient
                          ? const CircularProgressIndicator()
                          : const Icon(Icons.search),
                      onPressed: isSearchingPatient ? null : searchPatient,
                    ),
                  ],
                ),
                if (patientError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(patientError!, style: const TextStyle(color: Colors.red)),
                  ),
                if (foundPatients.isNotEmpty && selectedPatientIndex == null)
                  Column(
                    children: [
                      ...foundPatients.asMap().entries.map((entry) {
                        final i = entry.key;
                        final patient = entry.value;
                        return Card(
                          child: ListTile(
                            title: Text([
                              patient['firstName'] ?? '',
                              patient['fatherName'] ?? '',
                              patient['grandfatherName'] ?? '',
                              patient['familyName'] ?? ''
                            ].where((e) => e != '').join(' ')),
                            subtitle: Text('رقم الهوية: ${patient['idNumber'] ?? ''}'),
                            selected: selectedPatientIndex == i,
                            onTap: () {
                              setState(() {
                                selectedPatientIndex = i;
                                _selectedPatientId = patient['uid'];
                                _selectedPatientName = [
                                  patient['firstName'] ?? '',
                                  patient['fatherName'] ?? '',
                                  patient['grandfatherName'] ?? '',
                                  patient['familyName'] ?? ''
                                ].where((e) => e != '').join(' ');
                              });
                              FocusScope.of(context).unfocus();
                            },
                            trailing: selectedPatientIndex == i
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : null,
                          ),
                        );
                      }),
                    ],
                  ),
                if (selectedPatientIndex != null && foundPatients.isNotEmpty && selectedPatientIndex! < foundPatients.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'المريض المختار: ${_selectedPatientName!} رقم الهوية: ${foundPatients[selectedPatientIndex!]['idNumber'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                const SizedBox(height: 20),
                if (_selectedPatientId != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('نوع الأشعة:'),
                      Row(
                        children: [
                          Radio<String>(
                            value: 'single',
                            groupValue: _xrayType,
                            onChanged: (v) => setState(() => _xrayType = v!),
                          ),
                          const Text('سن واحد'),
                          Radio<String>(
                            value: 'group',
                            groupValue: _xrayType,
                            onChanged: (v) => setState(() => _xrayType = v!),
                          ),
                          const Text('مجموعة أسنان'),
                          Radio<String>(
                            value: 'panorama',
                            groupValue: _xrayType,
                            onChanged: (v) => setState(() => _xrayType = v!),
                          ),
                          const Text('بانوراما'),
                        ],
                      ),
                      if (_xrayType == 'single')
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('الفك:'),
                            Row(
                              children: [
                                Radio<String>(
                                  value: 'علوي',
                                  groupValue: _jaw,
                                  onChanged: (v) => setState(() => _jaw = v),
                                ),
                                const Text('علوي'),
                                Radio<String>(
                                  value: 'سفلي',
                                  groupValue: _jaw,
                                  onChanged: (v) => setState(() => _jaw = v),
                                ),
                                const Text('سفلي'),
                              ],
                            ),
                            const Text('الجهة:'),
                            Row(
                              children: [
                                Radio<String>(
                                  value: 'أيمن',
                                  groupValue: _side,
                                  onChanged: (v) => setState(() => _side = v),
                                ),
                                const Text('أيمن'),
                                Radio<String>(
                                  value: 'أيسر',
                                  groupValue: _side,
                                  onChanged: (v) => setState(() => _side = v),
                                ),
                                const Text('أيسر'),
                              ],
                            ),
                            TextField(
                              controller: _toothController,
                              decoration: const InputDecoration(labelText: 'رقم السن'),
                            ),
                          ],
                        ),
                      if (_xrayType == 'group')
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...groupTeeth.map((t) => Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    title: Text('الفك: ${t['jaw']} - الجهة: ${t['side']} - السن: ${t['tooth']}'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          groupTeeth.remove(t);
                                        });
                                      },
                                    ),
                                  ),
                                )),
                            const Text('إضافة سن:'),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('الفك:'),
                                      Row(
                                        children: [
                                          Radio<String>(
                                            value: 'علوي',
                                            groupValue: _jaw,
                                            onChanged: (v) => setState(() => _jaw = v),
                                          ),
                                          const Text('علوي'),
                                          Radio<String>(
                                            value: 'سفلي',
                                            groupValue: _jaw,
                                            onChanged: (v) => setState(() => _jaw = v),
                                          ),
                                          const Text('سفلي'),
                                        ],
                                      ),
                                      const Text('الجهة:'),
                                      Row(
                                        children: [
                                          Radio<String>(
                                            value: 'أيمن',
                                            groupValue: _side,
                                            onChanged: (v) => setState(() => _side = v),
                                          ),
                                          const Text('أيمن'),
                                          Radio<String>(
                                            value: 'أيسر',
                                            groupValue: _side,
                                            onChanged: (v) => setState(() => _side = v),
                                          ),
                                          const Text('أيسر'),
                                        ],
                                      ),
                                      TextField(
                                        controller: _toothController,
                                        decoration: const InputDecoration(labelText: 'رقم السن'),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle, color: Colors.blue, size: 32),
                                  onPressed: () {
                                    if (_jaw != null && _side != null && _toothController.text.isNotEmpty) {
                                      setState(() {
                                        groupTeeth.add({
                                          'jaw': _jaw!,
                                          'side': _side!,
                                          'tooth': _toothController.text.trim(),
                                        });
                                        _toothController.clear();
                                        _jaw = null;
                                        _side = null;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _submitRequest,
                        child: const Text('إرسال الطلب'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
