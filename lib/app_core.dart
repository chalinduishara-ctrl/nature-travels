import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

// ============================================================================
// CONFIGURATION (Render Cloud Production + Localhost Fallback)
// ============================================================================
class AppConfig {
  static String railwayUrl = 'https://nature-travels-backend-ounb.onrender.com';
  static const String localHost = '127.0.0.1';
  static const int localPort = 5000;
  static bool useProduction = true;

  static String get origin {
    if (useProduction && railwayUrl.isNotEmpty && !railwayUrl.contains('YOUR_RAILWAY_APP')) {
      return railwayUrl.endsWith('/') ? railwayUrl.substring(0, railwayUrl.length - 1) : railwayUrl;
    }
    return 'http://$localHost:$localPort';
  }

  static String get api => '$origin/api';

  static void setProductionUrl(String url) {
    railwayUrl = url.trim();
    useProduction = true;
  }
}

// ============================================================================
// LUXURY PRODUCT DESIGN PALETTE (COMPILE-SAFE + THEME-ADAPTIVE)
// ============================================================================
class AppColors {
  // Brand accents
  static const forest = Color(0xFF092317);
  static const deepGreen = Color(0xFF103A24);
  static const green = Color(0xFF1C5237);
  static const mint = Color(0xFF2C8457);
  static const emerald = Color(0xFF3DA36E);
  static const lightMint = Color(0xFF65D498);
  static const goldAccent = Color(0xFFD4AF37);

  // 🌿 Light Mode Defaults (Keep static const so 'const' widgets compile cleanly)
  static const canvasBg = Color(0xFFE5EDE7);
  static const cardSurface = Color(0xFFFFFFFF);
  static const cardStroke = Color(0xFFCFDDD3);
  static const softPlate = Color(0xFFD9E5DC);
  static const tint = Color(0xFFEAF3ED);

  static const textMain = Color(0xFF0D2116);
  static const textMuted = Color(0xFF566D60);
  static const textSubtle = Color(0xFF82988C);

  // 🌲 Luxury Deep Forest Dark Mode Palette
  static const darkCanvasBg = Color(0xFF08120D);
  static const darkCardSurface = Color(0xFF101E17);
  static const darkCardStroke = Color(0xFF1C3125);
  static const darkSoftPlate = Color(0xFF15261D);
  static const darkTint = Color(0xFF182A20);

  static const darkTextMain = Color(0xFFF1F6F3);
  static const darkTextMuted = Color(0xFF90A79A);
  static const darkTextSubtle = Color(0xFF688172);

  // 🔄 Theme State Tracker
  static bool isDarkMode = false;

  // 🔄 Theme-Adaptive Resolvers (Context-aware for dynamic Light/Dark switching)
  static Color bg([BuildContext? context]) {
    final dark = (context != null && Theme.of(context).brightness == Brightness.dark) || isDarkMode;
    return dark ? darkCanvasBg : canvasBg;
  }

  static Color card([BuildContext? context]) {
    final dark = (context != null && Theme.of(context).brightness == Brightness.dark) || isDarkMode;
    return dark ? darkCardSurface : cardSurface;
  }

  static Color stroke([BuildContext? context]) {
    final dark = (context != null && Theme.of(context).brightness == Brightness.dark) || isDarkMode;
    return dark ? darkCardStroke : cardStroke;
  }

  static Color text([BuildContext? context]) {
    final dark = (context != null && Theme.of(context).brightness == Brightness.dark) || isDarkMode;
    return dark ? darkTextMain : textMain;
  }

  static Color muted([BuildContext? context]) {
    final dark = (context != null && Theme.of(context).brightness == Brightness.dark) || isDarkMode;
    return dark ? darkTextMuted : textMuted;
  }

  static Color tintBg([BuildContext? context]) {
    final dark = (context != null && Theme.of(context).brightness == Brightness.dark) || isDarkMode;
    return dark ? darkTint : tint;
  }

