// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'patient_sidebar.dart';
import 'patient_prescriptions_page.dart';
import 'patient_profile_page.dart';
import '../dashboard/patient_dashboard.dart';

class PatientAppointmentsPage extends StatefulWidget {
  final String patientUid;
  const PatientAppointmentsPage({super.key, required this.patientUid});

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
          if (patientUid != null && patientUid == widget.patientUid) {
            appts.add(appt);
          }
        }

        for (var appt in appts) {
          String phone = '';
          String fullName = '';
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PatientProfilePage(),
          ),
        );
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);
    bool hasTodayAppointment = _appointments.any((appt) {
      String dateStr = appt['date']?.toString() ?? '';
      String dateOnly = dateStr.contains('T') ? dateStr.split('T')[0] : (dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr);
      return dateOnly == todayStr;
    });
    const Color primaryColor = Color(0xFF2A7A94);
    final locale = Localizations.localeOf(context).languageCode;
    String t(String ar, String en) => locale == 'ar' ? ar : en;
    final hasTodayLabel = t('يوجد موعد اليوم', 'You have an appointment today');
    final noTodayLabel = t('لا يوجد موعد اليوم', 'No appointment today');
    final isTodayLabel = t('موعد اليوم', 'Today');
    final notTodayLabel = t('ليس اليوم', 'Not today');
    return Scaffold(
      appBar: AppBar(
        title: Text(t('مواعيدي', 'My Appointments'), style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
      ),
      drawer: PatientSidebar(
        onNavigate: _handleSidebarNavigation,
        currentRoute: '/patient_appointments',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _appointments.isEmpty
              ? Center(
                  child: Text(t('لا يوجد مواعيد', 'No appointments'), style: theme.textTheme.titleMedium?.copyWith(color: theme.hintColor)),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Chip(
                            label: Text(
                              hasTodayAppointment ? hasTodayLabel : noTodayLabel,
                              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: theme.primaryColorLight, width: 1),
                            ),
                            elevation: 3,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                              title: Text('${t('تاريخ الموعد', 'Appointment Date')}: $dateOnly', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('${t('أنشأ الموعد', 'Created by')}: ${appt['createdByName'] ?? '---'}', style: theme.textTheme.bodyMedium),
                                  if ((appt['createdByPhone'] ?? '').isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Text(
                                        '${t('رقم هاتف الطالب', 'Student phone')}: ${appt['createdByPhone']}',
                                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor),
                                      ),
                                    ),
                                  if (appt['start'] != null && appt['end'] != null)
                                    Text('${t('من', 'From')}: ${formatTime(appt['start'])} ${t('إلى', 'to')}: ${formatTime(appt['end'])}', style: theme.textTheme.bodyMedium),
                                ],
                              ),
                              trailing: Chip(
                                label: Text(
                                  isToday ? isTodayLabel : notTodayLabel,
                                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                                ),
                                backgroundColor: isToday ? primaryColor : Colors.grey,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
