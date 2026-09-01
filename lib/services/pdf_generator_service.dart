import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../config/app_config.dart';
import '../models/student_model.dart';

class PdfGeneratorService {
  static const PdfColor primaryBlue = PdfColor.fromInt(0xFF0F3B82);
  static const PdfColor darkBlue = PdfColor.fromInt(0xFF072454);
  static const PdfColor lightBlue = PdfColor.fromInt(0xFF1B55B0);
  static const PdfColor gold = PdfColor.fromInt(0xFFF5B800);
  static const PdfColor darkText = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor mutedText = PdfColor.fromInt(0xFF64748B);
  static const PdfColor cardBg = PdfColor.fromInt(0xFFFFFFFF);
  static const PdfColor lightBorder = PdfColor.fromInt(0xFFE2E8F0);

  /// Generates the printable front-and-back ID Pass PDF document
  static Future<Uint8List> generatePassPdf(StudentModel student) async {
    final pdf = pw.Document();

    // Load student photo if available (handles base64 data and native files)
    pw.MemoryImage? studentPhoto;
    if (student.photoPath != null && student.photoPath!.isNotEmpty) {
      try {
        final path = student.photoPath!.trim();
        if (path.startsWith('data:image') ||
            (path.length > 200 && !path.contains('/') && !path.contains('\\'))) {
          final rawBase64 = path.contains(',') ? path.split(',').last : path;
          final bytes = base64Decode(rawBase64);
          studentPhoto = pw.MemoryImage(bytes);
        } else if (!kIsWeb) {
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            studentPhoto = pw.MemoryImage(bytes);
          }
        }
      } catch (_) {}
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Page Header
              pw.Text(
                'Al Ijadah International School',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Official Lanyard Identification Pass • Print & Laminate Specification',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: mutedText,
                ),
              ),
              pw.SizedBox(height: 24),

