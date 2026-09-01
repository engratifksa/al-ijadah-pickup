import 'dart:convert';
import 'dart:io';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// Local SMTP Bridge Server for Flutter Web
/// Enables Flutter Web running in Chrome to dispatch real Gmail SMTP emails
/// by bridging HTTP requests to native TCP socket SSL connections.
void main() async {
  const port = 8085;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  print('[SMTP Bridge] Server listening on http://127.0.0.1:$port');

  await for (HttpRequest request in server) {
    // Add CORS headers for browser access
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type, Origin, Accept');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      continue;
    }

    if (request.uri.path == '/status') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'status': 'online', 'bridge': 'Al Ijadah SMTP Bridge'}));
      await request.response.close();
      continue;
    }

    if (request.uri.path == '/send-email' && request.method == 'POST') {
      try {
        final content = await utf8.decoder.bind(request).join();
        final data = jsonDecode(content) as Map<String, dynamic>;

        final user = (data['user'] as String?)?.trim() ?? '';
        final rawPass = (data['pass'] as String?)?.trim() ?? '';
        // Strip spaces: Google displays App Passwords with spaces (xxxx xxxx xxxx xxxx) for readability,
        // but SMTP protocol authentication requires the clean 16 characters without spaces.
        final pass = rawPass.replaceAll(' ', '');
        final recipient = (data['recipient'] as String?)?.trim() ?? '';
        final subject = (data['subject'] as String?) ?? 'Pickup Notification';
        final html = (data['html'] as String?) ?? '';
        final senderName = (data['senderName'] as String?) ?? 'Al Ijadah Pickup';

        if (user.isEmpty || pass.isEmpty || recipient.isEmpty) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'success': false, 'error': 'Missing user, pass, or recipient'}));
          await request.response.close();
          continue;
        }

        print('[SMTP Bridge] Dispatching email from $user to $recipient...');

        final smtpServer = SmtpServer(
          'smtp.gmail.com',
          port: 465,
          ssl: true,
          username: user,
          password: pass,
        );

        final message = Message()
          ..from = Address(user, senderName)
          ..recipients.add(recipient)
          ..subject = subject
          ..html = html;

        final sendReport = await send(message, smtpServer);
        print('[SMTP Bridge] Email successfully sent! Report: $sendReport');

        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'success': true,
          'message': 'Email dispatched successfully via Gmail SMTP',
        }));
      } catch (e) {
        print('[SMTP Bridge] Error sending email: $e');
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'success': false,
          'error': e.toString(),
        }));
      }
      await request.response.close();
      continue;
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }
}
