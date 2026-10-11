import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import '../screens/login_screen.dart';

class InactivityAutoLock extends ConsumerStatefulWidget {
  final Widget child;
  const InactivityAutoLock({super.key, required this.child});

  @override
  ConsumerState<InactivityAutoLock> createState() => _InactivityAutoLockState();
}

class _InactivityAutoLockState extends ConsumerState<InactivityAutoLock> with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _backgroundTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _backgroundTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_backgroundTime != null) {
        final elapsed = DateTime.now().difference(_backgroundTime!);
        if (elapsed.inMinutes >= 5) {
          _lockApp();
        } else {
          _resetTimer();
        }
        _backgroundTime = null;
      }
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn) return;

    _timer = Timer(const Duration(minutes: 5), () {
      _lockApp();
    });
  }

  void _lockApp() {
    _timer?.cancel();
    final auth = ref.read(authProvider);
    if (auth.isLoggedIn) {
      ref.read(authProvider.notifier).logout();
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isLoggedIn) {
        _resetTimer();
      } else {
        _timer?.cancel();
      }
    });

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerSignal: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
