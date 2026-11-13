import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_core.dart';
import 'profile_dialogs.dart';

// ============================================================================
// 1. PROFILE HERO COVER & AVATAR HEADER
// ============================================================================
class ProfileHeroHeader extends StatelessWidget {
  final AuthUser user;
  final bool isDark;
  final Color pageBg;
  final VoidCallback onOpenShare;
  final VoidCallback onOpenSettings;

  const ProfileHeroHeader({
    super.key,
    required this.user,
    required this.isDark,
    required this.pageBg,
    required this.onOpenShare,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          height: 230,
          width: double.infinity,
          foregroundDecoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.4),
                Colors.transparent,
                pageBg.withOpacity(0.85),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: safeNetworkImageWidget(
            user.coverUrl.isNotEmpty
                ? user.coverUrl
                : "https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=1200",
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 18,
          right: 18,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_rounded, color: AppColors.lightMint, size: 14),
                        SizedBox(width: 5),
                        Text("VERIFIED TRAILBLAZER", style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ),
              // TOP RIGHT BUTTONS: SHARE AND SETTINGS ONLY
              Row(
                children: [
                  GestureDetector(
                    onTap: onOpenShare,
                    child: CircleAvatar(
                      radius: 19,
                      backgroundColor: Colors.black.withOpacity(0.45),
                      child: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onOpenSettings,
                    child: CircleAvatar(
                      radius: 19,
                      backgroundColor: Colors.black.withOpacity(0.45),
                      child: const Icon(Icons.settings_rounded, color: Colors.white, size: 19),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
        Positioned(
          bottom: -50,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.greenGradient,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x3D092317),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    )
                  ],
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: isDark ? const Color(0xFF17241C) : Colors.white,
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: AppColors.tint,
                    backgroundImage: safeNetworkImage(user.photoUrl),
                  ),
                ),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.emerald,
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? const Color(0xFF17241C) : Colors.white, width: 2.5),
                  ),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 2. EXPLORER STATS STRIP (REALTIME FOLLOWERS & FOLLOWING)
// ============================================================================
class ProfileStatsStrip extends StatelessWidget {
  final int followersCount;
  final int followingCount;
  final int karmaScore;
  final Color cardSurface;
  final Color cardStroke;
  final Color forestColor;
  final Color textMuted;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  const ProfileStatsStrip({
    super.key,
    required this.followersCount,
    required this.followingCount,
    required this.karmaScore,
    required this.cardSurface,
    required this.cardStroke,
    required this.forestColor,
    required this.textMuted,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  Widget _buildStatColumn(String val, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(val, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: forestColor)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textMuted)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardStroke, width: 1.2),
        boxShadow: [
          BoxShadow(color: AppColors.forest.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatColumn("$followersCount", "Followers", onTap: onFollowersTap),
          Container(width: 1, height: 32, color: cardStroke),
          _buildStatColumn("$followingCount", "Following", onTap: onFollowingTap),
          Container(width: 1, height: 32, color: cardStroke),
          _buildStatColumn("$karmaScore", "Karma"),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. EXPLORER DETAILS CARD
// ============================================================================
class ProfileDetailsCard extends StatelessWidget {
  final AuthUser user;
  final Color cardSurface;
  final Color cardStroke;
  final Color forestColor;
  final Color textMain;
  final Color textMuted;

  const ProfileDetailsCard({
    super.key,
    required this.user,
    required this.cardSurface,
    required this.cardStroke,
    required this.forestColor,
    required this.textMain,
    required this.textMuted,
  });

  Widget _buildRow(IconData icon, String label, String val) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.mint),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(val, style: TextStyle(fontWeight: FontWeight.w800, color: textMain, fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardStroke, width: 1.2),
        boxShadow: [
          BoxShadow(color: AppColors.forest.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Explorer Details", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: forestColor)),
          const SizedBox(height: 12),
          _buildRow(Icons.place_rounded, "Current Location", user.livesIn.isNotEmpty ? user.livesIn : "Central Range, SL"),
          Divider(height: 18, color: cardStroke),
          _buildRow(Icons.home_work_rounded, "Hometown Base", user.fromLocation.isNotEmpty ? user.fromLocation : "Sri Lanka"),
          Divider(height: 18, color: cardStroke),
          _buildRow(Icons.mail_outline_rounded, "Official Contact", user.email),
          Divider(height: 18, color: cardStroke),
          _buildRow(Icons.verified_user_rounded, "Community Pass", "Verified Member"),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. TAB SEGMENTS SELECTOR
// ============================================================================
class ProfileTabSegments extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final Color cardSurface;
  final Color cardStroke;
  final Color textMuted;

  const ProfileTabSegments({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.cardSurface,
    required this.cardStroke,
    required this.textMuted,
  });

  Widget _buildTabSegment(int index, String title, IconData icon) {
    final isSelected = selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTabSelected(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.greenGradient : null,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : textMuted),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : textMuted,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardStroke, width: 1.2),
      ),
      child: Row(
        children: [
          _buildTabSegment(0, "Grid", Icons.grid_view_rounded),
          _buildTabSegment(1, "Saved", Icons.bookmark_rounded),
          _buildTabSegment(2, "Badges", Icons.military_tech_rounded),
          _buildTabSegment(3, "Timeline", Icons.history_rounded),
        ],
      ),
    );
  }
}

// ============================================================================
// 5. SOCIAL ROUND ICON BUTTON
// ============================================================================
class SocialIconButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final Color bg;
  final Color stroke;

  const SocialIconButton({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    required this.bg,
    required this.stroke,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: stroke, width: 1.2),
        ),
        child: Center(child: Icon(icon, color: iconColor, size: 22)),
      ),
    );
  }
}
