import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/pin_lock_screen.dart';
import 'services/auto_lock_policy.dart';
import 'services/donation_storage.dart';
import 'services/pin_service.dart';

class BloodDonationApp extends StatefulWidget {
  const BloodDonationApp({super.key});

  @override
  State<BloodDonationApp> createState() => _BloodDonationAppState();
}

class _BloodDonationAppState extends State<BloodDonationApp>
    with WidgetsBindingObserver {
  bool _pinEnabled = false;
  bool _unlocked = true;
  bool _ready = false;
  int _autoLockSeconds = AutoLockPolicy.defaultTimeoutSeconds;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPinState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadPinState({bool preserveSession = false}) async {
    final enabled = await PinService.instance.isEnabled();
    final autoLock = await DonationStorage.getAutoLockTimeoutSeconds();
    if (!mounted) return;
    setState(() {
      _pinEnabled = enabled;
      _autoLockSeconds = autoLock;
      if (!preserveSession) {
        // Cold start / first load: lock if PIN is on.
        _unlocked = !enabled;
      } else if (!enabled) {
        // PIN turned off in Settings — stay in the app.
        _unlocked = true;
      }
      // PIN just enabled: keep current session unlocked until background.
      _ready = true;
    });
  }

  /// Called from Settings when PIN lock / auto-lock prefs change.
  void refreshPinLock() {
    _loadPinState(preserveSession: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_pinEnabled) return;

    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      if (AutoLockPolicy.lockImmediatelyOnPause(_autoLockSeconds) &&
          _unlocked) {
        setState(() => _unlocked = false);
      }
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (_unlocked &&
          AutoLockPolicy.shouldLockOnResume(
            timeoutSeconds: _autoLockSeconds,
            pausedAt: _pausedAt,
            now: DateTime.now(),
          )) {
        setState(() => _unlocked = false);
      }
      _pausedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'blood_donation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scrollbarTheme: const ScrollbarThemeData(
          thickness: WidgetStatePropertyAll(0),
          thumbVisibility: WidgetStatePropertyAll(false),
          trackVisibility: WidgetStatePropertyAll(false),
          interactive: false,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD3180C),
          secondary: Color(0xFF8B0000),
          surface: Color(0xFF0D0D0D),
          error: Color(0xFFD3180C),
          onPrimary: Colors.white,
          onSurface: Colors.white,
          onSecondary: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        fontFamily: 'Roboto',
      ),
      home: !_ready
          ? const Scaffold(
              backgroundColor: Color(0xFF0D0D0D),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFFD3180C)),
              ),
            )
          : (_pinEnabled && !_unlocked)
              ? PinLockScreen(
                  onUnlocked: () {
                    setState(() => _unlocked = true);
                  },
                )
              : HomeScreen(onPinSettingsChanged: refreshPinLock),
    );
  }
}