  // Gradients
  static const LinearGradient greenGradient = LinearGradient(
    colors: [Color(0xFF3DA36E), Color(0xFF1C5237), Color(0xFF092317)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient storyRing = LinearGradient(
    colors: [Color(0xFF65D498), Color(0xFF2C8457), Color(0xFF092317)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

// ============================================================================
// UNIVERSAL MEDIA URL RESOLVER
// ============================================================================
String resolveMediaUrl(String? url) {
  if (url == null || url.trim().isEmpty) return '';
  String clean = url.trim();

  if (clean.startsWith('"') && clean.endsWith('"')) {
    clean = clean.substring(1, clean.length - 1);
  }

  if (clean.contains('.r2.dev/')) {
    final path = clean.split('.r2.dev/').last;
    return '${AppConfig.origin}/api/media/$path';
  }

  return clean;
}

ImageProvider safeNetworkImage(
  String? url, {
  String fallback = 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
}) {
  final resolved = resolveMediaUrl(url);
  if (resolved.isEmpty || !resolved.startsWith('http')) {
    return NetworkImage(fallback);
  }
  return NetworkImage(resolved);
}

Widget safeNetworkImageWidget(
  String? url, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  BorderRadius? borderRadius,
}) {
  final raw = resolveMediaUrl(url);

  if (raw.startsWith('/') || raw.startsWith('file://')) {
    final file = File(raw.replaceFirst('file://', ''));
    if (file.existsSync()) {
      final img = Image.file(file, width: width, height: height, fit: fit);
      return borderRadius != null ? ClipRRect(borderRadius: borderRadius, child: img) : img;
    }
  }

  final validUrl = (raw.isNotEmpty && raw.startsWith('http'))
      ? raw
      : 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800';

  final img = Image.network(
    validUrl,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (context, error, stackTrace) => Container(
      width: width,
      height: height,
      color: AppColors.tint,
      child: const Center(
        child: Icon(Icons.terrain_rounded, color: AppColors.emerald, size: 32),
      ),
    ),
    loadingBuilder: (context, child, progress) {
      if (progress == null) return child;
      return Container(
        width: width,
        height: height,
        color: AppColors.tint,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.emerald, strokeWidth: 2),
        ),
      );
    },
  );

  if (borderRadius != null) {
    return ClipRRect(borderRadius: borderRadius, child: img);
  }
  return img;
}

// ============================================================================
// AUTH CONTROLLER (Google Sign-In + Backend Sync)
// ============================================================================
class AuthUser {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final String bio;
  final String livesIn;
  final String fromLocation;
  final String occupation;
  final String coverUrl;

  AuthUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.bio,
    required this.livesIn,
    required this.fromLocation,
    required this.occupation,
    required this.coverUrl,
  });

