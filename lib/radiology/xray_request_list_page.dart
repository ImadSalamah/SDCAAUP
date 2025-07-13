import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../radiology/radiology_sidebar.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class XrayRequestListPage extends StatefulWidget {
  const XrayRequestListPage({Key? key}) : super(key: key);

  @override
  State<XrayRequestListPage> createState() => _XrayRequestListPageState();
}

class _XrayRequestListPageState extends State<XrayRequestListPage> {
  late DatabaseReference _xrayWaitingListRef;
  List<Map<String, dynamic>> xrayWaitingPatients = [];
  bool _isLoading = true;
  String userName = '';
  String userImageUrl = '';

  @override
  void initState() {
    super.initState();
    _xrayWaitingListRef = FirebaseDatabase.instance.ref('xray_waiting_list');
    _loadUserData();
    _loadXrayWaitingPatients();
  }

  Future<void> _loadUserData() async {
    // جلب أول مستخدم كاختبار، عدل لاحقاً لجلب المستخدم الحالي من Firebase Auth
    final userSnap = await FirebaseDatabase.instance.ref('users').orderByKey().limitToFirst(1).get();
    if (userSnap.exists) {
      final data = (userSnap.value as Map).values.first as Map;
      setState(() {
        // اسم رباعي
        userName = [
          data['firstName'] ?? '',
          data['fatherName'] ?? '',
          data['grandfatherName'] ?? '',
          data['familyName'] ?? ''
        ].where((e) => e.toString().trim().isNotEmpty).join(' ');
        final imageData = data['image']?.toString() ?? '';
        userImageUrl = imageData.isNotEmpty ? 'data:image/jpeg;base64,$imageData' : '';
      });
    } else {
      setState(() {
        userName = 'فني الأشعة';
        userImageUrl = '';
      });
    }
  }

