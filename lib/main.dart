import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

// Separate modules import
import 'app_core.dart';
import 'app_theme_manager.dart';
import 'map_spots_page.dart';
import 'nature_hub_page.dart';
import 'community_echo_page.dart';
import 'live_profile_page.dart';

// ============================================================================
// BALANCED VIBRANT GREEN ACCENTS FOR DARK THEME (REFINED & COMFORTABLE)
// ============================================================================
class ShineGreen {
  static const Color primary = Color(0xFF00B862); // Smooth, vivid emerald green
  static const Color accent = Color(0xFF20D573);  // Balanced green (removed harsh neon glare)
  static const Color deep = Color(0xFF077E40);    // Deep lush forest green

  static const LinearGradient gradient = LinearGradient(
    colors: [Color(0xFF077E40), Color(0xFF20D573)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ring = LinearGradient(
    colors: [Color(0xFF20D573), Color(0xFF00B862), Color(0xFF4ADE80)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBqHQxKs_sgP5dvRGk8rIXb9OgqnIgwbfM",
        appId: "1:178066771434:android:76cbcc13aab7a996703693",
        messagingSenderId: "178066771434",
        projectId: "nature-travels",
        storageBucket: "nature-travels.appspot.com",
      ),
    );
  } catch (e) {
    debugPrint("Firebase init: $e");
  }

  runApp(const NatureTravelsApp());
}

// ============================================================================
// MAIN APP ROOT (APP-WIDE REACTIVE THEME & REALTIME HUB)
// ============================================================================
class NatureTravelsApp extends StatelessWidget {
  const NatureTravelsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppThemeManager.instance,
      builder: (context, _) {
        final isDark = AppThemeManager.instance.isDarkMode;

        // Dynamic System Status Bar Styling
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: isDark ? Colors.black : Colors.white,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
        );

        return MaterialApp(
          title: 'Nature Travels',
          debugShowCheckedModeBanner: false,
          themeMode: AppThemeManager.instance.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: AppColors.canvasBg,
            fontFamily: 'sans-serif',
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.forest,
              primary: AppColors.forest,
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Colors.black, // Pure Black
            canvasColor: Colors.black,
            fontFamily: 'sans-serif',
            colorScheme: ColorScheme.fromSeed(
              seedColor: ShineGreen.primary,
              primary: ShineGreen.accent,
              surface: const Color(0xFF16181B), // Clean Dark Charcoal Grey
              brightness: Brightness.dark,
            ),
          ),
          home: const MainNavigationShell(),
        );
      },
    );
  }
}

// ============================================================================
// LIQUID JELLY SLIDING NAVIGATION BAR
// ============================================================================
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    FeedController.I.refresh();
    FeedController.I.startPolling();
  }

  @override
  void dispose() {
    FeedController.I.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screens = [
      const HomeFeedPage(),
      const MapSpotsPage(),
      const NatureHubPage(),
      const CommunityEchoPage(),
      const LiveProfilePage(),
    ];

    return Scaffold(
      backgroundColor: isDark ? Colors.black : AppColors.canvasBg,
      extendBody: true,
      body: screens[_currentIndex],
      bottomNavigationBar: SafeArea(
        child: LiquidJellyNavBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            HapticFeedback.lightImpact();
            setState(() => _currentIndex = index);
          },
        ),
      ),
    );
  }
}

class LiquidJellyNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const LiquidJellyNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<LiquidJellyNavBar> createState() => _LiquidJellyNavBarState();
}

