import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/export_crypto.dart';
import '../services/pin_service.dart';

/// Full-screen PIN unlock gate.
class PinLockScreen extends StatefulWidget {
  const PinLockScreen({
    super.key,
    required this.onUnlocked,
    this.title = 'Enter PIN',
  });

  final VoidCallback onUnlocked;
  final String title;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _controller.text.trim();
    if (!PinService.isValidPinFormat(pin)) {
      setState(() {
        _error =
            'Enter a ${PinService.minPinLength}–${PinService.maxPinLength} digit PIN';
      });
      return;
    }

    final throttle = PinService.instance.throttleRemaining();
    if (throttle != null) {
      setState(() {
        _error =
            'Too many attempts. Try again in ${throttle.inSeconds}s';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final ok = await PinService.instance.verifyPin(pin);
    if (!mounted) return;

    if (ok) {
      widget.onUnlocked();
      return;
    }

    final remaining = PinService.instance.throttleRemaining();
    setState(() {
      _busy = false;
      _controller.clear();
      _error = remaining != null
          ? 'Too many attempts. Try again in ${remaining.inSeconds}s'
          : 'Incorrect PIN';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Unlock to view your donation data',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: PinService.maxPinLength,
                enabled: !_busy,
                autofocus: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  letterSpacing: 8,
                ),
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    letterSpacing: 8,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Unlock'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog helpers for setting / changing / removing a PIN.
class PinDialogs {
  PinDialogs._();

  static Future<String?> promptNewPin(
    BuildContext context, {
    required String title,
  }) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: Text(title, style: const TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose a ${PinService.minPinLength}–${PinService.maxPinLength} digit PIN. '
                  'It is stored as a salted hash — not in plaintext.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: PinService.maxPinLength,
                  style: const TextStyle(color: Colors.white),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'PIN',
                    labelStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    counterText: '',
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: PinService.maxPinLength,
                  style: const TextStyle(color: Colors.white),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Confirm PIN',
                    labelStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    counterText: '',
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final pin = pinController.text.trim();
                  final confirm = confirmController.text.trim();
                  if (!PinService.isValidPinFormat(pin)) {
                    setDialogState(() {
                      error =
                          'PIN must be ${PinService.minPinLength}–${PinService.maxPinLength} digits';
                    });
                    return;
                  }
                  if (pin != confirm) {
                    setDialogState(() => error = 'PINs do not match');
                    return;
                  }
                  Navigator.pop(ctx, pin);
                },
                child: Text(
                  'Save',
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    pinController.dispose();
    confirmController.dispose();
    return result;
  }

  static Future<String?> promptCurrentPin(
    BuildContext context, {
    required String title,
  }) async {
    final controller = TextEditingController();
    String? error;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: Text(title, style: const TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  obscureText: true,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: PinService.maxPinLength,
                  style: const TextStyle(color: Colors.white),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Current PIN',
                    labelStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    counterText: '',
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                    ),
                  ),
                  onSubmitted: (_) {
                    final pin = controller.text.trim();
                    if (!PinService.isValidPinFormat(pin)) {
                      setDialogState(() {
                        error =
                            'Enter a ${PinService.minPinLength}–${PinService.maxPinLength} digit PIN';
                      });
                      return;
                    }
                    Navigator.pop(ctx, pin);
                  },
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final pin = controller.text.trim();
                  if (!PinService.isValidPinFormat(pin)) {
                    setDialogState(() {
                      error =
                          'Enter a ${PinService.minPinLength}–${PinService.maxPinLength} digit PIN';
                    });
                    return;
                  }
                  Navigator.pop(ctx, pin);
                },
                child: Text(
                  'Continue',
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    controller.dispose();
    return result;
  }

  /// Prompt for a new export PIN/passphrase (confirmed). Not limited to digits.
  static Future<String?> promptExportPassphrase(
    BuildContext context, {
    String title = 'PIN-protected export',
  }) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: Text(title, style: const TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose an export PIN or passphrase (at least '
                    '${ExportCrypto.minPassphraseLength} characters). '
                    'You can reuse your app PIN or pick a separate one. '
                    'You will need it to import this file.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    obscureText: true,
                    autofocus: true,
                    maxLength: ExportCrypto.maxPassphraseLength,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Export PIN / passphrase',
                      labelStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      counterText: '',
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    maxLength: ExportCrypto.maxPassphraseLength,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Confirm',
                      labelStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      counterText: '',
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final pin = pinController.text.trim();
                  final confirm = confirmController.text.trim();
                  if (!ExportCrypto.isValidPassphrase(pin)) {
                    setDialogState(() {
                      error =
                          'Use ${ExportCrypto.minPassphraseLength}–${ExportCrypto.maxPassphraseLength} characters';
                    });
                    return;
                  }
                  if (pin != confirm) {
                    setDialogState(() => error = 'Entries do not match');
                    return;
                  }
                  Navigator.pop(ctx, pin);
                },
                child: Text(
                  'Encrypt & export',
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    pinController.dispose();
    confirmController.dispose();
    return result;
  }

  /// Single-field prompt to unlock a PIN-protected backup on import.
  static Future<String?> promptImportPassphrase(
    BuildContext context, {
    String title = 'Enter export PIN',
  }) async {
    final controller = TextEditingController();
    String? error;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: Text(title, style: const TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'This backup is PIN-protected. Enter the PIN or passphrase '
                  'used when exporting. A wrong PIN will not erase your data.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  obscureText: true,
                  autofocus: true,
                  maxLength: ExportCrypto.maxPassphraseLength,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Export PIN / passphrase',
                    labelStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    counterText: '',
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                    ),
                  ),
                  onSubmitted: (_) {
                    final pin = controller.text.trim();
                    if (!ExportCrypto.isValidPassphrase(pin)) {
                      setDialogState(() {
                        error =
                            'Enter at least ${ExportCrypto.minPassphraseLength} characters';
                      });
                      return;
                    }
                    Navigator.pop(ctx, pin);
                  },
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final pin = controller.text.trim();
                  if (!ExportCrypto.isValidPassphrase(pin)) {
                    setDialogState(() {
                      error =
                          'Enter at least ${ExportCrypto.minPassphraseLength} characters';
                    });
                    return;
                  }
                  Navigator.pop(ctx, pin);
                },
                child: Text(
                  'Unlock backup',
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    controller.dispose();
    return result;
  }
}
