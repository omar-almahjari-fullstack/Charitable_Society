import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../data/models/notification_model.dart';

// ============================================================
// NOTIFICATION SOUND & IN-APP ALERT SERVICE (الصوت والتنبيه اللحظي)
// ============================================================
class NotificationSoundService {
  static GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();
  static final AudioPlayer _audioPlayer = AudioPlayer();

  /// تشغيل صوت التنبيه اللحظي والاهتزاز
  static Future<void> playNotificationSound() async {
    try {
      // 1. تشغيل رنة إشعار واضحة ومسموعة عبر AudioPlayer
      await _audioPlayer.stop();
      await _audioPlayer.play(
        UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'),
        volume: 1.0,
      );
    } catch (_) {
      try {
        // احتياطي 1: صوت تنبيه بديل
        await _audioPlayer.play(
          UrlSource('https://actions.google.com/sounds/v1/alarms/beep_short.ogg'),
          volume: 1.0,
        );
      } catch (_) {
        // احتياطي 2: صوت النظام القياسي
        try {
          await SystemSound.play(SystemSoundType.alert);
        } catch (_) {}
      }
    }

    // 2. اهتزاز لطيف (Haptic Feedback)
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// إظهار بطاقة إشعار علوية منبثقة تفاعلية عند استقبال إشعار جديد أثناء استخدام التطبيق
  static void showInAppNotificationBanner({
    required AppNotification notification,
    VoidCallback? onTap,
  }) {
    // تشغيل الصوت والاهتزاز أولاً
    playNotificationSound();

    final messenger = messengerKey.currentState;
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(top: 10, left: 16, right: 16, bottom: 20),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 8,
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: notification.color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(notification.icon, color: notification.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: notification.color.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          notification.typeLabel,
                          style: TextStyle(color: notification.color, fontSize: 9.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          notification.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }
}