  static String _valid(dynamic val, String fallback) {
    if (val == null) return fallback;
    final s = val.toString().trim();
    return (s.isEmpty || !s.startsWith('http')) ? fallback : s;
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      uid: (json['uid'] ?? json['id'] ?? json['_id'] ?? 'guest').toString(),
      name: json['name'] ?? json['displayName'] ?? 'Nature Traveler',
      email: json['email'] ?? '',
      photoUrl: _valid(json['photoUrl'] ?? json['photoURL'] ?? json['avatar'], 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150'),
      bio: json['bio'] ?? 'Exploring wild Sri Lanka 🌿',
      livesIn: json['livesIn'] ?? 'Sri Lanka',
      fromLocation: json['fromLocation'] ?? 'Earth',
      occupation: json['occupation'] ?? 'Wilderness Explorer',
      coverUrl: _valid(json['coverUrl'], 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800'),
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'name': name,
    'email': email,
    'photoUrl': photoUrl,
    'bio': bio,
    'livesIn': livesIn,
    'fromLocation': fromLocation,
    'occupation': occupation,
    'coverUrl': coverUrl,
  };
}

class AuthController extends ChangeNotifier {
  AuthController._();
  static final AuthController I = AuthController._();

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  AuthUser? currentUser;
  bool isLoggingIn = false;

  bool get isLoggedIn => currentUser != null && currentUser!.uid != 'guest';

  Future<bool> signInWithGoogle() async {
    isLoggingIn = true;
    notifyListeners();
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        isLoggingIn = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication auth = await account.authentication;

      final res = await http.post(
        Uri.parse('${AppConfig.api}/auth/google-login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'idToken': auth.idToken,
          'accessToken': auth.accessToken,
          'uid': account.id,
          'name': account.displayName,
          'email': account.email,
          'photoUrl': account.photoUrl,
        }),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        currentUser = AuthUser.fromJson(data['user'] ?? data);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
    } finally {
      isLoggingIn = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> updateProfile(AuthUser updated) async {
    try {
      final res = await http.put(
        Uri.parse('${AppConfig.api}/users/${updated.uid}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updated.toJson()),
      );
      if (res.statusCode == 200) {
        currentUser = updated;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Update Profile error: $e");
    }
    return false;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    currentUser = null;
    notifyListeners();
  }
}

// ============================================================================
// REALTIME FEED CONTROLLER (SAFE PARSING & DATABASE SYNC ENGINE)
// ============================================================================
class FeedController extends ChangeNotifier {
  FeedController._();
  static final FeedController I = FeedController._();

  List<Map<String, dynamic>> posts = [];
  List<Map<String, dynamic>> stories = [];
  final Set<String> liked = {};
  final Set<String> bookmarked = {};
  final Map<String, List<Map<String, dynamic>>> comments = {};

  bool loading = true;
  Timer? _timer;

  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => refresh(silent: true));
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  // 🔄 DATABASE REFRESH (Robust Parsing for MongoDB + Render Cold Starts)
  Future<void> refresh({bool silent = false}) async {
    if (!silent && posts.isEmpty) {
      loading = true;
      notifyListeners();
    }

    // 1. Fetch Posts from Database
    try {
      final postsUri = Uri.parse('${AppConfig.api}/posts');
      final postRes = await http.get(postsUri).timeout(const Duration(seconds: 30));

      if (postRes.statusCode == 200) {
        final decoded = json.decode(postRes.body);
        List<dynamic> rawList = [];

        if (decoded is List) {
          rawList = decoded;
        } else if (decoded is Map) {
          if (decoded['posts'] is List) {
            rawList = decoded['posts'];
          } else if (decoded['data'] is List) {
            rawList = decoded['data'];
          } else if (decoded['expeditions'] is List) {
            rawList = decoded['expeditions'];
          }
        }

        final parsedPosts = rawList.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          if (map['id'] == null && map['_id'] != null) {
            map['id'] = map['_id'].toString();
          }
          return map;
        }).toList();

        posts = parsedPosts;
        debugPrint("✅ Database එකෙන් Posts ${posts.length} ක් Load විය!");
      } else {
        debugPrint("❌ Post fetch status: ${postRes.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Posts Fetch Error: $e");
    }

    // 2. Fetch Stories independently
    try {
      final storiesUri = Uri.parse('${AppConfig.api}/stories');
      final storyRes = await http.get(storiesUri).timeout(const Duration(seconds: 20));

      if (storyRes.statusCode == 200) {
        final decodedStories = json.decode(storyRes.body);
        List<dynamic> rawStories = [];

        if (decodedStories is List) {
          rawStories = decodedStories;
        } else if (decodedStories is Map && decodedStories['stories'] is List) {
          rawStories = decodedStories['stories'];
        }

        stories = rawStories.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          if (map['id'] == null && map['_id'] != null) {
            map['id'] = map['_id'].toString();
          }
          return map;
        }).toList();
      }
    } catch (e) {
      debugPrint("Stories Fetch Note: $e");
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String> _upload(File file) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse('${AppConfig.api}/upload'));
      req.headers['Accept'] = 'application/json';

      final multipartFile = await http.MultipartFile.fromPath(
        'image',
        file.path,
        filename: file.path.split('/').last,
      );
      req.files.add(multipartFile);

      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = json.decode(res.body);
        final url = (data['imageUrl'] ?? data['url'] ?? data['mediaUrl'] ?? '').toString().trim();
        return url;
      } else {
        throw Exception("Server returned status: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("Upload Exception: $e");
      rethrow;
    }
  }

  Future<void> createPost({required String description, required String location, File? image}) async {
    String imageUrl = '';
    if (image != null) {
      imageUrl = await _upload(image);
    }

    final user = AuthController.I.currentUser;

    final tempPost = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'title': description,
      'description': description,
      'location': location.isEmpty ? 'Sri Lanka' : location,
      'imageUrl': imageUrl.isNotEmpty ? imageUrl : (image?.path ?? ''),
      'userId': user?.uid ?? 'guest',
      'authorEmail': user?.email ?? '',
      'authorName': user?.name ?? 'Nature Explorer',
      'authorPhoto': user?.photoUrl ?? '',
      'likesCount': 0,
      'commentsCount': 0,
      'createdAt': DateTime.now().toIso8601String(),
    };

    posts.insert(0, tempPost);
    notifyListeners();

    try {
      final res = await http.post(
        Uri.parse('${AppConfig.api}/posts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'title': description,
          'description': description,
          'location': location.isEmpty ? 'Sri Lanka' : location,
          'imageUrl': imageUrl,
          'userId': user?.uid ?? 'guest',
          'authorEmail': user?.email ?? '',
          'authorName': user?.name ?? 'Nature Explorer',
          'authorPhoto': user?.photoUrl ?? '',
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = json.decode(res.body);
        final rawPost = data['post'] ?? data['data'] ?? data;
        if (rawPost is Map) {
          final savedPost = Map<String, dynamic>.from(rawPost);
          if (savedPost['id'] == null && savedPost['_id'] != null) {
            savedPost['id'] = savedPost['_id'].toString();
          }
          final index = posts.indexWhere((p) => p['id'] == tempPost['id']);
          if (index != -1) {
            posts[index] = savedPost;
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint("Error saving post to backend: $e");
    } finally {
      await refresh(silent: true);
    }
  }

  bool isPostAuthor(Map<String, dynamic> post) {
    final user = AuthController.I.currentUser;
    if (user == null || !AuthController.I.isLoggedIn) return false;

    final myUid = user.uid.trim();
    final myEmail = user.email.toLowerCase().trim();
    final myName = user.name.toLowerCase().trim();

    final postAuthorId = '${post['userId'] ?? post['authorId'] ?? post['userUid'] ?? post['uid'] ?? ''}'.trim();
    final postAuthorEmail = '${post['authorEmail'] ?? post['userEmail'] ?? post['email'] ?? ''}'.toLowerCase().trim();
    final postAuthorName = '${post['authorName'] ?? post['userName'] ?? ''}'.toLowerCase().trim();

    if (myUid.isNotEmpty && postAuthorId.isNotEmpty && myUid == postAuthorId) return true;
    if (myEmail.isNotEmpty && postAuthorEmail.isNotEmpty && myEmail == postAuthorEmail) return true;
    if (postAuthorId.isEmpty && postAuthorEmail.isEmpty && myName.isNotEmpty && myName == postAuthorName) return true;

    return false;
  }

  Future<bool> deletePost(String postId) async {
    final user = AuthController.I.currentUser;
    if (user == null) return false;

    final originalPosts = List<Map<String, dynamic>>.from(posts);
    posts.removeWhere((p) => '${p['id']}' == postId);
    notifyListeners();

    try {
      final res = await http.delete(
        Uri.parse('${AppConfig.api}/posts/$postId'),
        headers: {
          'Content-Type': 'application/json',
          'x-user-uid': user.uid,
          'x-user-email': user.email,
        },
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        return true;
      } else {
        posts = originalPosts;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint("Delete post error: $e");
      posts = originalPosts;
      notifyListeners();
      return false;
    }
  }

  Future<void> addStory(File image) async {
    final imageUrl = await _upload(image);
    final user = AuthController.I.currentUser;

    final tempStory = {
      'id': 'temp_story_${DateTime.now().millisecondsSinceEpoch}',
      'mediaUrl': imageUrl.isNotEmpty ? imageUrl : image.path,
      'authorName': user?.name ?? 'Explorer',
      'userPhoto': user?.photoUrl ?? '',
      'userId': user?.uid ?? 'guest',
      'caption': 'Living the wild trail 🌿',
    };
    stories.insert(0, tempStory);
    notifyListeners();

    try {
      await http.post(
        Uri.parse('${AppConfig.api}/stories'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'mediaUrl': imageUrl,
          'authorName': user?.name ?? 'Explorer',
          'userPhoto': user?.photoUrl ?? '',
          'userId': user?.uid ?? 'guest',
          'caption': 'Living the wild trail 🌿',
        }),
      );
    } catch (e) {
      debugPrint("Story save error: $e");
    } finally {
      await refresh(silent: true);
    }
  }

  Future<void> toggleLike(Map<String, dynamic> post) async {
    final id = '${post['id']}';
    final wasLiked = liked.contains(id);
    final count = int.tryParse('${post['likesCount'] ?? 0}') ?? 0;

    wasLiked ? liked.remove(id) : liked.add(id);
    post['likesCount'] = wasLiked ? math.max(0, count - 1) : count + 1;
    notifyListeners();

    try {
      await http.put(
        Uri.parse('${AppConfig.api}/posts/$id/like'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'action': wasLiked ? 'unlike' : 'like'}),
      );
    } catch (_) {
      wasLiked ? liked.add(id) : liked.remove(id);
      post['likesCount'] = count;
      notifyListeners();
    }
  }

  void toggleBookmark(String postId) {
    if (bookmarked.contains(postId)) {
      bookmarked.remove(postId);
    } else {
      bookmarked.add(postId);
    }
    notifyListeners();
  }

  Future<void> fetchComments(String postId) async {
    try {
      final res = await http.get(Uri.parse('${AppConfig.api}/posts/$postId/comments'));
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        List<dynamic> list = [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map && decoded['comments'] is List) {
          list = decoded['comments'];
        }
        comments[postId] = list.map((e) => Map<String, dynamic>.from(e)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> getComments(String postId) {
    return comments[postId] ?? [];
  }

  Future<void> addComment(String postId, String commentText) async {
    final user = AuthController.I.currentUser;
    final newEntry = {
      'author': user?.name ?? 'Wild Pioneer',
      'text': commentText,
      'time': 'Just now',
      'photo': user?.photoUrl ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
    };

    if (!comments.containsKey(postId)) {
      comments[postId] = [];
    }
    comments[postId]!.insert(0, newEntry);

    final postIndex = posts.indexWhere((p) => '${p['id']}' == postId);
    if (postIndex != -1) {
      posts[postIndex]['commentsCount'] = (posts[postIndex]['commentsCount'] ?? 0) + 1;
    }
    notifyListeners();

    try {
      await http.post(
        Uri.parse('${AppConfig.api}/posts/$postId/comments'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': commentText,
          'author': user?.name ?? 'Wild Pioneer',
          'authorName': user?.name ?? 'Wild Pioneer',
          'photo': user?.photoUrl ?? '',
          'userId': user?.uid ?? 'guest',
        }),
      );
    } catch (e) {
      debugPrint("Add comment error: $e");
    }
  }
}

// ============================================================================
// GLOBAL MODAL (THEME-ADAPTIVE GOOGLE SIGN-IN PROMPT)
// ============================================================================
void showLoginAlert(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark || AppColors.isDarkMode;
  final surface = isDark ? AppColors.darkCardSurface : AppColors.cardSurface;
  final stroke = isDark ? AppColors.darkCardStroke : AppColors.cardStroke;
  final textPrimary = isDark ? AppColors.darkTextMain : AppColors.textMain;
  final textSecondary = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
  final tintBg = isDark ? AppColors.darkTint : AppColors.tint;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: stroke),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tintBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_person_rounded, size: 40, color: AppColors.emerald),
          ),
          const SizedBox(height: 14),
          Text(
            "Google Sign-In Required",
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Please connect with your verified account to post wild discoveries, write comments, and join expeditions.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textSecondary,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.login_rounded, color: Colors.white),
              label: const Text(
                "Continue with Google",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await AuthController.I.signInWithGoogle();
              },
            ),
          )
        ],
      ),
    ),
  );
}
