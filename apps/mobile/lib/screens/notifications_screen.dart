import 'package:flutter/cupertino.dart';
import '../models/post_model.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/media_image_view.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() async {
    setState(() => isLoading = true);
    final fetched = await ApiService().fetchNotifications();
    if (mounted) {
      setState(() {
        notifications = fetched;
        isLoading = false;
      });
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'LIKE':
        return CupertinoIcons.heart_fill;
      case 'COMMENT':
        return CupertinoIcons.chat_bubble_fill;
      case 'TIME_CAPSULE':
        return CupertinoIcons.lock_shield_fill;
      default:
        return CupertinoIcons.bell_fill;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'LIKE':
        return const Color(0xFFFF2D55);
      case 'COMMENT':
        return const Color(0xFF007AFF);
      case 'TIME_CAPSULE':
        return const Color(0xFFFF9500);
      default:
        return const Color(0xFF5856D6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppTheme.scaffoldBg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppTheme.navBarBg,
        middle: Text(
          tr('ការជូនដំណឹង (Notifications)', 'Notifications'),
          style: TextStyle(color: AppTheme.primaryText, fontWeight: FontWeight.w700),
        ),
      ),
      child: LiquidGlassAmbientBackground(
        child: SafeArea(
          bottom: false,
          child: isLoading
              ? const Center(child: CupertinoActivityIndicator(radius: 16))
              : notifications.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: LiquidGlassContainer(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.bell_slash, size: 36, color: AppTheme.secondaryText),
                              const SizedBox(height: 10),
                              Text(
                                tr('គ្មានការជូនដំណឹងថ្មីឡើយ', 'No new notifications yet'),
                                style: TextStyle(color: AppTheme.secondaryText, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        ResponsiveLayout.horizontalPadding(context),
                        12,
                        ResponsiveLayout.horizontalPadding(context),
                        ResponsiveLayout.bottomDockClearance(context),
                      ),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = notifications[index];
                        final color = _getNotificationColor(item.type);

                        return LiquidGlassPressable(
                          onTap: () {
                            if (!item.isRead) {
                              setState(() {
                                item.isRead = true;
                              });
                              ApiService().markNotificationRead(item.id);
                            }
                          },
                          child: LiquidGlassContainer(
                            borderRadius: 20,
                            blurSigma: 18,
                            elevated: !item.isRead,
                            borderColor: item.isRead
                                ? AppTheme.border
                                : AppTheme.accentBlue.withValues(alpha: 0.45),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(22),
                                      child: MediaImageView(
                                        url: item.actorAvatar,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _getNotificationIcon(item.type),
                                          size: 11,
                                          color: CupertinoColors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppTheme.primaryText,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: item.actorName,
                                              style: const TextStyle(fontWeight: FontWeight.w700),
                                            ),
                                            TextSpan(text: ' ${item.title}'),
                                          ],
                                        ),
                                      ),
                                      if (item.body.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          item.body,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.secondaryText,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        item.timeAgo,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.tertiaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!item.isRead)
                                  Container(
                                    width: 9,
                                    height: 9,
                                    margin: const EdgeInsets.only(top: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentBlue,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
