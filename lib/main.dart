import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/donation_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initializes encrypted store (migrates plaintext prefs if needed) + notifications.
  await DonationStorage.initNotifications();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Color(0xFF0D0D0D),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const BloodDonationApp());
}
