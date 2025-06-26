import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'admin_sidebar.dart';
import 'admin_translations.dart';

class EditUserPage extends StatefulWidget {
  final Map<String, dynamic>? user;
  final List<Map<String, dynamic>>? usersList;
  final String? userName;
  final String? userImageUrl;
  final String Function(BuildContext, String) translate;
  final VoidCallback onLogout;

  const EditUserPage({
    super.key,
    this.user,
    this.usersList,
    this.userName,
    this.userImageUrl,
    required this.translate,
    required this.onLogout,
  });

  @override
  State<EditUserPage> createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController firstNameController;
  late TextEditingController fatherNameController;
  late TextEditingController grandfatherNameController;
  late TextEditingController familyNameController;
  late TextEditingController usernameController;
  late TextEditingController phoneController;
  late TextEditingController addressController;
  late TextEditingController idNumberController;
  late TextEditingController permissionsController;
  DateTime? birthDate;
  String? gender;
  String? role;
  dynamic userImage;
  bool isSaving = false;
  bool? isActive;
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> allUsers = [];
  List<Map<String, dynamic>> filteredUsers = [];
  TextEditingController searchController = TextEditingController();
  bool isLoadingUsers = false;
  String? currentUserUid; // uid المستخدم الحالي

  @override
  void initState() {
    super.initState();
    firstNameController = TextEditingController();
    fatherNameController = TextEditingController();
    grandfatherNameController = TextEditingController();
    familyNameController = TextEditingController();
    usernameController = TextEditingController();
    phoneController = TextEditingController();
    addressController = TextEditingController();
    idNumberController = TextEditingController();
    permissionsController = TextEditingController();
    birthDate = null;
    gender = null;
    role = null;
    isActive = true;
    userImage = null;
    currentUserUid = null;
    fetchAllUsers();
  }

  @override
  void dispose() {
    firstNameController.dispose();
    fatherNameController.dispose();
    grandfatherNameController.dispose();
    familyNameController.dispose();
    usernameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    idNumberController.dispose();
    permissionsController.dispose();
    super.dispose();
  }

  Future<bool> _checkPermissions() async {
    if (!kIsWeb) {
      final status = await Permission.photos.status;
      if (status.isDenied) {
        await Permission.photos.request();
      }
      return status.isGranted;
    }
    return true;
  }

