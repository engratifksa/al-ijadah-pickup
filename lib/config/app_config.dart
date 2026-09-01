import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String schoolName = 'Al Ijadah International School';
  static const String schoolMotto = 'Excellence in Education & Character';
  static const String schoolAddress = 'Plot 124, Educational District, Riyadh, KSA';
  static String schoolPhone = '+966 55 596 2300';
  static const String schoolEmail = 'security@alijadah.edu.sa';

  // School Administration Email where registration notifications are sent
  static String adminEmail = 'alijadahinternational@gmail.com';

  // Dynamic QR configuration
  static const int qrRefreshIntervalSeconds = 30;
  static const int qrValidityWindowSeconds = 45; // 30s dynamic cycle + 15s scan grace period (rejects old screenshots)

  // Default AES Secret Key for offline encryption (256-bit key: 32 bytes)
  static const String defaultAesKey = 'AlIjadahSecureKeyPickup2026!#99';
  static const String defaultAesIv = 'AlIjadahIVPass16';

  // Direct SMTP Configuration (Direct Gmail)
  static String smtpSenderName = 'Al Ijadah Security & Dispatch';
  static String smtpHost = 'smtp.gmail.com';
  static int smtpPortSsl = 465;
  static int smtpPortTls = 587;

  // Gmail Sender Credentials
  static String smtpGmailUser = 'alijadahinternational@gmail.com';
  static String smtpGmailAppPassword = 'pxuy qgkm ionn jjuw'; // 16-character Google App Password

  /// Always returns clean 16 characters with spaces removed for SMTP authentication
  static String get cleanSmtpPassword => smtpGmailAppPassword.replaceAll(' ', '').trim();

  // Security Guard Passcode (for scanner access, default: 2175)
  static String guardPin = '2175';

  // Admin & Settings Passcode (for settings configuration, default: 3825)
  static String settingsPin = '3825';

  /// Returns masked version of admin email for privacy (e.g. at***6@gmail.com)
  static String get maskedAdminEmail {
    if (!adminEmail.contains('@')) return 'admin@alijadah.edu.sa';
    final parts = adminEmail.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '$name***@$domain';
    return '${name.substring(0, 2)}***${name.substring(name.length - 1)}@$domain';
  }

  // Backward compatibility alias for staffPin
  static String get staffPin => guardPin;
  static set staffPin(String val) => guardPin = val;

  // Security Guard Session State (persists until guard logs out)
  static bool isGuardSessionActive = false;

  /// Activates the security guard session
  static Future<void> loginGuard() async {
    isGuardSessionActive = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('guard_session_active', true);
    } catch (e) {
      debugPrint('[AppConfig] Error persisting guard login: $e');
    }
  }

  /// Ends the security guard session
  static Future<void> logoutGuard() async {
    isGuardSessionActive = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('guard_session_active', false);
    } catch (e) {
      debugPrint('[AppConfig] Error persisting guard logout: $e');
    }
  }

  // Toggle for simulation when actual Gmail credentials are not configured
  static bool enableMockSmtpWhenOfflineOrEmpty = false;

  // Local HTTP bridge port for Flutter Web email relay
  static int webBridgePort = 8085;

  // Remote HTTPS Email Gateway URL for Web/PWA (Method 1)
  static String webHttpGatewayUrl =
      'https://script.google.com/macros/s/AKfycby8XbMVaeFLdVgTyXmSMOH1tFb0UVdIP_cbP_hBo_ElODGR-Qq9TPDa92HnYCoNYcNj/exec';

  /// Loads saved configuration from SharedPreferences so credentials survive reloads
  static Future<void> loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString('smtp_gmail_user');
      if (savedUser != null && savedUser.isNotEmpty && savedUser != 'alijadah.school.alerts@gmail.com') {
        smtpGmailUser = savedUser;
      } else {
        smtpGmailUser = 'alijadahinternational@gmail.com';
      }

      final savedPass = prefs.getString('smtp_gmail_app_password');
      if (savedPass != null && savedPass.isNotEmpty && savedPass != 'abcd efgh ijkl mnop' && savedPass != 'abcdefghijklmnop') {
        smtpGmailAppPassword = savedPass;
      } else {
        smtpGmailAppPassword = 'pxuy qgkm ionn jjuw';
      }

      final savedAdminEmail = prefs.getString('admin_email');
      if (savedAdminEmail != null && savedAdminEmail.isNotEmpty && savedAdminEmail != 'alijadah.school.alerts@gmail.com' && savedAdminEmail != 'eng.atif.rafiq@gmail.com') {
        adminEmail = savedAdminEmail;
      } else {
        adminEmail = 'alijadahinternational@gmail.com';
      }

      final savedPhone = prefs.getString('school_phone');
      if (savedPhone != null && savedPhone.isNotEmpty && savedPhone != '+966 11 456 7890') {
        schoolPhone = savedPhone;
      } else {
        schoolPhone = '+966 55 596 2300';
      }

      final savedHost = prefs.getString('smtp_host');
      if (savedHost != null && savedHost.isNotEmpty) {
        smtpHost = savedHost;
      }

      final savedPort = prefs.getInt('smtp_port_ssl');
      if (savedPort != null) {
        smtpPortSsl = savedPort;
      }

      final savedGuardPin = prefs.getString('guard_pin') ?? prefs.getString('staff_pin');
      if (savedGuardPin != null && savedGuardPin.isNotEmpty && savedGuardPin != '1234') {
        guardPin = savedGuardPin;
      } else {
        guardPin = '2175';
      }

      final savedSettingsPin = prefs.getString('settings_pin');
      if (savedSettingsPin != null && savedSettingsPin.isNotEmpty && savedSettingsPin != '9999') {
        settingsPin = savedSettingsPin;
      } else {
        settingsPin = '3825';
      }

      isGuardSessionActive = prefs.getBool('guard_session_active') ?? false;

      final savedMock = prefs.getBool('mock_smtp');
      if (savedMock != null) {
        enableMockSmtpWhenOfflineOrEmpty = savedMock;
      } else {
        enableMockSmtpWhenOfflineOrEmpty = false;
      }

      final savedGateway = prefs.getString('web_http_gateway_url');
      if (savedGateway != null && savedGateway.isNotEmpty) {
        webHttpGatewayUrl = savedGateway;
      } else {
        webHttpGatewayUrl =
            'https://script.google.com/macros/s/AKfycby8XbMVaeFLdVgTyXmSMOH1tFb0UVdIP_cbP_hBo_ElODGR-Qq9TPDa92HnYCoNYcNj/exec';
      }

      debugPrint('[AppConfig] Configuration loaded. Guard PIN: $guardPin, Settings PIN: $settingsPin, Guard Session: $isGuardSessionActive, Phone: $schoolPhone');
    } catch (e) {
      debugPrint('[AppConfig] Error loading preferences: $e');
    }
  }

  /// Saves current configuration to SharedPreferences
  static Future<void> saveToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('smtp_gmail_user', smtpGmailUser);
      await prefs.setString('smtp_gmail_app_password', smtpGmailAppPassword);
      await prefs.setString('admin_email', adminEmail);
      await prefs.setString('school_phone', schoolPhone);
      await prefs.setString('smtp_host', smtpHost);
      await prefs.setInt('smtp_port_ssl', smtpPortSsl);
      await prefs.setString('guard_pin', guardPin);
      await prefs.setString('settings_pin', settingsPin);
      await prefs.setBool('guard_session_active', isGuardSessionActive);
      await prefs.setBool('mock_smtp', enableMockSmtpWhenOfflineOrEmpty);
      await prefs.setString('web_http_gateway_url', webHttpGatewayUrl);
      debugPrint('[AppConfig] Saved configuration to SharedPreferences.');
    } catch (e) {
      debugPrint('[AppConfig] Error saving preferences: $e');
    }
  }
}
