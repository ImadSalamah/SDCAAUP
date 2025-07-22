import 'package:flutter/material.dart';

class SecretaryProvider extends ChangeNotifier {
  String uid = '';
  String fullName = '';
  String imageBase64 = '';
  String email = '';
  String phone = '';
  // أضف أي حقول أخرى تحتاجها

  void setSecretaryData(Map<String, dynamic> data) {
    uid = data['uid'] ?? '';
    fullName = data['fullName'] ?? '';
    imageBase64 = data['image'] ?? '';
    email = data['email'] ?? '';
    phone = data['phone'] ?? '';
    // أضف باقي الحقول
    notifyListeners();
  }

  void clear() {
    uid = '';
    fullName = '';
    imageBase64 = '';
    email = '';
    phone = '';
    // أضف باقي الحقول
    notifyListeners();
  }
}
