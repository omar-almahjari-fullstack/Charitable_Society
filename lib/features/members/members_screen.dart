import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/empty_state.dart';
import 'members_provider.dart';

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'الكل';

  final List<String> _filters = ['الكل', 'نشط', 'موقوف', 'معفي', 'غير نشط'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(membersProvider.notifier).loadMembers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersState = ref.watch(membersProvider);
    final members = membersState.filteredMembers;
    final isLoading = membersState.isLoading;
    final error = membersState.error;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: CustomAppBar(
        title: 'سجل وإدارة الأعضاء',
        subtitle: '${membersState.members.length} عضو مسجل',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => ref.read(membersProvider.notifier).refreshMembers(),
            tooltip: 'تحديث السجل',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
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
                // Search Bar
                TextField(
                  controller: _searchController,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم، رقم الهاتف، أو رقم العضوية...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 22),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(membersProvider.notifier).searchMembers('');
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    ref.read(membersProvider.notifier).searchMembers(value);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 12),

                // Filters Scrollable Row
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
                            ref.read(membersProvider.notifier).setFilter(filter);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // List / States
          Expanded(
            child: _buildMembersList(members, isLoading, error, isDark),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/member-details/new'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded, size: 20),
        label: const Text('إضافة عضو', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildMembersList(
    List<Member> members,
    bool isLoading,
    String? error,
    bool isDark,
  ) {
    if (isLoading && members.isEmpty) {
      return const LoadingWidget(message: 'جاري تحميل قائمة الأعضاء...');
    }

    if (error != null && members.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: AppColors.error),
              const SizedBox(height: 14),
              const Text('تعذر تحميل بيانات الأعضاء', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(error, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.read(membersProvider.notifier).refreshMembers(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (members.isEmpty) {
      return EmptyState(
        title: 'لا يوجد أعضاء مطابقين',
        subtitle: _searchController.text.isNotEmpty
            ? 'لم نجد أي عضو يطابق عبارة البحث المدخلة'
            : 'لم يتم تسجيل أي أعضاء في هذه الفئة بعد.',
        icon: Icons.group_off_rounded,
        buttonText: _searchController.text.isNotEmpty ? 'مسح البحث' : 'إضافة عضو جديد',
        onButtonPressed: _searchController.text.isNotEmpty
            ? () {
                _searchController.clear();
                ref.read(membersProvider.notifier).searchMembers('');
                setState(() {});
              }
            : () => context.go('/member-details/new'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(membersProvider.notifier).refreshMembers(),
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: members.length,
        itemBuilder: (context, index) {
          final member = members[index];
          return _buildMemberCard(member, isDark);
        },
      ),
    );
  }

  Widget _buildMemberCard(Member member, bool isDark) {
    ImageProvider? imageProvider;
    if (member.avatarUrl != null && member.avatarUrl!.startsWith('data:')) {
      try {
        final base64String = member.avatarUrl!.split(',').last;
        final bytes = base64Decode(base64String);
        imageProvider = MemoryImage(bytes);
      } catch (_) {}
    } else if (member.avatarUrl != null && member.avatarUrl!.startsWith('http')) {
      imageProvider = NetworkImage(member.avatarUrl!);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: InkWell(
        onTap: () => context.go('/member-details/${member.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.darkSurfaceElevated : AppColors.primarySubtle,
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                    width: 1.5,
                  ),
                  image: imageProvider != null
                      ? DecorationImage(
                          image: imageProvider,
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: imageProvider == null
                    ? Icon(
                        Icons.person_rounded,
                        color: isDark ? AppColors.accentLight : AppColors.primary,
                        size: 28,
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            member.fullName,
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: member.statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: member.statusColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            member.statusLabel,
                            style: TextStyle(
                              color: member.statusColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_rounded,
                          size: 13,
                          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          member.phone,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.credit_card_rounded,
                          size: 13,
                          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${member.monthlySubscription.toStringAsFixed(0)} ر.ي/شهر',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.accentLight : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    if (member.role != 'member') ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getRoleLabel(member.role),
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow indicator pointing left in RTL
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 14,
                color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'مدير';
      case 'super_admin':
        return 'مدير عام';
      case 'treasurer':
        return 'أمين صندوق';
      case 'member':
      default:
        return 'عضو';
    }
  }
}