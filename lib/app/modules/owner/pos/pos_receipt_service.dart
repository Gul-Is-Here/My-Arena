import 'dart:io';

import 'dart:typed_data';

import 'package:flutter/material.dart' show Colors;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../data/models/booking_model.dart';
import '../../../data/models/pos_shift_model.dart';
import '../../../data/models/pos_transaction_model.dart';
import '../../../theme/app_colors.dart';

final _pkr = NumberFormat('#,##0');
final _dtFmt = DateFormat('d MMM yyyy  hh:mm a');
final _dateFmt = DateFormat('d MMM yyyy');

class PosReceiptService {
  // ── Booking / Balance Receipt ─────────────────────────────────────────

  static Future<void> shareBookingReceipt({
    required BookingModel booking,
    required double amountCollected,
    required PosPaymentMethod method,
    required double newRemaining,
    String? refNo,
    required DateTime collectedAt,
  }) async {
    try {
      final pdf = await _buildBookingReceiptPdf(
        booking: booking,
        amountCollected: amountCollected,
        method: method,
        newRemaining: newRemaining,
        refNo: refNo,
        collectedAt: collectedAt,
      );
      final file = await _savePdf(pdf, 'receipt_${booking.id}.pdf');
      await _shareFile(
        file: file,
        label: 'Receipt',
        subject: 'Payment Receipt — ${booking.courtName}',
      );
    } catch (e) {
      Get.snackbar('Share Failed', e.toString(),
          backgroundColor: AppColors.error,
          colorText: Colors.white);
    }
  }

  // ── Shift Closing Report ──────────────────────────────────────────────

  static Future<void> shareShiftReport(
    PosShiftModel shift,
    double closingCash,
    double variance,
  ) async {
    try {
      final pdf = await _buildShiftReportPdf(shift, closingCash, variance);
      final file = await _savePdf(
          pdf, 'shift_${DateFormat('yyyy_MM_dd').format(shift.openedAt)}.pdf');
      await _shareFile(
        file: file,
        label: 'Shift Report',
        subject: 'Daily Closing Report — ${_dateFmt.format(shift.openedAt)}',
      );
    } catch (e) {
      Get.snackbar('Share Failed', e.toString(),
          backgroundColor: AppColors.error,
          colorText: Colors.white);
    }
  }

  // ── PDF builders ──────────────────────────────────────────────────────

  static Future<Uint8List> _buildBookingReceiptPdf({
    required BookingModel booking,
    required double amountCollected,
    required PosPaymentMethod method,
    required double newRemaining,
    String? refNo,
    required DateTime collectedAt,
  }) async {
    final pdf = pw.Document();
    final isPaid = newRemaining <= 0;

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('PAYMENT RECEIPT',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text(_dtFmt.format(collectedAt),
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ]),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: isPaid ? PdfColors.green100 : PdfColors.orange100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  isPaid ? 'FULLY PAID' : 'PARTIAL PAYMENT',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: isPaid ? PdfColors.green800 : PdfColors.orange800,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.SizedBox(height: 12),

          // Booking details
          _pdfSection('Booking Details', [
            _pdfRow('Customer',
                booking.customerName.isNotEmpty ? booking.customerName : 'Walk-in'),
            _pdfRow('Court', booking.courtName),
            _pdfRow('Slot', booking.timeRange),
          ]),
          pw.SizedBox(height: 12),

          // Payment details
          _pdfSection('Payment', [
            _pdfRow('Booking Total', 'PKR ${_pkr.format(booking.totalAmount)}'),
            _pdfRow('Previously Paid',
                'PKR ${_pkr.format((booking.amountPaid ?? 0) - amountCollected)}'),
            _pdfRow('Collected Now', 'PKR ${_pkr.format(amountCollected)}',
                bold: true),
            _pdfRow('Method', method.label),
            if (refNo != null && refNo.isNotEmpty) _pdfRow('Ref No.', refNo),
            pw.SizedBox(height: 4),
            _pdfRow(
              'Remaining Balance',
              isPaid ? 'FULLY PAID ✓' : 'PKR ${_pkr.format(newRemaining)}',
              bold: true,
            ),
          ]),

          pw.Spacer(),
          pw.Center(
            child: pw.Text('Thank you for visiting!',
                style: const pw.TextStyle(
                    fontSize: 11, color: PdfColors.grey600)),
          ),
        ],
      ),
    ));

    return pdf.save();
  }

  static Future<Uint8List> _buildShiftReportPdf(
    PosShiftModel shift,
    double closingCash,
    double variance,
  ) async {
    final pdf = pw.Document();
    final varLabel = variance.abs() < 50
        ? 'Balanced'
        : variance < 0
            ? 'Short by PKR ${_pkr.format(-variance)}'
            : 'Over by PKR ${_pkr.format(variance)}';

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('DAILY CLOSING REPORT',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(_dateFmt.format(shift.openedAt),
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
          pw.Text('${shift.arenaName}  ·  Staff: ${shift.staffName}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.SizedBox(height: 10),

          _pdfSection('Revenue', [
            _pdfRow('Cash Sales', 'PKR ${_pkr.format(shift.cashSales)}'),
            _pdfRow('Card Sales', 'PKR ${_pkr.format(shift.cardSales)}'),
            _pdfRow('Other Sales', 'PKR ${_pkr.format(shift.otherSales)}'),
            _pdfRow('Total Revenue', 'PKR ${_pkr.format(shift.totalRevenue)}', bold: true),
          ]),
          pw.SizedBox(height: 10),

          _pdfSection('Cash Drawer', [
            _pdfRow('Opening Cash', 'PKR ${_pkr.format(shift.openingCash)}'),
            if (shift.cashIn > 0)
              _pdfRow('Cash In', 'PKR ${_pkr.format(shift.cashIn)}'),
            _pdfRow('Expenses / Cash Out', '- PKR ${_pkr.format(shift.expenses)}'),
            _pdfRow('Expected', 'PKR ${_pkr.format(shift.expectedCash)}', bold: true),
            _pdfRow('You Counted', 'PKR ${_pkr.format(closingCash)}', bold: true),
            _pdfRow('Variance', varLabel, bold: true),
          ]),
          pw.SizedBox(height: 10),

          _pdfSection('Net Summary', [
            _pdfRow('Total Revenue', 'PKR ${_pkr.format(shift.totalRevenue)}'),
            _pdfRow('Expenses', '- PKR ${_pkr.format(shift.expenses)}'),
            _pdfRow('Net Revenue', 'PKR ${_pkr.format(shift.netRevenue)}', bold: true),
          ]),

          if (shift.notes.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text('Notes: ${shift.notes}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          ],
        ],
      ),
    ));

    return pdf.save();
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  static pw.Widget _pdfSection(String title, List<pw.Widget> rows) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(title.toUpperCase(),
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey600)),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(children: rows),
        ),
      ]);

  static pw.Widget _pdfRow(String label, String value, {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ],
        ),
      );

  static Future<File> _savePdf(Uint8List bytes, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> _shareFile({
    required File file,
    required String label,
    required String subject,
  }) async {
    final xfile = XFile(file.path, mimeType: 'application/pdf');
    await SharePlus.instance.share(
      ShareParams(files: [xfile], subject: subject, text: subject),
    );
  }
}