  Future<void> _pickImage() async {
    try {
      if (!await _checkPermissions()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض صلاحيات الوصول إلى المعرض')),
        );
        return;
      }
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() => userImage = bytes);
        } else {
          final bytes = await File(image.path).readAsBytes();
          await FlutterImageCompress.compressWithList(
            bytes,
            minWidth: 800,
            minHeight: 800,
            quality: 70,
          );
          setState(() => userImage = File(image.path));
        }
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ في تحميل الصورة: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ في تحميل الصورة: $e')),
      );
    }
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: birthDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF2A7A94),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != birthDate) {
      setState(() => birthDate = picked);
    }
  }

  Future<void> saveUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      isSaving = true;
    });
    String? imageBase64;
    if (userImage != null) {
      if (kIsWeb) {
        imageBase64 = base64Encode(userImage as Uint8List);
      } else if (userImage is File) {
        final bytes = await (userImage as File).readAsBytes();
        imageBase64 = base64Encode(bytes);
      }
    }
    final uid = currentUserUid;
    if (uid == null) {
      setState(() { isSaving = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار مستخدم أولاً')),
      );
      return;
    }
    // جلب القيم القديمة للمقارنة
    final DatabaseReference userRef = FirebaseDatabase.instance.ref('users/$uid');
    final oldSnapshot = await userRef.get();
    Map<String, dynamic> oldData = {};
    if (oldSnapshot.exists) {
      oldData = Map<String, dynamic>.from(oldSnapshot.value as Map);
    }
    // القيم الجديدة
    final Map<String, dynamic> newData = {
      'firstName': firstNameController.text.trim(),
      'fatherName': fatherNameController.text.trim(),
      'grandfatherName': grandfatherNameController.text.trim(),
      'familyName': familyNameController.text.trim(),
      'username': usernameController.text.trim(),
      'idNumber': idNumberController.text.trim(),
      'birthDate': birthDate?.millisecondsSinceEpoch,
      'gender': gender,
      'role': role,
      'phone': phoneController.text.trim(),
      'address': addressController.text.trim(),
      'permissions': permissionsController.text.trim(),
      'image': imageBase64 ?? '',
      'isActive': isActive == true ? 1 : 0,
    };
    // تحديث البيانات
    await userRef.update(newData);
    // إرسال إشعار إذا تغيرت أي قيمة
    final Map<String, String> fieldNames = {
      'firstName': 'الاسم الأول',
      'fatherName': 'اسم الأب',
      'grandfatherName': 'اسم الجد',
      'familyName': 'اسم العائلة',
      'username': 'اسم المستخدم',
      'idNumber': 'رقم الهوية',
      'birthDate': 'تاريخ الميلاد',
      'gender': 'الجنس',
      'role': 'نوع المستخدم',
      'phone': 'رقم الهاتف',
      'address': 'مكان السكن',
      'permissions': 'الصلاحيات',
      'isActive': 'حالة الحساب',
      'image': 'الصورة الشخصية',
    };
    for (final entry in newData.entries) {
      final key = entry.key;
      final newValue = entry.value;
      final oldValue = oldData[key];
      if (key == 'image') {
        // قارن فقط إذا تغيرت الصورة فعلاً
        if ((oldValue ?? '') != (newValue ?? '')) {
          await _sendEditNotification(uid, fieldNames[key] ?? key);
        }
      } else if (key == 'birthDate') {
        if ((oldValue ?? 0).toString() != (newValue ?? 0).toString()) {
          await _sendEditNotification(uid, fieldNames[key] ?? key);
        }
      } else if ((oldValue ?? '').toString() != (newValue ?? '').toString()) {
        await _sendEditNotification(uid, fieldNames[key] ?? key);
      }
    }
    setState(() {
      isSaving = false;
    });
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _sendEditNotification(String uid, String fieldName) async {
    final notifRef = FirebaseDatabase.instance.ref('notifications/$uid').push();
    await notifRef.set({
      'title': 'تم تعديل $fieldName',
      'message': 'تم تعديل $fieldName في بياناتك من قبل الإدارة.',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'read': false,
      'type': 'edit',
    });
  }

  Future<void> fetchAllUsers() async {
    setState(() => isLoadingUsers = true);
    final ref = FirebaseDatabase.instance.ref('users');
    final snapshot = await ref.get();
    List<Map<String, dynamic>> users = [];
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        final user = Map<String, dynamic>.from(value);
        user['uid'] = key;
        users.add(user);
      });
    }
    setState(() {
      allUsers = users;
      filteredUsers = users;
      isLoadingUsers = false;
    });
  }

  void filterUsers(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => filteredUsers = allUsers);
    } else {
      final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      setState(() {
        filteredUsers = allUsers.where((user) {
          final fields = [
            user['firstName']?.toString() ?? '',
            user['fatherName']?.toString() ?? '',
            user['grandfatherName']?.toString() ?? '',
            user['familyName']?.toString() ?? '',
            user['idNumber']?.toString() ?? '',
            user['username']?.toString() ?? ''
          ].map((f) => f.toLowerCase().trim()).toList();
          // يجب أن تكون كل كلمة موجودة في أي من الحقول
          return words.every((word) => fields.any((field) => field.contains(word)));
        }).toList();
      });
    }
  }

  void loadUserForEdit(Map<String, dynamic> user) {
    setState(() {
      firstNameController.text = user['firstName'] ?? '';
      fatherNameController.text = user['fatherName'] ?? '';
      grandfatherNameController.text = user['grandfatherName'] ?? '';
      familyNameController.text = user['familyName'] ?? '';
      usernameController.text = user['username'] ?? '';
      phoneController.text = user['phone'] ?? '';
      addressController.text = user['address'] ?? '';
      idNumberController.text = user['idNumber'] ?? '';
      permissionsController.text = user['permissions'] ?? '';
      birthDate = user['birthDate'] != null ? DateTime.fromMillisecondsSinceEpoch(user['birthDate']) : null;
      gender = user['gender']?.toString();
      role = user['role']?.toString();
      isActive = user['isActive'] == null ? true : user['isActive'] == true || user['isActive'] == 1;
      userImage = (user['image'] != null && user['image'].toString().isNotEmpty) ? base64Decode(user['image']) : null;
      currentUserUid = user['uid']; // حفظ uid المستخدم الحالي
    });
  }

  String _translate(BuildContext context, String key) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    return adminTranslations[key]?[languageProvider.currentLocale.languageCode] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF2A7A94);
    final Color accentColor = const Color(0xFF4AB8D8);
    final languageProvider = Provider.of<LanguageProvider>(context);
    // استخدم دالة الترجمة الموحدة
    String t(String key) => _translate(context, key);
    return Directionality(
      textDirection: languageProvider.isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(widget.translate(context, 'manage_users')),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        drawer: AdminSidebar(
          primaryColor: primaryColor,
          accentColor: accentColor,
          userName: widget.userName,
          userImageUrl: widget.userImageUrl,
          onLogout: widget.onLogout,
          parentContext: context,
          translate: _translate,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'بحث عن مستخدم بالاسم أو رقم الهوية...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: filterUsers,
                  ),
                  if (searchController.text.isNotEmpty)
                    SizedBox(
                      height: 200,
                      child: Card(
                        margin: const EdgeInsets.only(top: 8),
                        child: ListView.builder(
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            final fullName = ((user['firstName'] ?? '') + ' ' +
                                (user['fatherName'] ?? '') + ' ' +
                                (user['grandfatherName'] ?? '') + ' ' +
                                (user['familyName'] ?? '')).trim();
                            return ListTile(
                              title: Text(fullName),
                              subtitle: Text(user['username'] ?? ''),
                              onTap: () {
                                loadUserForEdit(user);
                                searchController.clear();
                                setState(() => filteredUsers = allUsers);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            border: Border.all(color: primaryColor),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: userImage == null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo,
                                          size: 50, color: primaryColor),
                                      const SizedBox(height: 8),
                                      Text('إضافة صورة شخصية',
                                          style:
                                              TextStyle(color: primaryColor)),
                                    ],
                                  )
                                : (kIsWeb
                                    ? Image.memory(
                                        userImage as Uint8List,
                                        width: 150,
                                        height: 150,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.error_outline,
                                                color: Colors.red, size: 40),
                                            SizedBox(height: 8),
                                            Text('حدث خطأ في تحميل الصورة',
                                                style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      )
                                    : (userImage is File
                                        ? Image.file(
                                            userImage as File,
                                            width: 150,
                                            height: 150,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.error_outline,
                                                    color: Colors.red,
                                                    size: 40),
                                                SizedBox(height: 8),
                                                Text('حدث خطأ في تحميل الصورة',
                                                    style: TextStyle(
                                                        color: Colors.red,
                                                        fontSize: 12)),
                                              ],
                                            ),
                                          )
                                        : Image.memory(
                                            userImage as Uint8List,
                                            width: 150,
                                            height: 150,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.error_outline,
                                                    color: Colors.red,
                                                    size: 40),
                                                SizedBox(height: 8),
                                                Text('حدث خطأ في تحميل الصورة',
                                                    style: TextStyle(
                                                        color: Colors.red,
                                                        fontSize: 12)),
                                              ],
                                            ),
                                          ))),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
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
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: firstNameController,
                                    decoration: InputDecoration(
                                      labelText: 'الاسم الأول *',
                                      prefixIcon: Icon(Icons.person,
                                          color: accentColor),
                                    ),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                            ? 'هذا الحقل مطلوب'
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: fatherNameController,
                                    decoration: InputDecoration(
                                      labelText: 'اسم الأب *',
                                      prefixIcon: Icon(Icons.person,
                                          color: accentColor),
                                    ),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                            ? 'هذا الحقل مطلوب'
                                            : null,
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
                                    decoration: InputDecoration(
                                      labelText: 'اسم الجد *',
                                      prefixIcon: Icon(Icons.person,
                                          color: accentColor),
                                    ),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                            ? 'هذا الحقل مطلوب'
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: familyNameController,
                                    decoration: InputDecoration(
                                      labelText: 'اسم العائلة *',
                                      prefixIcon: Icon(Icons.person,
                                          color: accentColor),
                                    ),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                            ? 'هذا الحقل مطلوب'
                                            : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: usernameController,
                                    decoration: InputDecoration(
                                      labelText: 'اسم المستخدم *',
                                      prefixIcon: Icon(Icons.person_pin,
                                          color: accentColor),
                                    ),
                                    validator: (value) {
                                      // إذا كان الدور مريض، لا تجعل الحقل مطلوبًا
                                      if (role == 'patient') return null;
                                      if (value == null || value.isEmpty) {
                                        return 'هذا الحقل مطلوب';
                                      }
                                      return null;
                                    },
                                    enabled: role !=
                                        'patient', // اجعل الحقل غير قابل للتعديل إذا كان مريض
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkWell(
                                    onTap: _selectBirthDate,
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'تاريخ الميلاد *',
                                        prefixIcon: Icon(Icons.calendar_today,
                                            color: accentColor),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 16, horizontal: 16),
                                      ),
                                      child: Text(
                                        birthDate == null
                                            ? 'اختر التاريخ'
                                            : DateFormat('yyyy-MM-dd')
                                                .format(birthDate!),
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: birthDate == null
                                              ? Colors.grey[600]
                                              : Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: gender,
                                    decoration: InputDecoration(
                                      labelText: 'الجنس *',
                                      prefixIcon:
                                          Icon(Icons.wc, color: accentColor),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: Colors.grey.shade300),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 16),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'male', child: Text('ذكر')),
                                      DropdownMenuItem(
                                          value: 'female', child: Text('أنثى')),
                                    ],
                                    onChanged: (value) =>
                                        setState(() => gender = value),
                                    validator: (value) => value == null
                                        ? 'الرجاء اختيار الجنس'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: role,
                                    decoration: InputDecoration(
                                      labelText: 'نوع المستخدم *',
                                      prefixIcon: Icon(
                                          Icons.admin_panel_settings,
                                          color: accentColor),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: Colors.grey.shade300),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 16),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'doctor', child: Text('طبيب')),
                                      DropdownMenuItem(
                                          value: 'secretary',
                                          child: Text('سكرتير')),
                                      DropdownMenuItem(
                                          value: 'security',
                                          child: Text('أمن')),
                                      DropdownMenuItem(
                                          value: 'admin', child: Text('مدير')),
                                      DropdownMenuItem(
                                          value: 'dental_student',
                                          child: Text('طالب طب أسنان')),
                                      DropdownMenuItem(
                                          value: 'patient',
                                          child: Text('مريض')),
                                    ],
                                    onChanged: (value) =>
                                        setState(() => role = value),
                                    validator: (value) => value == null
                                        ? 'الرجاء اختيار نوع المستخدم'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            TextFormField(
                              controller: phoneController,
                              decoration: InputDecoration(
                                labelText: 'رقم الهاتف *',
                                prefixIcon:
                                    Icon(Icons.phone, color: accentColor),
                              ),
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'هذا الحقل مطلوب';
                                }
                                if (value.length < 10) {
                                  return 'رقم الهاتف يجب أن يكون 10 أرقام';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 15),
                            TextFormField(
                              controller: addressController,
                              decoration: InputDecoration(
                                labelText: 'مكان السكن *',
                                prefixIcon:
                                    Icon(Icons.location_on, color: accentColor),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'هذا الحقل مطلوب'
                                      : null,
                            ),
                            const SizedBox(height: 15),
                            TextFormField(
                              controller: idNumberController,
                              decoration: InputDecoration(
                                labelText: 'رقم الهوية *',
                                prefixIcon:
                                    Icon(Icons.credit_card, color: accentColor),
                              ),
                              keyboardType: TextInputType.number,
                              maxLength: 9,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'هذا الحقل مطلوب';
                                }
                                if (value.length < 9) {
                                  return 'رقم الهوية يجب أن يكون 9 أرقام';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
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
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: permissionsController,
                              decoration: InputDecoration(
                                labelText: 'الصلاحيات',
                                prefixIcon:
                                    Icon(Icons.security, color: accentColor),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              margin: const EdgeInsets.only(top: 20),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 20),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Text('حالة الحساب:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 16),
                                  Switch(
                                    value: isActive ?? true,
                                    activeColor: primaryColor,
                                    onChanged: (val) {
                                      setState(() {
                                        isActive = val;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Text(isActive == true ? 'فعال' : 'غير فعال',
                                      style: TextStyle(
                                          color: isActive == true
                                              ? Colors.green
                                              : Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : saveUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: isSaving
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  'حفظ التعديلات',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
