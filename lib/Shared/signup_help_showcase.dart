import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

class SignUpHelpShowcase extends StatefulWidget {
  final List<GlobalKey> showcaseKeys;
  final Widget child;
  final bool autoStart;
  final Future<void> Function(GlobalKey key)? onStepScroll;
  final VoidCallback? onStartShowcase;

  const SignUpHelpShowcase({
    super.key,
    required this.showcaseKeys,
    required this.child,
    this.autoStart = false,
    this.onStepScroll,
    this.onStartShowcase,
  });

  @override
  State<SignUpHelpShowcase> createState() => _SignUpHelpShowcaseState();
}

class _SignUpHelpShowcaseState extends State<SignUpHelpShowcase> {
  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ShowCaseWidget.of(context).startShowCase(widget.showcaseKeys);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (context) => widget.child,
      onStart: (index, key) async {
        if (widget.onStepScroll != null) {
          await widget.onStepScroll!(key);
        }
        if (widget.onStartShowcase != null) widget.onStartShowcase!();
      },
    );
  }
}
