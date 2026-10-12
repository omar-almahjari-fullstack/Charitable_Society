import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/services/supabase_service.dart';
import '../../core/storage/local_cache_service.dart';
import '../auth/auth_provider.dart';

class AssistanceScreen extends ConsumerStatefulWidget {
  const AssistanceScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AssistanceScreen> createState() => _AssistanceScreenState();
}

class _AssistanceScreenState extends ConsumerState<AssistanceScreen> {
  String _selectedFilter = 'الكل';
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];
  String _searchQuery = '';

  final List<String> _filters = ['الكل', 'معلقة', 'مقبولة', 'مرفوضة', 'مكتملة'];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authProvider);
      final role = authState.userRole;
      final userId = SupabaseService.currentUser?.id;

      var builder = SupabaseService.client
          .from('assistance_requests')
          .select('*, profiles!member_id(full_name, phone)');

      final response = (role == 'member' && userId != null)
          ? await builder.eq('member_id', userId).order('created_at', ascending: false)
          : await builder.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });

        // حفظ طلبات المساعدة محلياً للاستعراض دون اتصال
        try {
          await LocalCacheService.save('cached_assistance_requests_${userId ?? "all"}', response);
        } catch (_) {}
      }
    } catch (e) {
      // استرجاع الطلبات من الكاش المحلي عند انقطاع الاتصال
      try {
        final userId = SupabaseService.currentUser?.id;
        final cached = await LocalCacheService.get('cached_assistance_requests_${userId ?? "all"}');
        if (cached is List && cached.isNotEmpty && mounted) {
          setState(() {
            _requests = List<Map<String, dynamic>>.from(cached);
            _isLoading = false;
          });
          return;
        }
      } catch (_) {}

      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredRequests {
    return _requests.where((req) {
      final status = req['status']?.toString() ?? 'pending';
      final label = _getStatusLabel(status);
      final title = (req['title']?.toString() ?? '').toLowerCase();
      final name = (req['profiles']?['full_name']?.toString() ?? '').toLowerCase();

      final matchesFilter = _selectedFilter == 'الكل' || label == _selectedFilter;
      final matchesSearch = _searchQuery.isEmpty ||
          title.contains(_searchQuery.toLowerCase()) ||
          name.contains(_searchQuery.toLowerCase());

      return matchesFilter && matchesSearch;
    }).toList();
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'مقبولة';
      case 'rejected':
        return 'مرفوضة';
      case 'completed':
        return 'مكتملة';
      case 'pending':
      default:
        return 'معلقة';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'completed':
        return AppColors.accent;
      case 'pending':
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final list = _filteredRequests;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: CustomAppBar(
        title: 'طلبات المساعدات والإعانات',
        subtitle: '${_requests.length} طلب مسجل',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadRequests,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filters Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                TextField(
                  textDirection:  Directionality.of(context),
                  decoration: const InputDecoration(
                    hintText: 'ابحث بعنوان الطلب أو اسم صاحب الطلب...',
                    prefixIcon: Icon(Icons.search_rounded, size: 22),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isSelected = _selectedFilter == filter;
                      return ChoiceChip(
                        label: Text(
                          filter,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.background,
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? AppColors.darkBorder : AppColors.border),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedFilter = filter);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const LoadingWidget(message: 'جاري تحميل الطلبات...')
                : list.isEmpty
                    ? EmptyState(
                        title: 'لا توجد طلبات مساعدة',
                        subtitle: _searchQuery.isNotEmpty
                            ? 'لم يتم العثور على أي طلب يطابق البحث'
                            : 'لم يتم تسجيل أي طلب مساعدة في هذه القائمة بعد.',
                        icon: Icons.volunteer_activism_outlined,
                        buttonText: 'تقديم طلب مساعدة',
                        onButtonPressed: () => context.go('/add-assistance'),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadRequests,
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final req = list[index];
                            return _buildRequestCard(req, isDark);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/add-assistance'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('تقديم طلب جديد', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req, bool isDark) {
    final id = req['id']?.toString() ?? '';
    final title = req['title']?.toString() ?? 'طلب مساعدة اجتماعية';
    final desc = req['description']?.toString() ?? '';
    final memberName = req['profiles']?['full_name']?.toString() ?? 'صاحب الطلب';
    final requestedAmount = ((req['requested_amount'] ?? 0) as num).toDouble();
    final status = req['status']?.toString() ?? 'pending';
    final statusLabel = _getStatusLabel(status);
    final statusColor = _getStatusColor(status);
    final date = req['created_at'] != null
        ? DateTime.parse(req['created_at'].toString())
        : DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: InkWell(
        onTap: () => context.go('/assistance-details/$id'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 14, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    memberName,
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                  ),
                ],
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('yyyy/MM/dd').format(date),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                    ),
                  ),
                  Text(
                    '${requestedAmount.toStringAsFixed(0)} د.ج',
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}