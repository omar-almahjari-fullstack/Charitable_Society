import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/services/audit_service.dart';
import '../../data/models/audit_log_model.dart';

// ============================================================
// AUDIT LOGS & ACTIVITY TRACKING SCREEN (لوحة التدقيق والرقابة)
// ============================================================

class AuditLogsScreen extends ConsumerStatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  ConsumerState<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends ConsumerState<AuditLogsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<AuditLogItem> _logs = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _pageSize = 30;

  String _selectedModule = 'الكل';
  String _selectedStatus = 'الكل';
  DateTime? _fromDate;
  DateTime? _toDate;

  final List<String> _modules = [
    'الكل',
    'المالية',
    'الأعضاء',
    'المحافظ',
    'المساعدات',
    'الإعلانات',
    'الإعدادات',
    'auth',
  ];

  final List<String> _statuses = ['الكل', 'SUCCESS', 'FAILED'];

  @override
  void initState() {
    super.initState();
    _loadLogs(reset: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoading) {
      _loadMoreLogs();
    }
  }

  Future<void> _loadLogs({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _offset = 0;
        _hasMore = true;
      });
    }

    final result = await AuditService.fetchAuditLogs(
      module: _selectedModule == 'الكل' ? null : _selectedModule,
      status: _selectedStatus == 'الكل' ? null : _selectedStatus,
      searchQuery: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      fromDate: _fromDate,
      toDate: _toDate,
      limit: _pageSize,
      offset: _offset,
    );

    if (mounted) {
      setState(() {
        if (reset) {
          _logs = result;
        } else {
          _logs.addAll(result);
        }
        _isLoading = false;
        _isLoadingMore = false;
        _hasMore = result.length >= _pageSize;
        _offset += result.length;
      });
    }
  }

  Future<void> _loadMoreLogs() async {
    setState(() => _isLoadingMore = true);
    await _loadLogs(reset: false);
  }

  List<AuditLogItem> get _filteredLogs {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _logs;

    return _logs.where((log) {
      final act = log.action.toLowerCase();
      final actAr = log.actionLabelArabic.toLowerCase();
      final user = (log.userName ?? '').toLowerCase();
      final id = log.id.toLowerCase();
      final entity = log.entity.toLowerCase();
      return act.contains(query) ||
          actAr.contains(query) ||
          user.contains(query) ||
          id.contains(query) ||
          entity.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: CustomAppBar(
        title: 'سجل التدقيق والمراقبة الشامل',
        subtitle: 'تتبع العمليات والتعديلات اللحظية (Append-Only)',
        showBackButton: true,
        onBackPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/home');
          }
        },
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => _loadLogs(reset: true),
            tooltip: 'تحديث السجل',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Header Card
          _buildFilterHeader(isDark),

          // Main List or Loading State
          Expanded(
            child: _isLoading
                ? const LoadingWidget(message: 'جاري استخراج وتحليل سجلات التدقيق...')
                : _filteredLogs.isEmpty
                    ? const EmptyState(
                        title: 'لا توجد سجلات تدقيق مطابقة',
                        subtitle: 'لم يتم العثور على أي نشاط مطابق للفلاتر المحددة حالياً.',
                        icon: Icons.history_edu_rounded,
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadLogs(reset: true),
                        color: AppColors.primary,
                        child: ListView.separated(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _filteredLogs.length + (_isLoadingMore ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (index == _filteredLogs.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            }
                            final log = _filteredLogs[index];
                            return _buildAuditCard(log, isDark);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Search Box
          TextField(
            controller: _searchController,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              hintText: 'ابحث باسم العملية، المشرف، أو المعرف...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: (val) => setState(() {}),
          ),
          const SizedBox(height: 10),

          // Horizontal Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Module Chips
                ..._modules.map((m) {
                  final isSelected = _selectedModule == m;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: FilterChip(
                      label: Text(m),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedModule = m);
                        _loadLogs(reset: true);
                      },
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      ),
                    ),
                  );
                }),

                const SizedBox(width: 8),

                // Status Chip (Success / Failed)
                ..._statuses.map((s) {
                  final isSelected = _selectedStatus == s;
                  final isFailed = s == 'FAILED';
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: FilterChip(
                      label: Text(s == 'SUCCESS' ? 'ناجحة ✅' : s == 'FAILED' ? 'فاشلة ❌' : 'الكل'),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedStatus = s);
                        _loadLogs(reset: true);
                      },
                      selectedColor: isFailed
                          ? AppColors.error.withValues(alpha: 0.15)
                          : AppColors.success.withValues(alpha: 0.15),
                      checkmarkColor: isFailed ? AppColors.error : AppColors.success,
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? (isFailed ? AppColors.error : AppColors.success)
                            : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditCard(AuditLogItem log, bool isDark) {
    final hasDiff = log.oldValues != null || log.newValues != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: log.isSuccess
              ? (isDark ? AppColors.darkBorder : AppColors.border)
              : AppColors.error.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showAuditDetailsModal(context, log, isDark),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Action & Status Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: log.isSuccess
                            ? AppColors.success.withValues(alpha: 0.12)
                            : AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            log.isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            size: 14,
                            color: log.isSuccess ? AppColors.success : AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            log.status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: log.isSuccess ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Module Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceElevated : AppColors.primarySubtle,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        log.moduleLabelArabic,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.accentLight : AppColors.primary,
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Timestamp
                    Text(
                      log.formattedDateTime,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Action Label
                Text(
                  log.actionLabelArabic,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 6),

                // Operator info & Details
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 15,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'المنفّذ: ${log.userName ?? "عضو / نظام"} (${log.userType})',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                    if (log.entityId != null) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.fingerprint_rounded,
                        size: 15,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '#${log.entityId!.length > 8 ? log.entityId!.substring(0, 8) : log.entityId}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),

                // Diff indicator if values changed
                if (hasDiff) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.compare_arrows_rounded, size: 14, color: Colors.amber),
                            SizedBox(width: 4),
                            Text(
                              'انقر لمعاينة الفروقات (Old vs New Diff)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// نافذة معاينة تفاصيل السجل والفروقات (Visual Diff Viewer Modal)
  void _showAuditDetailsModal(BuildContext context, AuditLogItem log, bool isDark) {
    final diffs = log.diffValues;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          children: [
            // Top Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Modal Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    log.isSuccess ? Icons.verified_user_rounded : Icons.error_outline_rounded,
                    color: log.isSuccess ? AppColors.success : AppColors.error,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.actionLabelArabic,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          log.formattedDateTime,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Modal Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Metadata Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                      ),
                      child: Column(
                        children: [
                          _buildMetaRow('معرف السجل', log.id, isDark, copyable: true),
                          _buildMetaRow('المنفّذ', '${log.userName ?? "غير محدد"} (${log.userType})', isDark),
                          if (log.entityId != null)
                            _buildMetaRow('المعرف المستهدف', log.entityId!, isDark, copyable: true),
                          _buildMetaRow('القسم المستهدف', log.moduleLabelArabic, isDark),
                          _buildMetaRow('الحالة', log.status, isDark, isStatus: true, isSuccess: log.isSuccess),
                          if (log.userAgent != null)
                            _buildMetaRow('بيئة التشغيل', log.userAgent!, isDark),
                          if (log.errorMessage != null && log.errorMessage!.isNotEmpty)
                            _buildMetaRow('تفاصيل / ملاحظات', log.errorMessage!, isDark),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Visual Diff Section
                    const Text(
                      'معاينة التغييرات والفروقات (Visual Diff Engine)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    if (diffs.isNotEmpty) ...[
                      ...diffs.entries.map((entry) {
                        final field = entry.key;
                        final oldVal = entry.value['old'];
                        final newVal = entry.value['new'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الحقل: $field',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  // Old Value
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('القيمة السابقة:', style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 2),
                                          Text(
                                            oldVal?.toString() ?? 'فارغ (null)',
                                            style: const TextStyle(fontSize: 12, decoration: TextDecoration.lineThrough),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // New Value
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('القيمة الجديدة:', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 2),
                                          Text(
                                            newVal?.toString() ?? 'فارغ (null)',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ] else if (log.newValues != null) ...[
                      // Create action payload
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('بيانات الإنشاء الجديدة (Created Values):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.success)),
                            const SizedBox(height: 6),
                            Text(
                              log.newValues.toString(),
                              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'لا توجد فروقات مسجلة لهذا الحدث.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, bool isDark, {bool copyable = false, bool isStatus = false, bool isSuccess = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isStatus ? FontWeight.bold : FontWeight.w500,
                      color: isStatus
                          ? (isSuccess ? AppColors.success : AppColors.error)
                          : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                    ),
                  ),
                ),
                if (copyable)
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ المعرف إلى الحافظة'), duration: Duration(seconds: 1)),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
