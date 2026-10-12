import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/empty_state.dart';
import 'wallet_model.dart';
import 'wallets_provider.dart';

class WalletsScreen extends ConsumerStatefulWidget {
  const WalletsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends ConsumerState<WalletsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletsProvider.notifier).loadWallets();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walletsState = ref.watch(walletsProvider);
    final wallets = walletsState.filteredWallets;
    final allWallets = walletsState.wallets;
    final isLoading = walletsState.isLoading;
    final error = walletsState.error;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeCount = allWallets.where((w) => w.isActive).length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: CustomAppBar(
        title: 'إدارة المحافظ والحسابات البنكية',
        subtitle: '$activeCount حساب نشط استقبال الاشتراكات',
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
            onPressed: () => ref.read(walletsProvider.notifier).refreshWallets(),
            tooltip: 'تحديث الحسابات',
          ),
        ],
      ),
      body: Column(
        children: [
          // Executive Treasury Summary Banner
          _buildTreasurySummaryBanner(allWallets.length, activeCount, isDark),

          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                  width: 1,
                ),
              ),
            ),
            child: TextField(
              controller: _searchController,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'ابحث باسم المحفظة، البنك، أو رقم الحساب...',
                prefixIcon: const Icon(Icons.search_rounded, size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(walletsProvider.notifier).searchWallets('');
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                ref.read(walletsProvider.notifier).searchWallets(value);
                setState(() {});
              },
            ),
          ),

          // Wallets Stream
          Expanded(
            child: _buildWalletsList(wallets, isLoading, error, isDark),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/add-wallet'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_card_rounded, size: 20),
        label: const Text('إضافة محفظة / حساب بنكي', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
      ),
    );
  }

  Widget _buildTreasurySummaryBanner(int totalCount, int activeCount, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'قنوات الدفع والتحصيل المعتمدة',
                style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '$totalCount حسابات',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.gold, width: 1),
                    ),
                    child: Text(
                      '$activeCount نشطة',
                      style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Icon(Icons.account_balance_rounded, color: AppColors.gold, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletsList(List<Wallet> wallets, bool isLoading, String? error, bool isDark) {
    if (isLoading && wallets.isEmpty) {
      return const LoadingWidget(message: 'جاري مراجعة قنوات المحافظ والحسابات البنكية...');
    }

    if (error != null && wallets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              const Text('تعذر تحميل بيانات المحافظ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.read(walletsProvider.notifier).refreshWallets(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (wallets.isEmpty) {
      return EmptyState(
        title: 'لا توجد محافظ مسجلة',
        subtitle: _searchController.text.isNotEmpty
            ? 'لم يتم العثور على أي محفظة تطابق البحث'
            : 'أضف قنوات الدفع والحسابات البنكية لاستقبال الاشتراكات والتبرعات.',
        icon: Icons.account_balance_wallet_outlined,
        buttonText: _searchController.text.isNotEmpty ? 'مسح البحث' : 'إضافة محفظة جديدة',
        onButtonPressed: _searchController.text.isNotEmpty
            ? () {
                _searchController.clear();
                ref.read(walletsProvider.notifier).searchWallets('');
                setState(() {});
              }
            : () => context.go('/add-wallet'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(walletsProvider.notifier).refreshWallets(),
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
        itemCount: wallets.length,
        itemBuilder: (context, index) {
          final wallet = wallets[index];
          return _buildInstitutionalWalletCard(wallet, isDark);
        },
      ),
    );
  }

  Widget _buildInstitutionalWalletCard(Wallet wallet, bool isDark) {
    final cardColor = _getWalletThemeColor(wallet.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: wallet.isActive
              ? (isDark ? AppColors.darkBorder : AppColors.border)
              : AppColors.error.withOpacity(0.4),
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          // Card Header Banner (Emulates an Official Banking Card Header)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cardColor.withOpacity(0.9),
                  cardColor.withOpacity(0.75),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getWalletIcon(wallet.type),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wallet.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        wallet.typeLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: wallet.isActive ? Colors.white : Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    wallet.isActive ? 'مفعلة' : 'معطلة',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: wallet.isActive ? cardColor : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Card Body: Account Number / RIB & Copy Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (wallet.accountNumber != null && wallet.accountNumber!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceElevated : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.numbers_rounded, size: 18, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Text(
                          'رقم الحساب / RIB: ',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            wallet.accountNumber!,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: wallet.accountNumber!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تم نسخ رقم الحساب (${wallet.accountNumber})'),
                                backgroundColor: AppColors.success,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          tooltip: 'نسخ رقم الحساب',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'تاريخ التسجيل: ${_formatDate(wallet.createdAt)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                      ),
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            context.go('/add-wallet', extra: wallet);
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(80, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: const Text('تعديل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                          onPressed: () => _showDeleteDialog(wallet),
                          tooltip: 'حذف المحفظة',
                        ),
                      ],
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

  Color _getWalletThemeColor(String type) {
    switch (type) {
      case 'bank':
        return AppColors.primary;
      case 'mobile':
        return AppColors.accent;
      case 'crypto':
        return AppColors.gold;
      case 'exchange':
        return const Color(0xFF1E3A8A);
      default:
        return AppColors.primary;
    }
  }

  IconData _getWalletIcon(String type) {
    switch (type) {
      case 'bank':
        return Icons.account_balance_rounded;
      case 'mobile':
        return Icons.phone_android_rounded;
      case 'crypto':
        return Icons.currency_bitcoin_rounded;
      case 'exchange':
        return Icons.currency_exchange_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  void _showDeleteDialog(Wallet wallet) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المحفظة'),
        content: Text('هل أنت متأكد من رغبتك في حذف محفظة "${wallet.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(walletsProvider.notifier).deleteWallet(wallet.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
  }
}