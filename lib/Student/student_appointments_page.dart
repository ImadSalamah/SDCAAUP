import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../Student/student_sidebar.dart';

class StudentAppointmentsPage extends StatefulWidget {
  @override
  _StudentAppointmentsPageState createState() => _StudentAppointmentsPageState();
}

class _StudentAppointmentsPageState extends State<StudentAppointmentsPage> {
  DateTime? selectedDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  List<Map<String, dynamic>> appointments = [];
  final _auth = FirebaseAuth.instance;
  final DatabaseReference _appointmentsRef = FirebaseDatabase.instance.ref('appointments');
  bool _isLoading = false;
  String diseaseName = '';
  List<String> allDiseases = [];
  List<String> filteredDiseases = [];
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');
  final TextEditingController _diseaseController = TextEditingController();
  String selectedPatientName = '';
  String selectedPatientUid = '';
  List<Map<String, String>> allPatients = [];
  List<Map<String, String>> filteredPatients = [];
  final TextEditingController _patientController = TextEditingController();
  String? _studentName;
  String? _studentImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchStudentInfo();
    _fetchPatients();
    _fetchDiseases();
    _fetchStudentAppointments();
  }

  Future<void> _fetchStudentInfo() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final snapshot = await _usersRef.child(user.uid).get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final firstName = data['firstName'] ?? '';
      final fatherName = data['fatherName'] ?? '';
      final grandfatherName = data['grandfatherName'] ?? '';
      final familyName = data['familyName'] ?? '';
      final fullName = [firstName, fatherName, grandfatherName, familyName]
          .where((part) => part.toString().isNotEmpty)
          .join(' ');
      setState(() {
        _studentName = fullName.isNotEmpty ? fullName : 'الطالب';
        _studentImageUrl = data['imageUrl'] ?? null;
      });
    }
  }

  Future<void> _fetchPatients() async {
    final snapshot = await _usersRef.get();
    final List<Map<String, String>> patients = [];
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        if (value is Map && value['firstName'] != null && value['role'] == 'patient') {
          final fullName = [
            value['firstName'],
            value['fatherName'],
            value['grandfatherName'],
            value['familyName']
          ].where((e) => e != null && e.toString().isNotEmpty).join(' ');
          patients.add({'uid': key.toString(), 'name': fullName});
        }
      });
    }
    setState(() {
      allPatients = patients;
      filteredPatients = patients;
    });
  }

  Future<void> _fetchDiseases() async {
    final snapshot = await _usersRef.get();
    final Set<String> diseasesSet = {};
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        if (value is Map && value['diseaseName'] != null && value['diseaseName'].toString().isNotEmpty) {
          diseasesSet.add(value['diseaseName'].toString());
        }
      });
    }
    setState(() {
      allDiseases = diseasesSet.toList();
      filteredDiseases = allDiseases;
    });
  }

  Future<void> _fetchStudentAppointments() async {
    final user = _auth.currentUser;
    if (user == null) return;
    print('Fetching appointments for studentId: ' + user.uid);
    final snapshot = await _appointmentsRef.orderByChild('studentId').equalTo(user.uid).get();
    final List<Map<String, dynamic>> loadedAppointments = [];
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        if (value is Map) {
          final appt = Map<String, dynamic>.from(value);
          appt['key'] = key; // حفظ key مع كل موعد
          loadedAppointments.add(appt);
        }
      });
    }
    print('Loaded appointments: ' + loadedAppointments.toString());
    loadedAppointments.sort((a, b) {
      final dateA = DateTime.parse(a['date']);
      final dateB = DateTime.parse(b['date']);
      if (dateA != dateB) {
        return dateA.compareTo(dateB);
      }
      final timeA = a['start'];
      final timeB = b['start'];
      return timeA.compareTo(timeB);
    });
    setState(() {
      appointments = loadedAppointments;
    });
  }

  Future<void> _deleteAppointment(String key) async {
    await _appointmentsRef.child(key).remove();
    await _fetchStudentAppointments();
  }

  void _sortAppointments() {
    appointments.sort((a, b) {
      final dateA = DateTime.parse(a['date']);
      final dateB = DateTime.parse(b['date']);
      if (dateA != dateB) {
        return dateA.compareTo(dateB);
      }
      // إذا كان التاريخ نفسه، قارن حسب وقت البداية
      final timeA = a['start'];
      final timeB = b['start'];
      return timeA.compareTo(timeB);
    });
  }

  void _addAppointment() async {
    if (selectedDate != null && startTime != null && endTime != null && selectedPatientUid.isNotEmpty) {
      setState(() { _isLoading = true; });
      final user = _auth.currentUser;
      final appointment = {
        'date': selectedDate!.toIso8601String(),
        'start': startTime!.format(context),
        'end': endTime!.format(context),
        'studentId': user?.uid,
        'studentEmail': user?.email,
        'patientUid': selectedPatientUid,
        'patientName': selectedPatientName,
      };
      print('Adding appointment: ' + appointment.toString());
      await _appointmentsRef.push().set(appointment);
      await _fetchStudentAppointments();
      setState(() {
        selectedDate = null;
        startTime = null;
        endTime = null;
        selectedPatientName = '';
        selectedPatientUid = '';
        _patientController.clear();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() { selectedDate = picked; });
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startTime = picked;
        } else {
          endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;
    return Scaffold(
      appBar: AppBar(
        title: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'مواعيدي' : 'My Appointments'),
        backgroundColor: const Color(0xFF2A7A94),
        centerTitle: true,
        elevation: 2,
      ),
      drawer: StudentSidebar(
        studentName: _studentName,
        studentImageUrl: _studentImageUrl,
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 40 : 12,
          vertical: isTablet ? 30 : 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      Localizations.localeOf(context).languageCode == 'ar' ? 'إضافة موعد جديد' : 'Add New Appointment',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isTablet ? 22 : 18,
                        color: const Color(0xFF2A7A94),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _patientController,
                      decoration: InputDecoration(
                        labelText: Localizations.localeOf(context).languageCode == 'ar' ? 'ابحث عن اسم المريض' : 'Search for patient name',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (value) {
                        setState(() {
                          selectedPatientName = value;
                          selectedPatientUid = '';
                          filteredPatients = allPatients.where((p) => p['name']!.contains(value)).toList();
                        });
                      },
                    ),
                    if (selectedPatientName.isNotEmpty && filteredPatients.isNotEmpty)
                      Container(
                        constraints: BoxConstraints(maxHeight: 150),
                        child: ListView(
                          shrinkWrap: true,
                          children: filteredPatients.map((p) => ListTile(
                            title: Text(p['name']!),
                            onTap: () {
                              setState(() {
                                selectedPatientName = p['name']!;
                                selectedPatientUid = p['uid']!;
                                _patientController.text = p['name']!;
                                filteredPatients = [];
                              });
                            },
                          )).toList(),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.calendar_today, color: Color(0xFF2A7A94)),
                            label: Text(
                              selectedDate == null
                                  ? (Localizations.localeOf(context).languageCode == 'ar' ? 'اختر اليوم' : 'Select day')
                                  : '${selectedDate!.year}/${selectedDate!.month}/${selectedDate!.day}',
                              style: TextStyle(color: Color(0xFF2A7A94)),
                            ),
                            onPressed: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.access_time, color: Color(0xFF2A7A94)),
                            label: Text(
                              startTime == null ? (Localizations.localeOf(context).languageCode == 'ar' ? 'من' : 'From') : startTime!.format(context),
                              style: TextStyle(color: Color(0xFF2A7A94)),
                            ),
                            onPressed: () => _pickTime(true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.access_time_filled, color: Color(0xFF2A7A94)),
                            label: Text(
                              endTime == null ? (Localizations.localeOf(context).languageCode == 'ar' ? 'إلى' : 'To') : endTime!.format(context),
                              style: TextStyle(color: Color(0xFF2A7A94)),
                            ),
                            onPressed: () => _pickTime(false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                            icon: const Icon(Icons.add, color: Colors.white),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2A7A94),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: TextStyle(fontSize: isTablet ? 18 : 16, color: Colors.white),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _addAppointment,
                            label: Text(
                              Localizations.localeOf(context).languageCode == 'ar' ? 'إضافة الموعد' : 'Add Appointment',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              Localizations.localeOf(context).languageCode == 'ar' ? 'جميع مواعيدي' : 'All My Appointments',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isTablet ? 20 : 16,
                color: Colors.black87, // لون مريح للعين
              ),
            ),
            const SizedBox(height: 10),
            appointments.isEmpty
                ? Center(child: Text('لا يوجد مواعيد'))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: appointments.length,
                    itemBuilder: (context, index) {
                      final appt = appointments[index];
                      print('Rendering appointment: ' + appt.toString());
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF4AB8D8),
                            child: Icon(Icons.calendar_today, color: Colors.white),
                          ),
                          title: Text(
                            (Localizations.localeOf(context).languageCode == 'ar' ? 'اليوم: ' : 'Day: ') + DateTime.parse(appt['date']).toLocal().toString().split(' ')[0]),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((Localizations.localeOf(context).languageCode == 'ar' ? 'من: ' : 'From: ') + "${appt['start']}"),
                              Text((Localizations.localeOf(context).languageCode == 'ar' ? 'إلى: ' : 'To: ') + "${appt['end']}"),
                              Text((Localizations.localeOf(context).languageCode == 'ar' ? 'المريض: ' : 'Patient: ') + (appt['patientName'] ?? '')),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            tooltip: 'حذف الموعد',
                            onPressed: () async {
                              final key = appt['key'];
                              if (key != null) {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'تأكيد الحذف' : 'Confirm Deletion'),
                                    content: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'هل أنت متأكد أنك تريد حذف هذا الموعد؟' : 'Are you sure you want to delete this appointment?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'لا' : 'No'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'نعم' : 'Yes'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _deleteAppointment(key);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'تم حذف الموعد بنجاح' : 'Appointment deleted successfully'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
