import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'app_core.dart';
import 'app_theme_manager.dart';
import 'profile_dialogs.dart';
import 'profile_widgets.dart';

export 'app_theme_manager.dart';

// Extension for safe AuthUser copyWith
extension AuthUserExtension on AuthUser {
  AuthUser copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoUrl,
    String? bio,
    String? livesIn,
    String? fromLocation,
    String? occupation,
    String? coverUrl,
  }) {
    return AuthUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      livesIn: livesIn ?? this.livesIn,
      fromLocation: fromLocation ?? this.fromLocation,
      occupation: occupation ?? this.occupation,
      coverUrl: coverUrl ?? this.coverUrl,
    );
  }
}

// Cloudflare R2 Storage Service
class CloudflareR2Service {
  static const String r2PublicDomain = "https://pub-your-id.r2.dev";
  static const String r2UploadWorkerUrl = "https://r2-upload.naturetravels.workers.dev/upload";

  static Future<String?> pickAndUploadImage({
    required BuildContext context,
    required ImageSource source,
    required Function(double progress) onProgress,
  }) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (pickedFile == null) return null;

      final Uint8List fileBytes = await pickedFile.readAsBytes();
      final String fileName = "memory_${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}";

      onProgress(0.15);

      final request = http.MultipartRequest('POST', Uri.parse(r2UploadWorkerUrl));
      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );

      onProgress(0.45);

      final streamedResponse = await request.send().timeout(const Duration(seconds: 40));
      onProgress(0.85);

      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        final respStr = await streamedResponse.stream.bytesToString();
        final Map<String, dynamic> data = jsonDecode(respStr);
        onProgress(1.0);
        return data['url'] ?? "$r2PublicDomain/$fileName";
      } else {
        final directResp = await http.put(
          Uri.parse("$r2UploadWorkerUrl/$fileName"),
          headers: {'Content-Type': 'image/jpeg'},
          body: fileBytes,
        ).timeout(const Duration(seconds: 40));

        if (directResp.statusCode == 200 || directResp.statusCode == 201) {
          onProgress(1.0);
          return "$r2PublicDomain/$fileName";
        }
      }
    } catch (e) {
      debugPrint("Cloudflare R2 Upload Error: $e");
    }
    return null;
  }
}

class LiveProfilePage extends StatefulWidget {
  const LiveProfilePage({super.key});

  @override
  State<LiveProfilePage> createState() => _LiveProfilePageState();
}

