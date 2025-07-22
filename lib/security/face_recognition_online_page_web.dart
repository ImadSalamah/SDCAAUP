// ignore_for_file: unused_import

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
// Web-only imports
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui;
import '../dashboard/security_dashboard.dart';
import '../security/security_sidebar.dart';

class FaceRecognitionOnlinePage extends StatefulWidget {
  const FaceRecognitionOnlinePage({super.key});

  @override
  State<FaceRecognitionOnlinePage> createState() =>
      _FaceRecognitionOnlinePageState();
}

class _FaceRecognitionOnlinePageState extends State<FaceRecognitionOnlinePage> {
  html.VideoElement? _videoElement;
  html.CanvasElement? _canvas;
  List<Map<String, dynamic>> _detectedFaces = [];
  String _rawJson = '';
  String _userName = '';
  String _userImageUrl = '';

  @override
  void initState() {
    super.initState();
    _initWebCamera();
    _loadSecurityUserInfo();
  }

  Future<void> _loadSecurityUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _userName = '';
          _userImageUrl = '';
        });
        return;
      }
      final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      final snapshot = await userRef.get();
      if (!snapshot.exists) {
        setState(() {
          _userName = '';
          _userImageUrl = '';
        });
        return;
      }
      final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
      final firstName = data['firstName']?.toString().trim() ?? '';
      final fatherName = data['fatherName']?.toString().trim() ?? '';
      final grandfatherName = data['grandfatherName']?.toString().trim() ?? '';
      final familyName = data['familyName']?.toString().trim() ?? '';
      final fullName = [
        if (firstName.isNotEmpty) firstName,
        if (fatherName.isNotEmpty) fatherName,
        if (grandfatherName.isNotEmpty) grandfatherName,
        if (familyName.isNotEmpty) familyName,
      ].join(' ');
      final imageData = data['image']?.toString() ?? '';
      setState(() {
        _userName = fullName;
        _userImageUrl = imageData.isNotEmpty ? 'data:image/jpeg;base64,$imageData' : '';
      });
    } catch (e) {
      setState(() {
        _userName = '';
        _userImageUrl = '';
      });
    }
  }

  void _initWebCamera() {
    _videoElement = html.VideoElement()
      ..autoplay = true
      ..style.width = '100%'
      ..style.height = 'auto';
    // Register the video element for Flutter web
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry
        .registerViewFactory('cameraElement', (int viewId) => _videoElement!);
    html.window.navigator.mediaDevices
        ?.getUserMedia({'video': true}).then((stream) {
      _videoElement!.srcObject = stream;
      _videoElement!.play();
      _canvas = html.CanvasElement(width: 640, height: 480);
      _sendWebFrame();
    }).catchError((e) {
      setState(() {
        _detectedFaces = [
          {'name': 'فشل في الوصول إلى الكاميرا'}
        ];
      });
    });
  }

  void _sendWebFrame() async {
    if (!mounted || _videoElement == null || _canvas == null) return;
    try {
      final context = _canvas!.context2D;
      context.drawImage(_videoElement!, 0, 0);
      final imageDataUrl = _canvas!.toDataUrl('image/png');
      final base64Image = imageDataUrl.split(',').last;
      await _sendToApi(base64Image);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detectedFaces = [
          {'name': 'فشل في المعالجة'}
        ];
        _rawJson = 'Exception: $e';
      });
    }
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 500), _sendWebFrame);
    }
  }

  Future<void> _sendToApi(String base64Image) async {
    final response = await http.post(
      Uri.parse('https://recproj.fly.dev/recognize'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'image': base64Image}),
    );
    if (!mounted) return;
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      setState(() {
        _detectedFaces = List<Map<String, dynamic>>.from(decoded['faces']);
        _rawJson = jsonEncode(decoded);
      });
    } else {
      setState(() {
        _detectedFaces = [
          {'name': 'خطأ في التعرف'}
        ];
        _rawJson = 'Status: ${response.statusCode}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    const primaryColor = Color(0xFF2A7A94);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        title: Text(
          isArabic ? 'التعرف على الوجه' : 'Face Recognition',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      drawer: SecuritySidebar(
        userName: _userName,
        userImageUrl: _userImageUrl,
      ),
      body: Container(
        color: Colors.white,
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // الكاميرا على كامل الشاشة
            const HtmlElementView(viewType: 'cameraElement'),
            ..._buildFaceBoxes(screenWidth),
            _buildRawJsonBox(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFaceBoxes(double screenWidth) {
    return _detectedFaces.map((face) {
      if (!face.containsKey('top')) return const SizedBox();
      final name = face['name'] ?? '';
      // تحديد الدور من الاسم
      String role = '';
      if (name == 'غير معروف' || name.isEmpty) {
        role = 'unknown';
      } else if (name.contains('سلامة')) { // مثال: لو عندك قاعدة بيانات محلية أو تحقق من الاسم
        role = 'patient';
      } else if (name.contains('طالب') || name.contains('دكتور') || name.contains('سكرتير') || name.contains('أمن')) {
        role = 'staff';
      } else {
        role = 'other';
      }
      Color boxColor;
      if (role == 'patient') {
        boxColor = Colors.blue;
      } else if (role == 'staff') {
        boxColor = Colors.green;
      } else if (role == 'unknown') {
        boxColor = Colors.red;
      } else {
        boxColor = Colors.green;
      }
      final top = face['top'] * (screenWidth / 640);
      final left = face['left'] * (screenWidth / 640);
      final width = (face['right'] - face['left']) * (screenWidth / 640);
      final height = (face['bottom'] - face['top']) * (screenWidth / 640);
      return Positioned(
        top: top,
        left: left,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            border: Border.all(
              color: boxColor,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
         color: Colors.white.withAlpha(25),

          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
color: boxColor.withAlpha(204),
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildRawJsonBox() {
    return Positioned(
      bottom: 10,
      left: 10,
      right: 10,
      child: Container(
        color: const Color(0xCC000000),
        padding: const EdgeInsets.all(8),
        child: Text(
          _rawJson,
          style: const TextStyle(color: Colors.white, fontSize: 10),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
