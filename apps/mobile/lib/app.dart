import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/auth_screen.dart';
import 'screens/home_feed_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/reels_screen.dart';
import 'widgets/create_post_sheet.dart';
import 'services/api_service.dart';
import 'services/language_service.dart';
import 'models/user_model.dart';
import 'widgets/liquid_glass.dart';

class SpacesApp extends StatelessWidget {
  const SpacesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ApiService().isDarkModeNotifier,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<String>(
          valueListenable: LanguageService().languageNotifier,
          builder: (context, lang, _) {
            return CupertinoApp(
              title: 'Spaces Social Media Cambodia',
              debugShowCheckedModeBanner: false,
              theme: CupertinoThemeData(
                brightness: isDark ? Brightness.dark : Brightness.light,
                primaryColor: const Color(0xFF007AFF),
                scaffoldBackgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
                barBackgroundColor: isDark ? const Color(0xEE12141C) : const Color(0xF0FFFFFF),
                textTheme: CupertinoTextThemeData(
                  primaryColor: isDark ? CupertinoColors.white : CupertinoColors.black,
                  navLargeTitleTextStyle: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: isDark ? CupertinoColors.white : CupertinoColors.black,
                    letterSpacing: -0.7,
                  ),
                ),
              ),
              localizationsDelegates: const [
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('km', 'KH'),
                Locale('en', 'US'),
              ],
              home: const MobileAppFrameWrapper(),
            );
          },
        );
      },
    );
  }
}

/// Enforces the Mobile-App-First experience.
/// On desktop web browsers, it renders a sleek iPhone frame.
/// On mobile devices, it renders natively full-screen.
class MobileAppFrameWrapper extends StatelessWidget {
  const MobileAppFrameWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiService();

    return ValueListenableBuilder<UserModel?>(
      valueListenable: api.authNotifier,
      builder: (context, currentUser, _) {
        final activeScreen = currentUser == null ? const AuthScreen() : const MainTabScreen();

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 500) {
              // Desktop Viewport: Centered in sleek iPhone Frame
              return Container(
                color: const Color(0xFF0A0F1D), // Elegant dark slate background
                child: Center(
                  child: Container(
                    width: 416,
                    height: constraints.maxHeight > 880 ? 850 : constraints.maxHeight - 28,
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(46),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.65),
                          blurRadius: 50,
                          spreadRadius: 8,
                          offset: const Offset(0, 20),
                        ),
                        BoxShadow(
                          color: const Color(0xFF007AFF).withOpacity(0.2),
                          blurRadius: 70,
                          spreadRadius: 10,
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFF242938),
                        width: 7,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(39),
                      child: Stack(
                        children: [
                          Positioned.fill(child: activeScreen),
                          // Sleek Dynamic Island Header Notch
                          Positioned(
                            top: 8,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                width: 112,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            // Mobile Device Viewport: Full screen native app
            return activeScreen;
          },
        );
      },
    );
  }
}

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;
  final List<GlobalKey<NavigatorState>> _navKeys = List.generate(
    4,
    (_) => GlobalKey<NavigatorState>(),
  );

  void _openCreateModal() async {
    final spaces = await ApiService().fetchSpaces();
    if (mounted) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CreatePostSheet(
          spaces: spaces,
          onPostCreated: (_) {
            setState(() {
              _currentIndex = 0;
            });
          },
        ),
      );
    }
  }

  int _toPageIndex(int dockIndex) {
    if (dockIndex == 0) return 0;
    if (dockIndex == 1) return 1;
    if (dockIndex == 3) return 2;
    if (dockIndex == 4) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final pageIndex = _toPageIndex(_currentIndex);
    final dockItems = [
      LiquidGlassDockItem(
        icon: CupertinoIcons.house_alt,
        activeIcon: CupertinoIcons.house_alt_fill,
        label: tr('ទំព័រដើម', 'Home'),
      ),
      LiquidGlassDockItem(
        icon: CupertinoIcons.play_circle,
        activeIcon: CupertinoIcons.play_circle_fill,
        label: 'Reels',
      ),
      LiquidGlassDockItem(
        icon: CupertinoIcons.add,
        activeIcon: CupertinoIcons.add,
        label: tr('បង្កើត', 'Create'),
        isCreateButton: true,
      ),
      LiquidGlassDockItem(
        icon: CupertinoIcons.chat_bubble_2,
        activeIcon: CupertinoIcons.chat_bubble_2_fill,
        label: tr('ការជជែក', 'Chats'),
      ),
      LiquidGlassDockItem(
        icon: CupertinoIcons.person_crop_circle,
        activeIcon: CupertinoIcons.person_crop_circle_fill,
        label: tr('គណនី', 'Profile'),
      ),
    ];

    return LiquidGlassAmbientBackground(
      child: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: pageIndex,
              children: [
                CupertinoTabView(
                  navigatorKey: _navKeys[0],
                  builder: (_) => HomeFeedScreen(
                    onNotificationTap: () {
                      Navigator.of(context, rootNavigator: true).push(
                        CupertinoPageRoute(builder: (_) => const NotificationsScreen()),
                      );
                    },
                  ),
                ),
                CupertinoTabView(
                  navigatorKey: _navKeys[1],
                  builder: (_) => const ReelsScreen(),
                ),
                CupertinoTabView(
                  navigatorKey: _navKeys[2],
                  builder: (_) => const ChatScreen(),
                ),
                CupertinoTabView(
                  navigatorKey: _navKeys[3],
                  builder: (_) => const ProfileScreen(),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LiquidGlassDockBar(
              currentIndex: _currentIndex,
              items: dockItems,
              onTap: (index) {
                if (index == 2) {
                  _openCreateModal();
                  return;
                }
                if (index == _currentIndex) {
                  final activeNav = _navKeys[_toPageIndex(index)].currentState;
                  activeNav?.popUntil((route) => route.isFirst);
                } else {
                  setState(() {
                    _currentIndex = index;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
