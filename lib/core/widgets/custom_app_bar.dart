import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool centerTitle;
  final Widget? titleWidget;
  final PreferredSizeWidget? bottom;
  final String? subtitle;

  const CustomAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.leading,
    this.showBackButton = false,
    this.onBackPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.centerTitle = true,
    this.titleWidget,
    this.bottom,
    this.subtitle,
  }) : super(key: key);

  void _handleBack(BuildContext context) {
    if (onBackPressed != null) {
      onBackPressed!();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ?? (isDark ? AppColors.darkSurface : AppColors.primary);
    final fg = foregroundColor ?? AppColors.textWhite;

    return AppBar(
      title: titleWidget ??
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  letterSpacing: 0.2,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: fg.withOpacity(0.8),
                    ),
                  ),
                ),
            ],
          ),
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: elevation ?? 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      leading: leading ??
          (showBackButton
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Material(
                    color: Colors.white.withOpacity(0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _handleBack(context),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: fg,
                        size: 18,
                      ),
                    ),
                  ),
                )
              : null),
      actions: actions != null
          ? [
              ...actions!,
              const SizedBox(width: 6),
            ]
          : null,
      bottom: bottom,
      automaticallyImplyLeading: showBackButton,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0) + (subtitle != null ? 14.0 : 0.0));
}