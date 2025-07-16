import 'dart:convert';
import 'package:flutter/material.dart';

class RadiologySidebar extends StatelessWidget {
  final Color primaryColor;
  final Color accentColor;
  final String userName;
  final String userImageUrl;
  final VoidCallback onHome;
  final VoidCallback onWaitingList;
  final VoidCallback onClose;
  final BuildContext parentContext;
  final bool collapsed;
  final String lang;
  final Map<String, Map<String, String>> localizedStrings;

  const RadiologySidebar({
    super.key,
    required this.primaryColor,
    required this.accentColor,
    required this.userName,
    required this.userImageUrl,
    required this.onHome,
    required this.onWaitingList,
    required this.onClose,
    required this.parentContext,
    this.collapsed = false,
    required this.lang,
    required this.localizedStrings,
  });

  @override
  Widget build(BuildContext context) {
    double sidebarWidth = collapsed ? 60 : 260;
    if (MediaQuery.of(context).size.width < 700 && !collapsed) {
      sidebarWidth = 200;
    }
    return Drawer(
      child: Container(
        width: sidebarWidth,
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: primaryColor),
              child: Stack(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (userImageUrl.isNotEmpty)
                        userImageUrl.startsWith('http') || userImageUrl.startsWith('https')
                            ? CircleAvatar(
                                radius: collapsed ? 18 : 32,
                                backgroundColor: Colors.white,
                                backgroundImage: NetworkImage(userImageUrl),
                              )
                            : CircleAvatar(
                                radius: collapsed ? 18 : 32,
                                backgroundColor: Colors.white,
                                child: ClipOval(
                                  child: Image.memory(
                                    base64Decode(userImageUrl.replaceFirst('data:image/jpeg;base64,', '')),
                                    width: collapsed ? 36 : 64,
                                    height: collapsed ? 36 : 64,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                      else
                        CircleAvatar(
                          radius: collapsed ? 18 : 32,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, size: collapsed ? 18 : 32, color: accentColor),
                        ),
                      if (!collapsed) ...[
                        const SizedBox(height: 10),
                        Text(
                          userName.isNotEmpty ? userName : (localizedStrings['xray_technician']?[lang] ?? 'فني الأشعة'),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          localizedStrings['xray_technician']?[lang] ?? 'فني الأشعة',
                          style: const TextStyle(fontSize: 14, color: Colors.white),
                        ),
                      ],
                    ],
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: onClose,
                      tooltip: localizedStrings['change_language']?[lang] ?? 'إغلاق',
                    ),
                  ),
                ],
              ),
            ),
            _buildSidebarItem(
              context,
              icon: Icons.dashboard,
              label: localizedStrings['home']?[lang] ?? 'الرئيسية',
              onTap: () {
                Navigator.pop(context);
                onHome();
              },
            ),
            _buildSidebarItem(
              context,
              icon: Icons.list_alt,
              label: localizedStrings['waiting_list']?[lang] ?? 'قائمة الانتظار',
              onTap: () {
                Navigator.pop(context);
                onWaitingList();
              },
            ),
            const Divider(),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(BuildContext context, {required IconData icon, required String label, VoidCallback? onTap, Color? iconColor, Color? textColor}) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? primaryColor),
      title: collapsed ? null : Text(label, style: TextStyle(color: textColor)),
      onTap: onTap,
      contentPadding: collapsed ? const EdgeInsets.symmetric(horizontal: 12) : null,
      minLeadingWidth: 0,
      horizontalTitleGap: collapsed ? 0 : null,
    );
  }
}
