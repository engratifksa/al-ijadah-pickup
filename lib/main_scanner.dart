import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'config/app_config.dart';
import 'config/theme.dart';
import 'screens/scanner/scanner_screen.dart';
import 'services/database_helper.dart';
import 'services/encryption_service.dart';
import 'services/smtp_email_service.dart';

/// Entrypoint for AL IJADAH SECURITY SCANNER APP
/// Distribute this APK/build to School Guards & Staff.
/// Directly opens the Camera Barcode Scanner & Verification flow.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  try {
    await AppConfig.loadFromPreferences();
    await EncryptionService().init();
    await SmtpEmailService().init();
    await DatabaseHelper().init();
    if (!kIsWeb) {
      await DatabaseHelper().database;
    }
  } catch (e) {
    debugPrint('[ScannerApp] Initialization note: $e');
  }

  runApp(const AlIjadahScannerApp());
}

class AlIjadahScannerApp extends StatelessWidget {
  const AlIjadahScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Al Ijadah Security Scanner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const ScannerScreen(),
    );
  }
}
