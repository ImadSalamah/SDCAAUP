import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


class PrescriptionPage extends StatefulWidget {
  final bool isArabic;
  final String doctorName;
  const PrescriptionPage({super.key, required this.isArabic, required this.doctorName});

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
        'doctorName': widget.doctorName,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Prescription(s) added for patient')),
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
  Widget build(BuildContext context) {
    final isArabic = widget.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = const Color(0xFF2A7A94);
    final Color accentColor = const Color(0xFF4AB8D8);
    final Color bgColor = isDark ? const Color(0xFF23272F) : const Color(0xFFF9F3FF);
    final Color cardColor = isDark ? const Color(0xFF2A2D37) : Colors.white;
    final Color borderColor = isDark ? Colors.white12 : Colors.black12;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(isArabic ? 'إضافة وصفة طبية' : 'Add Prescription'),
        centerTitle: true,
        elevation: 2,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: borderColor,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          isArabic
                              ? 'ابحث عن المريض بالاسم أو رقم الهوية:'
                              : 'Search patient by name or ID:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: primaryColor)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: patientSearchController,
                              decoration: InputDecoration(
                                labelText: isArabic
                                    ? 'اسم المريض أو رقم الهوية'
                                    : 'Patient name or ID',
                                prefixIcon: const Icon(Icons.person_search),
                                filled: true,
                                fillColor: bgColor,
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
                                : Icon(Icons.search, color: primaryColor),
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
                                color: bgColor,
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
                                      '${isArabic ? 'رقم الهوية' : 'ID'}: ${patient['idNumber'] ?? ''}'),
                                  selected: selectedPatientIndex == i,
                                  onTap: () {
                                    setState(() {
                                      selectedPatientIndex = i;
                                    });
                                    FocusScope.of(context).unfocus();
                                  },
                                  trailing: selectedPatientIndex == i
                                      ? Icon(Icons.check_circle, color: accentColor)
                                      : null,
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      if (selectedPatientIndex != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            isArabic
                                ? 'المريض المختار: ' +
                                    [
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
                                    ].where((e) => e != '').join(' ') +
                                    ' رقم الهوية: ${foundPatients[selectedPatientIndex!]['idNumber'] ?? ''}'
                                : 'Selected: ' +
                                    [
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
                                    ].where((e) => e != '').join(' ') +
                                    ' ID: ${foundPatients[selectedPatientIndex!]['idNumber'] ?? ''}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: accentColor),
                          ),
                        ),
                      const Divider(height: 30),
                      Text(
                          isArabic
                              ? 'اختر الدواء:'
                              : 'Select medicine:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: primaryColor)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          labelText:
                              isArabic ? 'بحث عن دواء' : 'Search medicine',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: bgColor,
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
                          fillColor: bgColor,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        hint: Text(
                            isArabic ? 'اختر دواء' : 'Select medicine'),
                      ),
                      if (selectedMedicine == 'Other/أخرى')
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: TextField(
                            controller: customController,
                            decoration: InputDecoration(
                              labelText: isArabic
                                  ? 'اسم الدواء'
                                  : 'Medicine name',
                              filled: true,
                              fillColor: bgColor,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Text(
                          isArabic
                              ? 'متى يأخذ الدواء:'
                              : 'When to take the medicine:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: primaryColor)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: timeController,
                        decoration: InputDecoration(
                          labelText: isArabic
                              ? 'مثال: مرتين يومياً بعد الأكل'
                              : 'e.g. Twice daily after meals',
                          prefixIcon: const Icon(Icons.schedule),
                          filled: true,
                          fillColor: bgColor,
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
                                backgroundColor: accentColor,
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
                              child: Text(isArabic ? 'إضافة دواء' : 'Add Medicine'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: selectedPatientIndex != null && tempMedicines.isNotEmpty
                                  ? addPrescription
                                  : null,
                              child: Text(isArabic ? 'حفظ الوصفة' : 'Save Prescription'),
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
                                isArabic ? 'الأدوية المضافة:' : 'Added medicines:',
                                style: TextStyle(fontWeight: FontWeight.bold, color: accentColor),
                              ),
                              ...tempMedicines.map((med) => Card(
                                    color: cardColor,
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    child: ListTile(
                                      title: Text(med['medicine'] ?? ''),
                                      subtitle: Text((isArabic ? 'وقت الاستخدام: ' : 'Time: ') + (med['time'] ?? '')),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                    isArabic
                        ? 'الوصفات المضافة:'
                        : 'Added prescriptions:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: primaryColor)),
                if (prescriptions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      isArabic
                          ? 'لا توجد وصفات مضافة بعد'
                          : 'No prescriptions added yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ...prescriptions.map((p) => Card(
                      color: cardColor,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text('${p['medicine']}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '${isArabic ? 'للمريض' : 'For'}: ${p['patientName']}\n${isArabic ? 'وقت الاستخدام' : 'Time'}: ${p['time']}'),
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}