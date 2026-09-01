import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'config/app_config.dart';
import 'config/theme.dart';
import 'screens/parent/student_list_screen.dart';
import 'services/database_helper.dart';
import 'services/encryption_service.dart';
import 'services/smtp_email_service.dart';

/// Entrypoint for AL IJADAH PARENT APP
/// Distribute this APK/build exclusively to Parents & Guardians.
/// Parents CANNOT see security scanners, verification screens, or admin settings.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWebNoWebWorker;
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
    debugPrint('[ParentApp] Initialization note: $e');
  }

  runApp(const AlIjadahParentApp());
}

class AlIjadahParentApp extends StatelessWidget {
  const AlIjadahParentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Al Ijadah Parent Pass',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const StudentListScreen(),
    );
  }
}
