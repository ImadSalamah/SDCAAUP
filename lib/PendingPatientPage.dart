// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';


// تحويل الصفحة إلى StatefulWidget لمعاينة الصورة مباشرة
class PendingPatientPage extends StatefulWidget {
  const PendingPatientPage({super.key});

  static Future<Map<String, dynamic>?> getPendingUserDataByUid(String uid) async {
    final dbRef = FirebaseDatabase.instance.ref();
    // جرب أولاً pendingUsers
    final snapshot = await dbRef.child('pendingUsers/$uid').get();
    if (snapshot.exists) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    // إذا لم يوجد في pendingUsers، جرب rejectedUsers
    final rejectedSnapshot = await dbRef.child('rejectedUsers/$uid').get();
    if (rejectedSnapshot.exists) {
      return Map<String, dynamic>.from(rejectedSnapshot.value as Map);
    }
    return null;
  }

  @override
  State<PendingPatientPage> createState() => _PendingPatientPageState();
}

class _PendingPatientPageState extends State<PendingPatientPage> {
  String? _localImageBase64; // لمعاينة الصورة الجديدة
  bool _isUploading = false;
  bool _editSaved = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';
    debugPrint('DEBUG: UID used for pending search: $uid');
    return FutureBuilder<Map<String, dynamic>?> (
      future: PendingPatientPage.getPendingUserDataByUid(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const Center(child: Text('لا توجد بيانات لهذا الحساب.'));
        }
        final userData = snapshot.data!;
        List<String> fieldsToEdit = [];
        bool isRejected = false;
        if (userData['fieldsToEdit'] is List && (userData['fieldsToEdit'] as List).isNotEmpty) {
          fieldsToEdit = List<String>.from(userData['fieldsToEdit']);
          isRejected = true;
        }
        String? rejectionReason = userData['rejectionReason'];
        final TextEditingController firstNameController = TextEditingController(text: userData['firstName'] ?? '');
        final TextEditingController fatherNameController = TextEditingController(text: userData['fatherName'] ?? '');
        final TextEditingController grandfatherNameController = TextEditingController(text: userData['grandfatherName'] ?? '');
        final TextEditingController familyNameController = TextEditingController(text: userData['familyName'] ?? '');
        final TextEditingController idNumberController = TextEditingController(text: userData['idNumber'] ?? '');
        final TextEditingController birthDateController = TextEditingController(
            text: userData['birthDate'] != null
                ? DateTime.fromMillisecondsSinceEpoch(userData['birthDate']).toString().split(' ')[0]
                : '');
        final TextEditingController genderController = TextEditingController(text: userData['gender'] ?? '');
        final TextEditingController phoneController = TextEditingController(text: userData['phone'] ?? '');
        final TextEditingController addressController = TextEditingController(text: userData['address'] ?? '');
        final TextEditingController emailController = TextEditingController(text: userData['email'] ?? '');
        return Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.hourglass_empty, size: 80, color: Colors.orange),
                    const SizedBox(height: 24),
                    Text('حسابك قيد المراجعة',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800]),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    if (isRejected) ...[
                      Text(
                        'يرجى تعديل الحقول المطلوبة أدناه ثم الضغط على حفظ التعديلات.',
                        style: TextStyle(
                            fontSize: 18,
                            color: Colors.red[800],
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      if (rejectionReason != null && rejectionReason.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 12),
                          child: Text('ملاحظة: $rejectionReason',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.orange[900])),
                        ),
                    ] else ...[
                      const Text(
                        'تم استلام طلبك بنجاح. حسابك كمريض قيد المراجعة من قبل الإدارة. سيتم تفعيل الحساب قريبًا ويمكنك المتابعة لاحقًا.',
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],
                    // صورة المستخدم تظهر دائماً
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // معاينة الصورة الجديدة إذا تم اختيارها، وإلا الصورة القديمة
                            if (_localImageBase64 != null && _localImageBase64!.isNotEmpty)
                              buildSafeCircleAvatar(_localImageBase64!, 60)
                            else if (userData['image'] != null && userData['image'].toString().isNotEmpty)
                              buildSafeCircleAvatar(userData['image'].toString(), 60)
                            else
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.grey[200],
                                child: Icon(Icons.person, size: 60, color: Colors.grey[600]),
                              ),
                            // زر التعديل يظهر فقط إذا كان الحساب مرفوض ويحتاج تعديل الصورة
                            if (isRejected && fieldsToEdit.contains('image'))
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: IconButton(
                                  icon: Icon(Icons.edit, color: Colors.orange[800]),
                                  onPressed: () async {
                                    final ImagePicker picker = ImagePicker();
                                    final XFile? picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                                    if (picked != null) {
                                      final bytes = await picked.readAsBytes();
                                      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                                      setState(() {
                                        _localImageBase64 = base64Image;
                                      });
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // قسم المعلومات الشخصية
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'المعلومات الشخصية',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: firstNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'الاسم الأول',
                                    prefixIcon: Icon(Icons.person),
                                    border: OutlineInputBorder(),
                                  ),
                                  readOnly: !(isRejected && (fieldsToEdit.contains('firstName'))),
                                  enabled: isRejected && (fieldsToEdit.contains('firstName')),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: fatherNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'اسم الأب',
                                    prefixIcon: Icon(Icons.person),
                                    border: OutlineInputBorder(),
                                  ),
                                  readOnly: !(isRejected && (fieldsToEdit.contains('fatherName'))),
                                  enabled: isRejected && (fieldsToEdit.contains('fatherName')),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: grandfatherNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'اسم الجد',
                                    prefixIcon: Icon(Icons.person),
                                    border: OutlineInputBorder(),
                                  ),
                                  readOnly: !(isRejected && (fieldsToEdit.contains('grandfatherName'))),
                                  enabled: isRejected && (fieldsToEdit.contains('grandfatherName')),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: familyNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'اسم العائلة',
                                    prefixIcon: Icon(Icons.person),
                                    border: OutlineInputBorder(),
                                  ),
                                  readOnly: !(isRejected && (fieldsToEdit.contains('familyName'))),
                                  enabled: isRejected && (fieldsToEdit.contains('familyName')),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: idNumberController,
                                  decoration: const InputDecoration(
                                    labelText: 'رقم الهوية',
                                    prefixIcon: Icon(Icons.credit_card),
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  maxLength: 9,
                                  readOnly: !(isRejected && (fieldsToEdit.contains('idNumber'))),
                                  enabled: isRejected && (fieldsToEdit.contains('idNumber')),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: birthDateController,
                                  decoration: const InputDecoration(
                                    labelText: 'تاريخ الميلاد',
                                    prefixIcon: Icon(Icons.calendar_today),
                                    border: OutlineInputBorder(),
                                  ),
                                  readOnly: !(isRejected && fieldsToEdit.contains('birthDate')),
                                  enabled: isRejected && fieldsToEdit.contains('birthDate'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: genderController,
                                  decoration: const InputDecoration(
                                    labelText: 'الجنس',
                                    prefixIcon: Icon(Icons.wc),
                                    border: OutlineInputBorder(),
                                  ),
                                  readOnly: !(isRejected && (fieldsToEdit.contains('gender'))),
                                  enabled: isRejected && (fieldsToEdit.contains('gender')),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: phoneController,
                                  decoration: const InputDecoration(
                                    labelText: 'رقم الهاتف',
                                    prefixIcon: Icon(Icons.phone),
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.phone,
                                  maxLength: 10,
                                  readOnly: !(isRejected && (fieldsToEdit.contains('phone'))),
                                  enabled: isRejected && (fieldsToEdit.contains('phone')),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: addressController,
                            decoration: const InputDecoration(
                              labelText: 'مكان السكن',
                              prefixIcon: Icon(Icons.location_on),
                              border: OutlineInputBorder(),
                            ),
                            readOnly: !(isRejected && (fieldsToEdit.contains('address'))),
                            enabled: isRejected && (fieldsToEdit.contains('address')),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // قسم معلومات الحساب
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'معلومات الحساب',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: emailController,
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني',
                              prefixIcon: Icon(Icons.email),
                              border: OutlineInputBorder(),
                            ),
                            readOnly: !(isRejected && (fieldsToEdit.contains('email'))),
                            enabled: isRejected && (fieldsToEdit.contains('email')),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (isRejected && (fieldsToEdit.isNotEmpty || fieldsToEdit.contains('image')))
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_isUploading || _editSaved) ? null : () async {
                            if (uid.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('خطأ: لا يمكن تحديد حساب المستخدم. يرجى إعادة تسجيل الدخول.')),
                              );
                              return;
                            }
                            setState(() { _isUploading = true; });
                            final dbRef = FirebaseDatabase.instance.ref();
                            final updatedData = {
                              'authUid': uid,
                              'firstName': firstNameController.text.trim(),
                              'fatherName': fatherNameController.text.trim(),
                              'grandfatherName': grandfatherNameController.text.trim(),
                              'familyName': familyNameController.text.trim(),
                              'idNumber': idNumberController.text.trim(),
                              'birthDate': (isRejected && fieldsToEdit.contains('birthDate')) ? birthDateController.text.trim() : userData['birthDate'],
                              'gender': genderController.text.trim(),
                              'phone': phoneController.text.trim(),
                              'address': addressController.text.trim(),
                              'email': emailController.text.trim(),
                              'image': (_localImageBase64 != null && fieldsToEdit.contains('image')) ? _localImageBase64!.trim() : userData['image'],
                              // إعادة المستخدم إلى قائمة السكرتيرة بعد التعديل
                              'editedAfterRejection': null,
                              'fieldsToEdit': [],
                              // حذف سبب الرفض
                              'rejectionReason': null,
                            };
                            // نقل البيانات إلى pendingUsers
                            await dbRef.child('pendingUsers/$uid').update(updatedData);
                            // حذف من rejectedUsers إذا كان موجودًا
                            await dbRef.child('rejectedUsers/$uid').remove();
                            setState(() {
                              _isUploading = false;
                              _editSaved = true;
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم حفظ التعديلات بنجاح')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _editSaved ? Colors.green : Colors.orange[700],
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isUploading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(
                                  _editSaved ? 'تم التعديل' : 'حفظ التعديلات',
                                  style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context)
                              .pushNamedAndRemoveUntil('/', (route) => false);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[400],
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('العودة إلى صفحة الدخول',
                            style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// دالة avatar الآمنة خارج الكلاس
Widget buildSafeCircleAvatar(String imageUrl, double radius) {
  try {
    final base64Str = imageUrl.replaceFirst('data:image/jpeg;base64,', '');
    final bytes = base64Decode(base64Str);
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[200],
      backgroundImage: MemoryImage(bytes),
    );
  } catch (e) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[200],
      child: Icon(Icons.person, size: radius, color: Colors.grey[600]),
    );
  }
}