  Future<void> _loadXrayWaitingPatients() async {
    setState(() { _isLoading = true; });
    final snapshot = await _xrayWaitingListRef.get();
    if (!snapshot.exists) {
      setState(() {
        xrayWaitingPatients = [];
        _isLoading = false;
      });
      return;
    }
    final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
    final List<Map<String, dynamic>> patients = [];
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is Map<dynamic, dynamic>) {
        final patientMap = Map<String, dynamic>.from(value);
        // جلب رقم الهوية من users
        String? idNumber = patientMap['idNumber'];
        if (idNumber == null && patientMap['patientId'] != null) {
          final userSnap = await FirebaseDatabase.instance.ref('users/${patientMap['patientId']}').get();
          if (userSnap.exists) {
            final userData = userSnap.value as Map<dynamic, dynamic>;
            idNumber = userData['idNumber']?.toString();
          }
        }
        patients.add({
          'id': key,
          ...patientMap,
          'idNumber': idNumber,
        });
      }
    }
    setState(() {
      xrayWaitingPatients = patients;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    const Color primaryColor = Color(0xFF2A7A94);
    const Color accentColor = Color(0xFF4AB8D8);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final lang = languageProvider.currentLocale.languageCode;
    // قاموس النصوص متعدد اللغات
    final Map<String, Map<String, String>> localizedStrings = {
   
    
      'waiting_list': {
        'ar': 'قائمة الانتظار',
        'en': 'Waiting List',
      },
      'change_language': {
        'ar': 'تغيير اللغة',
        'en': 'Change Language',
      },
      'logout': {
        'ar': 'تسجيل الخروج',
        'en': 'Logout',
      },
      'xray_technician': {
        'ar': 'فني الأشعة',
        'en': 'Radiology Technician',
      },
      'patient_details': {
        'ar': 'تفاصيل المريض',
        'en': 'Patient Details',
      },
      'patient_name': {
        'ar': 'اسم المريض',
        'en': 'Patient Name',
      },
      'file_number': {
        'ar': 'رقم الملف',
        'en': 'File Number',
      },
      'xray_requests_title': {
        'ar': 'طلبات انتظار الأشعة',
        'en': 'X-ray Waiting Requests',
      },
      'upload_xray_title': {
        'ar': 'رفع صورة الأشعة',
        'en': 'Upload X-ray Image',
      },
      'pick_xray_image': {
        'ar': 'اختيار صورة الأشعة',
        'en': 'Pick X-ray Image',
      },
      'upload_and_save': {
        'ar': 'رفع الصورة وحفظ',
        'en': 'Upload and Save',
      },
      'no_image_selected': {
        'ar': 'لم يتم اختيار صورة',
        'en': 'No image selected',
      },
      'upload_success': {
        'ar': 'تم رفع صورة الأشعة بنجاح',
        'en': 'X-ray image uploaded successfully',
      },
      'patient_name_label': {
        'ar': 'اسم المريض',
        'en': 'Patient Name',
      },
      'id_number_label': {
        'ar': 'رقم الهوية',
        'en': 'ID Number',
      },
      'xray_type_label': {
        'ar': 'نوع الأشعة',
        'en': 'X-ray Type',
      },
      'jaw_label': {
        'ar': 'الفك',
        'en': 'Jaw',
      },
      'side_label': {
        'ar': 'الجهة',
        'en': 'Side',
      },
      'tooth_label': {
        'ar': 'رقم السن',
        'en': 'Tooth Number',
      },
      'group_tooth_label': {
        'ar': 'سن: الفك {jaw} - الجهة {side} - رقم {tooth}',
        'en': 'Tooth: Jaw {jaw} - Side {side} - No. {tooth}',
      },
      'home': {
        'ar': 'الرئيسية',
        'en': 'Home',
      },
      // أضف المزيد حسب الحاجة
    };
    // بيانات افتراضية لاسم المستخدم وصورته (يمكنك تعديلها لاحقاً)
    return Scaffold(
      drawer: RadiologySidebar(
        primaryColor: primaryColor,
        accentColor: accentColor,
        userName: userName,
        userImageUrl: userImageUrl,
        onClose: () {
          Navigator.pop(context);
        },
        onHome: () {
          Navigator.pushReplacementNamed(context, '/radiology-dashboard');
        },
        onWaitingList: () {
          Navigator.pop(context);
        },
        parentContext: context,
        lang: lang,
        localizedStrings: localizedStrings,
      ),
      appBar: AppBar(
        title: Text(localizedStrings['xray_requests_title']?[lang] ?? ''),
        backgroundColor: primaryColor,
        elevation: 2,
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        width: double.infinity,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : xrayWaitingPatients.isEmpty
                ? Center(
                    child: Text(
                      'لا يوجد طلبات حالياً',
                      style: textTheme.titleMedium?.copyWith(color: theme.hintColor),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    itemCount: xrayWaitingPatients.length,
                    itemBuilder: (context, index) {
                      final patient = xrayWaitingPatients[index];
                      return Card(
                        color: isDark ? theme.cardColor : Colors.white,
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Directionality(
                          textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              // استدعاء صفحة رفع الأشعة مع تمرير البراميترات
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => XrayUploadPage(
                                    request: patient,
                                    lang: lang,
                                    localizedStrings: localizedStrings,
                                  ),
                                ),
                              );
                              // إعادة تحميل قائمة الانتظار تلقائياً بعد العودة
                              _loadXrayWaitingPatients();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(Icons.person, color: primaryColor, size: 36),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: lang == 'ar' ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          patient['patientName'] ?? 'بدون اسم',
                                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                          textAlign: lang == 'ar' ? TextAlign.right : TextAlign.left,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${localizedStrings['file_number']?[lang] ?? 'رقم الهوية'}: ${patient['idNumber'] ?? ''}',
                                          style: textTheme.bodyMedium,
                                          textAlign: lang == 'ar' ? TextAlign.right : TextAlign.left,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${localizedStrings['xray_type_label']?[lang] ?? 'نوع الأشعة'}: ${patient['xrayType'] ?? ''}',
                                          style: textTheme.bodySmall?.copyWith(color: theme.hintColor),
                                          textAlign: lang == 'ar' ? TextAlign.right : TextAlign.left,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios, color: primaryColor, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class XrayUploadPage extends StatefulWidget {
  final Map<String, dynamic> request;
  final String lang;
  final Map<String, Map<String, String>> localizedStrings;
  const XrayUploadPage({Key? key, required this.request, required this.lang, required this.localizedStrings}) : super(key: key);

  @override
  State<XrayUploadPage> createState() => _XrayUploadPageState();
}

class _XrayUploadPageState extends State<XrayUploadPage> {
  XFile? xrayImage;
  Uint8List? xrayImageBytes;
  bool _isUploading = false;

  late TextEditingController _nameController;
  late TextEditingController _idController;
  late TextEditingController _typeController;

  @override
  void initState() {
    super.initState();
    final req = widget.request;
    _nameController = TextEditingController(text: req['patientName'] ?? '');
    _idController = TextEditingController(text: req['idNumber'] ?? '');
    _typeController = TextEditingController(text: req['xrayType'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        xrayImage = picked;
        xrayImageBytes = bytes;
      });
    }
  }

  Future<void> _uploadXray() async {
    if (xrayImageBytes == null) return;
    final req = widget.request;
    // حذف الطلب من قائمة الانتظار مباشرة بعد الضغط على الزر
    final ref = FirebaseDatabase.instance.ref('xray_waiting_list/${req['id']}');
    await ref.remove();
    if (mounted) {
      setState(() {}); // تحديث الواجهة مباشرة بعد الحذف
    }
    setState(() { _isUploading = true; });
    final base64Image = base64Encode(xrayImageBytes!);
    // إرسال الصورة إلى السيرفر لتحليلها
    Map<String, dynamic>? analysisResultJson;
    String? analyzedImageBase64;
    try {
      final response = await fetchAnalyzedXray(base64Image);
      if (response != null) {
        analysisResultJson = response;
        if (response['analyzedImage'] != null) {
          analyzedImageBase64 = response['analyzedImage'];
        }
      }
    } catch (e) {
      analyzedImageBase64 = null;
      analysisResultJson = null;
    }
    final xrayImagesRef = FirebaseDatabase.instance.ref('xray_images');
    // حفظ بيانات صورة الأشعة الأصلية والمحللة في مجموعة جديدة مع الموقع المطلوب، مع حفظ كل الجيسون الراجع من الAPI
    await xrayImagesRef.push().set({
      'patientName': _nameController.text.trim(),
      'idNumber': _idController.text.trim(),
      'xrayType': _typeController.text.trim(),
      'jaw': req['jaw'],
      'side': req['side'],
      'tooth': req['tooth'],
      'groupTeeth': req['groupTeeth'],
      'patientId': req['patientId'],
      'originalXrayImage': base64Image,
      'analyzedXrayImage': analyzedImageBase64 ?? '',
      'analysisResultJson': analysisResultJson ?? {},
      'location': req['location'], // إضافة الموقع المطلوب
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    setState(() { _isUploading = false; });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع صورة الأشعة بنجاح')));
    Navigator.pop(context);
  }

  // دالة إرسال الصورة إلى السيرفر واستقبال الصورة المحللة
  Future<Map<String, dynamic>?> fetchAnalyzedXray(String base64Image) async {
    // عدل الرابط حسب عنوان السيرفر الفعلي
    const String apiUrl = 'https://xraymodel.fly.dev/analyze';
    try {
      // فك تشفير base64 إلى bytes
      final imageBytes = base64Decode(base64Image);
      final request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'xray.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        print('Server response: \\n${response.body}');
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error in fetchAnalyzedXray: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final size = MediaQuery.of(context).size;
    const Color primaryColor = Color(0xFF2A7A94); // اللون الموحد في كل البرنامج
    final lang = widget.lang;
    final localizedStrings = widget.localizedStrings;
    return Scaffold(
      appBar: AppBar(
        title: Text(localizedStrings['upload_xray_title']?[lang] ?? ''),
        backgroundColor: primaryColor,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.06 > 32 ? 32 : size.width * 0.06,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${localizedStrings['patient_name_label']?[lang] ?? 'اسم المريض'}: ${req['patientName'] ?? ''}',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('${localizedStrings['id_number_label']?[lang] ?? 'رقم الهوية'}: ${req['idNumber'] ?? ''}',
                  style: textTheme.bodyMedium),
              const SizedBox(height: 10),
              Text('${localizedStrings['xray_type_label']?[lang] ?? 'نوع الأشعة'}: ${req['xrayType'] ?? ''}',
                  style: textTheme.bodyMedium),
              if (req['jaw'] != null) Text('الفك: ${req['jaw']}', style: textTheme.bodyMedium),
              if (req['side'] != null) Text('الجهة: ${req['side']}', style: textTheme.bodyMedium),
              if (req['tooth'] != null) Text('رقم السن: ${req['tooth']}', style: textTheme.bodyMedium),
              if (req['groupTeeth'] != null && req['groupTeeth'] is List)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang == 'ar' ? 'الأسنان المطلوبة:' : 'Requested Teeth:',
                      style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    ...List<Map>.from(req['groupTeeth']).map((t) => Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: TextStyle(fontSize: 18)),
                            Expanded(
                              child: Text(
                                (localizedStrings['group_tooth_label']?[lang] ?? 'سن: الفك {jaw} - الجهة {side} - رقم {tooth}')
                                    .replaceAll('{jaw}', t['jaw'].toString())
                                    .replaceAll('{side}', t['side'].toString())
                                    .replaceAll('{tooth}', t['tooth'].toString()),
                                style: textTheme.bodySmall,
                              ),
                            ),
                          ],
                        )),
                  ],
                ),
              const SizedBox(height: 20),
              Center(
                child: xrayImageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(xrayImageBytes!, height: size.height * 0.22, fit: BoxFit.cover),
                      )
                    : Text(localizedStrings['no_image_selected']?[lang] ?? '', style: textTheme.bodySmall?.copyWith(color: theme.hintColor)),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image),
                  label: Text(localizedStrings['pick_xray_image']?[lang] ?? ''),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: SizedBox(
                  width: size.width * 0.6,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: xrayImageBytes != null && !_isUploading ? _uploadXray : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: _isUploading
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(localizedStrings['upload_and_save']?[lang] ?? ''),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
