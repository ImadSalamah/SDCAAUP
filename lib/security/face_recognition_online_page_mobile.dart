import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import '../dashboard/security_dashboard.dart';
import '../security/security_sidebar.dart';

class FaceRecognitionOnlinePage extends StatefulWidget {
  const FaceRecognitionOnlinePage({super.key});

  @override
  State<FaceRecognitionOnlinePage> createState() =>
      _FaceRecognitionOnlinePageState();
}

class _FaceRecognitionOnlinePageState extends State<FaceRecognitionOnlinePage> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _selectedCameraIdx = 0;
  bool _isCameraInitialized = false;
  List<Map<String, dynamic>> _detectedFaces = [];
  String _rawJson = '';

  @override
  void initState() {
    super.initState();
    _initMobileCamera();
  }

  Future<void> _initMobileCamera([int cameraIdx = 0]) async {
    try {
      _cameras ??= await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _detectedFaces = [
            {'name': 'No camera found'}
          ];
        });
        return;
      }
      _selectedCameraIdx = cameraIdx;
      _cameraController?.dispose();
      _cameraController = CameraController(
        _cameras![cameraIdx],
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      setState(() {
        _isCameraInitialized = true;
      });
      _startMobileFrameStream();
    } catch (e) {
      setState(() {
        _detectedFaces = [
          {'name': 'فشل في الوصول إلى الكاميرا'}
        ];
      });
    }
  }

  void _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    final nextIdx = (_selectedCameraIdx + 1) % _cameras!.length;
    setState(() {
      _isCameraInitialized = false;
    });
    await _initMobileCamera(nextIdx);
  }

  void _startMobileFrameStream() {
    Future.doWhile(() async {
      if (!mounted || !_isCameraInitialized || _cameraController == null) {
        return false;
      }
      try {
        final XFile file = await _cameraController!.takePicture();
        final bytes = await file.readAsBytes();
        final base64Image = base64Encode(bytes);
        await _sendToApi(base64Image);
      } catch (e) {
        setState(() {
          _detectedFaces = [
            {'name': 'فشل في المعالجة'}
          ];
          _rawJson = 'Exception: $e';
        });
      }
      await Future.delayed(const Duration(milliseconds: 1000));
      return true;
    });
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
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    const primaryColor = Color(0xFF2A7A94);
    const accentColor = Color(0xFF4AB8D8);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SecurityDashboard()),
            );
          },
        ),
        title: Text(
          isArabic ? 'التعرف على الوجه' : 'Face Recognition',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_cameras != null && _cameras!.length > 1)
            IconButton(
              icon: const Icon(Icons.cameraswitch, color: Colors.white),
              tooltip: isArabic ? 'تبديل الكاميرا' : 'Switch Camera',
              onPressed: _switchCamera,
            ),
        ],
      ),
      drawer: const SecuritySidebar(),
      body: Container(
        color: Colors.white,
        child: Stack(
          children: [
            if (!_isCameraInitialized)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      isArabic ? 'جاري تفعيل الكاميرا...' : 'Activating camera...',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            else
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: accentColor, width: 2),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CameraPreview(_cameraController!),
                    ),
                  ),
                ),
              ),
            if (_isCameraInitialized && _detectedFaces.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Text(
                    isArabic ? 'لا يوجد وجوه مكتشفة بعد' : 'No faces detected yet',
                    style: TextStyle(color: Colors.grey[700], fontSize: 16),
                  ),
                ),
              ),
            ..._buildFaceBoxes(screenWidth),
            _buildRawJsonBox(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFaceBoxes(double screenWidth) {
    const accentColor = Color(0xFF4AB8D8);
    return _detectedFaces.map((face) {
      if (!face.containsKey('top')) return const SizedBox();
      final name = face['name'] ?? '';
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
              color: name == 'غير معروف' ? Colors.red : accentColor,
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
                color: name == 'غير معروف'
                    ? Colors.red.withAlpha(204)
                    : accentColor.withAlpha(204),
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
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(180),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(
            _rawJson,
            style: const TextStyle(color: Colors.white, fontSize: 11),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
