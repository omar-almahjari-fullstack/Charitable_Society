import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/arabic_pdf_helper.dart';

class ReceiptView extends StatefulWidget {
  final String paymentId;

  const ReceiptView({Key? key, required this.paymentId}) : super(key: key);

  @override
  State<ReceiptView> createState() => _ReceiptViewState();
}

class _ReceiptViewState extends State<ReceiptView> {
  bool _isLoading = true;
  Map<String, dynamic>? _paymentData;
  String? _errorMessage;

  static const List<String> _monthsArabic = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];

  @override
  void initState() {
    super.initState();
    _loadReceiptData();
  }

  Future<void> _loadReceiptData() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService.client
          .from('payments')
          .select('*, profiles!member_id(full_name, phone, national_id, role)')
          .eq('id', widget.paymentId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _paymentData = response;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _errorMessage = 'لم يتم العثور على بيانات السند المطلوب';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'خطأ في تحميل السند: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  String _getMonthName(int month) {
    if (month >= 1 && month <= 12) return _monthsArabic[month - 1];
    return 'شهر $month';
  }

  String _getMethodLabel(String? method, String? walletType) {
    if (walletType != null && walletType.trim().isNotEmpty) {
      return 'محفظة إلكترونية ($walletType)';
    }
    const methods = {
      'cash': 'نقدي',
      'bank_transfer': 'تحويل بنكي',
      'online': 'محفظة إلكترونية',
      'crypto': 'عملات رقمية',
      'check': 'صك بريدي / بنكي',
    };
    return methods[method] ?? method ?? 'نقدي';
  }

  void _shareReceipt() {
    if (_paymentData == null) return;
    final receiptNum = _paymentData!['receipt_number'] ?? widget.paymentId;
    final profile = _paymentData!['profiles'] as Map<String, dynamic>?;
    final memberName = profile?['full_name'] ?? 'عضو الجمعية';
    final amount = (_paymentData!['amount'] ?? 0).toString();
    final month = _getMonthName(_paymentData!['payment_month'] ?? 1);
    final year = (_paymentData!['payment_year'] ?? 2026).toString();
    final methodLabel = _getMethodLabel(_paymentData!['payment_method'], _paymentData!['wallet_type']);
    final dateStr = DateFormat('yyyy/MM/dd HH:mm').format(
      _paymentData!['payment_date'] != null
          ? DateTime.parse(_paymentData!['payment_date'].toString())
          : DateTime.now(),
    );

    final text = '''
📄 سند تحصيل اشتراك رسمي
جمعية التكافل والتنمية القروية - الجمهورية اليمنية
------------------------------------------------
رقم السند: $receiptNum
اسم العضو المسدد: $memberName
فترة الاشتراك: $month $year
وسيلة التحصيل: $methodLabel
المبلغ المسدد: $amount ر.ي
التاريخ: $dateStr
حالة السند: معتمد رقمياً ومسجل بالخزينة العامة ✅
------------------------------------------------
''';
    Share.share(text);
  }

  Future<void> _exportPdfReceipt() async {
    if (_paymentData == null) return;
    try {
      final fontRegular = await ArabicPdfHelper.loadArabicFont();
      final fontBold = await ArabicPdfHelper.loadArabicBoldFont();

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
      );

      final data = _paymentData!;
      final profile = data['profiles'] as Map<String, dynamic>?;
      final memberName = profile?['full_name'] ?? 'عضو الجمعية';
      final memberNumber = profile?['member_number'] ?? profile?['national_id'] ?? widget.paymentId.substring(0, 6);
      final phone = profile?['phone'] ?? '---';
      final receiptNumber = data['receipt_number'] ?? 'REC-${widget.paymentId.substring(0, 6)}';
      final amount = ((data['amount'] ?? 0.0) as num).toDouble();
      final month = _getMonthName(data['payment_month'] ?? 1);
      final year = data['payment_year'] ?? 2026;
      final methodLabel = _getMethodLabel(data['payment_method'], data['wallet_type']);
      final dateStr = DateFormat('yyyy/MM/dd - HH:mm').format(
        data['payment_date'] != null ? DateTime.parse(data['payment_date'].toString()) : DateTime.now(),
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blue900, width: 2),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(ArabicPdfHelper.reshape('جمعية التكافل والتنمية القروية'), style: pw.TextStyle(font: fontBold, fontSize: 16)),
                  pw.SizedBox(height: 2),
                  pw.Text(ArabicPdfHelper.reshape('الجمهورية اليمنية'), style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey700)),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                    child: pw.Text(ArabicPdfHelper.reshape('سند تحصيل اشتراك رسمي - رقم: $receiptNumber'), style: pw.TextStyle(font: fontBold, fontSize: 11)),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Divider(thickness: 1),
                  pw.SizedBox(height: 8),

                  _pdfRow('اسم العضو المسدد:', memberName, fontBold, fontRegular),
                  _pdfRow('رقم العضوية:', memberNumber, fontBold, fontRegular),
                  _pdfRow('رقم الهاتف:', phone, fontBold, fontRegular),
                  _pdfRow('اشتراك شهر / سنة:', '$month $year', fontBold, fontRegular),
                  _pdfRow('طريقة التحصيل:', methodLabel, fontBold, fontRegular),
                  if (data['wallet_transaction_id'] != null && data['wallet_transaction_id'].toString().isNotEmpty)
                    _pdfRow('رقم عملية المحفظة:', data['wallet_transaction_id'].toString(), fontBold, fontRegular),
                  _pdfRow('تاريخ السداد:', dateStr, fontBold, fontRegular),

                  pw.SizedBox(height: 12),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(color: PdfColors.green50, border: pw.Border.all(color: PdfColors.green700)),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(ArabicPdfHelper.reshape('المبلغ الإجمالي المسدد:'), style: pw.TextStyle(font: fontBold, fontSize: 12)),
                        pw.Text(ArabicPdfHelper.reshape('${amount.toStringAsFixed(0)} ر.ي'), style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.green900)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(ArabicPdfHelper.reshape('توقيع أمين الصندوق: معتمد رقمياً ✅'), style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey800)),
                      pw.Text(ArabicPdfHelper.reshape('الختم المالي الرسمي'), style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.blue900)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'سند_تحصيل_$receiptNumber.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في استخراج السند PDF: ${e.toString()}'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  pw.Widget _pdfRow(String label, String value, pw.Font bold, pw.Font reg) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(ArabicPdfHelper.reshape(label), style: pw.TextStyle(font: reg, fontSize: 10, color: PdfColors.grey800)),
          pw.Text(ArabicPdfHelper.reshape(value), style: pw.TextStyle(font: bold, fontSize: 10.5)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: CustomAppBar(
        title: 'سند تحصيل رسمي معتمد',
        subtitle: 'وثيقة الخزينة العامة للجمعية',
        showBackButton: true,
        onBackPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/payments');
          }
        },
        actions: [
          if (_paymentData != null) ...[
            IconButton(
              icon: const Icon(Icons.print_rounded, color: Colors.white),
              onPressed: _exportPdfReceipt,
              tooltip: 'طباعة / تصدير PDF',
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.white),
              onPressed: _shareReceipt,
              tooltip: 'مشاركة السند',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'جاري استخراج بيانات السند الرسمي...')
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadReceiptData,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('إعادة التحديث'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _buildReceiptVoucher(isDark),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _exportPdfReceipt,
                              icon: const Icon(Icons.print_rounded, size: 18),
                              label: const Text('طباعة / تصدير السند (PDF)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _shareReceipt,
                              icon: const Icon(Icons.share_rounded, size: 18),
                              label: const Text('مشاركة السند الرقمي'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () => context.go('/payments'),
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: const Text('العودة لقائمة السندات المالية'),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildReceiptVoucher(bool isDark) {
    final data = _paymentData!;
    final profile = data['profiles'] as Map<String, dynamic>?;
    final memberName = profile?['full_name'] ?? 'عضو الجمعية';
    final memberNumber = profile?['member_number'] ?? profile?['national_id'] ?? widget.paymentId.substring(0, 6);
    final phone = profile?['phone'] ?? '---';
    final receiptNumber = data['receipt_number'] ?? 'REC-${widget.paymentId.substring(0, 6)}';
    final amount = ((data['amount'] ?? 0.0) as num).toDouble();
    final month = _getMonthName(data['payment_month'] ?? 1);
    final year = data['payment_year'] ?? 2026;
    final methodLabel = _getMethodLabel(data['payment_method'], data['wallet_type']);
    final date = data['payment_date'] != null
        ? DateTime.parse(data['payment_date'].toString())
        : DateTime.now();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          // Header Ribbon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.account_balance_rounded, color: AppColors.gold, size: 24),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'جمعية التكافل والتنمية القروية',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'الجمهورية اليمنية',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gold.withOpacity(0.5)),
                  ),
                  child: Text(
                    'وصل تحصيل اشتراك رسمي: $receiptNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Receipt Body
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildReceiptRow('اسم العضو المسدد:', memberName, isBold: true, isDark: isDark),
                _buildReceiptRow('رقم العضوية:', memberNumber, isDark: isDark),
                _buildReceiptRow('رقم الهاتف:', phone, isDark: isDark),
                const Divider(height: 24),
                _buildReceiptRow('عن اشتراك شهر:', '$month $year', isDark: isDark),
                _buildReceiptRow('طريقة التحصيل:', methodLabel, isDark: isDark),
                if (data['wallet_transaction_id'] != null && data['wallet_transaction_id'].toString().isNotEmpty)
                  _buildReceiptRow('رقم عملية المحفظة:', data['wallet_transaction_id'].toString(), isDark: isDark),
                if (data['notes'] != null && data['notes'].toString().trim().isNotEmpty)
                  _buildReceiptRow('ملاحظات السند:', data['notes'].toString(), isDark: isDark),
                _buildReceiptRow('تاريخ وساعة السداد:', DateFormat('yyyy/MM/dd - HH:mm').format(date), isDark: isDark),
                const Divider(height: 24),

                // Amount Display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : AppColors.accentSubtle,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'المبلغ الإجمالي المسدد:',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${amount.toStringAsFixed(0)} ر.ي',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accentDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Stamp / Verified signature
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('أمين الصندوق والمالية', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        const Text('معتمد بالخزينة العامة ✅', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.gold, width: 2),
                      ),
                      child: const Icon(Icons.verified_rounded, color: AppColors.gold, size: 28),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false, required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}