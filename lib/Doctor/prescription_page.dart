// ignore_for_file: unused_import

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'doctor_sidebar.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class PrescriptionPage extends StatefulWidget {
  final bool isArabic;
  const PrescriptionPage({super.key, required this.isArabic});

  @override
  State<PrescriptionPage> createState() => _PrescriptionPageState();
}

class _PrescriptionPageState extends State<PrescriptionPage> {
  final List<String> medicines = [
    'Amoxicillin',
    'Metronidazole',
    'Ibuprofen',
    'Paracetamol',
    'Clindamycin',
    'Augmentin',
    'Naproxen',
    'Diclofenac',
    'Mefenamic Acid',
    'Chlorhexidine',
    'Aspirin',
    'Ciprofloxacin',
    'Other/أخرى',
  ];
  final List<Map<String, dynamic>> prescriptions = [];
  String? selectedMedicine;
  String? customMedicine;
  final TextEditingController searchController = TextEditingController();
  final TextEditingController customController = TextEditingController();
  final TextEditingController patientSearchController = TextEditingController();
  final TextEditingController timeController = TextEditingController();
  Map<String, dynamic>? foundPatient;
  bool isSearchingPatient = false;
  String? patientError;

  List<Map<String, dynamic>> foundPatients = [];
  int? selectedPatientIndex;

  List<Map<String, String>> tempMedicines = [];

  String? _doctorName;
  String? _doctorImageUrl;

  List<String> get filteredMedicines {
    if (searchController.text.isEmpty) return medicines;
    return medicines
        .where((m) => m.toLowerCase().contains(searchController.text.toLowerCase()))
        .toList();
  }

