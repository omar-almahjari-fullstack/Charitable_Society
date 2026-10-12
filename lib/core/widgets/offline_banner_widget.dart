import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/network_connectivity_service.dart';

// ============================================================
// REDESIGNED MODERN OFFLINE & RESTORED STATUS BANNER
// شريط حالة الاتصال العصري الأنيق مع تأثيرات انسيابية
// ============================================================

class OfflineBannerWidget extends ConsumerStatefulWidget {
  final Widget? child;
  const OfflineBannerWidget({super.key, this.child});

  @override
  ConsumerState<OfflineBannerWidget> createState() => _OfflineBannerWidgetState();
}

class _OfflineBannerWidgetState extends ConsumerState<OfflineBannerWidget> with SingleTickerProviderStateMixin {
  bool _wasOffline = false;
  bool _showRestoredBanner = false;
  bool _isDismissedByUser = false;
  Timer? _restoredTimer;

  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _restoredTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _updateBannerVisibility(bool isOnline) {
    if (!isOnline) {
      _wasOffline = true;
      _showRestoredBanner = false;
      _isDismissedByUser = false;
      _animController.forward();
    } else if (_wasOffline && isOnline) {
      _wasOffline = false;
      _showRestoredBanner = true;
      _isDismissedByUser = false;
      _animController.forward();

      _restoredTimer?.cancel();
      _restoredTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          _animController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _showRestoredBanner = false;
              });
            }
          });
        }
      });
    } else if (!_showRestoredBanner) {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _updateBannerVisibility(isOnline);

    final isOfflineActive = !isOnline && !_isDismissedByUser;
    final isRestoredActive = _showRestoredBanner && isOnline;

    return Stack(
      children: [
        // Main App Content
        if (widget.child != null) widget.child!,

        // Floating Modern Status Banner
        if (isOfflineActive || isRestoredActive)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Material(
                      color: Colors.transparent,
                      elevation: 8,
                      shadowColor: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: isRestoredActive
                              ? (isDark ? const Color(0xFF065F46) : const Color(0xFF10B981))
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFF334155)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isRestoredActive
                                ? const Color(0xFF34D399).withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.15),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isRestoredActive ? const Color(0xFF10B981) : Colors.black)
                                  .withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Animated Dot Indicator
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isRestoredActive ? Colors.white : const Color(0xFFF59E0B),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isRestoredActive ? Colors.white : const Color(0xFFF59E0B))
                                        .withValues(alpha: 0.6),
                                    blurRadius: 6,
                                    spreadRadius: 1.5,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Icon
                            Icon(
                              isRestoredActive ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 10),

                            // Text Label
                            Expanded(
                              child: Text(
                                isRestoredActive
                                    ? 'تم استعادة الاتصال • البيانات محدثة ومزامنة'
                                    : 'وضع عدم الاتصال • يتم عرض البيانات المحفوظة محلياً',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),

                            // Dismiss (X) toggle
                            if (isOfflineActive)
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  setState(() {
                                    _isDismissedByUser = true;
                                  });
                                  _animController.reverse();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    size: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
