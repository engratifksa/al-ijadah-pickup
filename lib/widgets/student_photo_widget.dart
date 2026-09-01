import 'dart:convert';
import 'dart:io' show File, Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Universal Student Photo Widget that safely renders photos across
/// Flutter Web (Chrome/Edge/Safari), Android, iOS, Windows, and macOS.
///
/// Handles:
/// - In-memory bytes (Uint8List)
/// - Base64 data URLs (data:image/jpeg;base64,...)
/// - Pure base64 strings
/// - Network/Blob URLs (http://, https://, blob:)
/// - Local assets (assets/...)
/// - Local filesystem paths (File) on native platforms (kIsWeb == false)
/// - Graceful fallback avatar when no photo or error occurs
class StudentPhotoWidget extends StatelessWidget {
  final String? photoPath;
  final Uint8List? memoryBytes;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final double iconSize;

  const StudentPhotoWidget({
    super.key,
    this.photoPath,
    this.memoryBytes,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.iconSize = 36,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Direct memory bytes provided
    if (memoryBytes != null && memoryBytes!.isNotEmpty) {
      return Image.memory(
        memoryBytes!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
      );
    }

    final path = photoPath?.trim();

    // 2. Empty path -> fallback placeholder
    if (path == null || path.isEmpty) {
      return _buildPlaceholder();
    }

    // 3. Base64 Data URL (e.g. data:image/jpeg;base64,...) or raw base64 string
    if (path.startsWith('data:image') || _isLikelyBase64(path)) {
      try {
        final rawBase64 = path.contains(',') ? path.split(',').last : path;
        final decodedBytes = base64Decode(rawBase64);
        return Image.memory(
          decodedBytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
        );
      } catch (e) {
        debugPrint('[StudentPhotoWidget] Base64 decode error: $e');
        return _buildPlaceholder();
      }
    }

    // 4. Web URLs or Blob URLs (blob:http://...)
    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('blob:')) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.accentGold,
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    }

    // 5. Local asset path
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
      );
    }

    // 6. Native File path (Android, iOS, Windows, macOS) - NEVER called on Web!
    if (!kIsWeb) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
          );
        }
      } catch (e) {
        debugPrint('[StudentPhotoWidget] File check error: $e');
      }
    }

    // Default fallback
    return _buildPlaceholder();
  }

  bool _isLikelyBase64(String str) {
    if (str.length > 200 &&
        !str.contains(' ') &&
        !str.contains('/') &&
        !str.contains('\\')) {
      return true;
    }
    return false;
  }

  Widget _buildPlaceholder() {
    if (placeholder != null) return placeholder!;
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF1F5F9),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: iconSize,
          color: AppTheme.primaryRoyalBlue.withOpacity(0.4),
        ),
      ),
    );
  }
}
