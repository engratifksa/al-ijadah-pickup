import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'config/app_config.dart';
import 'config/theme.dart';
import 'screens/role_selection_screen.dart';
import 'services/database_helper.dart';
import 'services/encryption_service.dart';
import 'services/smtp_email_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite database factory across all platforms (Web, Windows, Android, iOS)
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
    try {
      BrowserContextMenu.disableContextMenu();
    } catch (_) {}
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Set system UI overlay style matching Royal Blue branding
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Core Services & Configuration
  try {
    await AppConfig.loadFromPreferences();
    await EncryptionService().init();
    await SmtpEmailService().init();
    if (!kIsWeb) {
      await DatabaseHelper().database;
    }
  } catch (e) {
    debugPrint('[Main] Service initialization note: $e');
  }

  runApp(const AlIjadahApp());
}

class AlIjadahApp extends StatelessWidget {
  const AlIjadahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Al Ijadah Pickup Pass',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const RoleSelectionScreen(),
    );
  }
}
