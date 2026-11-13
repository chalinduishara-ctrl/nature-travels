import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'app_core.dart';
import 'app_theme_manager.dart';
import 'live_profile_page.dart' show CloudflareR2Service;

// ============================================================================
// 1. SETTINGS & PREFERENCES MODAL (THEME TOGGLE & ACCOUNT LOGOUT)
// ============================================================================
void showSettingsModal(BuildContext context, {required VoidCallback onSignOut}) {
  HapticFeedback.lightImpact();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ListenableBuilder(
      listenable: AppThemeManager.instance,
      builder: (context, _) {
        final isDark = AppThemeManager.instance.isDarkMode;
        final sheetBg = isDark ? const Color(0xFF142018) : Colors.white;
        final textColor = isDark ? Colors.white : AppColors.forest;
        final subTextColor = isDark ? const Color(0xFF9EAF9F) : AppColors.textMuted;
        final cardBg = isDark ? const Color(0xFF1D2E24) : AppColors.canvasBg;
        final strokeColor = isDark ? const Color(0xFF2B4435) : AppColors.cardStroke;

        return Container(
          padding: EdgeInsets.only(
            top: 16,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.settings_suggest_rounded, color: AppColors.emerald, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Settings & Preferences",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: subTextColor),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "Manage app themes, explorer sessions, and preferences.",
                style: TextStyle(color: subTextColor, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // THEME SWITCHER
              Text(
                "APP APPEARANCE",
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: subTextColor,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        AppThemeManager.instance.toggleTheme(false);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: !isDark ? AppColors.tint.withOpacity(0.6) : cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: !isDark ? AppColors.forest : strokeColor,
                            width: !isDark ? 2.0 : 1.2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.wb_sunny_rounded, color: Colors.orange, size: 26),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Light Mode",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                                color: !isDark ? AppColors.forest : textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text("Emerald Wild", style: TextStyle(fontSize: 11, color: subTextColor)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        AppThemeManager.instance.toggleTheme(true);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E3326) : cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? AppColors.emerald : strokeColor,
                            width: isDark ? 2.0 : 1.2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.nightlight_round, color: Color(0xFF7986CB), size: 26),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Dark Mode",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                                color: isDark ? Colors.white : textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text("Night Timber", style: TextStyle(fontSize: 11, color: subTextColor)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: strokeColor, width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            color: isDark ? AppColors.emerald : Colors.orange, size: 22),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isDark ? "Dark Theme Active" : "Light Theme Active",
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: textColor),
                            ),
                            Text(
                              isDark ? "Enhanced night contrast" : "Fresh daytime contrast",
                              style: TextStyle(fontSize: 11, color: subTextColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: isDark,
                      activeColor: AppColors.emerald,
                      onChanged: (val) {
                        HapticFeedback.selectionClick();
                        AppThemeManager.instance.toggleTheme(val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // LOGOUT SECTION
              Text(
                "ACCOUNT SESSION",
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: subTextColor,
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.pop(ctx);
                  onSignOut();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1.2),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                      SizedBox(width: 10),
                      Text(
                        "Log Out from Account",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              )
            ],
          ),
        );
      },
    ),
  );
}

