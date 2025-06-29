// أداة تنظيف تلقائي للبيانات القديمة في Firebase Realtime Database
// تحذف أي عنصر في waitingList أو examinations مفتاحه ليس userId حقيقي (أي يبدأ بـ '-')
// ملاحظة: شغل هذا الكود مرة واحدة فقط من تطبيق admin أو من صفحة خاصة

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class FirebaseCleaner extends StatelessWidget {
  const FirebaseCleaner({super.key});

  Future<void> cleanDatabase(BuildContext context) async {
    final db = FirebaseDatabase.instance.ref();
    int removedWaiting = 0;
    int removedExams = 0;

    // تنظيف waitingList
    final waitingSnap = await db.child('waitingList').get();
    if (waitingSnap.exists) {
      final data = waitingSnap.value as Map<dynamic, dynamic>;
      for (final key in data.keys) {
        if (key.toString().startsWith('-')) {
          await db.child('waitingList').child(key).remove();
          removedWaiting++;
        }
      }
    }

    // تنظيف examinations
    final examsSnap = await db.child('examinations').get();
    if (examsSnap.exists) {
      final data = examsSnap.value as Map<dynamic, dynamic>;
      for (final key in data.keys) {
        if (key.toString().startsWith('-')) {
          await db.child('examinations').child(key).remove();
          removedExams++;
        }
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف $removedWaiting من قائمة الانتظار و $removedExams من الفحوصات')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Cleaner')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => cleanDatabase(context),
          child: const Text('تنظيف البيانات القديمة'),
        ),
      ),
    );
  }
}
