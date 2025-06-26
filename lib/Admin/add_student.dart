import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'admin_sidebar.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import 'add_user_page.dart';

class AddDentalStudentPage extends StatefulWidget {
  final String? userName;
  final String? userImageUrl;
  final String Function(BuildContext, String) translate;
  final VoidCallback onLogout;

  const AddDentalStudentPage({
    super.key,
    this.userName,
    this.userImageUrl,
    required this.translate,
    required this.onLogout,
  });

  @override
  State<AddDentalStudentPage> createState() => _AddDentalStudentPageState();
}

class _AddDentalStudentPageState extends State<AddDentalStudentPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _grandfatherNameController = TextEditingController();
  final _familyNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _studentIdController = TextEditingController();

  String? _gender;
  DateTime? _birthDate;
  dynamic _profileImage;
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool isSidebarOpen = false;
  bool showSidebarButton = true;

  final Color primaryColor = const Color(0xFF2A7A94);
  final Color accentColor = const Color(0xFF4AB8D8);
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final ImagePicker _picker = ImagePicker();

  // أعد متغيرات الترجمة ودالة _tr
  final Map<String, Map<String, String>> _translations = {
    'admin_dashboard': {'ar': 'لوحة الإدارة', 'en': 'Admin Dashboard'},
    'manage_users': {'ar': 'إدارة المستخدمين', 'en': 'Manage Users'},
    'add_user': {'ar': 'إضافة مستخدم', 'en': 'Add User'},
    'add_user_student': {'ar': 'إضافة طالب طب أسنان', 'en': 'Add Dental Student'},
    'change_permissions': {'ar': 'تغيير الصلاحيات', 'en': 'Change Permissions'},
    'admin': {'ar': 'مدير النظام', 'en': 'System Admin'},
    'home': {'ar': 'الرئيسية', 'en': 'Home'},
    'settings': {'ar': 'الإعدادات', 'en': 'Settings'},
    'logout': {'ar': 'تسجيل الخروج', 'en': 'Logout'},
    // Form fields
    'first_name': {'ar': 'الاسم الأول', 'en': 'First Name'},
    'father_name': {'ar': 'اسم الأب', 'en': 'Father Name'},
    'grandfather_name': {'ar': 'اسم الجد', 'en': 'Grandfather Name'},
    'family_name': {'ar': 'اسم العائلة', 'en': 'Family Name'},
    'username': {'ar': 'اسم المستخدم', 'en': 'Username'},
    'birth_date': {'ar': 'تاريخ الميلاد', 'en': 'Birth Date'},
    'select_date': {'ar': 'اختر التاريخ', 'en': 'Select date'},
    'gender': {'ar': 'الجنس', 'en': 'Gender'},
    'male': {'ar': 'ذكر', 'en': 'Male'},
    'female': {'ar': 'أنثى', 'en': 'Female'},
    'phone_number': {'ar': 'رقم الهاتف', 'en': 'Phone Number'},
    'address': {'ar': 'العنوان', 'en': 'Address'},
    'id_number': {'ar': 'رقم الهوية', 'en': 'ID Number'},
    'student_id': {'ar': 'رقم الطالب', 'en': 'Student ID'},
    'personal_info': {'ar': 'المعلومات الشخصية', 'en': 'Personal Information'},
    'account_info': {'ar': 'معلومات الحساب', 'en': 'Account Information'},
    'password': {'ar': 'كلمة المرور', 'en': 'Password'},
    'confirm_password': {'ar': 'تأكيد كلمة المرور', 'en': 'Confirm Password'},
    'add_profile_photo': {'ar': 'إضافة صورة شخصية', 'en': 'Add Profile Photo'},
    'image_error': {'ar': 'خطأ في الصورة', 'en': 'Image Error'},
    'add': {'ar': 'إضافة', 'en': 'Add'},
    // Validation
    'required_field': {'ar': 'هذا الحقل مطلوب', 'en': 'This field is required'},
    'phone_10_digits': {'ar': 'يجب أن يكون رقم الهاتف 10 أرقام', 'en': 'Phone must be 10 digits'},
    'id_9_digits': {'ar': 'يجب أن يكون رقم الهوية 9 أرقام', 'en': 'ID must be 9 digits'},
    'student_id_9_digits': {'ar': 'يجب أن يكون رقم الطالب 9 أرقام', 'en': 'Student ID must be 9 digits'},
    'password_6_chars': {'ar': 'يجب أن تكون كلمة المرور 6 أحرف على الأقل', 'en': 'Password must be at least 6 characters'},
    'passwords_not_match': {'ar': 'كلمتا المرور غير متطابقتين', 'en': 'Passwords do not match'},
    'select_gender': {'ar': 'يرجى اختيار الجنس', 'en': 'Please select gender'},
    'student_added_success': {'ar': 'تمت إضافة الطالب بنجاح', 'en': 'Student added successfully'},
    'username_taken': {'ar': 'اسم المستخدم مستخدم بالفعل', 'en': 'Username already taken'},
    'email_in_use': {'ar': 'البريد الإلكتروني مستخدم بالفعل', 'en': 'Email already in use'},
    'weak_password': {'ar': 'كلمة المرور ضعيفة', 'en': 'Password must be at least 6 characters'},
    'error_adding_student': {'ar': 'حدث خطأ أثناء إضافة الطالب', 'en': 'Error adding student'},
    'gallery_access_denied': {'ar': 'تم رفض الوصول للمعرض', 'en': 'Gallery access denied'},
    'image_upload_error': {'ar': 'خطأ في رفع الصورة', 'en': 'Image upload error'},
    // ... add more as needed ...
  };

  // استخدم دالة الترجمة المحلية بدل widget.translate
  String _tr(BuildContext context, String key) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    return _translations[key]?[languageProvider.currentLocale.languageCode] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    return Directionality(
      textDirection: languageProvider.currentLocale.languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isLargeScreen = constraints.maxWidth >= 900;
          final isRtl = languageProvider.currentLocale.languageCode == 'ar';
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: Text(_tr(context, 'add_user_student')),
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
              leading: isLargeScreen
                  ? (showSidebarButton && !isSidebarOpen
                      ? IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () {
                            setState(() {
                              isSidebarOpen = true;
                              showSidebarButton = false;
                            });
                          },
                        )
                      : null)
                  : IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () {
                        setState(() {
                          isSidebarOpen = !isSidebarOpen;
                        });
                      },
                    ),
            ),
            body: Row(
              children: [
                if (isLargeScreen && isSidebarOpen)
                  Align(
                    alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                    child: SizedBox(
                      width: 260,
                      child: Stack(
                        children: [
                          AdminSidebar(
                            primaryColor: primaryColor,
                            accentColor: accentColor,
                            userName: widget.userName,
                            userImageUrl: widget.userImageUrl,
                            onLogout: widget.onLogout,
                            parentContext: context,
                            translate: _tr, // استخدم _tr هنا
                          ),
                          Positioned(
                            top: 8,
                            right: isRtl ? null : 0,
                            left: isRtl ? 0 : null,
                            child: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  isSidebarOpen = false;
                                  showSidebarButton = true;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Profile Image
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
                                      child: _buildImageWidget(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 30),

                                // Personal Information Section
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        _tr(context, 'personal_info'),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 20),

                                      // Name Fields
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildTextFormField(
                                              controller: _firstNameController,
                                              labelText: _tr(context, 'first_name'),
                                              prefixIcon: Icon(Icons.person, color: accentColor),
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return _tr(context, 'required_field');
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _buildTextFormField(
                                              controller: _fatherNameController,
                                              labelText: _tr(context, 'father_name'),
                                              prefixIcon: Icon(Icons.person, color: accentColor),
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return _tr(context, 'required_field');
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 15),

                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildTextFormField(
                                              controller: _grandfatherNameController,
                                              labelText: _tr(context, 'grandfather_name'),
                                              prefixIcon: Icon(Icons.person, color: accentColor),
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return _tr(context, 'required_field');
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _buildTextFormField(
                                              controller: _familyNameController,
                                              labelText: _tr(context, 'family_name'),
                                              prefixIcon: Icon(Icons.person, color: accentColor),
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return _tr(context, 'required_field');
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 15),

                                      // Username and Birth Date
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildTextFormField(
                                              controller: _usernameController,
                                              labelText: _tr(context, 'username'),
                                              prefixIcon: Icon(Icons.person_pin, color: accentColor),
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return _tr(context, 'required_field');
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: InkWell(
                                              onTap: _selectBirthDate,
                                              child: InputDecorator(
                                                decoration: InputDecoration(
                                                  labelText: _tr(context, 'birth_date'),
                                                  labelStyle: TextStyle(color: primaryColor.withValues(alpha: 0.8)),
                                                  prefixIcon: Icon(Icons.calendar_today, color: accentColor),
                                                  filled: true,
                                                  fillColor: Colors.grey[50],
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                                  ),
                                                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                                ),
                                                child: Text(
                                                  _birthDate == null
                                                      ? _tr(context, 'select_date')
                                                      : DateFormat('yyyy-MM-dd').format(_birthDate!),
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: _birthDate == null ? Colors.grey[600] : Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 15),

                                      // Gender Radio Buttons
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 8.0),
                                            child: Text(
                                              _tr(context, 'gender'),
                                              style: const TextStyle(
                                                color: Colors.black87,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: RadioListTile<String>(
                                                  title: Text(_tr(context, 'male')),
                                                  value: 'male',
                                                  groupValue: _gender,
                                                  activeColor: primaryColor,
                                                  onChanged: (value) => setState(() => _gender = value),
                                                ),
                                              ),
                                              Expanded(
                                                child: RadioListTile<String>(
                                                  title: Text(_tr(context, 'female')),
                                                  value: 'female',
                                                  groupValue: _gender,
                                                  activeColor: primaryColor,
                                                  onChanged: (value) => setState(() => _gender = value),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 15),

                                      // Phone Number
                                      _buildTextFormField(
                                        controller: _phoneController,
                                        labelText: _tr(context, 'phone_number'),
                                        keyboardType: TextInputType.phone,
                                        maxLength: 10,
                                        prefixIcon: Icon(Icons.phone, color: accentColor),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return _tr(context, 'required_field');
                                          }
                                          if (value.length < 10) {
                                            return _tr(context, 'phone_10_digits');
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 15),

                                      // Address
                                      _buildTextFormField(
                                        controller: _addressController,
                                        labelText: _tr(context, 'address'),
                                        prefixIcon: Icon(Icons.location_on, color: accentColor),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return _tr(context, 'required_field');
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 15),

                                      // ID Number
                                      _buildTextFormField(
                                        controller: _idNumberController,
                                        labelText: _tr(context, 'id_number'),
                                        keyboardType: TextInputType.number,
                                        maxLength: 9,
                                        prefixIcon: Icon(Icons.credit_card, color: accentColor),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return _tr(context, 'required_field');
                                          }
                                          if (value.length < 9) {
                                            return _tr(context, 'id_9_digits');
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 15),

                                      // Student ID
                                      _buildTextFormField(
                                        controller: _studentIdController,
                                        labelText: _tr(context, 'student_id'),
                                        keyboardType: TextInputType.number,
                                        maxLength: 9,
                                        prefixIcon: Icon(Icons.school, color: accentColor),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return _tr(context, 'required_field');
                                          }
                                          if (value.length < 9) {
                                            return _tr(context, 'student_id_9_digits');
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 15),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Account Information Section
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        _tr(context, 'account_info'),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 20),

                                      // Password
                                      _buildTextFormField(
                                        controller: _passwordController,
                                        labelText: _tr(context, 'password'),
                                        obscureText: !_showPassword,
                                        prefixIcon: Icon(Icons.lock, color: accentColor),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _showPassword ? Icons.visibility : Icons.visibility_off,
                                            color: accentColor,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _showPassword = !_showPassword;
                                            });
                                          },
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return _tr(context, 'required_field');
                                          }
                                          if (value.length < 6) {
                                            return _tr(context, 'password_6_chars');
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 15),

                                      // Confirm Password
                                      _buildTextFormField(
                                        controller: _confirmPasswordController,
                                        labelText: _tr(context, 'confirm_password'),
                                        obscureText: !_showConfirmPassword,
                                        prefixIcon: Icon(Icons.lock_outline, color: accentColor),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                            color: accentColor,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _showConfirmPassword = !_showConfirmPassword;
                                            });
                                          },
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return _tr(context, 'required_field');
                                          }
                                          if (value != _passwordController.text) {
                                            return _tr(context, 'passwords_not_match');
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 30),

                                // Add Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _addStudent,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : Text(
                                            _tr(context, 'add_user_student'),
                                            style: const TextStyle(
                                              fontSize: 18,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Example button to navigate to another page with parameters
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AddUserPage(
                                          userName: widget.userName,
                                          userImageUrl: widget.userImageUrl,
                                          translate: _tr, // استخدم _tr هنا
                                          onLogout: widget.onLogout,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Text(_tr(context, 'add_user')),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLargeScreen && isSidebarOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          isSidebarOpen = false;
                        });
                      },
                      child: Container(
                        color: Colors.black.withOpacity(0.3),
                        alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () {},
                          child: SizedBox(
                            width: 260,
                            height: double.infinity,
                            child: Material(
                              elevation: 8,
                              child: Stack(
                                children: [
                                  AdminSidebar(
                                    primaryColor: primaryColor,
                                    accentColor: accentColor,
                                    userName: widget.userName,
                                    userImageUrl: widget.userImageUrl,
                                    onLogout: widget.onLogout,
                                    parentContext: context,
                                    translate: widget.translate,
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: isRtl ? null : 0,
                                    left: isRtl ? 0 : null,
                                    child: IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        setState(() {
                                          isSidebarOpen = false;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? prefixIcon,
    Widget? suffixIcon,
    int? maxLength,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: primaryColor.withValues(alpha: 0.8)),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      validator: validator,
    );
  }

  Widget _buildImageWidget() {
    if (_profileImage == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo, size: 50, color: primaryColor),
          const SizedBox(height: 8),
          Text(
            _tr(context, 'add_profile_photo'),
            style: const TextStyle(color: Colors.black87),
          ),
        ],
      );
    }

    try {
      return kIsWeb
          ? Image.memory(
              _profileImage as Uint8List,
              width: 150,
              height: 150,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
            )
          : Image.file(
              _profileImage as File,
              width: 150,
              height: 150,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
            );
    } catch (e) {
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 40),
        const SizedBox(height: 8),
        Text(
          _tr(context, 'image_error'),
          style: const TextStyle(color: Colors.red, fontSize: 12),
        ),
      ],
    );
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
          SnackBar(content: Text(_tr(context, 'gallery_access_denied'))),
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
          setState(() => _profileImage = bytes);
        } else {
          final bytes = await File(image.path).readAsBytes();
          // Remove unused compressedImage variable
          await FlutterImageCompress.compressWithList(
            bytes,
            minWidth: 800,
            minHeight: 800,
            quality: 70,
          );
          setState(() => _profileImage = File(image.path));
        }
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_tr(context, 'image_upload_error')}: [${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_tr(context, 'image_upload_error')}: $e')),
      );
    }
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _birthDate) {
      setState(() => _birthDate = picked);
    }
  }

  Future<bool> _isUsernameUnique(String username) async {
    final snapshot = await _database
        .child('users')
        .orderByChild('username')
        .equalTo(username)
        .once();

    return snapshot.snapshot.value == null;
  }

  Future<void> _addStudent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr(context, 'passwords_not_match'))),
      );
      return;
    }

    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr(context, 'select_gender'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if username is unique
      final isUnique = await _isUsernameUnique(_usernameController.text.trim());
      if (!isUnique) {
        throw FirebaseAuthException(
          code: 'username-exists',
          message: _tr(context, 'username_taken'),
        );
      }

      // Convert image to base64
      String? imageBase64;
      if (_profileImage != null) {
        if (kIsWeb) {
          imageBase64 = base64Encode(_profileImage as Uint8List);
        } else {
          final bytes = await (_profileImage as File).readAsBytes();
          imageBase64 = base64Encode(bytes);
        }
      }

      // Create student email
      final email = '${_usernameController.text.trim()}@student.aaup.edu';

      // Create user in Firebase Auth
      final auth = FirebaseAuth.instance;
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      // Prepare student data
      final studentData = {
        'firstName': _firstNameController.text.trim(),
        'fatherName': _fatherNameController.text.trim(),
        'grandfatherName': _grandfatherNameController.text.trim(),
        'familyName': _familyNameController.text.trim(),
        'fullName': '${_firstNameController.text.trim()} ${_fatherNameController.text.trim()} ${_grandfatherNameController.text.trim()} ${_familyNameController.text.trim()}',
        'username': _usernameController.text.trim(),
        'idNumber': _idNumberController.text.trim(),
        'studentId': _studentIdController.text.trim(),
        'birthDate': _birthDate?.millisecondsSinceEpoch,
        'gender': _gender,
        'role': 'dental_student',
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'email': email,
        'image': imageBase64,
        'createdAt': ServerValue.timestamp,
        'isActive': true,
      };

      // Save data to Realtime Database
      await _database.child('users/${userCredential.user!.uid}').set(studentData);
      await _database.child('students/${userCredential.user!.uid}').set({
        'uid': userCredential.user!.uid,
        'username': _usernameController.text.trim(),
        'fullName': studentData['fullName'],
        'email': email,
        'studentId': _studentIdController.text.trim(),
      });

      // Send verification email
      await userCredential.user?.sendEmailVerification();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr(context, 'student_added_success'))),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      String errorMessage = _tr(context, 'error_adding_student');
      if (e.code == 'weak-password') {
        errorMessage = _tr(context, 'weak_password');
      } else if (e.code == 'email-already-in-use') {
        errorMessage = _tr(context, 'email_in_use');
      } else if (e.code == 'username-exists') {
        errorMessage = _tr(context, 'username_taken');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_tr(context, 'error_adding_student')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _fatherNameController.dispose();
    _grandfatherNameController.dispose();
    _familyNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _idNumberController.dispose();
    _studentIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}