// ============================================================================
// 2. REAL-TIME FOLLOWERS / FOLLOWING EXPLORER LIST MODAL
// ============================================================================
void showUsersListModal(BuildContext context, String title, int count, List<Map<String, dynamic>> users) {
  HapticFeedback.selectionClick();
  final isDark = AppThemeManager.instance.isDarkMode;
  final sheetBg = isDark ? const Color(0xFF142018) : Colors.white;
  final textColor = isDark ? Colors.white : AppColors.forest;
  final subTextColor = isDark ? const Color(0xFF9EAF9F) : AppColors.textMuted;
  final cardBg = isDark ? const Color(0xFF1D2E24) : AppColors.canvasBg;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      height: MediaQuery.of(context).size.height * 0.65,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(width: 44, height: 4.5, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    title == "Followers" ? Icons.people_alt_rounded : Icons.person_add_alt_1_rounded,
                    color: AppColors.emerald,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "$title ($count)",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: subTextColor),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: users.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.nature_people_rounded, size: 54, color: subTextColor.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text(
                          "No $title Found Yet",
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textColor),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Your explorer community updates live.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: subTextColor, height: 1.4),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final u = users[index];
                      final name = u['name'] ?? u['userName'] ?? 'Explorer Scout';
                      final photo = u['photoUrl'] ?? u['avatar'] ?? '';
                      final role = u['occupation'] ?? u['bio'] ?? 'Wilderness Enthusiast';

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.tint,
                              backgroundImage: safeNetworkImage(photo),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: TextStyle(fontWeight: FontWeight.w900, color: textColor, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(role, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: subTextColor, fontSize: 12)),
                                ],
                              ),
                            ),
                            const Icon(Icons.verified_rounded, size: 18, color: AppColors.emerald),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

// ============================================================================
// 3. REAL-TIME STATUS UPDATER MODAL
// ============================================================================
void showStatusEditorModal(
  BuildContext context, {
  required String currentStatus,
  required String currentEmoji,
  required Function(String status, String emoji) onStatusChanged,
}) {
  final controller = TextEditingController(text: currentStatus);
  String selectedEmoji = currentEmoji;

  final presets = [
    {"emoji": "🟢", "text": "Active in Central Highlands"},
    {"emoji": "🏕️", "text": "Camped at Wilderness Ridge"},
    {"emoji": "🧭", "text": "Solo Off-grid GPS Tracking"},
    {"emoji": "🌧️", "text": "Sheltered from Mountain Rain"},
    {"emoji": "📸", "text": "Wildlife & Macro Photography"},
    {"emoji": "☕", "text": "Resting at Mountain Basecamp"},
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setSheetState) => Container(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.radar_rounded, color: AppColors.emerald, size: 24),
                SizedBox(width: 10),
                Text(
                  "Set Live Status",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.forest),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              "Broadcasts your real-time status across the explorer network.",
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLength: 45,
              decoration: InputDecoration(
                prefixText: "$selectedEmoji ",
                labelText: "Custom Live Status",
                filled: true,
                fillColor: AppColors.canvasBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 10),
            const Text("Quick Status Presets:", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets.map((p) {
                final isSelected = selectedEmoji == p["emoji"] && controller.text == p["text"];
                return ActionChip(
                  backgroundColor: isSelected ? AppColors.emerald.withOpacity(0.15) : AppColors.canvasBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: isSelected ? AppColors.emerald : AppColors.cardStroke),
                  ),
                  avatar: Text(p["emoji"]!),
                  label: Text(
                    p["text"]!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.emerald : AppColors.forest,
                    ),
                  ),
                  onPressed: () {
                    setSheetState(() {
                      selectedEmoji = p["emoji"]!;
                      controller.text = p["text"]!;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  final newStatus = controller.text.trim().isEmpty ? "Active in Wilderness" : controller.text.trim();
                  onStatusChanged(newStatus, selectedEmoji);
                  Navigator.pop(ctx);
                },
                child: const Text("Broadcast Status Live", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            )
          ],
        ),
      ),
    ),
  );
}

