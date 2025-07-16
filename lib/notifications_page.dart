// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'Secretry/account_approv.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    final ref = FirebaseDatabase.instance.ref('notifications/${user.uid}');
    final snapshot = await ref.get();
    final List<Map<String, dynamic>> notifs = [];
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        if (value is Map<dynamic, dynamic>) {
          notifs.add({
            'id': key,
            ...Map<String, dynamic>.from(value),
          });
        }
      });
      notifs.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
    }
    setState(() {
      notifications = notifs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? const Center(child: Text('لا يوجد إشعارات'))
              : ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notif = notifications[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: Icon(
                          notif['read'] == false ? Icons.notifications_active : Icons.notifications,
                          color: notif['read'] == false ? Colors.red : Colors.grey,
                        ),
                        title: Text(notif['title'] ?? ''),
                        subtitle: Text(notif['message'] ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (notif['read'] == false)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: GestureDetector(
                                  onTap: () async {
                                    final user = _auth.currentUser;
                                    if (user != null) {
                                      final ref = FirebaseDatabase.instance.ref('notifications/${user.uid}/${notif['id']}');
                                      await ref.update({'read': true});
                                    }
                                    setState(() {
                                      notifications[index]['read'] = true;
                                    });
                                    // إرسال رسالة للداشبورد لعرض MaterialBanner هناك
                                    Navigator.pop(context, {'showBanner': true, 'bannerMessage': 'تمت قراءة الإشعار بنجاح'});
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'تم',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ),
                              ),
                            if (notif['read'] == false)
                              const Text('جديد', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        onTap: () async {
                          // فقط إذا كان الاشعار عند السكرتير ويحمل userId
                          if (notif['type'] == 'pending_account' && notif['userId'] != null) {
                            // إذا كان الإشعار غير مقروء فقط، عيّنه كمقروء
                            if (notif['read'] == false) {
                              final user = _auth.currentUser;
                              if (user != null) {
                                final ref = FirebaseDatabase.instance.ref('notifications/${user.uid}/${notif['id']}');
                                await ref.update({'read': true});
                              }
                              setState(() {
                                notifications[index]['read'] = true;
                              });
                            }
                            // انتقل لصفحة الموافقة على الحسابات مع userId
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AccountApprovalPage(
                                  initialUserId: notif['userId'],
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
