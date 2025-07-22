import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'patient_sidebar.dart';
import '../dashboard/patient_dashboard.dart';
import 'patient_profile_page.dart';
import 'patient_appointments_page.dart';

class PatientPrescriptionsPage extends StatefulWidget {
  final String patientId;
  const PatientPrescriptionsPage({required this.patientId, super.key});

  @override
  State<PatientPrescriptionsPage> createState() => _PatientPrescriptionsPageState();
}

class _PatientPrescriptionsPageState extends State<PatientPrescriptionsPage> {
  List<Map<dynamic, dynamic>> prescriptions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrescriptions();
  }

  void _loadPrescriptions() async {
    final ref = FirebaseDatabase.instance.ref('prescriptions/${widget.patientId}');
    final snapshot = await ref.get();
    final List<Map<dynamic, dynamic>> loaded = [];
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        loaded.add(value as Map<dynamic, dynamic>);
      });
    }
    setState(() {
      prescriptions = loaded;
      isLoading = false;
    });
  }

  String _formatDate(dynamic iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso.toString();
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientAppointmentsPage(
              patientUid: widget.patientId,
            ),
          ),
        );
        break;
      case '/patient_prescriptions':
        // Already here
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
    final locale = Localizations.localeOf(context).languageCode;
    String t(String ar, String en) => locale == 'ar' ? ar : en;
    const Color primaryColor = Color(0xFF2A7A94);
    return Scaffold(
      appBar: AppBar(
        title: Text(t('الوصفات الطبية', 'Prescriptions'), style: const TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        centerTitle: true,
        elevation: 0,
      ),
      drawer: PatientSidebar(
        onNavigate: _handleSidebarNavigation,
        currentRoute: '/patient_prescriptions',
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFe0f7fa), Color(0xFFffffff)],
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : prescriptions.isEmpty
                ? Center(child: Text(t('لا توجد وصفات طبية', 'No prescriptions found'), style: const TextStyle(fontSize: 18, color: Colors.black54)))
                : ListView.separated(
                    itemCount: prescriptions.length,
                    separatorBuilder: (context, index) => Divider(thickness: 1.2, color: Colors.grey.shade200, height: 16),
                    itemBuilder: (context, index) {
                      final p = prescriptions[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.medication, color: primaryColor, size: 22),
                                  const SizedBox(width: 8),
                                  Text(t('الدواء:', 'Medicine:'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      p['medicine']?.toString() ?? '-',
                                      style: const TextStyle(fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, color: primaryColor, size: 20),
                                  const SizedBox(width: 8),
                                  Text(t('وقت الاستخدام:', 'Usage time:'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(p['time']?.toString() ?? '-', style: const TextStyle(fontSize: 15)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, color: primaryColor, size: 20),
                                  const SizedBox(width: 8),
                                  Text(t('تاريخ الإضافة:', 'Added on:'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _formatDate(p['createdAt']),
                                      style: const TextStyle(fontSize: 15, color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.person, color: primaryColor, size: 20),
                                  const SizedBox(width: 8),
                                  Text(t('اسم الدكتور:', 'Doctor:'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      p['doctorName']?.toString() ?? '-',
                                      style: const TextStyle(fontSize: 15),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
