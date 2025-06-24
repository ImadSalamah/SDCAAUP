import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'patient_sidebar.dart';
import 'patient_prescriptions_page.dart';
import 'patient_profile_page.dart';
import '../dashboard/patient_dashboard.dart';

class PatientAppointmentsPage extends StatefulWidget {
  final String patientUid;
  final String patientName;
  const PatientAppointmentsPage({super.key, required this.patientUid, required this.patientName});

  @override
  State<PatientAppointmentsPage> createState() => _PatientAppointmentsPageState();
}

class _PatientAppointmentsPageState extends State<PatientAppointmentsPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _database.child('appointments').once();
      List<Map<String, dynamic>> appts = [];

      if (snapshot.snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
        for (var entry in data.entries) {
          final appt = Map<String, dynamic>.from(entry.value);
          appt['key'] = entry.key;

          final patientUid = appt['patientUid']?.toString();
          final patientName = appt['patientName']?.toString();
          if ((patientUid != null && patientUid == widget.patientUid) ||
              (patientName != null && patientName == widget.patientName)) {
            appts.add(appt);
          }
        }

        for (var appt in appts) {
          String phone = '';
          String fullName = '';

          // جلب اسم الطالب ورقم هاتفه من users باستخدام userId == studentId
          final studentId = appt['studentId']?.toString();
          if (studentId != null && studentId.isNotEmpty) {
            final userSnap = await _database.child('users/$studentId').get();
            if (userSnap.exists && userSnap.value != null) {
              final userData = Map<String, dynamic>.from(userSnap.value as Map);
              final firstName = userData['firstName']?.toString().trim() ?? '';
              final fatherName = userData['fatherName']?.toString().trim() ?? '';
              final grandfatherName = userData['grandfatherName']?.toString().trim() ?? '';
              final familyName = userData['familyName']?.toString().trim() ?? '';
              fullName = [firstName, fatherName, grandfatherName, familyName].where((e) => e.isNotEmpty).join(' ');
              final phoneVal = userData['phone']?.toString() ?? '';
              phone = phoneVal;
            }
          }

          appt['createdByName'] = fullName.isNotEmpty ? fullName : '---';
          appt['createdByPhone'] = phone;
        }

        // ترتيب حسب التاريخ
        appts.sort((a, b) {
          final aTime = DateTime.tryParse(a['date'] ?? '') ?? DateTime.now();
          final bTime = DateTime.tryParse(b['date'] ?? '') ?? DateTime.now();
          return aTime.compareTo(bTime);
        });
      }

      setState(() {
        _appointments = appts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء جلب المواعيد: $e')),
      );
    }
  }

  String formatTime(String time) {
    try {
      // معالجة الوقت مثل "7:00 م" أو "6:00 ص"
      final arTime = time.replaceAll('ص', 'AM').replaceAll('م', 'PM').replaceAll(' ', '');
      final parsed = DateFormat('h:mm a', 'en').parse(arTime);
      return DateFormat('h:mm a', 'ar').format(parsed);
    } catch (_) {
      return time;
    }
  }

  void _handleSidebarNavigation(String route) async {
    if (ModalRoute.of(context)?.settings.name == route) return;
    switch (route) {
      case '/patient_dashboard':
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const PatientDashboard()),
          (route) => false,
        );
        break;
      case '/medical_records':
        Navigator.pushNamed(context, '/medical_records');
        break;
      case '/patient_appointments':
        // Already here
        break;
      case '/patient_prescriptions':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientPrescriptionsPage(patientId: widget.patientUid),
          ),
        );
        break;
      case '/patient_profile':
        // جلب بيانات المريض من قاعدة البيانات
        final userSnap = await _database.child('users/${widget.patientUid}').get();
        Map<String, dynamic> patientData = {};
        String patientImageUrl = '';
        if (userSnap.exists && userSnap.value != null) {
          patientData = Map<String, dynamic>.from(userSnap.value as Map);
          final imageData = patientData['image']?.toString() ?? '';
          if (imageData.isNotEmpty) {
            patientImageUrl = 'data:image/jpeg;base64,$imageData';
          }
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientProfilePage(
              patientData: patientData,
              patientImageUrl: patientImageUrl,
            ),
          ),
        );
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);
    bool hasTodayAppointment = _appointments.any((appt) {
      String dateStr = appt['date']?.toString() ?? '';
      String dateOnly = dateStr.contains('T') ? dateStr.split('T')[0] : (dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr);
      return dateOnly == todayStr;
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('مواعيدي'),
      ),
      drawer: PatientSidebar(
        onNavigate: _handleSidebarNavigation,
        currentRoute: '/patient_appointments',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _appointments.isEmpty
              ? const Center(child: Text('لا يوجد مواعيد'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Chip(
                            label: Text(
                              hasTodayAppointment ? 'يوجد موعد اليوم' : 'لا يوجد موعد اليوم',
                              style: const TextStyle(color: Colors.white),
                            ),
                            backgroundColor: hasTodayAppointment ? Colors.green : Colors.red,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _appointments.length,
                        itemBuilder: (context, index) {
                          final appt = _appointments[index];
                          String dateStr = appt['date']?.toString() ?? '';
                          String dateOnly = '';
                          if (dateStr.contains('T')) {
                            dateOnly = dateStr.split('T')[0];
                          } else if (dateStr.length >= 10) {
                            dateOnly = dateStr.substring(0, 10);
                          } else {
                            dateOnly = dateStr;
                          }

                          bool isToday = dateOnly == todayStr;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                            child: ListTile(
                              title: Text('تاريخ الموعد: $dateOnly'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('أنشأ الموعد: ${appt['createdByName'] ?? '---'}'),
                                  if ((appt['createdByPhone'] ?? '').isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Text(
                                        'رقم هاتف الطالب: ${appt['createdByPhone']}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                      ),
                                    ),
                                  if (appt['start'] != null && appt['end'] != null)
                                    Text('من: ${formatTime(appt['start'])} إلى: ${formatTime(appt['end'])}'),
                                ],
                              ),
                              trailing: Chip(
                                label: Text(
                                  isToday ? 'موعد اليوم' : 'ليس اليوم',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                backgroundColor: isToday ? Colors.green : Colors.red,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