class _LiquidJellyNavBarState extends State<LiquidJellyNavBar> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _prevIndex = 0;

  final List<Map<String, dynamic>> _tabs = const [
    {"icon": Icons.home_rounded, "label": "Feed"},
    {"icon": Icons.explore_rounded, "label": "Map"},
    {"icon": Icons.park_rounded, "label": "Nature"},
    {"icon": Icons.forum_rounded, "label": "Community"},
    {"icon": Icons.person_rounded, "label": "Profile"},
  ];

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.currentIndex;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..value = 1.0;
  }

  @override
  void didUpdateWidget(covariant LiquidJellyNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _prevIndex = oldWidget.currentIndex;
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Map<String, double> _getTabBounds(int targetIndex, double totalW, double activeW, double inactiveW) {
    double left = 0;
    for (int i = 0; i < targetIndex; i++) {
      left += (i == targetIndex) ? activeW : inactiveW;
    }
    return {'left': left, 'right': left + activeW};
  }

  @override
  Widget build(BuildContext context) {
    const double barHeight = 64.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final barBg = isDark ? const Color(0xFF141618) : Colors.white;
    final barBorder = isDark ? const Color(0xFF26292C) : AppColors.forest.withOpacity(0.12);
    final unselectedIconColor = isDark ? Colors.white60 : Colors.black45;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      height: barHeight,
      decoration: BoxDecoration(
        color: barBg,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.6) : AppColors.forest.withOpacity(0.14),
            blurRadius: 26,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: barBorder, width: 1.2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalW = constraints.maxWidth;
          final activeW = math.min(115.0, totalW * 0.32);
          final inactiveW = (totalW - activeW) / 4.0;

          return AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              final t = _animController.value;
              final isForward = widget.currentIndex >= _prevIndex;

              final leadCurve = const Interval(0.0, 0.75, curve: Curves.easeOutCubic).transform(t);
              final trailCurve = const Interval(0.20, 1.0, curve: Curves.easeOutCubic).transform(t);

              final fromBounds = _getTabBounds(_prevIndex, totalW, activeW, inactiveW);
              final toBounds = _getTabBounds(widget.currentIndex, totalW, activeW, inactiveW);

              double bubbleLeft, bubbleRight;

              if (isForward) {
                bubbleRight = lerpDouble(fromBounds['right']!, toBounds['right']!, leadCurve)!;
                bubbleLeft = lerpDouble(fromBounds['left']!, toBounds['left']!, trailCurve)!;
              } else {
                bubbleLeft = lerpDouble(fromBounds['left']!, toBounds['left']!, leadCurve)!;
                bubbleRight = lerpDouble(fromBounds['right']!, toBounds['right']!, trailCurve)!;
              }

              final squish = math.sin(t * math.pi) * 3.0;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: bubbleLeft + 3,
                    width: math.max(activeW - 6, bubbleRight - bubbleLeft - 6),
                    top: 3 + squish,
                    bottom: 3 + squish,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: isDark ? ShineGreen.gradient : AppColors.greenGradient,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? ShineGreen.primary.withOpacity(0.35) : AppColors.forest.withOpacity(0.38),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      children: List.generate(_tabs.length, (index) {
                        final isSelected = widget.currentIndex == index;
                        final currentTabWidth = isSelected ? activeW : inactiveW;

                        return GestureDetector(
                          onTap: () => widget.onTap(index),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 380),
                            curve: Curves.easeOutCubic,
                            width: currentTabWidth,
                            height: double.infinity,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedScale(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOutBack,
                                  scale: isSelected ? 1.18 : 0.98,
                                  child: Icon(
                                    _tabs[index]["icon"] as IconData,
                                    size: 24,
                                    color: isSelected ? Colors.white : unselectedIconColor,
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: AnimatedOpacity(
                                      duration: const Duration(milliseconds: 240),
                                      opacity: _animController.value > 0.55 ? 1.0 : 0.0,
                                      child: Text(
                                        _tabs[index]["label"] as String,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12.5,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// TAB 1: HOME FEED SCREEN
// ============================================================================
class HomeFeedPage extends StatefulWidget {
  const HomeFeedPage({super.key});

  @override
  State<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<HomeFeedPage> {
  int _selectedCategoryIndex = 0;

  final List<Map<String, dynamic>> _categories = const [
    {"name": "All Expeditions", "icon": Icons.terrain_rounded, "filter": ""},
    {"name": "Rainforests 🌿", "icon": Icons.forest_rounded, "filter": "rainforest"},
    {"name": "Cascades 💦", "icon": Icons.water_drop_rounded, "filter": "fall"},
    {"name": "High Peaks ⛺", "icon": Icons.night_shelter_rounded, "filter": "peak"},
    {"name": "Ancient Caves 🦇", "icon": Icons.landscape_rounded, "filter": "cave"},
    {"name": "Biospheres 🌊", "icon": Icons.waves_rounded, "filter": "coast"},
  ];

  @override
  Widget build(BuildContext context) {
    final c = FeedController.I;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF16181B) : AppColors.cardSurface;
    final cardBorder = isDark ? const Color(0xFF26292C) : AppColors.cardStroke;
    final subtlePlate = isDark ? const Color(0xFF222528) : AppColors.tint;
    final textMainColor = isDark ? Colors.white : AppColors.textMain;
    final textMutedColor = isDark ? const Color(0xFFA1B0A7) : AppColors.textMuted;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : AppColors.canvasBg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: isDark ? ShineGreen.accent : AppColors.forest,
          onRefresh: () => c.refresh(),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. BRAND & ATMOSPHERE HUD
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                height: 44,
                                width: 44,
                                decoration: BoxDecoration(
                                  gradient: isDark ? ShineGreen.gradient : AppColors.greenGradient,
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark ? ShineGreen.primary.withOpacity(0.3) : AppColors.forest.withOpacity(0.28),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.explore_rounded, color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        "NATURE",
                                        style: TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                          color: isDark ? ShineGreen.accent : AppColors.forest,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      ShaderMask(
                                        shaderCallback: (bounds) => (isDark ? ShineGreen.gradient : AppColors.greenGradient).createShader(bounds),
                                        child: const Text(
                                          "TRAVELS",
                                          style: TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.0,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: isDark ? ShineGreen.accent : AppColors.emerald,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        "WILD SRI LANKA • REALTIME HUD",
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.4,
                                          color: textMutedColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          ListenableBuilder(
                            listenable: AuthController.I,
                            builder: (context, _) {
                              final user = AuthController.I.currentUser;
                              if (AuthController.I.isLoggedIn && user != null) {
                                return GestureDetector(
                                  onTap: () => AuthController.I.signOut(),
                                  child: Container(
                                    padding: const EdgeInsets.all(2.6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: isDark ? ShineGreen.gradient : AppColors.greenGradient,
                                      boxShadow: [
                                        BoxShadow(
                                          color: isDark ? ShineGreen.primary.withOpacity(0.28) : AppColors.forest.withOpacity(0.2),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        )
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: isDark ? const Color(0xFF16181B) : Colors.white,
                                      backgroundImage: safeNetworkImage(user.photoUrl),
                                    ),
                                  ),
                                );
                              }
                              return GestureDetector(
                                onTap: () => AuthController.I.signInWithGoogle(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8.5),
                                  decoration: BoxDecoration(
                                    gradient: isDark ? ShineGreen.gradient : AppColors.greenGradient,
                                    borderRadius: BorderRadius.circular(22),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDark ? ShineGreen.primary.withOpacity(0.3) : AppColors.forest.withOpacity(0.25),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.login_rounded, size: 14, color: Colors.white),
                                      SizedBox(width: 6),
                                      Text(
                                        "Sign In",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 2. STORIES TRAY
              const SliverToBoxAdapter(child: StoriesTray()),

              // 3. ACTION TRAY (UPLOAD BAR)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: GestureDetector(
                    onTap: () {
                      if (!AuthController.I.isLoggedIn) {
                        showLoginAlert(context);
                        return;
                      }
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const LiquidCreatorStudio(),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: cardBorder, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black.withOpacity(0.5) : AppColors.forest.withOpacity(0.07),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: subtlePlate,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.add_photo_alternate_rounded, color: isDark ? ShineGreen.accent : AppColors.forest, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Log a wilderness spot or waterfall...",
                              style: TextStyle(color: textMutedColor, fontSize: 13.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: isDark ? ShineGreen.gradient : AppColors.greenGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text("Share", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 4. CATEGORY FILTER SLIDER
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 16),
                  child: SizedBox(
                    height: 48,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final item = _categories[index];
                        final isSelected = _selectedCategoryIndex == index;

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedCategoryIndex = index);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: isSelected ? (isDark ? ShineGreen.gradient : AppColors.greenGradient) : null,
                              color: isSelected ? null : cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? Colors.transparent : cardBorder,
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? (isDark ? ShineGreen.primary.withOpacity(0.3) : AppColors.forest.withOpacity(0.3))
                                      : (isDark ? Colors.transparent : AppColors.forest.withOpacity(0.04)),
                                  blurRadius: isSelected ? 12 : 6,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item["icon"] as IconData,
                                  size: 16,
                                  color: isSelected ? Colors.white : (isDark ? ShineGreen.accent : AppColors.forest),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  item["name"] as String,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected ? Colors.white : textMainColor,
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
              ),

              // 5. POST FEED LIST (REALTIME LISTENED)
              ListenableBuilder(
                listenable: c,
                builder: (context, _) {
                  if (c.loading && c.posts.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(60),
                        child: Center(child: CircularProgressIndicator(color: isDark ? ShineGreen.accent : AppColors.forest)),
                      ),
                    );
                  }

                  final filterKey = _categories[_selectedCategoryIndex]["filter"] as String;
                  final displayPosts = filterKey.isEmpty
                      ? c.posts
                      : c.posts.where((p) {
                          final hay = "${p['description'] ?? ''} ${p['title'] ?? ''} ${p['location'] ?? ''}".toLowerCase();
                          return hay.contains(filterKey);
                        }).toList();

                  if (displayPosts.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(50),
                        child: Center(
                          child: Text(
                            "No wild expeditions found in this category.\nBe the first pioneer on this trail!",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textMutedColor, fontSize: 14, height: 1.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => ComplexPostCard(post: displayPosts[i]),
                      childCount: displayPosts.length,
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// STORIES TRAY & VIEWER
// ============================================================================
class StoriesTray extends StatefulWidget {
  const StoriesTray({super.key});

  @override
  State<StoriesTray> createState() => _StoriesTrayState();
}

class _StoriesTrayState extends State<StoriesTray> {
  bool _isUploadingStory = false;

  Future<void> _uploadStory(BuildContext context) async {
    if (!AuthController.I.isLoggedIn) {
      showLoginAlert(context);
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _isUploadingStory = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text("Uploading trail story..."),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF16181B) : AppColors.forest,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    try {
      final file = File(picked.path);
      await FeedController.I.addStory(file);
      await FeedController.I.refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Trail story uploaded successfully! 🌿"),
            backgroundColor: ShineGreen.deep,
          ),
        );
      }
    } catch (e) {
      debugPrint("Story upload error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload Failed: $e"),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingStory = false);
    }
  }

  void _openStoryViewer(BuildContext context, Map<String, dynamic> story) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Story",
      pageBuilder: (ctx, anim1, anim2) => StoryViewerModal(story: story),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF16181B) : AppColors.cardSurface;
    final textMainColor = isDark ? Colors.white : AppColors.textMain;

    return ListenableBuilder(
      listenable: FeedController.I,
      builder: (context, _) {
        final stories = FeedController.I.stories;
        return Container(
          height: 115,
          margin: const EdgeInsets.only(bottom: 6),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: stories.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 15),
            itemBuilder: (context, index) {
              if (index == 0) {
                return GestureDetector(
                  onTap: _isUploadingStory ? null : () => _uploadStory(context),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cardBg,
                              boxShadow: [
                                BoxShadow(
                                  color: isDark ? ShineGreen.primary.withOpacity(0.18) : AppColors.forest.withOpacity(0.12),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: isDark ? ShineGreen.accent : AppColors.emerald.withOpacity(0.6),
                                width: 2.2,
                              ),
                            ),
                            child: _isUploadingStory
                                ? Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: isDark ? ShineGreen.accent : AppColors.forest, strokeWidth: 2.5)))
                                : Icon(Icons.person, color: isDark ? ShineGreen.accent : AppColors.forest, size: 28),
                          ),
                          if (!_isUploadingStory)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4.5),
                                decoration: BoxDecoration(
                                  gradient: isDark ? ShineGreen.gradient : AppColors.greenGradient,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isDark ? Colors.black : Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.add, color: Colors.white, size: 13),
                              ),
                            )
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _isUploadingStory ? "Uploading..." : "Add Story",
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: textMainColor),
                      ),
                    ],
                  ),
                );
              }

              final story = stories[index - 1];
              final rawMedia = (story['mediaUrl'] ?? story['imageUrl'] ?? story['photo'] ?? '').toString();
              final mediaUrl = (rawMedia.isNotEmpty && rawMedia != 'null') ? rawMedia : 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400';

              return GestureDetector(
                onTap: () => _openStoryViewer(context, story),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isDark ? ShineGreen.ring : AppColors.storyRing,
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? ShineGreen.primary.withOpacity(0.24) : AppColors.forest.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 29,
                          backgroundColor: isDark ? const Color(0xFF16181B) : AppColors.tint,
                          backgroundImage: safeNetworkImage(mediaUrl, fallback: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    SizedBox(
                      width: 70,
                      child: Text(
                        story['authorName'] ?? 'Explorer',
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: textMainColor),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class StoryViewerModal extends StatefulWidget {
  final Map<String, dynamic> story;
  const StoryViewerModal({super.key, required this.story});

  @override
  State<StoryViewerModal> createState() => _StoryViewerModalState();
}

class _StoryViewerModalState extends State<StoryViewerModal> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this, duration: const Duration(seconds: 5))
      ..forward()
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (mounted) Navigator.of(context).pop();
        }
      });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = (widget.story['mediaUrl'] ?? widget.story['imageUrl'] ?? '').toString();
    final photo = (widget.story['userPhoto'] ?? widget.story['authorPhoto'] ?? '').toString();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: safeNetworkImageWidget(
              media.isNotEmpty && media != 'null' ? media : 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=1000',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black87, Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, _) => LinearProgressIndicator(
                    value: _progressController.value,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(ShineGreen.accent),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white24,
                        backgroundImage: safeNetworkImage(photo),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.story['authorName'] ?? 'Explorer', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const Text("Sri Lanka Wilderness • Live", style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    widget.story['caption'] ?? 'Exploring untouched Ceylon nature 🌿',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
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

// ============================================================================
// COMPLEX POST CARD (100% REALTIME REACTIVE & AUTHOR POST DELETION)
// ============================================================================
class ComplexPostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  const ComplexPostCard({super.key, required this.post});

  @override
  State<ComplexPostCard> createState() => _ComplexPostCardState();
}

class _ComplexPostCardState extends State<ComplexPostCard> with SingleTickerProviderStateMixin {
  bool _showHeartAnim = false;

  void _triggerDoubleTapLike() {
    HapticFeedback.mediumImpact();
    setState(() => _showHeartAnim = true);
    final postId = '${widget.post['id']}';
    if (!FeedController.I.liked.contains(postId)) {
      FeedController.I.toggleLike(widget.post);
    }
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showHeartAnim = false);
    });
  }

  void _openCommentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsBottomSheet(postId: '${widget.post['id']}'),
    );
  }

  void _openShareModal() {
    final postId = '${widget.post['id']}';
    final shareUrl = "https://naturetravels.lk/expeditions/$postId";
    Clipboard.setData(ClipboardData(text: shareUrl));

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16181B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 42, height: 4.5, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF222528) : AppColors.tint, shape: BoxShape.circle),
                  child: Icon(Icons.share_rounded, color: isDark ? ShineGreen.accent : AppColors.forest, size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Share Expedition", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: isDark ? Colors.white : AppColors.forest)),
                    Text("Link copied to clipboard automatically!", style: TextStyle(color: isDark ? Colors.white70 : AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF101214) : AppColors.canvasBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF26292C) : AppColors.cardStroke),
              ),
              child: Row(
                children: [
                  Icon(Icons.link_rounded, color: isDark ? ShineGreen.accent : AppColors.forest, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      shareUrl,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : AppColors.textMain, fontSize: 12.5),
                    ),
                  ),
                  Text("COPIED", style: TextStyle(color: isDark ? ShineGreen.accent : AppColors.emerald, fontWeight: FontWeight.w900, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? ShineGreen.deep : AppColors.forest,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // POST OPTIONS MENU (ONLY POST AUTHOR CAN DELETE)
  // ============================================================================
  void _showPostOptions(BuildContext context, Map<String, dynamic> livePost) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = AuthController.I.currentUser;

    // Current Logged-in User Info
    final myUid = currentUser?.uid ?? '';
    final myEmail = (currentUser?.email ?? '').toLowerCase().trim();
    final myName = (currentUser?.name ?? '').trim();

    // Post Author Info
    final postAuthorId = '${livePost['userId'] ?? livePost['authorId'] ?? livePost['userUid'] ?? livePost['uid'] ?? ''}'.trim();
    final postAuthorEmail = '${livePost['authorEmail'] ?? livePost['userEmail'] ?? livePost['email'] ?? ''}'.toLowerCase().trim();
    final postAuthorName = '${livePost['authorName'] ?? livePost['userName'] ?? ''}'.trim();

    // Strict Author Validation
    final bool isMyPost = AuthController.I.isLoggedIn && (
      (myUid.isNotEmpty && postAuthorId.isNotEmpty && myUid == postAuthorId) ||
      (myEmail.isNotEmpty && postAuthorEmail.isNotEmpty && myEmail == postAuthorEmail) ||
      (postAuthorId.isEmpty && postAuthorEmail.isEmpty && myName.isNotEmpty && myName.toLowerCase() == postAuthorName.toLowerCase())
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16181B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: isDark ? const Color(0xFF26292C) : AppColors.cardStroke),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),

            // Share Option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF222528) : AppColors.tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.share_rounded, color: isDark ? ShineGreen.accent : AppColors.forest, size: 20),
              ),
              title: Text("Share Trail", style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textMain)),
              onTap: () {
                Navigator.pop(ctx);
                _openShareModal();
              },
            ),

            // DELETE OPTION (ONLY AUTHOR)
            if (isMyPost) ...[
              const SizedBox(height: 4),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 22),
                ),
                title: const Text(
                  "Delete Expedition",
                  style: TextStyle(fontWeight: FontWeight.w800, color: Colors.redAccent),
                ),
                subtitle: Text(
                  "Permanently remove your post from the trail",
                  style: TextStyle(color: isDark ? Colors.white38 : AppColors.textMuted, fontSize: 11.5),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeletePost(livePost);
                },
              ),
            ] else ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.flag_rounded, color: Colors.orange, size: 20),
                ),
                title: Text("Report Spot", style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textMain)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Trail flagged for moderation.")),
                  );
                },
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // DELETE CONFIRMATION DIALOG
  Future<void> _confirmDeletePost(Map<String, dynamic> livePost) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final postId = '${livePost['id']}';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF16181B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Text(
              "Delete Post?",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : AppColors.textMain),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to permanently delete this expedition from the wild trail?",
          style: TextStyle(color: isDark ? Colors.white70 : AppColors.textMuted, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _executeDelete(postId);
    }
  }

  // EXECUTE DELETE LOCALLY & ON BACKEND
  Future<void> _executeDelete(String postId) async {
    final c = FeedController.I;

    setState(() {
      c.posts.removeWhere((p) => '${p['id']}' == postId);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Expedition deleted successfully! 🌿"),
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? ShineGreen.deep : AppColors.forest,
        ),
      );
    }

    try {
      final user = AuthController.I.currentUser;
      final uri = Uri.parse('${AppConfig.api}/posts/$postId');

      await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-user-uid': user?.uid ?? '',
          'x-user-email': user?.email ?? '',
        },
      );

      await c.refresh();
    } catch (e) {
      debugPrint("Backend delete error: $e");
    }
  }

  Widget _buildPostImage(String rawPath) {
    final image = rawPath.trim();
    if (image.isEmpty || image == 'null') return const SizedBox.shrink();

    if (image.startsWith('http://') || image.startsWith('https://')) {
      return safeNetworkImageWidget(
        image,
        width: double.infinity,
        height: 300,
        borderRadius: BorderRadius.circular(22),
      );
    } else {
      final file = File(image.replaceFirst('file://', ''));
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.file(
            file,
            width: double.infinity,
            height: 300,
            fit: BoxFit.cover,
          ),
        );
      }
      return safeNetworkImageWidget(
        image,
        width: double.infinity,
        height: 300,
        borderRadius: BorderRadius.circular(22),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = FeedController.I;

    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final postId = '${widget.post['id']}';

        final livePost = c.posts.firstWhere(
          (p) => '${p['id']}' == postId,
          orElse: () => widget.post,
        );

        final isLiked = c.liked.contains(postId);
        final isSaved = c.bookmarked.contains(postId);

        final dynamic rawImg = livePost['imageUrl'] ??
                               livePost['image'] ??
                               livePost['mediaUrl'] ??
                               livePost['photo'] ??
                               livePost['photoUrl'] ??
                               livePost['url'];
        final String image = (rawImg != null && rawImg.toString() != 'null') ? rawImg.toString().trim() : '';
        final bool hasImage = image.isNotEmpty;

        final localComments = c.getComments(postId);
        final baseCount = int.tryParse('${livePost['commentsCount'] ?? 0}') ?? 0;
        final commentsCount = math.max(localComments.length, baseCount);

        int likesCount = int.tryParse('${livePost['likesCount'] ?? 0}') ?? 0;
        if (isLiked && likesCount == 0) likesCount = 1;

        final isDark = Theme.of(context).brightness == Brightness.dark;

        final cardBg = isDark ? const Color(0xFF16181B) : AppColors.cardSurface;
        final cardBorder = isDark ? const Color(0xFF26292C) : AppColors.cardStroke;
        final subtlePlate = isDark ? const Color(0xFF222528) : AppColors.tint;
        final textMainColor = isDark ? Colors.white : AppColors.textMain;
        final textMutedColor = isDark ? const Color(0xFFA1B0A7) : AppColors.textMuted;

        final authorPhoto = (livePost['authorPhoto'] ?? livePost['userPhoto'] ?? '').toString();

        return Container(
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: cardBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.55) : AppColors.forest.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isDark ? ShineGreen.gradient : AppColors.greenGradient,
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: isDark ? const Color(0xFF16181B) : Colors.white,
                        backgroundImage: (authorPhoto.isNotEmpty && authorPhoto != 'null') ? safeNetworkImage(authorPhoto) : null,
                        child: (authorPhoto.isEmpty || authorPhoto == 'null')
                            ? Text(
                                (livePost['authorName'] ?? 'T')[0].toUpperCase(),
                                style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? ShineGreen.accent : AppColors.forest, fontSize: 15),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  livePost['authorName'] ?? 'Explorer',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: textMainColor),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Icon(Icons.verified_rounded, size: 15, color: isDark ? ShineGreen.accent : AppColors.emerald),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: subtlePlate,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text("PIONEER", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: isDark ? ShineGreen.accent : AppColors.forest)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded, size: 13, color: isDark ? ShineGreen.accent : AppColors.mint),
                              const SizedBox(width: 3),
                              Text(
                                livePost['location'] ?? 'Sri Lanka',
                                style: TextStyle(color: textMutedColor, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 6),
                              Text("• Active Now", style: TextStyle(color: isDark ? Colors.white38 : AppColors.textSubtle, fontSize: 11.5)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.more_horiz_rounded, color: isDark ? Colors.white54 : Colors.black45),
                      onPressed: () => _showPostOptions(context, livePost),
                    ),
                  ],
                ),
              ),
              if (hasImage)
                GestureDetector(
                  onDoubleTap: _triggerDoubleTapLike,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: _buildPostImage(image),
                      ),
                      Positioned(
                        top: 20,
                        left: 22,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.48),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: dynamicMainAxisSize(),
                                children: [
                                  Icon(Icons.terrain_rounded, color: isDark ? ShineGreen.accent : AppColors.lightMint, size: 14),
                                  const SizedBox(width: 6),
                                  const Text(
                                    "Wild Expedition • Ceylon",
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_showHeartAnim)
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.elasticOut,
                          tween: Tween(begin: 0.0, end: 1.2),
                          builder: (context, val, child) => Transform.scale(
                            scale: val,
                            child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 85),
                          ),
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      splashRadius: 22,
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          key: ValueKey(isLiked),
                          color: isLiked ? Colors.redAccent : (isDark ? Colors.white70 : AppColors.textMain),
                          size: 26,
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        c.toggleLike(livePost);
                      },
                    ),
                    IconButton(
                      splashRadius: 22,
                      icon: Icon(Icons.mode_comment_outlined, color: isDark ? Colors.white70 : AppColors.textMain, size: 23),
                      onPressed: _openCommentsSheet,
                    ),
                    IconButton(
                      splashRadius: 22,
                      icon: Icon(Icons.near_me_outlined, color: isDark ? Colors.white70 : AppColors.textMain, size: 23),
                      onPressed: _openShareModal,
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        c.toggleBookmark(postId);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSaved ? subtlePlate : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          color: isSaved ? (isDark ? ShineGreen.accent : AppColors.forest) : (isDark ? Colors.white70 : AppColors.textMain),
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      height: 26,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: isDark ? const Color(0xFF16181B) : Colors.white,
                              child: CircleAvatar(radius: 10, backgroundImage: safeNetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100')),
                            ),
                          ),
                          Positioned(
                            left: 14,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: isDark ? const Color(0xFF16181B) : Colors.white,
                              child: CircleAvatar(radius: 10, backgroundImage: safeNetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100')),
                            ),
                          ),
                          Positioned(
                            left: 28,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: isDark ? const Color(0xFF16181B) : Colors.white,
                              child: CircleAvatar(radius: 10, backgroundImage: safeNetworkImage('https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100')),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isLiked
                          ? (likesCount > 1 ? "You and ${likesCount - 1} explorers liked this" : "You liked this")
                          : "$likesCount explorers liked this",
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? ShineGreen.accent : AppColors.forest),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 14, height: 1.45, color: textMainColor),
                        children: [
                          TextSpan(
                            text: "${livePost['authorName'] ?? 'Explorer'} ",
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          TextSpan(
                            text: livePost['description'] ?? livePost['title'] ?? '',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "#WildSriLanka #KnucklesRange #EllaHikes #CeylonCamping",
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? ShineGreen.accent : AppColors.mint),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _openCommentsSheet,
                      child: Text(
                        commentsCount == 0
                            ? "Be the first to add trail advice..."
                            : "View all $commentsCount reflections & trail notes",
                        style: TextStyle(color: isDark ? Colors.white54 : AppColors.textSubtle, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  MainAxisSize dynamicMainAxisSize() => MainAxisSize.min;
}

// ============================================================================
// REALTIME COMMENTS BOTTOM SHEET (LIVE SYNCED)
// ============================================================================
class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  const CommentsBottomSheet({super.key, required this.postId});

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    FeedController.I.fetchComments(widget.postId);
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    if (!AuthController.I.isLoggedIn) {
      showLoginAlert(context);
      return;
    }

    HapticFeedback.lightImpact();
    FeedController.I.addComment(widget.postId, text);
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = FeedController.I;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF16181B) : Colors.white;
    final textMainColor = isDark ? Colors.white : AppColors.textMain;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 44, height: 4.5, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 14),
          Text(
            "Trail Reflections & Notes",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? ShineGreen.accent : AppColors.forest),
          ),
          Divider(color: isDark ? const Color(0xFF26292C) : AppColors.cardStroke),
          Expanded(
            child: ListenableBuilder(
              listenable: c,
              builder: (context, _) {
                final list = c.getComments(widget.postId);
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      "No trail notes yet.\nShare your advice for this trail!",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? Colors.white54 : AppColors.textMuted, height: 1.4),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, i) {
                    final item = list[i];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: isDark ? const Color(0xFF222528) : AppColors.tint,
                          backgroundImage: safeNetworkImage(item['photo']),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(item['author'] ?? 'Explorer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: textMainColor)),
                                  const SizedBox(width: 8),
                                  Text(item['time'] ?? 'Just now', style: TextStyle(color: isDark ? Colors.white38 : AppColors.textSubtle, fontSize: 11)),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(item['text'] ?? '', style: TextStyle(color: textMainColor, fontSize: 13, height: 1.3)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: BoxDecoration(
              color: sheetBg,
              border: Border(top: BorderSide(color: isDark ? const Color(0xFF26292C) : AppColors.cardStroke)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: TextStyle(color: textMainColor),
                    cursorColor: isDark ? ShineGreen.accent : AppColors.emerald,
                    decoration: InputDecoration(
                      hintText: "Add your trail advice...",
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : AppColors.textMuted),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF101214) : AppColors.canvasBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _submitComment(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send_rounded, color: isDark ? ShineGreen.accent : AppColors.forest),
                  onPressed: _submitComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LIQUID CREATOR STUDIO (R2 BACKEND UPLOAD + IMMEDIATE REALTIME INGEST)
// ============================================================================
class LiquidCreatorStudio extends StatefulWidget {
  final String initialLocation;
  const LiquidCreatorStudio({super.key, this.initialLocation = ''});

  @override
  State<LiquidCreatorStudio> createState() => _LiquidCreatorStudioState();
}

class _LiquidCreatorStudioState extends State<LiquidCreatorStudio> {
  final _desc = TextEditingController();
  late final _loc = TextEditingController(text: widget.initialLocation);
  File? _image;
  bool _isPublishing = false;

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        setState(() => _image = File(picked.path));
      }
    } catch (e) {
      debugPrint("Image picker error: $e");
    }
  }

  Future<void> _publish() async {
    final description = _desc.text.trim();
    final location = _loc.text.trim();

    if (description.isEmpty && _image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please add a photo or description for the spot!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!AuthController.I.isLoggedIn) {
      showLoginAlert(context);
      return;
    }

    setState(() => _isPublishing = true);

    try {
      await FeedController.I.createPost(
        description: description.isEmpty ? 'Wild Sri Lanka Expedition' : description,
        location: location.isEmpty ? 'Sri Lanka' : location,
        image: _image,
      );

      await FeedController.I.refresh();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Expedition discovery published successfully! 🌿"),
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? ShineGreen.deep : AppColors.forest,
          ),
        );
      }
    } catch (e) {
      debugPrint("Upload failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Publishing Failed: $e"),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF16181B) : Colors.white;
    final inputBg = isDark ? const Color(0xFF101214) : AppColors.canvasBg;
    final buttonBg = isDark ? const Color(0xFF222528) : AppColors.tint;
    final textMainColor = isDark ? Colors.white : AppColors.textMain;

    return Container(
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 32, offset: Offset(0, -8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.forest_rounded, color: isDark ? ShineGreen.accent : AppColors.green),
                  const SizedBox(width: 8),
                  Text("Share New Spot", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.forest)),
                ],
              ),
              IconButton(icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : Colors.black87), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            maxLines: 3,
            style: TextStyle(color: textMainColor),
            cursorColor: isDark ? ShineGreen.accent : AppColors.emerald,
            decoration: InputDecoration(
              hintText: "Describe your wild adventure... 🌿",
              hintStyle: TextStyle(color: isDark ? Colors.white38 : AppColors.textMuted),
              filled: true,
              fillColor: inputBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _loc,
            style: TextStyle(color: textMainColor),
            cursorColor: isDark ? ShineGreen.accent : AppColors.emerald,
            decoration: InputDecoration(
              hintText: "Location (e.g. Ella, Horton Plains)",
              hintStyle: TextStyle(color: isDark ? Colors.white38 : AppColors.textMuted),
              prefixIcon: Icon(Icons.location_on_rounded, color: isDark ? ShineGreen.accent : AppColors.mint),
              filled: true,
              fillColor: inputBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),
          if (_image != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(_image!, height: 160, width: double.infinity, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _image = null),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonBg,
                      foregroundColor: isDark ? ShineGreen.accent : AppColors.forest,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text("Gallery", style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _pick(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonBg,
                      foregroundColor: isDark ? ShineGreen.accent : AppColors.forest,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text("Camera", style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _pick(ImageSource.camera),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: isDark ? ShineGreen.gradient : AppColors.greenGradient,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: isDark ? ShineGreen.primary.withOpacity(0.35) : AppColors.forest.withOpacity(0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              ),
              onPressed: _isPublishing ? null : _publish,
              child: _isPublishing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text("Publishing discovery...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    )
                  : const Text("Publish Discovery", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          )
        ],
      ),
    );
  }
}