class _LiveProfilePageState extends State<LiveProfilePage> with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 0;

  // Scroll Controller
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;

  // Real-time Status & Role State
  String _activeStatus = "Active Wilderness Pioneer";
  String _statusEmoji = "🟢";
  String _userRole = "explorer"; // 'explorer', 'guide', 'stay', 'gear', 'eatery'
  double _partnerRating = 5.0;
  int _partnerReviewsCount = 0;

  // Real-time Data
  List<Map<String, dynamic>> _highlights = [];
  List<Map<String, dynamic>> _travelMemories = [];
  int _followersCount = 0;
  int _followingCount = 0;
  List<Map<String, dynamic>> _followersList = [];
  List<Map<String, dynamic>> _followingList = [];

  // Stream Subscriptions
  StreamSubscription<DocumentSnapshot>? _userDocSub;
  StreamSubscription<QuerySnapshot>? _followersSub;
  StreamSubscription<QuerySnapshot>? _followingSub;
  StreamSubscription<QuerySnapshot>? _memoriesSub;
  StreamSubscription<QuerySnapshot>? _highlightsSub;

  bool _isAuthenticating = false;
  static const String _sessionKey = 'nature_travels_cached_user';
  static const String _followersCountKey = 'cached_followers_count';
  static const String _followingCountKey = 'cached_following_count';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollListener);
    _restoreSavedSession();
    _loadCachedFollowCounts();
    _setupRealtimeStreams();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollListener);
    _scrollController.dispose();
    _cancelRealtimeSubs();
    super.dispose();
  }

  void _onScrollListener() {
    if (_scrollController.hasClients) {
      if (_scrollController.offset > 350 && !_showBackToTop) {
        setState(() => _showBackToTop = true);
      } else if (_scrollController.offset <= 350 && _showBackToTop) {
        setState(() => _showBackToTop = false);
      }
    }
  }

  void _scrollToTop() {
    HapticFeedback.mediumImpact();
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _cancelRealtimeSubs() {
    _userDocSub?.cancel();
    _followersSub?.cancel();
    _followingSub?.cancel();
    _memoriesSub?.cancel();
    _highlightsSub?.cancel();
  }

  void _setupRealtimeStreams() {
    final user = AuthController.I.currentUser;
    if (user == null || user.uid.isEmpty) return;

    _cancelRealtimeSubs();

    try {
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      _userDocSub = userDocRef.snapshots().listen((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return;
        final data = snapshot.data() as Map<String, dynamic>;

        int fCount = _followersCount;
        int fgCount = _followingCount;

        if (data.containsKey('followersCount')) {
          fCount = (data['followersCount'] is num) ? (data['followersCount'] as num).toInt() : fCount;
        } else if (data['followers'] is List) {
          fCount = (data['followers'] as List).length;
        }

        if (data.containsKey('followingCount')) {
          fgCount = (data['followingCount'] is num) ? (data['followingCount'] as num).toInt() : fgCount;
        } else if (data['following'] is List) {
          fgCount = (data['following'] as List).length;
        }

        final status = (data['liveStatus'] ?? _activeStatus).toString();
        final emoji = (data['liveStatusEmoji'] ?? _statusEmoji).toString();
        final role = (data['role'] ?? 'explorer').toString();
        final rating = (data['partnerRating'] is num) ? (data['partnerRating'] as num).toDouble() : 5.0;
        final reviews = (data['partnerReviewsCount'] is num) ? (data['partnerReviewsCount'] as num).toInt() : 0;

        if (mounted) {
          setState(() {
            _followersCount = fCount;
            _followingCount = fgCount;
            _activeStatus = status;
            _statusEmoji = emoji;
            _userRole = role;
            _partnerRating = rating;
            _partnerReviewsCount = reviews;
          });
          _saveCachedFollowCounts(fCount, fgCount);
        }
      }, onError: (e) => debugPrint("User Doc Stream Error: $e"));

      _memoriesSub = userDocRef
          .collection('memories')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snap) {
        final docs = snap.docs.map((d) {
          final map = d.data();
          map['id'] = d.id;
          return map;
        }).toList();

        if (mounted) {
          setState(() => _travelMemories = docs);
        }
      }, onError: (e) => debugPrint("Memories Stream Error: $e"));

      _highlightsSub = userDocRef
          .collection('highlights')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snap) {
        final docs = snap.docs.map((d) {
          final map = d.data();
          map['id'] = d.id;
          return map;
        }).toList();

        if (mounted) {
          setState(() => _highlights = docs);
        }
      }, onError: (e) => debugPrint("Highlights Stream Error: $e"));

      _followersSub = userDocRef.collection('followers').snapshots().listen((snap) {
        final docs = snap.docs.map((d) => d.data()).toList();
        if (mounted) {
          setState(() {
            _followersCount = snap.docs.length > _followersCount ? snap.docs.length : _followersCount;
            _followersList = docs;
          });
          _saveCachedFollowCounts(_followersCount, _followingCount);
        }
      }, onError: (_) {});

      _followingSub = userDocRef.collection('following').snapshots().listen((snap) {
        final docs = snap.docs.map((d) => d.data()).toList();
        if (mounted) {
          setState(() {
            _followingCount = snap.docs.length > _followingCount ? snap.docs.length : _followingCount;
            _followingList = docs;
          });
          _saveCachedFollowCounts(_followersCount, _followingCount);
        }
      }, onError: (_) {});
    } catch (e) {
      debugPrint("Error initializing Realtime Streams: $e");
    }
  }

  Future<void> _updateUserRoleInCloud(String newRole) async {
    final user = AuthController.I.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'role': newRole,
      }, SetOptions(merge: true));
      setState(() => _userRole = newRole);
      _showToast("Account role updated to ${_getRoleLabel(newRole)}!");
    } catch (e) {
      _showToast("Could not update role.");
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'guide':
        return 'Certified Mountain Guide';
      case 'stay':
        return 'Verified Eco-Stay Host';
      case 'gear':
        return 'Wilderness Gear Outfitter';
      case 'eatery':
        return 'Trail Eatery Partner';
      default:
        return 'Wilderness Explorer';
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'guide':
        return Icons.hiking_rounded;
      case 'stay':
        return Icons.hotel_rounded;
      case 'gear':
        return Icons.backpack_rounded;
      case 'eatery':
        return Icons.restaurant_rounded;
      default:
        return Icons.explore_rounded;
    }
  }

  Future<void> _updateLiveStatusInCloud(String status, String emoji) async {
    final user = AuthController.I.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'liveStatus': status,
        'liveStatusEmoji': emoji,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Failed to update status: $e");
    }
  }

  Future<void> _createMemoryInCloud(Map<String, dynamic> memoryData) async {
    final user = AuthController.I.currentUser;
    if (user == null) return;
    try {
      memoryData['createdAt'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('memories')
          .add(memoryData);
      _showToast("Expedition memory saved to your Live Diary! 📖🌿");
    } catch (e) {
      _showToast("Could not save memory. Check your internet connection.");
    }
  }

  Future<void> _deleteMemoryFromCloud(String memoryId) async {
    final user = AuthController.I.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('memories')
          .doc(memoryId)
          .delete();
      _showToast("Expedition record removed.");
    } catch (e) {
      _showToast("Failed to remove expedition record.");
    }
  }

  Future<void> _addHighlightToCloud(Map<String, String> highlightData) async {
    final user = AuthController.I.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('highlights')
          .add({
        'title': highlightData['title'] ?? 'Expedition',
        'img': highlightData['img'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _showToast("Highlight reel published.");
    } catch (e) {
      _showToast("Failed to upload highlight.");
    }
  }

  Future<void> _removeHighlightFromCloud(String highlightId) async {
    final user = AuthController.I.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('highlights')
          .doc(highlightId)
          .delete();
      _showToast("Highlight removed.");
    } catch (_) {}
  }

  Future<void> _loadCachedFollowCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fc = prefs.getInt(_followersCountKey) ?? 0;
      final fgc = prefs.getInt(_followingCountKey) ?? 0;
      if (mounted) {
        setState(() {
          _followersCount = fc;
          _followingCount = fgc;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveCachedFollowCounts(int followers, int following) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_followersCountKey, followers);
      await prefs.setInt(_followingCountKey, following);
    } catch (_) {}
  }

  Future<void> _restoreSavedSession() async {
    try {
      if (AuthController.I.currentUser == null) {
        final prefs = await SharedPreferences.getInstance();
        final rawJson = prefs.getString(_sessionKey);
        if (rawJson != null && rawJson.isNotEmpty) {
          final data = jsonDecode(rawJson) as Map<String, dynamic>;
          final restored = AuthUser(
            uid: data['uid'] ?? '',
            name: data['name'] ?? 'Explorer',
            email: data['email'] ?? '',
            photoUrl: data['photoUrl'] ?? '',
            bio: data['bio'] ?? '',
            livesIn: data['livesIn'] ?? '',
            fromLocation: data['fromLocation'] ?? '',
            occupation: data['occupation'] ?? '',
            coverUrl: data['coverUrl'] ?? '',
          );
          if (restored.uid.isNotEmpty) {
            await AuthController.I.updateProfile(restored);
            _setupRealtimeStreams();
            if (mounted) setState(() {});
          }
        }
      } else {
        _setupRealtimeStreams();
      }
    } catch (_) {}
  }

  Future<void> _saveUserSession(AuthUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'uid': user.uid,
        'name': user.name,
        'email': user.email,
        'photoUrl': user.photoUrl,
        'bio': user.bio,
        'livesIn': user.livesIn,
        'fromLocation': user.fromLocation,
        'occupation': user.occupation,
        'coverUrl': user.coverUrl,
      };
      await prefs.setString(_sessionKey, jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      await prefs.remove(_followersCountKey);
      await prefs.remove(_followingCountKey);
    } catch (_) {}
  }

  void _startGoogleSignInWithAnimation() async {
    if (_isAuthenticating) return;
    HapticFeedback.heavyImpact();
    setState(() => _isAuthenticating = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (dialogCtx) => const AnimatedAuthLoadingDialog(),
    );

    try {
      await AuthController.I.signInWithGoogle();
      final currentUser = AuthController.I.currentUser;

      if (currentUser != null) {
        await _saveUserSession(currentUser);
        _setupRealtimeStreams();
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        _showToast("Welcome back, ${currentUser.name}! 🌿");
      } else {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showToast("Google Sign-In canceled or failed.");
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  Future<void> _handleSignOut() async {
    HapticFeedback.mediumImpact();
    _cancelRealtimeSubs();
    await _clearUserSession();
    await AuthController.I.signOut();
    setState(() {
      _followersCount = 0;
      _followingCount = 0;
      _followersList.clear();
      _followingList.clear();
      _travelMemories.clear();
      _highlights.clear();
    });
    _showToast("Signed out from Pioneer Network.");
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.forest,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleSocialConnect(String platform) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: "https://naturetravels.lk/social/$platform"));
    _showToast("$platform link copied to clipboard!");
  }

  String _getPostId(Map<String, dynamic> post) => (post['id'] ?? '').toString();
  String _getPostImg(Map<String, dynamic> post) => (post['imageUrl'] ?? post['img'] ?? '').toString();
  String _getPostLocation(Map<String, dynamic> post) => (post['location'] ?? 'Wilderness').toString();
  String _getPostCaption(Map<String, dynamic> post) => (post['caption'] ?? '').toString();
  int _getPostLikes(Map<String, dynamic> post) => (post['likes'] ?? post['likesCount'] ?? 0) as int;
  bool _getPostIsLiked(Map<String, dynamic> post) => post['isLiked'] == true;

  void _toggleBookmark(Map<String, dynamic> post) {
    final dynamic dFeed = FeedController.I;
    final String id = _getPostId(post);
    try {
      dFeed.toggleBookmark(post);
      return;
    } catch (_) {}
    try {
      dFeed.toggleBookmark(id);
      return;
    } catch (_) {}
  }

  // Role Switcher Modal
  void _openRoleSelectorModal(BuildContext context, bool isDark) {
    HapticFeedback.mediumImpact();
    final textC = isDark ? Colors.white : AppColors.textMain;
    final cardBg = isDark ? const Color(0xFF16221A) : Colors.white;

    final roles = [
      {'key': 'explorer', 'title': 'Wilderness Explorer', 'desc': 'Track hikes, record summits, share photos & review partners.', 'icon': Icons.explore_rounded, 'color': AppColors.forest},
      {'key': 'guide', 'title': 'Certified Mountain Guide', 'desc': 'Lead wilderness expeditions, receive hiker bookings & reviews.', 'icon': Icons.hiking_rounded, 'color': AppColors.emerald},
      {'key': 'stay', 'title': 'Eco Stay / Campsite Host', 'desc': 'Manage tents, treehouses & lodges with direct guest inquiries.', 'icon': Icons.hotel_rounded, 'color': const Color(0xFF10B981)},
      {'key': 'gear', 'title': 'Camping Gear Outfitter', 'desc': 'Rent camping equipment, stoves, packs & off-grid trail gear.', 'icon': Icons.backpack_rounded, 'color': const Color(0xFFF59E0B)},
      {'key': 'eatery', 'title': 'Haven Eatery', 'desc': 'Trailside fresh local food, spring water & mountain rations.', 'icon': Icons.restaurant_rounded, 'color': const Color(0xFFE11D48)},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 14),
            Text("Pioneer Account Identity", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textC)),
            const Text("Select your active explorer or verified service provider role", style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            ...roles.map((r) {
              final isCurrent = _userRole == r['key'];
              return GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _updateUserRoleInCloud(r['key'] as String);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrent ? (r['color'] as Color).withOpacity(0.12) : (isDark ? const Color(0xFF1E2F23) : const Color(0xFFF4F7F5)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isCurrent ? (r['color'] as Color) : Colors.transparent, width: 1.4),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: (r['color'] as Color).withOpacity(0.15), shape: BoxShape.circle),
                        child: Icon(r['icon'] as IconData, color: r['color'] as Color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r['title'] as String, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: textC)),
                            const SizedBox(height: 2),
                            Text(r['desc'] as String, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                          ],
                        ),
                      ),
                      if (isCurrent)
                        Icon(Icons.check_circle_rounded, color: r['color'] as Color, size: 20),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // Memory Sheet
  void _openWriteMemorySheet(BuildContext context, bool isDark) {
    HapticFeedback.mediumImpact();
    final titleCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final dateCtrl = TextEditingController(
      text: "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}",
    );
    final stayedCtrl = TextEditingController();
    final foodCtrl = TextEditingController();
    final crewCtrl = TextEditingController();
    final storyCtrl = TextEditingController();

    String selectedMood = "🏕️";
    String? uploadedImageUrl;
    bool isUploadingImage = false;
    double uploadProgress = 0.0;

    final List<String> moods = ["🏕️", "⛰️", "🌊", "🚂", "🛵", "🎒", "⛺", "🌅", "🛖"];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: isDark ? const Color(0xFF121B15) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final fieldFill = isDark ? const Color(0xFF1B281F) : const Color(0xFFF3F7F4);
          final textC = isDark ? Colors.white : AppColors.textMain;
          final hintC = isDark ? const Color(0xFF8CA190) : AppColors.textMuted;

          Future<void> triggerImageUpload(ImageSource source) async {
            setModalState(() {
              isUploadingImage = true;
              uploadProgress = 0.05;
            });

            final url = await CloudflareR2Service.pickAndUploadImage(
              context: context,
              source: source,
              onProgress: (p) => setModalState(() => uploadProgress = p),
            );

            setModalState(() {
              isUploadingImage = false;
              if (url != null) {
                uploadedImageUrl = url;
              }
            });
          }

          Future<void> pickExpeditionDate() async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: ctx,
              initialDate: now,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: AppColors.forest,
                      onPrimary: Colors.white,
                      onSurface: textC,
                    ),
                  ),
                  child: child!,
                );
              },
            );

            if (picked != null) {
              setModalState(() {
                dateCtrl.text =
                    "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
              });
            }
          }

          Widget buildTextField({
            required TextEditingController controller,
            required String label,
            required String hint,
            required IconData icon,
            int maxLines = 1,
            VoidCallback? onTap,
            bool readOnly = false,
          }) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextField(
                controller: controller,
                maxLines: maxLines,
                readOnly: readOnly,
                onTap: onTap,
                style: TextStyle(color: textC, fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: TextStyle(color: hintC, fontSize: 13, fontWeight: FontWeight.bold),
                  hintText: hint,
                  hintStyle: TextStyle(color: hintC.withOpacity(0.55), fontSize: 12.5),
                  prefixIcon: Icon(icon, color: AppColors.forest, size: 20),
                  suffixIcon: readOnly ? const Icon(Icons.arrow_drop_down_rounded, color: AppColors.forest) : null,
                  filled: true,
                  fillColor: fieldFill,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.forest, width: 1.5),
                  ),
                ),
              ),
            );
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.90,
            minChildSize: 0.40,
            maxChildSize: 0.95,
            expand: false,
            builder: (sheetCtx, scrollController) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                  top: 10,
                  left: 20,
                  right: 20,
                ),
                child: ListView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 48,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.forest.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.auto_stories_rounded, color: AppColors.forest, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Log Expedition Memory", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textC)),
                              Text("Preserve your journey in the Wilderness Diary", style: TextStyle(color: hintC, fontSize: 12)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded, size: 20, color: textC),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    Text("Expedition Cover Photo", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: hintC)),
                    const SizedBox(height: 8),

                    if (uploadedImageUrl != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: safeNetworkImageWidget(uploadedImageUrl!, height: 160, width: double.infinity, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => setModalState(() => uploadedImageUrl = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), borderRadius: BorderRadius.circular(10)),
                              child: const Row(
                                children: [
                                  Icon(Icons.cloud_done_rounded, size: 14, color: AppColors.emerald),
                                  SizedBox(width: 5),
                                  Text("Photo uploaded", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (isUploadingImage)
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: fieldFill,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.forest.withOpacity(0.4)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(value: uploadProgress, color: AppColors.forest, strokeWidth: 3),
                            const SizedBox(height: 12),
                            Text(
                              "Uploading photo... ${(uploadProgress * 100).toInt()}%",
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: textC),
                            ),
                          ],
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.photo_library_rounded, color: AppColors.forest, size: 18),
                              label: const Text("Gallery Upload", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.forest)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.forest.withOpacity(0.4), width: 1.4),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () => triggerImageUpload(ImageSource.gallery),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.camera_alt_rounded, color: AppColors.forest, size: 18),
                              label: const Text("Camera Capture", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.forest)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.forest.withOpacity(0.4), width: 1.4),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () => triggerImageUpload(ImageSource.camera),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 18),

                    Text("Journey Vibe", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: hintC)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: moods.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final m = moods[i];
                          final isSel = selectedMood == m;
                          return GestureDetector(
                            onTap: () => setModalState(() => selectedMood = m),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel ? AppColors.forest : fieldFill,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isSel ? AppColors.forest : Colors.transparent, width: 1.2),
                              ),
                              child: Center(child: Text(m, style: const TextStyle(fontSize: 20))),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),

                    buildTextField(controller: titleCtrl, label: "Expedition Title", hint: "e.g. Namunukula Summit Trek", icon: Icons.terrain_rounded),
                    buildTextField(controller: locationCtrl, label: "Region / Location", hint: "e.g. Central Highlands Range", icon: Icons.location_on_rounded),
                    buildTextField(
                      controller: dateCtrl,
                      label: "Expedition Date",
                      hint: "Tap to select date",
                      icon: Icons.calendar_month_rounded,
                      readOnly: true,
                      onTap: pickExpeditionDate,
                    ),
                    buildTextField(controller: stayedCtrl, label: "Basecamp / Lodging", hint: "e.g. Cliffside Tent Pitch / Eco Homestay", icon: Icons.hotel_rounded),
                    buildTextField(controller: foodCtrl, label: "Local Eateries & Rations", hint: "e.g. Mountain Spring & Village Rotti Shack", icon: Icons.restaurant_rounded),
                    buildTextField(controller: crewCtrl, label: "Trail Companions", hint: "e.g. Solo Ranger / Scouting Clan", icon: Icons.group_rounded),
                    buildTextField(controller: storyCtrl, label: "Field Notes & Reflections", hint: "Document weather, route obstacles, moments...", icon: Icons.edit_note_rounded, maxLines: 4),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.bookmark_added_rounded, color: Colors.white, size: 20),
                        label: const Text("Save Expedition Entry", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 3,
                        ),
                        onPressed: () {
                          if (titleCtrl.text.trim().isEmpty) {
                            _showToast("Please provide an expedition title.");
                            return;
                          }

                          final newMem = {
                            "title": titleCtrl.text.trim(),
                            "location": locationCtrl.text.trim().isEmpty ? "Wilderness Trail" : locationCtrl.text.trim(),
                            "date": dateCtrl.text.trim(),
                            "mood": selectedMood,
                            "stayed": stayedCtrl.text.trim().isEmpty ? "Day Expedition" : stayedCtrl.text.trim(),
                            "food": foodCtrl.text.trim().isEmpty ? "Field Rations" : foodCtrl.text.trim(),
                            "crew": crewCtrl.text.trim().isEmpty ? "Solo Ranger" : crewCtrl.text.trim(),
                            "story": storyCtrl.text.trim(),
                            "imageUrl": uploadedImageUrl ?? "",
                          };

                          Navigator.pop(ctx);
                          _createMemoryInCloud(newMem);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<bool> _showDeleteConfirmDialog(BuildContext context, bool isDark) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF19251D) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              "Remove Record?",
              style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.textMain),
            ),
            content: Text(
              "This action cannot be undone. Are you sure you want to remove this expedition memory from your live diary?",
              style: TextStyle(color: isDark ? const Color(0xFF9EAF9F) : AppColors.textMuted, fontSize: 13.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text("Keep Entry", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.forest)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _openMemoryDetailDialog(BuildContext context, Map<String, dynamic> memory, bool isDark) {
    HapticFeedback.lightImpact();
    final cardBg = isDark ? const Color(0xFF141F18) : Colors.white;
    final textC = isDark ? Colors.white : AppColors.textMain;
    final textMuted = isDark ? const Color(0xFF9EAF9F) : AppColors.textMuted;
    final strokeC = isDark ? const Color(0xFF263D2F) : AppColors.cardStroke;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        expand: false,
        builder: (sheetCtx, scrollController) => ListView(
          controller: scrollController,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          children: [
            Center(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 18),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.forest.withOpacity(0.12), borderRadius: BorderRadius.circular(18)),
                  child: Text(memory['mood'] ?? "🏕️", style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(memory['title'] ?? '', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textC)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 14, color: AppColors.forest),
                          const SizedBox(width: 4),
                          Expanded(child: Text(memory['location'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.forest))),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text("Recorded: ${memory['date'] ?? ''}", style: TextStyle(color: textMuted, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: "Delete entry",
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () async {
                    final shouldDelete = await _showDeleteConfirmDialog(ctx, isDark);
                    if (shouldDelete && mounted) {
                      Navigator.pop(ctx);
                      if (memory['id'] != null) {
                        _deleteMemoryFromCloud(memory['id'].toString());
                      }
                    }
                  },
                ),
                IconButton(
                  tooltip: "Close",
                  icon: Icon(Icons.close_rounded, color: textC),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 18),

            if ((memory['imageUrl'] ?? '').toString().isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: safeNetworkImageWidget(memory['imageUrl'], height: 210, width: double.infinity, fit: BoxFit.cover),
              ),

            const SizedBox(height: 18),

            _buildLedgerTile(
              icon: Icons.hotel_rounded,
              title: "Basecamp / Lodging",
              content: memory['stayed'] ?? 'Day Expedition',
              isDark: isDark,
              strokeC: strokeC,
              textC: textC,
              textMuted: textMuted,
            ),
            const SizedBox(height: 10),

            _buildLedgerTile(
              icon: Icons.restaurant_rounded,
              title: "Food & Rations",
              content: memory['food'] ?? 'Packed Trail Supplies',
              isDark: isDark,
              strokeC: strokeC,
              textC: textC,
              textMuted: textMuted,
            ),
            const SizedBox(height: 10),

            _buildLedgerTile(
              icon: Icons.people_alt_rounded,
              title: "Trail Companions",
              content: memory['crew'] ?? 'Solo Scout',
              isDark: isDark,
              strokeC: strokeC,
              textC: textC,
              textMuted: textMuted,
            ),
            const SizedBox(height: 16),

            if ((memory['story'] ?? '').toString().isNotEmpty) ...[
              Text("Explorer Journal Narrative", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.forest)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1B2A20) : const Color(0xFFF4F8F5),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: strokeC),
                ),
                child: Text(
                  memory['story'],
                  style: TextStyle(color: textC, fontSize: 13.5, height: 1.55, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerTile({
    required IconData icon,
    required String title,
    required String content,
    required bool isDark,
    required Color strokeC,
    required Color textC,
    required Color textMuted,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A271E) : const Color(0xFFF4F8F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: strokeC),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.emerald, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textMuted)),
                const SizedBox(height: 3),
                Text(content, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textC)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActiveTabSlivers({
    required bool isTablet,
    required double horizontalPadding,
    required List<Map<String, dynamic>> userPosts,
    required List<Map<String, dynamic>> savedPosts,
    required List<Map<String, dynamic>> dynamicBadges,
    required Color cardSurface,
    required Color cardStroke,
    required Color textMain,
    required Color textMuted,
    required Color forestColor,
    required bool isDark,
  }) {
    switch (_selectedTabIndex) {
      case 0:
        if (userPosts.isEmpty) {
          return [
            _buildEmptyState(
              "No Expeditions Logged",
              "Share photos from the feed to curate your profile journey.",
              Icons.add_a_photo_outlined,
              cardSurface,
              forestColor,
              textMuted,
            ),
          ];
        }
        return [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 110),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isTablet ? 4 : 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final post = userPosts[index];
                  final img = _getPostImg(post);
                  final isLiked = _getPostIsLiked(post);

                  return GestureDetector(
                    onTap: () => showPhotoLightboxDialog(context, post),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: safeNetworkImageWidget(img, fit: BoxFit.cover),
                        ),
                        if (isLiked)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 12),
                            ),
                          ),
                      ],
                    ),
                  );
                },
                childCount: userPosts.length,
              ),
            ),
          ),
        ];

      case 1:
        if (savedPosts.isEmpty) {
          return [
            _buildEmptyState(
              "No Saved Trails",
              "Bookmark routes and viewpoints from the feed to plan offline hikes.",
              Icons.bookmark_border_rounded,
              cardSurface,
              forestColor,
              textMuted,
            ),
          ];
        }
        return [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 110),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final post = savedPosts[index];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardStroke, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: safeNetworkImageWidget(_getPostImg(post), width: 68, height: 68, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getPostLocation(post),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w900, color: textMain, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getPostCaption(post),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.bookmark_remove_rounded, color: AppColors.emerald),
                          onPressed: () {
                            _toggleBookmark(post);
                            _showToast("Removed from saved list.");
                          },
                        ),
                      ],
                    ),
                  );
                },
                childCount: savedPosts.length,
              ),
            ),
          ),
        ];

      case 2:
        return [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 110),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final b = dynamicBadges[index];
                  final bool unlocked = b['isUnlocked'] == true;

                  return GestureDetector(
                    onTap: () => showBadgeCertificateDialog(context, b),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cardStroke, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: unlocked ? (b['color'] as Color).withOpacity(0.12) : Colors.black12,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              b['icon'] as IconData,
                              color: unlocked ? (b['color'] as Color) : textMuted,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b['title'] as String,
                                  style: TextStyle(fontWeight: FontWeight.w900, color: textMain, fontSize: 14.5),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  b['desc'] as String,
                                  style: TextStyle(color: textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            unlocked ? Icons.verified_rounded : Icons.lock_outline_rounded,
                            size: 18,
                            color: unlocked ? AppColors.emerald : textMuted,
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: dynamicBadges.length,
              ),
            ),
          ),
        ];

      case 3:
      default:
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 10, horizontalPadding, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Pioneer Travel Ledger", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: forestColor)),
                      Text("Travel Chronicles & Diaries", style: TextStyle(color: textMuted, fontSize: 11.5)),
                    ],
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_a_photo_rounded, size: 16, color: Colors.white),
                    label: const Text("New Entry", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    ),
                    onPressed: () => _openWriteMemorySheet(context, isDark),
                  ),
                ],
              ),
            ),
          ),
          if (_travelMemories.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 110),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(color: cardSurface, shape: BoxShape.circle),
                        child: Icon(Icons.auto_stories_rounded, size: 44, color: textMuted),
                      ),
                      const SizedBox(height: 14),
                      Text("Your Travel Diary is Empty", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: forestColor)),
                      const SizedBox(height: 6),
                      Text(
                        "Record summits, basecamps, and trail eateries to preserve your wilderness memories.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.forest),
                        label: const Text("Log First Expedition", style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.forest)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.forest, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        onPressed: () => _openWriteMemorySheet(context, isDark),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 4, horizontalPadding, 110),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final mem = _travelMemories[index];
                    final hasImg = (mem['imageUrl'] ?? '').toString().isNotEmpty;

                    return GestureDetector(
                      onTap: () => _openMemoryDetailDialog(context, mem, isDark),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: cardSurface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: cardStroke, width: 1.2),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasImg)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
                                child: safeNetworkImageWidget(mem['imageUrl'], height: 160, width: double.infinity, fit: BoxFit.cover),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: AppColors.forest.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                                        child: Text(mem['mood'] ?? "🏕️", style: const TextStyle(fontSize: 18)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              mem['title'] ?? '',
                                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textMain),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                const Icon(Icons.location_on_rounded, size: 13, color: AppColors.emerald),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    mem['location'] ?? '',
                                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: textMuted),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        mem['date'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppColors.mint),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      if ((mem['stayed'] ?? '').toString().isNotEmpty)
                                        _buildPillChip(Icons.hotel_rounded, mem['stayed']!, AppColors.forest, forestColor),
                                      if ((mem['food'] ?? '').toString().isNotEmpty)
                                        _buildPillChip(Icons.restaurant_rounded, mem['food']!, Colors.orange, Colors.orange),
                                      if ((mem['crew'] ?? '').toString().isNotEmpty)
                                        _buildPillChip(Icons.people_alt_rounded, mem['crew']!, AppColors.mint, AppColors.mint),
                                    ],
                                  ),

                                  if ((mem['story'] ?? '').toString().isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      mem['story']!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12.5, color: textMain.withOpacity(0.85), height: 1.4),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: _travelMemories.length,
                ),
              ),
            ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final horizontalPadding = isTablet ? 32.0 : 20.0;

    return ListenableBuilder(
      listenable: AppThemeManager.instance,
      builder: (context, _) {
        final isDark = AppThemeManager.instance.isDarkMode;
        final pageBg = isDark ? const Color(0xFF0F1713) : AppColors.canvasBg;
        final cardSurface = isDark ? const Color(0xFF17241C) : AppColors.cardSurface;
        final cardStroke = isDark ? const Color(0xFF263D2F) : AppColors.cardStroke;
        final textMain = isDark ? Colors.white : AppColors.textMain;
        final textMuted = isDark ? const Color(0xFF9EAF9F) : AppColors.textMuted;
        final forestColor = isDark ? const Color(0xFF4ADE80) : AppColors.forest;

        return Scaffold(
          backgroundColor: pageBg,
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 85.0),
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 280),
              offset: _showBackToTop ? Offset.zero : const Offset(0, 2),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 280),
                opacity: _showBackToTop ? 1.0 : 0.0,
                child: FloatingActionButton.small(
                  elevation: 5,
                  backgroundColor: AppColors.forest,
                  shape: const CircleBorder(),
                  onPressed: _scrollToTop,
                  child: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
          body: ListenableBuilder(
            listenable: AuthController.I,
            builder: (context, _) {
              final user = AuthController.I.currentUser;

              if (user == null) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(color: cardSurface, shape: BoxShape.circle),
                          child: const Icon(Icons.person_pin_circle_rounded, size: 64, color: AppColors.forest),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          "Pioneer Profile Locked",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: forestColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Sign in with Google to access your expeditions, GPS routes, and explorer community badges.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textMuted, fontSize: 13.5, height: 1.4),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.login_rounded, color: Colors.white, size: 20),
                            label: const Text(
                              "Sign In with Google",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15.5),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.forest,
                              elevation: 4,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            onPressed: _startGoogleSignInWithAnimation,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final feedCtrl = FeedController.I;

              final userPosts = feedCtrl.posts.where((p) {
                if (p is! Map<String, dynamic>) return false;
                final uid = (p['userId'] ?? '').toString();
                final author = (p['authorName'] ?? '').toString();
                return uid == user.uid ||
                    (author.isNotEmpty && author.trim().toLowerCase() == user.name.trim().toLowerCase());
              }).cast<Map<String, dynamic>>().toList();

              final savedPosts = feedCtrl.posts.where((p) {
                if (p is! Map<String, dynamic>) return false;
                final id = _getPostId(p);
                bool isSaved = false;
                try {
                  isSaved = feedCtrl.bookmarked.contains(id);
                } catch (_) {}
                if (!isSaved) {
                  isSaved = p['isSaved'] == true || p['isBookmarked'] == true;
                }
                return isSaved;
              }).cast<Map<String, dynamic>>().toList();

              final expeditionsCount = userPosts.length;
              final savedCount = savedPosts.length;
              final totalLikesReceived = userPosts.fold<int>(0, (sum, p) => sum + _getPostLikes(p));
              final karmaScore = totalLikesReceived + (_followersCount * 5) + (savedCount * 2);

              final dynamicBadges = [
                {
                  "title": "Ceylon Pioneer",
                  "desc": "Verified conservation scout & community contributor",
                  "icon": Icons.verified_rounded,
                  "color": AppColors.forest,
                  "tier": "Tier-1 Pioneer",
                  "isUnlocked": true,
                },
                {
                  "title": "Expedition Scout",
                  "desc": expeditionsCount > 0
                      ? "Logged $expeditionsCount wilderness expeditions"
                      : "Log your first summit expedition to unlock",
                  "icon": Icons.terrain_rounded,
                  "color": AppColors.emerald,
                  "tier": "Summit Explorer",
                  "isUnlocked": expeditionsCount > 0,
                },
                {
                  "title": "Trail Pathfinder",
                  "desc": savedCount > 0
                      ? "Actively tracking $savedCount off-grid routes"
                      : "Bookmark routes to unlock offline GPS sync",
                  "icon": Icons.bookmark_added_rounded,
                  "color": AppColors.mint,
                  "tier": "Navigator",
                  "isUnlocked": savedCount > 0,
                },
                {
                  "title": "Wilderness Master",
                  "desc": karmaScore >= 20
                      ? "Earned high karma among peer scouts"
                      : "Reach 20+ explorer karma points to unlock",
                  "icon": Icons.military_tech_rounded,
                  "color": const Color(0xFFE5A11A),
                  "tier": "Honor Rank",
                  "isUnlocked": karmaScore >= 20,
                },
              ];

              return RefreshIndicator(
                color: AppColors.forest,
                onRefresh: () async {
                  HapticFeedback.lightImpact();
                  _setupRealtimeStreams();
                  await Future.delayed(const Duration(milliseconds: 600));
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    SliverToBoxAdapter(
                      child: ProfileHeroHeader(
                        user: user,
                        isDark: isDark,
                        pageBg: pageBg,
                        onOpenShare: () => showShareProfileSheet(context, user),
                        onOpenSettings: () => showSettingsModal(context, onSignOut: _handleSignOut),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(horizontalPadding, 60, horizontalPadding, 10),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  user.name,
                                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: forestColor, letterSpacing: -0.4),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_rounded, size: 20, color: AppColors.emerald),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // DYNAMIC USER ROLE BADGE
                            GestureDetector(
                              onTap: () => _openRoleSelectorModal(context, isDark),
                              child: Container(
                                margin: const EdgeInsets.only(top: 4, bottom: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _userRole == 'explorer' ? AppColors.forest.withOpacity(0.12) : AppColors.emerald.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _userRole == 'explorer' ? AppColors.forest.withOpacity(0.3) : AppColors.emerald, width: 1.2),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_getRoleIcon(_userRole), size: 14, color: forestColor),
                                    const SizedBox(width: 6),
                                    Text(
                                      _getRoleLabel(_userRole),
                                      style: TextStyle(fontWeight: FontWeight.w900, color: forestColor, fontSize: 12),
                                    ),
                                    const SizedBox(width: 5),
                                    Icon(Icons.unfold_more_rounded, size: 13, color: textMuted),
                                  ],
                                ),
                              ),
                            ),

                            // If Partner: Show Rating & Reviews Count Banner
                            if (_userRole != 'explorer') ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: cardSurface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: cardStroke),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 17),
                                    const SizedBox(width: 4),
                                    Text("$_partnerRating", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: textMain)),
                                    Text(" ($_partnerReviewsCount reviews)", style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 8),
                            Text(
                              user.bio.isNotEmpty ? user.bio : "Highlands explorer & nature photography enthusiast.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textMuted, fontSize: 13.5, height: 1.45, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 12),

                            GestureDetector(
                              onTap: () => showStatusEditorModal(
                                context,
                                currentStatus: _activeStatus,
                                currentEmoji: _statusEmoji,
                                onStatusChanged: (status, emoji) {
                                  setState(() {
                                    _activeStatus = status;
                                    _statusEmoji = emoji;
                                  });
                                  _updateLiveStatusInCloud(status, emoji);
                                },
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: cardSurface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: cardStroke, width: 1.2),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_statusEmoji, style: const TextStyle(fontSize: 12)),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _activeStatus,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: forestColor),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.edit_outlined, size: 13, color: textMuted),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            ProfileStatsStrip(
                              followersCount: _followersCount,
                              followingCount: _followingCount,
                              karmaScore: karmaScore,
                              cardSurface: cardSurface,
                              cardStroke: cardStroke,
                              forestColor: forestColor,
                              textMuted: textMuted,
                              onFollowersTap: () => showUsersListModal(context, "Followers", _followersCount, _followersList),
                              onFollowingTap: () => showUsersListModal(context, "Following", _followingCount, _followingList),
                            ),
                            const SizedBox(height: 16),

                            // ACTION BUTTONS (CLEAN WITHOUT GUILD BUTTON)
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
                                    label: const Text("Edit Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.forest,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      padding: const EdgeInsets.symmetric(vertical: 13),
                                    ),
                                    onPressed: () => showEditProfileSheet(
                                      context,
                                      user,
                                      (updated) async {
                                        await AuthController.I.updateProfile(updated);
                                        await _saveUserSession(updated);
                                        _showToast("Explorer profile updated successfully!");
                                      },
                                      currentRole: _userRole,
                                      onRoleChanged: (newRole) => _updateUserRoleInCloud(newRole),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SocialIconButton(
                                  icon: Icons.chat_bubble_outline_rounded,
                                  iconColor: const Color(0xFF25D366),
                                  onTap: () => _handleSocialConnect("WhatsApp"),
                                  bg: cardSurface,
                                  stroke: cardStroke,
                                ),
                                const SizedBox(width: 8),
                                SocialIconButton(
                                  icon: Icons.camera_alt_outlined,
                                  iconColor: const Color(0xFFE1306C),
                                  onTap: () => _handleSocialConnect("Instagram"),
                                  bg: cardSurface,
                                  stroke: cardStroke,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(horizontalPadding, 10, horizontalPadding, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Expedition Highlights", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: forestColor)),
                                if (_highlights.isNotEmpty)
                                  Text("Hold to remove", style: TextStyle(fontSize: 11, color: textMuted)),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 105,
                            child: ListView.separated(
                              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: _highlights.length + 1,
                              separatorBuilder: (_, __) => const SizedBox(width: 14),
                              itemBuilder: (context, index) {
                                if (index == _highlights.length) {
                                  return GestureDetector(
                                    onTap: () => showAddNewHighlightDialog(context, (newH) {
                                      _addHighlightToCloud(newH);
                                    }),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 64,
                                          height: 64,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: cardSurface,
                                            border: Border.all(color: cardStroke, width: 1.5),
                                          ),
                                          child: Icon(Icons.add, color: forestColor, size: 24),
                                        ),
                                        const SizedBox(height: 6),
                                        Text("New", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: textMuted)),
                                      ],
                                    ),
                                  );
                                }

                                final item = _highlights[index];
                                final convertedList = _highlights
                                    .map((e) => {"title": (e["title"] ?? "").toString(), "img": (e["img"] ?? "").toString()})
                                    .toList();

                                return GestureDetector(
                                  onTap: () => showHighlightStoryViewer(context, convertedList, index),
                                  onLongPress: () {
                                    HapticFeedback.heavyImpact();
                                    if (item['id'] != null) {
                                      _removeHighlightFromCloud(item['id'].toString());
                                    }
                                  },
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(2.6),
                                        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.storyRing),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(color: isDark ? const Color(0xFF17241C) : Colors.white, shape: BoxShape.circle),
                                          child: CircleAvatar(
                                            radius: 28,
                                            backgroundImage: safeNetworkImage(item["img"] ?? ''),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(item["title"] ?? '', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: textMain)),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(horizontalPadding, 10, horizontalPadding, 14),
                        child: ProfileDetailsCard(
                          user: user,
                          cardSurface: cardSurface,
                          cardStroke: cardStroke,
                          forestColor: forestColor,
                          textMain: textMain,
                          textMuted: textMuted,
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: cardSurface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cardStroke, width: 1.2),
                          ),
                          child: Row(
                            children: [
                              _buildTabItem(0, Icons.grid_view_rounded, "Posts", isDark),
                              _buildTabItem(1, Icons.bookmark_added_rounded, "Saved", isDark),
                              _buildTabItem(2, Icons.military_tech_rounded, "Badges", isDark),
                              _buildTabItem(3, Icons.auto_stories_rounded, "Memories", isDark),
                            ],
                          ),
                        ),
                      ),
                    ),

                    ..._buildActiveTabSlivers(
                      isTablet: isTablet,
                      horizontalPadding: horizontalPadding,
                      userPosts: userPosts,
                      savedPosts: savedPosts,
                      dynamicBadges: dynamicBadges,
                      cardSurface: cardSurface,
                      cardStroke: cardStroke,
                      textMain: textMain,
                      textMuted: textMuted,
                      forestColor: forestColor,
                      isDark: isDark,
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

  Widget _buildEmptyState(String title, String desc, IconData icon, Color cardSurface, Color forestColor, Color textMuted) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 110),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: cardSurface, shape: BoxShape.circle),
                child: Icon(icon, size: 44, color: textMuted),
              ),
              const SizedBox(height: 14),
              Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: forestColor)),
              const SizedBox(height: 6),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: TextStyle(color: textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillChip(IconData icon, String text, Color baseColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: baseColor),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label, bool isDark) {
    final isSelected = _selectedTabIndex == index;
    final activeBg = isDark ? const Color(0xFF223528) : Colors.white;
    final activeColor = isDark ? const Color(0xFF4ADE80) : AppColors.forest;
    final inactiveColor = isDark ? const Color(0xFF7E9281) : AppColors.textMuted;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          if (_selectedTabIndex == index) {
            _scrollToTop();
          } else {
            setState(() => _selectedTabIndex = index);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: isSelected ? activeColor : inactiveColor),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