              // Cards Layout Container (Front & Back Side-by-Side)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // FRONT CARD
                  pw.Column(
                    children: [
                      pw.Text(
                        'FRONT VIEW',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: mutedText,
                          letterSpacing: 1,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      _buildFrontCard(student, studentPhoto),
                    ],
                  ),

                  // BACK CARD
                  pw.Column(
                    children: [
                      pw.Text(
                        'BACK VIEW',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: mutedText,
                          letterSpacing: 1,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      _buildBackCard(student),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 36),

              // Cutting & Lanyard Assembly Guide
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: lightBorder, width: 1),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  color: const PdfColor.fromInt(0xFFF8FAFC),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'INSTRUCTIONS FOR PARENTS & GUARDIANS:',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryBlue,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      '1. Cut along the outer solid border of both cards.\n'
                      '2. Fold or place back-to-back inside a standard CR-80 plastic lanyard pouch (85.6mm × 53.98mm).\n'
                      '3. Always present this card or the active dynamic mobile QR pass to security staff at pickup gate.',
                      style: pw.TextStyle(fontSize: 8.5, color: darkText, lineSpacing: 2),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Front View of Lanyard Card
  static pw.Widget _buildFrontCard(StudentModel student, pw.MemoryImage? photo) {
    return pw.Container(
      width: 230,
      height: 340,
      decoration: pw.BoxDecoration(
        color: cardBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
        border: pw.Border.all(color: primaryBlue, width: 2),
      ),
      child: pw.Column(
        children: [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: pw.BoxDecoration(
              color: primaryBlue,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(10),
                topRight: pw.Radius.circular(10),
              ),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'AL IJADAH',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: gold,
                    letterSpacing: 1.5,
                  ),
                ),
                pw.Text(
                  'INTERNATIONAL SCHOOL',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    letterSpacing: 0.8,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: gold,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'OFFICIAL PICKUP PASS',
                    style: pw.TextStyle(
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body Content
          pw.Padding(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              children: [
                // Student Photo Box
                pw.Container(
                  width: 76,
                  height: 88,
                  decoration: pw.BoxDecoration(
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: gold, width: 2),
                    color: const PdfColor.fromInt(0xFFF1F5F9),
                  ),
                  child: photo != null
                      ? pw.ClipRRect(
                          horizontalRadius: 6,
                          verticalRadius: 6,
                          child: pw.Image(photo, fit: pw.BoxFit.cover),
                        )
                      : pw.Center(
                          child: pw.Text(
                            'STUDENT\nPHOTO',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontSize: 8, color: mutedText),
                          ),
                        ),
                ),
                pw.SizedBox(height: 8),

                // Student Name
                pw.Text(
                  student.name,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryBlue,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  student.grade,
                  style: pw.TextStyle(fontSize: 8.5, color: darkText),
                ),
                pw.SizedBox(height: 8),

                // Info Rows
                _buildPdfFieldRow('ID Number:', student.id),
                _buildPdfFieldRow('Supervisor:', student.supervisor),
                _buildPdfFieldRow('Guardian:', student.guardianName),
                _buildPdfFieldRow('Parent Mobile:', student.parentMobile),
              ],
            ),
          ),

          pw.Spacer(),
          // Bottom Stripe
          pw.Container(
            height: 6,
            decoration: pw.BoxDecoration(
              color: gold,
              borderRadius: const pw.BorderRadius.only(
                bottomLeft: pw.Radius.circular(10),
                bottomRight: pw.Radius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Back View of Lanyard Card
  static pw.Widget _buildBackCard(StudentModel student) {
    return pw.Container(
      width: 230,
      height: 340,
      decoration: pw.BoxDecoration(
        color: cardBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
        border: pw.Border.all(color: primaryBlue, width: 2),
      ),
      child: pw.Column(
        children: [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: pw.BoxDecoration(
              color: primaryBlue,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(10),
                topRight: pw.Radius.circular(10),
              ),
            ),
            child: pw.Center(
              child: pw.Text(
                'SECURITY & VERIFICATION',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: gold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),

          // Content
          pw.Padding(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'TERMS OF USE:',
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryBlue,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  '• This card authorizes the named guardian to pick up the student.\n'
                  '• Possession of this pass does not replace verification if security flags an anomaly.\n'
                  '• If found, please return to Al Ijadah Security Command or call ${AppConfig.schoolPhone}.',
                  style: pw.TextStyle(fontSize: 6.5, color: darkText, lineSpacing: 1.6),
                ),
                pw.SizedBox(height: 12),

                // Barcode / Verification Code Box
                pw.Center(
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.code128(),
                    data: student.id,
                    width: 170,
                    height: 48,
                    drawText: true,
                    textStyle: const pw.TextStyle(fontSize: 7),
                  ),
                ),
                pw.SizedBox(height: 14),

                // Emergency Contact Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFF1F5F9),
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'EMERGENCY DISPATCH:',
                        style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: primaryBlue),
                      ),
                      pw.Text(
                        'Security Gate: ${AppConfig.schoolPhone}\nParent Mobile: ${student.parentMobile}',
                        style: pw.TextStyle(fontSize: 6.5, color: darkText),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(width: 80, height: 1, color: mutedText),
                        pw.SizedBox(height: 2),
                        pw.Text('Authorized Signature', style: pw.TextStyle(fontSize: 6, color: mutedText)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(width: 60, height: 1, color: mutedText),
                        pw.SizedBox(height: 2),
                        pw.Text('School Stamp', style: pw.TextStyle(fontSize: 6, color: mutedText)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.Spacer(),
          // Bottom Stripe
          pw.Container(
            height: 6,
            decoration: pw.BoxDecoration(
              color: gold,
              borderRadius: const pw.BorderRadius.only(
                bottomLeft: pw.Radius.circular(10),
                bottomRight: pw.Radius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfFieldRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 7.5, color: mutedText),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: darkText,
            ),
          ),
        ],
      ),
    );
  }

  /// Print or show print preview directly
  static Future<void> printPass(StudentModel student) async {
    final pdfBytes = await generatePassPdf(student);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Pickup_Pass_${student.name.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Share PDF file
  static Future<void> sharePass(StudentModel student) async {
    final pdfBytes = await generatePassPdf(student);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Al_Ijadah_Pass_${student.id}.pdf',
    );
  }
}