  Future<void> searchPatient() async {
    setState(() {
      isSearchingPatient = true;
      foundPatients = [];
      selectedPatientIndex = null;
      patientError = null;
    });
    final db = FirebaseDatabase.instance.ref('users');
    final query = patientSearchController.text.trim().toLowerCase();
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
            patientError = 'Patient not found';
          });
        }
      } else {
        setState(() {
          patientError = 'No patients found';
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

  void addMedicineToTempList() {
    String? med = selectedMedicine == 'Other/أخرى'
        ? customController.text.trim()
        : selectedMedicine;
    if (med == null || med.isEmpty || timeController.text.isEmpty) return;
    setState(() {
      tempMedicines.add({
        'medicine': med,
        'time': timeController.text,
      });
      if (selectedMedicine == 'Other/أخرى' && med.isNotEmpty && !medicines.contains(med)) {
        medicines.insert(medicines.length - 1, med);
      }
      selectedMedicine = null;
      customController.clear();
      timeController.clear();
    });
  }

  Future<void> addPrescription() async {
    if (selectedPatientIndex == null || tempMedicines.isEmpty) return;
    final foundPatient = foundPatients[selectedPatientIndex!];
    for (final med in tempMedicines) {
      final prescription = {
        'medicine': med['medicine'],
        'patientName': foundPatient['firstName'] ?? '',
        'patientId': foundPatient['idNumber'] ?? '',
        'time': med['time'],
        'createdAt': DateTime.now().toIso8601String(),
        'doctorName': _doctorName ?? '',
      };
      prescriptions.add(prescription);
      // Save to database
      final uid = foundPatient['uid'];
      final ref = FirebaseDatabase.instance.ref('prescriptions/$uid').push();
      await ref.set(prescription);
    }
    setState(() {
      tempMedicines.clear();
    });
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prescription(s) added for patient')),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    customController.dispose();
    patientSearchController.dispose();
    timeController.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2A7A94);
    const accentColor = Color(0xFF4AB8D8);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isArabic = languageProvider.currentLocale.languageCode == 'ar';
    return Scaffold(
      drawer: DoctorSidebar(
        primaryColor: primaryColor,
        accentColor: accentColor,
        userName: _doctorName ?? '',
        userImageUrl: _doctorImageUrl,
        parentContext: context,
        collapsed: false,
        translate: (ctx, key) => key,
        doctorUid: FirebaseAuth.instance.currentUser?.uid ?? '',
      ),
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(isArabic ? 'الوصفة الطبية' : 'Prescription'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        widget.isArabic
                            ? 'ابحث عن المريض بالاسم أو رقم الهوية:'
                            : 'Search patient by name or ID:',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.blue)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: patientSearchController,
                            decoration: InputDecoration(
                              labelText: widget.isArabic
                                  ? 'اسم المريض أو رقم الهوية'
                                  : 'Patient name or ID',
                              prefixIcon: const Icon(Icons.person_search),
                              filled: true,
                              fillColor: Colors.grey[200],
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onChanged: (_) => searchPatient(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: isSearchingPatient
                              ? const CircularProgressIndicator()
                              : const Icon(Icons.search, color: Colors.blue),
                          onPressed: isSearchingPatient ? null : searchPatient,
                        ),
                      ],
                    ),
                    if (patientError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(patientError!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    if (foundPatients.isNotEmpty && selectedPatientIndex == null)
                      Column(
                        children: [
                          ...foundPatients.asMap().entries.map((entry) {
                            final i = entry.key;
                            final patient = entry.value;
                            return Card(
                              color: Colors.grey[100],
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                title: Text(
                                    [
                                      patient['firstName'] ?? '',
                                      patient['fatherName'] ?? '',
                                      patient['grandfatherName'] ?? '',
                                      patient['familyName'] ?? ''
                                    ].where((e) => e != '').join(' '),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    '${widget.isArabic ? 'رقم الهوية' : 'ID'}: ${patient['idNumber'] ?? ''}'),
                                selected: selectedPatientIndex == i,
                                onTap: () {
                                  setState(() {
                                    selectedPatientIndex = i;
                                  });
                                  FocusScope.of(context).unfocus();
                                },
                                trailing: selectedPatientIndex == i
                                    ? const Icon(Icons.check_circle, color: Colors.blueAccent)
                                    : null,
                              ),
                            );
                          }),
                        ],
                      ),
                    if (selectedPatientIndex != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          widget.isArabic
                              ? 'المريض المختار: ${[
                                    foundPatients[selectedPatientIndex!]
                                            ['firstName'] ??
                                        '',
                                    foundPatients[selectedPatientIndex!]
                                            ['fatherName'] ??
                                        '',
                                    foundPatients[selectedPatientIndex!]
                                            ['grandfatherName'] ??
                                        '',
                                    foundPatients[selectedPatientIndex!]
                                            ['familyName'] ??
                                        ''
                                  ].where((e) => e != '').join(' ')} رقم الهوية: ${foundPatients[selectedPatientIndex!]['idNumber'] ?? ''}'
                              : 'Selected: ${[
                                    foundPatients[selectedPatientIndex!]
                                            ['firstName'] ??
                                        '',
                                    foundPatients[selectedPatientIndex!]
                                            ['fatherName'] ??
                                        '',
                                    foundPatients[selectedPatientIndex!]
                                            ['grandfatherName'] ??
                                        '',
                                    foundPatients[selectedPatientIndex!]
                                            ['familyName'] ??
                                        ''
                                  ].where((e) => e != '').join(' ')} ID: ${foundPatients[selectedPatientIndex!]['idNumber'] ?? ''}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.blueAccent),
                        ),
                      ),
                    const Divider(height: 30),
                    Text(
                        widget.isArabic
                            ? 'اختر الدواء:'
                            : 'Select medicine:',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.blue)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText:
                            widget.isArabic ? 'بحث عن دواء' : 'Search medicine',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedMedicine,
                      items: filteredMedicines.map((med) {
                        return DropdownMenuItem(
                          value: med,
                          child: Text(med),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedMedicine = val;
                          if (val == 'Other/أخرى') {
                            customMedicine = '';
                          }
                        });
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      hint: Text(
                          widget.isArabic ? 'اختر دواء' : 'Select medicine'),
                    ),
                    if (selectedMedicine == 'Other/أخرى')
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: TextField(
                          controller: customController,
                          decoration: InputDecoration(
                            labelText: widget.isArabic
                                ? 'اسم الدواء'
                                : 'Medicine name',
                            filled: true,
                            fillColor: Colors.grey[200],
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                        widget.isArabic
                            ? 'متى يأخذ الدواء:'
                            : 'When to take the medicine:',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.blue)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: timeController,
                      decoration: InputDecoration(
                        labelText: widget.isArabic
                            ? 'مثال: مرتين يومياً بعد الأكل'
                            : 'e.g. Twice daily after meals',
                        prefixIcon: const Icon(Icons.schedule),
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: ((selectedMedicine != null && selectedMedicine != 'Other/أخرى') ||
                                    (selectedMedicine == 'Other/أخرى' && customController.text.isNotEmpty)) &&
                                timeController.text.isNotEmpty
                                ? addMedicineToTempList
                                : null,
                            child: Text(widget.isArabic ? 'إضافة دواء' : 'Add Medicine'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: selectedPatientIndex != null && tempMedicines.isNotEmpty
                                ? addPrescription
                                : null,
                            child: Text(widget.isArabic ? 'حفظ الوصفة' : 'Save Prescription'),
                          ),
                        ),
                      ],
                    ),
                    if (tempMedicines.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isArabic ? 'الأدوية المضافة:' : 'Added medicines:',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                            ),
                            ...tempMedicines.map((med) => Card(
                                  color: Colors.grey[100],
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    title: Text(med['medicine'] ?? ''),
                                    subtitle: Text((widget.isArabic ? 'وقت الاستخدام: ' : 'Time: ') + (med['time'] ?? '')),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                  widget.isArabic
                      ? 'الوصفات المضافة:'
                      : 'Added prescriptions:',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 10),
              if (prescriptions.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    widget.isArabic
                        ? 'لا توجد وصفات مضافة بعد'
                        : 'No prescriptions added yet',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              if (prescriptions.isNotEmpty)
                Text(
                  widget.isArabic
                      ? 'عدد الوصفات المضافة: ${prescriptions.length}'
                      : 'Total prescriptions added: ${prescriptions.length}',
                  style: const TextStyle(color: Colors.blueAccent),
                ),
              const SizedBox(height: 10),
              ...prescriptions.map((p) => Card(
                    color: Colors.grey[100],
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text('${p['medicine']}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          '${widget.isArabic ? 'للمريض' : 'For'}: ${p['patientName']}\n${widget.isArabic ? 'وقت الاستخدام' : 'Time'}: ${p['time']}'),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}