// ============================================================================
// 4. INSTAGRAM STORY HIGHLIGHT VIEWER
// ============================================================================
void showHighlightStoryViewer(BuildContext context, List<Map<String, String>> highlights, int initialIndex) {
  if (highlights.isEmpty) return;
  HapticFeedback.lightImpact();
  int currentIndex = initialIndex;

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "StoryViewer",
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, anim1, anim2) {
      return StatefulBuilder(
        builder: (context, setStoryState) {
          final story = highlights[currentIndex];
          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              fit: StackFit.expand,
              children: [
                safeNetworkImageWidget(story["img"], fit: BoxFit.cover),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 140,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 180,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 14,
                  right: 14,
                  child: Row(
                    children: List.generate(highlights.length, (idx) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          height: 3,
                          decoration: BoxDecoration(
                            color: idx <= currentIndex ? Colors.white : Colors.white38,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 24,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: safeNetworkImage(story["img"]),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            story["title"]!,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                          const Text(
                            "Expedition Reel",
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                ),
                Positioned(
                  bottom: 40,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text("VERIFIED EXPEDITION", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        story["caption"] ?? "Expedition log recorded.",
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, height: 1.35),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          if (currentIndex > 0) {
                            setStoryState(() => currentIndex--);
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          if (currentIndex < highlights.length - 1) {
                            setStoryState(() => currentIndex++);
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// ============================================================================
// 5. ADD NEW HIGHLIGHT DIALOG (DIRECT PHOTO UPLOADER - NO MANUAL URL)
// ============================================================================
void showAddNewHighlightDialog(BuildContext context, Function(Map<String, String> newHighlight) onAdd) {
  final titleCtrl = TextEditingController();
  final captionCtrl = TextEditingController();
  String? uploadedImageUrl;
  bool isUploading = false;
  double progress = 0.0;

  showDialog(
    context: context,
    barrierDismissible: !isUploading,
    builder: (ctx) => StatefulBuilder(
      builder: (dialogCtx, setDialogState) {
        Future<void> pickStoryImage(ImageSource source) async {
          setDialogState(() {
            isUploading = true;
            progress = 0.05;
          });

          final url = await CloudflareR2Service.pickAndUploadImage(
            context: ctx,
            source: source,
            onProgress: (p) {
              if (dialogCtx.mounted) setDialogState(() => progress = p);
            },
          );

          if (!dialogCtx.mounted) return;
          setDialogState(() {
            isUploading = false;
            if (url != null && url.isNotEmpty) {
              uploadedImageUrl = url;
            }
          });
        }

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.add_photo_alternate_rounded, color: AppColors.emerald),
              SizedBox(width: 8),
              Text("New Story Reel", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.forest)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: isUploading
                      ? null
                      : () {
                          showModalBottomSheet(
                            context: ctx,
                            backgroundColor: Colors.transparent,
                            builder: (sheetCtx) => Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.photo_library_rounded, color: AppColors.forest),
                                    title: const Text("Choose from Gallery", style: TextStyle(fontWeight: FontWeight.bold)),
                                    onTap: () {
                                      Navigator.pop(sheetCtx);
                                      pickStoryImage(ImageSource.gallery);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.camera_alt_rounded, color: AppColors.forest),
                                    title: const Text("Take Photo with Camera", style: TextStyle(fontWeight: FontWeight.bold)),
                                    onTap: () {
                                      Navigator.pop(sheetCtx);
                                      pickStoryImage(ImageSource.camera);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                  child: Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.canvasBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardStroke, width: 1.5),
                    ),
                    child: isUploading
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(value: progress, color: AppColors.forest, strokeWidth: 3),
                              const SizedBox(height: 10),
                              Text("Uploading ${(progress * 100).toInt()}%...", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          )
                        : uploadedImageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    safeNetworkImageWidget(uploadedImageUrl!, fit: BoxFit.cover),
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.65),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.cached_rounded, color: Colors.white, size: 14),
                                            SizedBox(width: 4),
                                            Text("Change", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_rounded, size: 36, color: AppColors.forest.withOpacity(0.5)),
                                  const SizedBox(height: 8),
                                  const Text("Tap to select Reel photo", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.forest)),
                                  const SizedBox(height: 2),
                                  const Text("Gallery or Camera direct upload", style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: "Reel Name (e.g. Knuckles ⛺)",
                    filled: true,
                    fillColor: AppColors.canvasBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: captionCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: "Story Caption / Notes",
                    filled: true,
                    fillColor: AppColors.canvasBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: isUploading
                  ? null
                  : () {
                      if (titleCtrl.text.trim().isNotEmpty) {
                        final newH = {
                          "title": titleCtrl.text.trim(),
                          "img": uploadedImageUrl ?? "https://images.unsplash.com/photo-1542332213-9b5a5a3fad35?w=800",
                          "caption": captionCtrl.text.trim().isNotEmpty ? captionCtrl.text.trim() : "Wilderness adventure.",
                        };
                        onAdd(newH);
                        Navigator.pop(ctx);
                      }
                    },
              child: const Text("Add Reel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    ),
  );
}

// ============================================================================
// 6. REAL PHOTO LIGHTBOX
// ============================================================================
void showPhotoLightboxDialog(BuildContext context, Map<String, dynamic> post) {
  HapticFeedback.lightImpact();
  final feedCtrl = FeedController.I;

  final img = (post['imageUrl'] ?? post['img'] ?? '').toString();
  final loc = (post['location'] ?? 'Wilderness').toString();
  final cap = (post['caption'] ?? '').toString();

  showDialog(
    context: context,
    builder: (ctx) => ListenableBuilder(
      listenable: feedCtrl,
      builder: (context, _) {
        final isLiked = post['isLiked'] == true;
        final likesCount = (post['likes'] ?? post['likesCount'] ?? 0) as int;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 24)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    safeNetworkImageWidget(img, height: 260, width: double.infinity, fit: BoxFit.cover),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0x99000000),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: AppColors.mint, size: 14),
                            const SizedBox(width: 4),
                            Text(loc, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              feedCtrl.toggleLike(post);
                            },
                            child: Row(
                              children: [
                                Icon(
                                  isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: isLiked ? Colors.redAccent : AppColors.forest,
                                  size: 24,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "$likesCount likes",
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.forest),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.share_outlined, color: AppColors.forest),
                            onPressed: () {
                              Navigator.pop(ctx);
                              Clipboard.setData(ClipboardData(text: img));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text("Expedition link copied to clipboard!"),
                                  backgroundColor: AppColors.forest,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(cap, style: const TextStyle(fontSize: 13.5, color: AppColors.textMain, height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

// ============================================================================
// 7. BADGE CERTIFICATE DIALOG
// ============================================================================
void showBadgeCertificateDialog(BuildContext context, Map<String, dynamic> badge) {
  HapticFeedback.lightImpact();
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (badge['color'] as Color).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(badge['icon'] as IconData, size: 48, color: badge['color'] as Color),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(badge['title']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.forest)),
                const SizedBox(width: 5),
                Icon(
                  badge['isUnlocked'] == true ? Icons.verified_rounded : Icons.lock_outline_rounded,
                  color: badge['isUnlocked'] == true ? AppColors.emerald : AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(badge['desc']!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.canvasBg, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Requirement Status", style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      Text(
                        badge['isUnlocked'] == true ? "Unlocked & Verified" : "In Progress",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: badge['isUnlocked'] == true ? AppColors.emerald : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Explorer Tier", style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      Text(badge['tier'] ?? "Pioneer Scout", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.forest)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
                label: const Text("Share Credential Pass", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: "Ceylon Explorer Credential: ${badge['title']}"));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Credential pass copied to clipboard!"),
                      backgroundColor: AppColors.forest,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    ),
  );
}

// ============================================================================
// 8. PROFESSIONAL EDIT PROFILE MODAL (REALTIME FIRESTORE & DIRECT UPLOAD)
// ============================================================================
void showEditProfileSheet(
  BuildContext context,
  AuthUser user,
  Function(AuthUser updated) onSave, {
  String? currentRole,
  Function(String newRole)? onRoleChanged,
}) {
  final nameCtrl = TextEditingController(text: user.name);
  final bioCtrl = TextEditingController(text: user.bio);
  final livesCtrl = TextEditingController(text: user.livesIn);
  final fromCtrl = TextEditingController(text: user.fromLocation);
  final occCtrl = TextEditingController(text: user.occupation);

  String avatarUrl = user.photoUrl;
  String coverUrl = user.coverUrl;
  String selectedRole = currentRole ?? 'explorer';

  bool uploadingAvatar = false;
  bool uploadingCover = false;
  bool isSavingFirestore = false;
  double uploadProgress = 0.0;

  final personas = [
    {"key": "explorer", "title": "Wilderness Explorer", "icon": Icons.explore_rounded, "badge": "Pioneer"},
    {"key": "guide", "title": "Trail Guide", "icon": Icons.hiking_rounded, "badge": "Leader"},
    {"key": "stay", "title": "Eco Lodge & Stay", "icon": Icons.cabin_rounded, "badge": "Host"},
    {"key": "gear", "title": "Gear Scout", "icon": Icons.backpack_rounded, "badge": "Tech"},
    {"key": "eatery", "title": "Haven Eatery", "icon": Icons.restaurant_rounded, "badge": "Dining"},
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (sheetCtx, setSheetState) {
        final bool isBusy = uploadingAvatar || uploadingCover || isSavingFirestore;

        Future<void> chooseAndUpload({required bool isAvatar}) async {
          showModalBottomSheet(
            context: ctx,
            backgroundColor: Colors.transparent,
            builder: (pickerCtx) => Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 42, height: 4.5, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 16),
                  Text(
                    isAvatar ? "Upload Profile Avatar" : "Upload Banner Cover",
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.forest),
                  ),
                  const SizedBox(height: 6),
                  const Text("Pick an image directly from your device", style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 16),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    tileColor: AppColors.canvasBg,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: AppColors.tint, shape: BoxShape.circle),
                      child: const Icon(Icons.photo_library_rounded, color: AppColors.forest, size: 20),
                    ),
                    title: const Text("Choose from Gallery", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.forest)),
                    onTap: () async {
                      Navigator.pop(pickerCtx);
                      setSheetState(() {
                        if (isAvatar) uploadingAvatar = true;
                        else uploadingCover = true;
                        uploadProgress = 0.05;
                      });

                      final url = await CloudflareR2Service.pickAndUploadImage(
                        context: ctx,
                        source: ImageSource.gallery,
                        onProgress: (p) {
                          if (sheetCtx.mounted) setSheetState(() => uploadProgress = p);
                        },
                      );

                      if (!sheetCtx.mounted) return;
                      setSheetState(() {
                        uploadingAvatar = false;
                        uploadingCover = false;
                        if (url != null && url.isNotEmpty) {
                          if (isAvatar) avatarUrl = url;
                          else coverUrl = url;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    tileColor: AppColors.canvasBg,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: AppColors.tint, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt_rounded, color: AppColors.forest, size: 20),
                    ),
                    title: const Text("Take Photo with Camera", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.forest)),
                    onTap: () async {
                      Navigator.pop(pickerCtx);
                      setSheetState(() {
                        if (isAvatar) uploadingAvatar = true;
                        else uploadingCover = true;
                        uploadProgress = 0.05;
                      });

                      final url = await CloudflareR2Service.pickAndUploadImage(
                        context: ctx,
                        source: ImageSource.camera,
                        onProgress: (p) {
                          if (sheetCtx.mounted) setSheetState(() => uploadProgress = p);
                        },
                      );

                      if (!sheetCtx.mounted) return;
                      setSheetState(() {
                        uploadingAvatar = false;
                        uploadingCover = false;
                        if (url != null && url.isNotEmpty) {
                          if (isAvatar) avatarUrl = url;
                          else coverUrl = url;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        }

        Widget buildModernInputField({
          required TextEditingController controller,
          required String label,
          required String hint,
          required IconData icon,
          int maxLines = 1,
        }) {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8F6),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2EBE5), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: AppColors.emerald),
                    const SizedBox(width: 6),
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Color(0xFF6E8276),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: controller,
                  maxLines: maxLines,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF132A1E),
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    hintText: hint,
                    hintStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFA0B0A6),
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          );
        }

        Future<void> executeProfileSave() async {
          if (nameCtrl.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("Explorer name cannot be blank."),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            );
            return;
          }

          setSheetState(() => isSavingFirestore = true);

          final updated = AuthUser(
            uid: user.uid,
            name: nameCtrl.text.trim(),
            email: user.email,
            photoUrl: avatarUrl,
            bio: bioCtrl.text.trim(),
            livesIn: livesCtrl.text.trim(),
            fromLocation: fromCtrl.text.trim(),
            occupation: occCtrl.text.trim(),
            coverUrl: coverUrl,
          );

          try {
            // DIRECT REAL-TIME FIRESTORE UPDATE
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'name': updated.name,
              'bio': updated.bio,
              'occupation': updated.occupation,
              'livesIn': updated.livesIn,
              'fromLocation': updated.fromLocation,
              'photoUrl': updated.photoUrl,
              'coverUrl': updated.coverUrl,
              'role': selectedRole,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (e) {
            debugPrint("Firestore write note: $e");
          }

          onRoleChanged?.call(selectedRole);
          onSave(updated);

          if (ctx.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text("Explorer profile updated in real-time!"),
                  ],
                ),
                backgroundColor: AppColors.forest,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            );
          }
        }

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.90,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              // DRAG HANDLE & TOP BAR
              Padding(
                padding: const EdgeInsets.only(top: 12, left: 20, right: 16, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.forest, size: 24),
                      onPressed: isBusy ? null : () => Navigator.pop(ctx),
                    ),
                    const Text(
                      "Edit Explorer Profile",
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.forest),
                    ),
                    TextButton(
                      onPressed: isBusy ? null : executeProfileSave,
                      child: isSavingFirestore
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald))
                          : const Text(
                              "Save",
                              style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // SCROLLABLE FORM CONTENT
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // PROFESSIONAL COVER & AVATAR EDITOR
                      Container(
                        height: 175,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.cardStroke),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // COVER PHOTO BANNER
                            ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  safeNetworkImageWidget(coverUrl, fit: BoxFit.cover),
                                  Container(color: Colors.black.withOpacity(0.25)),
                                  if (uploadingCover)
                                    Container(
                                      color: Colors.black54,
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(value: uploadProgress, color: Colors.white, strokeWidth: 3),
                                            const SizedBox(height: 8),
                                            Text("Uploading ${(uploadProgress * 100).toInt()}%...", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: GestureDetector(
                                      onTap: isBusy ? null : () => chooseAndUpload(isAvatar: false),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            color: Colors.black.withOpacity(0.45),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.photo_camera_back_rounded, color: Colors.white, size: 14),
                                                SizedBox(width: 5),
                                                Text("Change Cover", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // AVATAR PREVIEW OVERLAY
                            Positioned(
                              left: 20,
                              bottom: -28,
                              child: GestureDetector(
                                onTap: isBusy ? null : () => chooseAndUpload(isAvatar: true),
                                child: Stack(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3.5),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.18),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 38,
                                        backgroundColor: AppColors.tint,
                                        backgroundImage: safeNetworkImage(avatarUrl),
                                        child: uploadingAvatar
                                            ? Container(
                                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                                child: CircularProgressIndicator(value: uploadProgress, color: Colors.white, strokeWidth: 3),
                                              )
                                            : null,
                                      ),
                                    ),
                                    Positioned(
                                      right: 2,
                                      bottom: 2,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.emerald,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 38),

                      // WILDERNESS PERSONA ROLE PICKER
                      const Text(
                        "WILDERNESS PERSONA ROLE",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: personas.map((p) {
                            final isSelected = selectedRole == p["key"];
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setSheetState(() {
                                  selectedRole = p["key"] as String;
                                  if (occCtrl.text.isEmpty || personas.any((element) => element["title"] == occCtrl.text)) {
                                    occCtrl.text = p["title"] as String;
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.forest : const Color(0xFFF6F8F6),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? AppColors.forest : const Color(0xFFE2EBE5),
                                    width: isSelected ? 1.6 : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [BoxShadow(color: AppColors.forest.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))]
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      p["icon"] as IconData,
                                      size: 16,
                                      color: isSelected ? Colors.white : AppColors.emerald,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      p["title"] as String,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? Colors.white : AppColors.forest,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // EXPLORER IDENTITY FORM FIELDS
                      const Text(
                        "EXPLORER IDENTITY",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 12),
                      buildModernInputField(
                        controller: nameCtrl,
                        label: "Explorer Name",
                        hint: "e.g. Maya Forester",
                        icon: Icons.person_rounded,
                      ),
                      buildModernInputField(
                        controller: bioCtrl,
                        label: "Expedition Bio",
                        hint: "Brief note about your trail journey...",
                        icon: Icons.notes_rounded,
                        maxLines: 2,
                      ),
                      buildModernInputField(
                        controller: occCtrl,
                        label: "Specialty / Subtitle",
                        hint: "e.g. Certified Trail Guide",
                        icon: Icons.military_tech_rounded,
                      ),
                      buildModernInputField(
                        controller: livesCtrl,
                        label: "Current Base (Lives In)",
                        hint: "e.g. Ella, Sri Lanka",
                        icon: Icons.location_on_rounded,
                      ),
                      buildModernInputField(
                        controller: fromCtrl,
                        label: "Home Base (From)",
                        hint: "e.g. Central Province",
                        icon: Icons.home_work_rounded,
                      ),

                      const SizedBox(height: 20),

                      // SAVE BUTTON
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: AppColors.greenGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: AppColors.forest.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                          onPressed: isBusy ? null : executeProfileSave,
                          child: isSavingFirestore
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                                    SizedBox(width: 12),
                                    Text("Updating Real-time...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                                  ],
                                )
                              : const Text(
                                  "Save Changes",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

// ============================================================================
// 9. SOCIAL SHARE PROFILE MODAL
// ============================================================================
void showShareProfileSheet(BuildContext context, AuthUser user) {
  final link = "https://naturetravels.lk/pioneers/${user.uid}";
  Clipboard.setData(ClipboardData(text: link));

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 42, height: 4.5, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: AppColors.tint, shape: BoxShape.circle),
                child: const Icon(Icons.qr_code_2_rounded, color: AppColors.forest, size: 28),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Share ${user.name}'s Pass", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.forest)),
                  const Text("Traveler pass copied to clipboard!", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: AppColors.canvasBg, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, color: AppColors.forest, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(link, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
                const Text("COPIED", style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w900, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
// 10. AUTH LOADING ANIMATED DIALOG
// ============================================================================
class AnimatedAuthLoadingDialog extends StatefulWidget {
  const AnimatedAuthLoadingDialog({super.key});

  @override
  State<AnimatedAuthLoadingDialog> createState() => _AnimatedAuthLoadingDialogState();
}

class _AnimatedAuthLoadingDialogState extends State<AnimatedAuthLoadingDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Center(
        child: Container(
          width: 290,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 30,
                offset: const Offset(0, 10),
              )
            ],
            border: Border.all(color: AppColors.tint, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _animCtrl,
                builder: (context, _) {
                  final pulse = (1.0 + (_animCtrl.value * 0.18));
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: pulse,
                        child: Container(
                          width: 85,
                          height: 85,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.mint.withOpacity(0.18 * (1.0 - _animCtrl.value)),
                          ),
                        ),
                      ),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.greenGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.forest.withOpacity(0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Center(
                          child: Transform.rotate(
                            angle: _animCtrl.value * 2 * 3.14159,
                            child: const Icon(
                              Icons.explore_rounded,
                              size: 38,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              const Text(
                "Authenticating...",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.forest,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Connecting to Google & syncing your Ceylon Pioneer Explorer pass...",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 4,
                  child: LinearProgressIndicator(
                    backgroundColor: AppColors.tint,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emerald),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
