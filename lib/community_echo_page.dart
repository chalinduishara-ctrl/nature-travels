import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_core.dart';
import 'sri_lanka_100_hubs.dart';

class CommunityBackendConfig {
  static String? _manualOverride;

  static String get baseUrl {
    if (_manualOverride != null && _manualOverride!.trim().isNotEmpty) {
      String custom = _manualOverride!.trim();
      while (custom.endsWith('/')) {
        custom = custom.substring(0, custom.length - 1);
      }
      return custom.endsWith('/api') ? custom : '$custom/api';
    }

    String base = AppConfig.api.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  static set manualOverride(String? url) {
    _manualOverride = url;
  }

  static String get uploadUrl => '$baseUrl/upload';
}

class CommunityEchoPage extends StatefulWidget {
  const CommunityEchoPage({super.key});

  @override
  State<CommunityEchoPage> createState() => _CommunityEchoPageState();
}

class _CommunityEchoPageState extends State<CommunityEchoPage> {
  static final List<Map<String, dynamic>> _corePublicChannels = [
    {
      'id': 'public_general',
      'name': '🌍 Ceylon Travellers Hub',
      'description': 'Open community chat for all explorers across Sri Lanka.',
      'category': 'Public Hub',
      'isDirect': false,
      'isPublic': true,
      'iconUrl': '',
      'memberCount': 'All Travelers',
      'lastMessage': 'Welcome to the open Ceylon travelers community!',
      'updatedAt': DateTime.now().toIso8601String(),
    },
    {
      'id': 'public_hiking',
      'name': '🥾 Hiking & Trail Explorers',
      'description': 'Live trail conditions, Knuckles, Ella, Adams Peak & misty summits.',
      'category': 'Hiking',
      'isDirect': false,
      'isPublic': true,
      'iconUrl': '',
      'memberCount': 'Hikers',
      'lastMessage': 'Share live trail updates and hiking tips here.',
      'updatedAt': DateTime.now().toIso8601String(),
    },
    {
      'id': 'public_camping',
      'name': '🏕️ Camping & Wilderness Gear',
      'description': 'Campgrounds, permits, night skies, and gear discussions.',
      'category': 'Camping',
      'isDirect': false,
      'isPublic': true,
      'iconUrl': '',
      'memberCount': 'Campers',
      'lastMessage': 'Find safe camp spots and share camping gear experiences.',
      'updatedAt': DateTime.now().toIso8601String(),
    },
    {
      'id': 'public_wildlife',
      'name': '🐘 Wildlife & Safari Sightings',
      'description': 'Yala, Wilpattu, birding trails, and ethical wildlife spotting.',
      'category': 'Wildlife',
      'isDirect': false,
      'isPublic': true,
      'iconUrl': '',
      'memberCount': 'Nature Lovers',
      'lastMessage': 'Report safe wildlife encounters and national park conditions.',
      'updatedAt': DateTime.now().toIso8601String(),
    },
    {
      'id': 'public_safety',
      'name': '🚨 Live Travel & Weather Alerts',
      'description': 'Rainfall, landslides, road closures, and emergency trail warnings.',
      'category': 'Safety',
      'isDirect': false,
      'isPublic': true,
      'iconUrl': '',
      'memberCount': 'Live Radar',
      'lastMessage': 'Keep everyone safe! Share instant trail alerts here.',
      'updatedAt': DateTime.now().toIso8601String(),
    },
  ];

  static List<Map<String, dynamic>> get allAvailableHubs {
    final List<Map<String, dynamic>> all = List.from(_corePublicChannels);
    for (final hub in sriLanka100Hubs) {
      all.add({
        'id': hub['id'] ?? '',
        'name': hub['name'] ?? 'Hub',
        'description': hub['description'] ?? '',
        'category': hub['category'] ?? 'Public Hub',
        'province': hub['province'] ?? '',
        'district': hub['district'] ?? '',
        'isDirect': false,
        'isPublic': true,
        'iconUrl': '',
        'memberCount': hub['memberCount'] ?? 'Explorers',
        'lastMessage': hub['lastMessage'] ?? 'Live destination updates.',
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
    return all;
  }

  List<Map<String, dynamic>> _channels = [];
  Set<String> _joinedChannelIds = {'public_general'};
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  Timer? _realtimeChannelPoller;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Public Hub',
    'Hiking',
    'Camping',
    'Wildlife',
    'Safety',
    'Direct Chats',
  ];

  String get _currentUid {
    final authUid = AuthController.I.currentUser?.uid;
    if (authUid != null && authUid.trim().isNotEmpty) return authUid.trim();
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  String get _currentEmail {
    final authEmail = AuthController.I.currentUser?.email;
    if (authEmail != null && authEmail.trim().isNotEmpty) return authEmail.trim();
    return FirebaseAuth.instance.currentUser?.email ?? '';
  }

  String get _currentName {
    final authName = AuthController.I.currentUser?.name;
    if (authName != null && authName.trim().isNotEmpty) return authName.trim();
    final fbName = FirebaseAuth.instance.currentUser?.displayName;
    if (fbName != null && fbName.trim().isNotEmpty) return fbName.trim();
    if (_currentEmail.isNotEmpty && _currentEmail.contains('@')) {
      return _currentEmail.split('@')[0];
    }
    return 'Traveler';
  }

  String get _currentPhoto {
    final authPhoto = AuthController.I.currentUser?.photoUrl;
    if (authPhoto != null && authPhoto.trim().isNotEmpty) return authPhoto.trim();
    return FirebaseAuth.instance.currentUser?.photoURL ?? '';
  }

  String get _cacheKey => 'cached_channels_${_currentUid.isNotEmpty ? _currentUid : "guest"}';
  String get _joinedKey => 'joined_channels_${_currentUid.isNotEmpty ? _currentUid : "guest"}';

  bool _isCurrentUser(dynamic uid, dynamic email, [dynamic name]) {
    final myUid = _currentUid.toLowerCase();
    final myEmail = _currentEmail.toLowerCase();
    final checkUid = (uid ?? '').toString().trim().toLowerCase();
    final checkEmail = (email ?? '').toString().trim().toLowerCase();

    if (checkUid.isNotEmpty && myUid.isNotEmpty && checkUid == myUid) return true;
    if (checkEmail.isNotEmpty && myEmail.isNotEmpty && checkEmail == myEmail) return true;

    if (checkUid.isEmpty && checkEmail.isEmpty && name != null) {
      final myName = _currentName.toLowerCase();
      final checkName = name.toString().trim().toLowerCase();
      const generic = {'explorer', 'traveler', 'nature explorer', 'user', 'guest', 'fellow traveler', ''};
      if (!generic.contains(checkName) && checkName == myName) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadInitialState();

    _realtimeChannelPoller = Timer.periodic(const Duration(milliseconds: 3000), (_) {
      if (mounted) {
        _fetchChannels(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _realtimeChannelPoller?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialState() async {
    await _loadJoinedIds();
    await _loadCachedChannels();
    _syncCurrentUserToDatabase();
    _fetchChannels(silent: false);
  }

  Future<void> _loadJoinedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_joinedKey);
      if (stored != null && stored.isNotEmpty) {
        _joinedChannelIds = stored.toSet();
      } else {
        _joinedChannelIds = {'public_general'};
      }
    } catch (_) {}
  }

  Future<void> _saveJoinedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_joinedKey, _joinedChannelIds.toList());
    } catch (_) {}
  }

  Future<void> _loadCachedChannels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        final decoded = json.decode(cached);
        if (decoded is List && mounted) {
          final loaded = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          setState(() {
            _channels = _deduplicateChannels(loaded);
            _isLoading = false;
          });
        }
      }
    } catch (_) {}

    if (mounted && _channels.isEmpty) {
      final defaultList = allAvailableHubs.where((h) => _joinedChannelIds.contains(h['id'])).toList();
      setState(() {
        _channels = defaultList.isNotEmpty ? defaultList : [_corePublicChannels.first];
        _isLoading = false;
      });
    }
  }

  Future<void> _saveCachedChannels(List<Map<String, dynamic>> channels) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, json.encode(channels));
    } catch (_) {}
  }

  void _upsertChannelLocally(Map<String, dynamic> newChannel) {
    final channelId = (newChannel['id'] ?? '').toString();
    if (channelId.isEmpty) return;

    _joinedChannelIds.add(channelId);
    _saveJoinedIds();

    final existingIndex = _channels.indexWhere((c) => (c['id'] ?? '').toString() == channelId);
    if (existingIndex >= 0) {
      _channels[existingIndex] = {..._channels[existingIndex], ...newChannel};
    } else {
      _channels.insert(0, newChannel);
    }

    _channels = _deduplicateChannels(_channels);

    if (mounted) {
      setState(() {
        _channels = List.from(_channels);
        _isLoading = false;
      });
    }
    _saveCachedChannels(_channels);
  }

  List<Map<String, dynamic>> _deduplicateChannels(List<Map<String, dynamic>> list) {
    final Map<String, Map<String, dynamic>> uniqueMap = {};

    for (final c in list) {
      final id = (c['id'] ?? '').toString();
      final isDirect = c['isDirect'] == true;

      if (isDirect) {
        final info = _getCounterpartyInfo(c);
        final otherEmail = info['email'].toString();
        final otherUid = info['uid'].toString();
        final key = otherUid.isNotEmpty ? otherUid : (otherEmail.isNotEmpty ? otherEmail : id);
        uniqueMap[key] = c;
      } else {
        if (id.isNotEmpty) {
          if (uniqueMap.containsKey(id)) {
            uniqueMap[id] = {...uniqueMap[id]!, ...c};
          } else {
            uniqueMap[id] = c;
          }
        }
      }
    }

    final result = uniqueMap.values.toList();
    result.sort((a, b) {
      final tA = DateTime.tryParse((a['updatedAt'] ?? a['createdAt'] ?? '').toString()) ?? DateTime(2000);
      final tB = DateTime.tryParse((b['updatedAt'] ?? b['createdAt'] ?? '').toString()) ?? DateTime(2000);
      return tB.compareTo(tA);
    });
    return result;
  }

  Future<void> _syncCurrentUserToDatabase() async {
    final uid = _currentUid;
    final email = _currentEmail;
    if (uid.isEmpty && email.isEmpty) return;

    try {
      final authProfile = AuthController.I.currentUser;
      final realName = _currentName;
      final realPhoto = _currentPhoto;

      await http.post(
        Uri.parse('${CommunityBackendConfig.baseUrl}/users/sync'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'uid': uid,
          'id': uid,
          'name': realName,
          'displayName': realName,
          'email': email,
          'photoUrl': realPhoto,
          'photoURL': realPhoto,
          'avatar': realPhoto,
          'livesIn': authProfile?.livesIn ?? 'Sri Lanka',
          'occupation': authProfile?.occupation ?? 'Wilderness Explorer',
          'bio': authProfile?.bio ?? 'Exploring untamed wilderness 🌿',
        }),
      ).timeout(const Duration(seconds: 4)).catchError((_) => http.Response('{}', 200));
    } catch (_) {}
  }

  Future<void> _fetchChannels({bool silent = false}) async {
    if (!silent && _channels.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final myUid = _currentUid;
      final myEmail = _currentEmail;
      final uri = Uri.parse('${CommunityBackendConfig.baseUrl}/chat/channels?userUid=$myUid&userEmail=$myEmail');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        List<dynamic> serverRaw = [];
        if (data is Map && data['channels'] is List) {
          serverRaw = data['channels'];
        } else if (data is List) {
          serverRaw = data;
        }

        final serverList = serverRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        final joinedStaticHubs = allAvailableHubs.where((h) => _joinedChannelIds.contains(h['id'])).toList();

        final merged = _deduplicateChannels([...joinedStaticHubs, ...serverList, ..._channels]);

        if (mounted) {
          setState(() {
            _channels = merged;
            _isLoading = false;
          });
          _saveCachedChannels(_channels);
        }
        return;
      }
    } catch (_) {
    } finally {
      if (!silent && mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _getCounterpartyInfo(Map<String, dynamic> channel) {
    final isDirect = channel['isDirect'] == true;
    final isPublic = channel['isPublic'] == true;

    if (!isDirect) {
      return {
        'name': (channel['name'] ?? 'Public Community').toString(),
        'photoUrl': (channel['iconUrl'] ?? '').toString(),
        'subtitle': (channel['description'] ?? 'Open Community Discussion').toString(),
        'livesIn': channel['province'] ?? 'Sri Lanka',
        'occupation': isPublic ? 'Destination Hub' : 'Expedition Group',
        'bio': (channel['description'] ?? 'Open conversation for all nature travelers.').toString(),
        'email': '',
        'uid': '',
        'isDirect': false,
        'category': (channel['category'] ?? 'Public Hub').toString(),
      };
    }

    final rawDetails = channel['participantDetails'];
    if (rawDetails is Map) {
      for (final entry in rawDetails.entries) {
        final detail = entry.value;
        if (detail is Map) {
          final uid = (detail['uid'] ?? detail['id'] ?? detail['_id'] ?? entry.key).toString();
          final email = (detail['email'] ?? '').toString();
          final name = (detail['name'] ?? detail['displayName'] ?? '').toString();

          if (!_isCurrentUser(uid, email, name)) {
            final photo = (detail['photoUrl'] ?? detail['photoURL'] ?? detail['avatar'] ?? '').toString();
            final livesIn = (detail['livesIn'] ?? 'Sri Lanka').toString().trim();
            final occ = (detail['occupation'] ?? 'Traveler').toString().trim();
            final bio = (detail['bio'] ?? 'Passionate traveler exploring untamed trails 🌿').toString().trim();

            return {
              'name': name.isNotEmpty ? name : (email.isNotEmpty ? email.split('@')[0] : 'Traveler'),
              'photoUrl': photo,
              'subtitle': '$livesIn • $occ',
              'livesIn': livesIn,
              'occupation': occ,
              'bio': bio,
              'email': email,
              'uid': uid,
              'isDirect': true,
            };
          }
        }
      }
    }

    final creatorUid = (channel['creatorUid'] ?? '').toString();
    final creatorEmail = (channel['creatorEmail'] ?? '').toString();
    final creatorName = (channel['creatorName'] ?? '').toString();
    final creatorPhoto = (channel['creatorPhoto'] ?? '').toString();

    final targetUid = (channel['targetUid'] ?? '').toString();
    final targetEmail = (channel['targetEmail'] ?? '').toString();
    final targetName = (channel['targetName'] ?? '').toString();
    final targetPhoto = (channel['targetPhoto'] ?? '').toString();

    if (_isCurrentUser(creatorUid, creatorEmail, creatorName)) {
      return {
        'name': targetName.isNotEmpty ? targetName : (targetEmail.isNotEmpty ? targetEmail.split('@')[0] : 'Traveler'),
        'photoUrl': targetPhoto,
        'subtitle': targetEmail.isNotEmpty ? targetEmail : 'Verified Traveler',
        'livesIn': 'Sri Lanka',
        'occupation': 'Traveler',
        'bio': 'Passionate traveler exploring untamed trails 🌿',
        'email': targetEmail,
        'uid': targetUid,
        'isDirect': true,
      };
    } else {
      return {
        'name': creatorName.isNotEmpty ? creatorName : (creatorEmail.isNotEmpty ? creatorEmail.split('@')[0] : 'Traveler'),
        'photoUrl': creatorPhoto,
        'subtitle': creatorEmail.isNotEmpty ? creatorEmail : 'Verified Traveler',
        'livesIn': 'Sri Lanka',
        'occupation': 'Traveler',
        'bio': 'Passionate traveler exploring untamed trails 🌿',
        'email': creatorEmail,
        'uid': creatorUid,
        'isDirect': true,
      };
    }
  }

  Future<void> _openDiscoveryAndChatSheet() async {
    final Map<String, dynamic>? selectedChannel = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HubDiscoveryBottomSheet(
        existingChannels: _channels,
        joinedIds: _joinedChannelIds,
        allHubs: allAvailableHubs,
      ),
    );

    if (selectedChannel != null && mounted) {
      final channelId = (selectedChannel['id'] ?? '').toString();
      _joinedChannelIds.add(channelId);
      await _saveJoinedIds();

      _upsertChannelLocally(selectedChannel);

      final info = _getCounterpartyInfo(selectedChannel);
      final isDirect = selectedChannel['isDirect'] == true;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExpeditionChatRoomPage(
            channelId: channelId,
            channelName: info['name'].toString(),
            category: (selectedChannel['category'] ?? 'Community').toString(),
            iconUrl: info['photoUrl'].toString(),
            subtitle: isDirect ? info['subtitle'].toString() : null,
            peerProfileDetails: info,
            onMessageSent: (lastMsg) {
              selectedChannel['lastMessage'] = lastMsg;
              selectedChannel['updatedAt'] = DateTime.now().toIso8601String();
              _upsertChannelLocally(selectedChannel);
            },
          ),
        ),
      );

      _fetchChannels(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchQuery.toLowerCase().trim();

    final filteredChannels = _channels.where((c) {
      final isDirect = c['isDirect'] == true;
      final cat = (c['category'] ?? '').toString();

      final info = _getCounterpartyInfo(c);
      final displayName = (info['name'] ?? '').toString().toLowerCase();
      final desc = (c['description'] ?? '').toString().toLowerCase();
      final dist = (c['district'] ?? '').toString().toLowerCase();
      final prov = (c['province'] ?? '').toString().toLowerCase();

      final matchesSearch = q.isEmpty ||
          displayName.contains(q) ||
          desc.contains(q) ||
          dist.contains(q) ||
          prov.contains(q);

      bool matchesCat = true;
      if (_selectedCategory == 'Direct Chats') {
        matchesCat = isDirect;
      } else if (_selectedCategory != 'All') {
        matchesCat = (cat.toLowerCase() == _selectedCategory.toLowerCase());
      }
      return matchesSearch && matchesCat;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.canvasBg,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 106, right: 8),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.greenGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.forest.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton(
            backgroundColor: Colors.transparent,
            elevation: 0,
            tooltip: "Explore Hubs & Direct Chat",
            onPressed: _openDiscoveryAndChatSheet,
            child: const Icon(Icons.add_comment_rounded, color: Colors.white, size: 26),
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.forest,
          onRefresh: () async {
            await _syncCurrentUserToDatabase();
            await _fetchChannels(silent: false);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: AppColors.greenGradient,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.emerald.withOpacity(0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.hub_rounded, color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Ceylon Community",
                                    style: TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.forest,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.fiber_manual_record, color: Color(0xFF10B981), size: 10),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${_channels.length} Joined Hubs & Direct Chats",
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.emerald,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: AppColors.forest, size: 24),
                            onPressed: () => _fetchChannels(silent: false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cardStroke, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.forest.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: "Search your joined discussions...",
                            hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.forest, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: _categories.map((cat) {
                            final isSel = _selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () => setState(() => _selectedCategory = cat),
                                borderRadius: BorderRadius.circular(20),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSel ? AppColors.forest : AppColors.cardSurface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: isSel ? AppColors.forest : AppColors.cardStroke),
                                  ),
                                  child: Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: isSel ? Colors.white : AppColors.textMain,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_isLoading && _channels.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.forest),
                  ),
                )
              else if (filteredChannels.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.forest.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.explore_outlined, size: 48, color: AppColors.forest),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "No discussions found",
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.forest),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Tap the '+' button below to explore 100+ destination hubs across Sri Lanka or direct message other travelers!",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.forest,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            ),
                            icon: const Icon(Icons.explore_rounded, color: Colors.white, size: 18),
                            label: const Text("Explore 100+ Hubs", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            onPressed: _openDiscoveryAndChatSheet,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final channel = filteredChannels[index];
                        return _buildChannelCard(channel);
                      },
                      childCount: filteredChannels.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelCard(Map<String, dynamic> channel) {
    final channelId = (channel['id'] ?? '').toString();
    final isDirect = channel['isDirect'] == true;
    final isPublic = channel['isPublic'] == true || (!isDirect && (channelId.startsWith('public_') || channelId.startsWith('hub_')));
    final category = (channel['category'] ?? (isPublic ? 'Public Hub' : 'Expedition')).toString();

    final info = _getCounterpartyInfo(channel);
    final channelName = info['name'].toString();
    final iconUrl = info['photoUrl'].toString();
    final userSubtitle = info['subtitle'].toString();
    final district = (channel['district'] ?? '').toString();
    final province = (channel['province'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPublic ? AppColors.forest.withOpacity(0.2) : AppColors.cardStroke,
          width: isPublic ? 1.3 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPublic ? AppColors.forest.withOpacity(0.04) : Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ExpeditionChatRoomPage(
                  channelId: channelId,
                  channelName: channelName,
                  category: category,
                  iconUrl: iconUrl,
                  subtitle: isDirect ? userSubtitle : null,
                  peerProfileDetails: info,
                  onMessageSent: (lastMsg) {
                    channel['lastMessage'] = lastMsg;
                    channel['updatedAt'] = DateTime.now().toIso8601String();
                    _upsertChannelLocally(channel);
                  },
                ),
              ),
            ).then((_) => _fetchChannels(silent: true));
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: iconUrl.isNotEmpty
                      ? Image.network(
                          iconUrl,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildChannelAvatar(channelName, isDirect, isPublic),
                        )
                      : _buildChannelAvatar(channelName, isDirect, isPublic),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              channelName,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textMain),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isPublic
                                  ? AppColors.forest.withOpacity(0.12)
                                  : (isDirect ? Colors.blueGrey.withOpacity(0.12) : AppColors.emerald.withOpacity(0.12)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isPublic ? category : (isDirect ? 'Direct' : category),
                              style: TextStyle(
                                color: isPublic ? AppColors.forest : (isDirect ? Colors.blueGrey : AppColors.emerald),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDirect ? userSubtitle : (channel['description'] ?? 'Open community conversation'),
                        style: const TextStyle(fontSize: 12, color: AppColors.emerald, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        channel['lastMessage'] ?? (isDirect ? "Tap to open direct chat" : "Open for all travelers"),
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            isPublic ? Icons.public_rounded : (isDirect ? Icons.lock_outline_rounded : Icons.people_alt_rounded),
                            size: 13,
                            color: isPublic ? AppColors.forest : AppColors.emerald,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPublic
                                ? "${channel['memberCount'] ?? 'Explorers'}"
                                : (isDirect ? "Private Direct Message" : "${channel['memberCount'] ?? 'Active'} travelers"),
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                          ),
                          if (district.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            const SizedBox(width: 6),
                            Text(
                              district,
                              style: const TextStyle(fontSize: 11, color: AppColors.emerald, fontWeight: FontWeight.bold),
                            ),
                          ],
                          if (province.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text(
                              "($province)",
                              style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            isPublic ? "Open" : "Chat",
                            style: const TextStyle(fontSize: 11.5, color: AppColors.forest, fontWeight: FontWeight.w800),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.forest),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelAvatar(String name, bool isDirect, bool isPublic) {
    if (isPublic) {
      IconData iconData = Icons.place_rounded;
      final lower = name.toLowerCase();
      if (lower.contains('hiking') || lower.contains('trail') || lower.contains('peak') || lower.contains('mountain')) {
        iconData = Icons.hiking_rounded;
      } else if (lower.contains('camp') || lower.contains('ridge') || lower.contains('plains')) {
        iconData = Icons.cabin_rounded;
      } else if (lower.contains('wildlife') || lower.contains('safari') || lower.contains('park') || lower.contains('wetland')) {
        iconData = Icons.pets_rounded;
      } else if (lower.contains('alert') || lower.contains('weather') || lower.contains('safety')) {
        iconData = Icons.warning_amber_rounded;
      } else if (lower.contains('beach') || lower.contains('bay') || lower.contains('surf') || lower.contains('island')) {
        iconData = Icons.beach_access_rounded;
      } else if (lower.contains('falls') || lower.contains('river') || lower.contains('lake') || lower.contains('wewa')) {
        iconData = Icons.water_drop_rounded;
      }

      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: AppColors.greenGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Icon(iconData, color: Colors.white, size: 26),
        ),
      );
    }

    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'T';
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.forest.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: isDirect
            ? Text(initial, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.forest))
            : const Icon(Icons.terrain_rounded, color: AppColors.forest, size: 24),
      ),
    );
  }
}

class HubDiscoveryBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> existingChannels;
  final Set<String> joinedIds;
  final List<Map<String, dynamic>> allHubs;

  const HubDiscoveryBottomSheet({
    super.key,
    required this.existingChannels,
    required this.joinedIds,
    required this.allHubs,
  });

  @override
  State<HubDiscoveryBottomSheet> createState() => _HubDiscoveryBottomSheetState();
}

class _HubDiscoveryBottomSheetState extends State<HubDiscoveryBottomSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _hubSearchCtrl = TextEditingController();
  String _hubSearchQuery = '';
  String _selectedHubCategory = 'All';

  final TextEditingController _userSearchCtrl = TextEditingController();
  String _userSearchQuery = '';
  List<Map<String, dynamic>> _users = [];
  bool _isLoadingUsers = true;

  final TextEditingController _topicNameCtrl = TextEditingController();
  final TextEditingController _topicDescCtrl = TextEditingController();
  String _newTopicCategory = 'Public Hub';
  bool _isCreatingTopic = false;

  final List<String> _hubCategories = [
    'All',
    'Public Hub',
    'Hiking',
    'Camping',
    'Wildlife',
    'Safety',
  ];

  String get _myUid {
    final authUid = AuthController.I.currentUser?.uid;
    if (authUid != null && authUid.trim().isNotEmpty) return authUid.trim();
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  String get _myEmail {
    final authEmail = AuthController.I.currentUser?.email;
    if (authEmail != null && authEmail.trim().isNotEmpty) return authEmail.trim();
    return FirebaseAuth.instance.currentUser?.email ?? '';
  }

  String get _myName {
    final authName = AuthController.I.currentUser?.name;
    if (authName != null && authName.trim().isNotEmpty) return authName.trim();
    final fbName = FirebaseAuth.instance.currentUser?.displayName;
    if (fbName != null && fbName.trim().isNotEmpty) return fbName.trim();
    if (_myEmail.isNotEmpty && _myEmail.contains('@')) {
      return _myEmail.split('@')[0];
    }
    return 'Explorer';
  }

  String get _myPhoto {
    final authPhoto = AuthController.I.currentUser?.photoUrl;
    if (authPhoto != null && authPhoto.trim().isNotEmpty) return authPhoto.trim();
    return FirebaseAuth.instance.currentUser?.photoURL ?? '';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _syncAndFetchUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hubSearchCtrl.dispose();
    _userSearchCtrl.dispose();
    _topicNameCtrl.dispose();
    _topicDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _syncAndFetchUsers() async {
    setState(() => _isLoadingUsers = true);
    final myUid = _myUid;
    final myEmail = _myEmail;

    try {
      final uri = Uri.parse('${CommunityBackendConfig.baseUrl}/users?excludeUid=$myUid&excludeEmail=$myEmail');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        List<dynamic> rawList = [];

        if (decoded is List) {
          rawList = decoded;
        } else if (decoded is Map) {
          if (decoded['users'] is List) {
            rawList = decoded['users'];
          } else if (decoded['data'] is List) {
            rawList = decoded['data'];
          } else if (decoded['travelers'] is List) {
            rawList = decoded['travelers'];
          }
        }

        final List<Map<String, dynamic>> parsedUsers = [];
        for (final item in rawList) {
          if (item is Map) {
            final uMap = Map<String, dynamic>.from(item);
            final uid = (uMap['uid'] ?? uMap['id'] ?? uMap['_id'] ?? '').toString();
            final email = (uMap['email'] ?? '').toString();

            if ((myUid.isNotEmpty && uid.toLowerCase() == myUid.toLowerCase()) ||
                (myEmail.isNotEmpty && email.toLowerCase() == myEmail.toLowerCase())) {
              continue;
            }

            final name = (uMap['name'] ?? uMap['displayName'] ?? (email.isNotEmpty ? email.split('@')[0] : 'Traveler')).toString();
            final photo = (uMap['photoUrl'] ?? uMap['photoURL'] ?? uMap['avatar'] ?? '').toString();
            final livesIn = (uMap['livesIn'] ?? 'Sri Lanka').toString();
            final occ = (uMap['occupation'] ?? 'Nature Explorer').toString();

            parsedUsers.add({
              'uid': uid,
              'email': email,
              'name': name,
              'photoUrl': photo,
              'livesIn': livesIn,
              'occupation': occ,
            });
          }
        }

        if (mounted) {
          setState(() {
            _users = parsedUsers;
            _isLoadingUsers = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _startDirectChatWithUser(Map<String, dynamic> targetUser) async {
    final myUid = _myUid;
    final myEmail = _myEmail;
    final myName = _myName;
    final myPhoto = _myPhoto;
    final authProfile = AuthController.I.currentUser;

    final targetUid = (targetUser['uid'] ?? targetUser['id'] ?? '').toString();
    final targetEmail = (targetUser['email'] ?? '').toString();
    final targetName = (targetUser['name'] ?? (targetEmail.isNotEmpty ? targetEmail.split('@')[0] : 'Traveler')).toString();
    final targetPhoto = (targetUser['photoUrl'] ?? '').toString();
    final targetLocation = (targetUser['livesIn'] ?? 'Sri Lanka').toString();
    final targetOccupation = (targetUser['occupation'] ?? 'Nature Explorer').toString();

    for (final ec in widget.existingChannels) {
      if (ec['isDirect'] == true) {
        final participants = (ec['participants'] as List?)?.map((e) => e.toString().toLowerCase()).toList() ?? [];
        final tUid = targetUid.toLowerCase();
        final tEmail = targetEmail.toLowerCase();

        bool match = false;
        if (tUid.isNotEmpty && participants.contains(tUid)) match = true;
        if (tEmail.isNotEmpty && participants.contains(tEmail)) match = true;

        if (match) {
          Navigator.of(context).pop(ec);
          return;
        }
      }
    }

    final fallbackId = 'direct_${myUid.hashCode.abs()}_${targetUid.hashCode.abs()}';

    final channelPayload = {
      'id': fallbackId,
      'name': '$myName & $targetName',
      'description': 'Direct message trail',
      'category': 'Direct',
      'isDirect': true,
      'isPublic': false,
      'creatorUid': myUid,
      'creatorEmail': myEmail,
      'creatorName': myName,
      'creatorPhoto': myPhoto,
      'targetUid': targetUid,
      'targetEmail': targetEmail,
      'targetName': targetName,
      'targetPhoto': targetPhoto,
      'participants': [myUid, targetUid, myEmail, targetEmail],
      'participantDetails': {
        myUid: {
          'uid': myUid,
          'email': myEmail,
          'name': myName,
          'photoUrl': myPhoto,
          'livesIn': authProfile?.livesIn ?? 'Sri Lanka',
          'occupation': authProfile?.occupation ?? 'Wilderness Explorer',
        },
        targetUid: {
          'uid': targetUid,
          'email': targetEmail,
          'name': targetName,
          'photoUrl': targetPhoto,
          'livesIn': targetLocation,
          'occupation': targetOccupation,
        },
      },
      'lastMessage': 'Private direct chat started',
      'updatedAt': DateTime.now().toIso8601String(),
    };

    try {
      final res = await http.post(
        Uri.parse('${CommunityBackendConfig.baseUrl}/chat/channels'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(channelPayload),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = json.decode(res.body);
        if (data['channelId'] != null) {
          channelPayload['id'] = data['channelId'];
        }
      }
    } catch (_) {}

    if (mounted) {
      Navigator.of(context).pop(channelPayload);
    }
  }

  Future<void> _createCustomTopic() async {
    final title = _topicNameCtrl.text.trim();
    final desc = _topicDescCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() => _isCreatingTopic = true);
    final myUid = _myUid;
    final myName = _myName;

    final fallbackId = 'pub_${DateTime.now().millisecondsSinceEpoch}';

    final channelPayload = {
      'id': fallbackId,
      'name': title,
      'description': desc.isNotEmpty ? desc : 'Open Public Discussion for all travelers',
      'category': _newTopicCategory,
      'isDirect': false,
      'isPublic': true,
      'iconUrl': '',
      'createdBy': myName,
      'creatorUid': myUid,
      'memberCount': 'Open Community',
      'lastMessage': 'Public topic initiated by $myName',
      'updatedAt': DateTime.now().toIso8601String(),
    };

    try {
      final res = await http.post(
        Uri.parse('${CommunityBackendConfig.baseUrl}/chat/channels'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(channelPayload),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = json.decode(res.body);
        if (data['channelId'] != null) {
          channelPayload['id'] = data['channelId'];
        }
      }
    } catch (_) {}

    if (mounted) {
      Navigator.of(context).pop(channelPayload);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qHub = _hubSearchQuery.toLowerCase().trim();
    final filteredHubs = widget.allHubs.where((hub) {
      final name = (hub['name'] ?? '').toString().toLowerCase();
      final desc = (hub['description'] ?? '').toString().toLowerCase();
      final dist = (hub['district'] ?? '').toString().toLowerCase();
      final prov = (hub['province'] ?? '').toString().toLowerCase();
      final cat = (hub['category'] ?? '').toString();

      final matchesQuery = qHub.isEmpty ||
          name.contains(qHub) ||
          desc.contains(qHub) ||
          dist.contains(qHub) ||
          prov.contains(qHub);

      final matchesCategory = _selectedHubCategory == 'All' ||
          (cat.toLowerCase() == _selectedHubCategory.toLowerCase());

      return matchesQuery && matchesCategory;
    }).toList();

    final qUser = _userSearchQuery.toLowerCase().trim();
    final filteredUsers = _users.where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      final livesIn = (u['livesIn'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      return qUser.isEmpty || name.contains(qUser) || livesIn.contains(qUser) || email.contains(qUser);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 12),

          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.forest,
            indicatorWeight: 3,
            labelColor: AppColors.forest,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
            tabs: const [
              Tab(icon: Icon(Icons.explore_rounded, size: 20), text: "Explore Hubs"),
              Tab(icon: Icon(Icons.person_pin_rounded, size: 20), text: "Direct Chat"),
              Tab(icon: Icon(Icons.add_box_rounded, size: 20), text: "Create Topic"),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.canvasBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cardStroke),
                      ),
                      child: TextField(
                        controller: _hubSearchCtrl,
                        onChanged: (val) => setState(() => _hubSearchQuery = val),
                        decoration: InputDecoration(
                          hintText: "Search 100+ destinations (Ella, Jaffna, Knuckles)...",
                          hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.forest, size: 20),
                          suffixIcon: _hubSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () {
                                    _hubSearchCtrl.clear();
                                    setState(() => _hubSearchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: _hubCategories.map((cat) {
                          final isSel = _selectedHubCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(cat),
                              selected: isSel,
                              selectedColor: AppColors.forest,
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : AppColors.textMain,
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                              onSelected: (_) => setState(() => _selectedHubCategory = cat),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredHubs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.cardStroke),
                        itemBuilder: (context, idx) {
                          final hub = filteredHubs[idx];
                          final id = (hub['id'] ?? '').toString();
                          final isJoined = widget.joinedIds.contains(id);
                          final name = hub['name'] ?? 'Destination Hub';
                          final district = hub['district'] ?? '';
                          final province = hub['province'] ?? '';

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: AppColors.greenGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.place_rounded, color: Colors.white, size: 22),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.forest),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              "$district ($province) • ${hub['category'] ?? 'Public Hub'}",
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isJoined ? Colors.grey.shade200 : AppColors.forest,
                                foregroundColor: isJoined ? AppColors.forest : Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop(hub);
                              },
                              child: Text(
                                isJoined ? "Open" : "Join & Chat",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.canvasBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cardStroke),
                      ),
                      child: TextField(
                        controller: _userSearchCtrl,
                        onChanged: (val) => setState(() => _userSearchQuery = val),
                        decoration: InputDecoration(
                          hintText: "Search travelers by name or city...",
                          hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.forest, size: 20),
                          suffixIcon: _userSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () {
                                    _userSearchCtrl.clear();
                                    setState(() => _userSearchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Expanded(
                      child: _isLoadingUsers
                          ? const Center(child: CircularProgressIndicator(color: AppColors.forest))
                          : filteredUsers.isEmpty
                              ? const Center(
                                  child: Text(
                                    "No travelers found online yet.\nLog in on another account to test direct chat!",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                  ),
                                )
                              : ListView.separated(
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: filteredUsers.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.cardStroke),
                                  itemBuilder: (context, idx) {
                                    final user = filteredUsers[idx];
                                    final name = user['name'].toString();
                                    final livesIn = user['livesIn'].toString();
                                    final occupation = user['occupation'].toString();
                                    final photoUrl = user['photoUrl'].toString();

                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                      leading: CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppColors.forest.withOpacity(0.12),
                                        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                        child: photoUrl.isEmpty
                                            ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'T', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.forest))
                                            : null,
                                      ),
                                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textMain)),
                                      subtitle: Text(
                                        "$livesIn • $occupation",
                                        style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.forest,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => _startDirectChatWithUser(user),
                                        child: const Text("Message", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),

                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Launch a Custom Public Group", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.forest)),
                      const SizedBox(height: 4),
                      const Text("Create a dedicated channel for an upcoming hike, meetup, or trail.", style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _topicNameCtrl,
                        decoration: InputDecoration(
                          labelText: "Channel Title",
                          hintText: "e.g. Ella Rock Sunrise Trek 🌅",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.forest),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _topicDescCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: "Topic Description",
                          hintText: "Meetup point, train schedules, essential tips...",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          prefixIcon: const Icon(Icons.description_rounded, color: AppColors.forest),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text("Channel Category:", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.forest)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ['Public Hub', 'Hiking', 'Camping', 'Wildlife', 'Safety'].map((cat) {
                          final isSel = _newTopicCategory == cat;
                          return ChoiceChip(
                            label: Text(cat),
                            selected: isSel,
                            selectedColor: AppColors.forest,
                            labelStyle: TextStyle(color: isSel ? Colors.white : AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 11.5),
                            onSelected: (_) => setState(() => _newTopicCategory = cat),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.forest,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _isCreatingTopic ? null : _createCustomTopic,
                          child: _isCreatingTopic
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Launch Channel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5)),
                        ),
                      ),
                    ],
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

class ExpeditionChatRoomPage extends StatefulWidget {
  final String channelId;
  final String channelName;
  final String category;
  final String iconUrl;
  final String? subtitle;
  final Map<String, dynamic>? peerProfileDetails;
  final Function(String lastMessage)? onMessageSent;

  const ExpeditionChatRoomPage({
    super.key,
    required this.channelId,
    required this.channelName,
    required this.category,
    required this.iconUrl,
    this.subtitle,
    this.peerProfileDetails,
    this.onMessageSent,
  });

  @override
  State<ExpeditionChatRoomPage> createState() => _ExpeditionChatRoomPageState();
}

class _ExpeditionChatRoomPageState extends State<ExpeditionChatRoomPage> {
  final List<dynamic> _messages = [];
  bool _isLoading = true;
  Timer? _pollingTimer;
  final TextEditingController _msgInputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingMedia = false;

  bool get _isPublicChannel =>
      widget.channelId.startsWith('public_') ||
      widget.channelId.startsWith('hub_') ||
      widget.category != 'Direct';

  String get _currentUid {
    final authUid = AuthController.I.currentUser?.uid;
    if (authUid != null && authUid.trim().isNotEmpty) return authUid.trim();
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  String get _currentEmail {
    final authEmail = AuthController.I.currentUser?.email;
    if (authEmail != null && authEmail.trim().isNotEmpty) return authEmail.trim();
    return FirebaseAuth.instance.currentUser?.email ?? '';
  }

  String get _currentName {
    final authName = AuthController.I.currentUser?.name;
    if (authName != null && authName.trim().isNotEmpty) return authName.trim();
    final fbName = FirebaseAuth.instance.currentUser?.displayName;
    if (fbName != null && fbName.trim().isNotEmpty) return fbName.trim();
    if (_currentEmail.isNotEmpty && _currentEmail.contains('@')) {
      return _currentEmail.split('@')[0];
    }
    return 'Traveler';
  }

  String get _currentPhoto {
    final authPhoto = AuthController.I.currentUser?.photoUrl;
    if (authPhoto != null && authPhoto.trim().isNotEmpty) return authPhoto.trim();
    return FirebaseAuth.instance.currentUser?.photoURL ?? '';
  }

  bool _checkIsMe(Map<String, dynamic> msg) {
    final msgId = (msg['id'] ?? '').toString();
    if (msgId.startsWith('temp_')) return true;

    dynamic rawSenderUid = msg['senderUid'] ??
        msg['senderId'] ??
        msg['sender_id'] ??
        msg['userId'] ??
        msg['user_id'] ??
        msg['uid'];
    if (rawSenderUid == null && msg['sender'] is Map) {
      rawSenderUid = msg['sender']['uid'] ?? msg['sender']['id'] ?? msg['sender']['_id'];
    }

    dynamic rawSenderEmail = msg['senderEmail'] ?? msg['email'];
    if (rawSenderEmail == null && msg['sender'] is Map) {
      rawSenderEmail = msg['sender']['email'];
    }

    final myUid = _currentUid.toLowerCase();
    final myEmail = _currentEmail.toLowerCase();
    final sUid = (rawSenderUid ?? '').toString().trim().toLowerCase();
    final sEmail = (rawSenderEmail ?? '').toString().trim().toLowerCase();

    if (sUid.isNotEmpty && myUid.isNotEmpty && sUid == myUid) return true;
    if (sEmail.isNotEmpty && myEmail.isNotEmpty && sEmail == myEmail) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadCachedMessages();
    _fetchMessages(initial: _messages.isEmpty);
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      _fetchMessages(initial: false);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _msgInputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'local_cache_msgs_${widget.channelId}';
      final cachedString = prefs.getString(key);
      if (cachedString != null && cachedString.isNotEmpty) {
        final decoded = json.decode(cachedString);
        if (decoded is List && mounted) {
          setState(() {
            _messages.clear();
            _messages.addAll(decoded);
            _isLoading = false;
          });
          _scrollToBottom();
        }
      }
    } catch (_) {}
  }

  Future<void> _saveMessagesToCache(List<dynamic> msgs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'local_cache_msgs_${widget.channelId}';
      final toSave = msgs.length > 150 ? msgs.sublist(msgs.length - 150) : msgs;
      await prefs.setString(key, json.encode(toSave));
    } catch (_) {}
  }

  Future<void> _fetchMessages({bool initial = false}) async {
    if (initial && _messages.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final uri = Uri.parse('${CommunityBackendConfig.baseUrl}/chat/channels/${widget.channelId}/messages');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true && data['messages'] != null) {
          final fetched = data['messages'] as List<dynamic>;
          if (mounted) {
            final oldLen = _messages.length;
            setState(() {
              _messages.clear();
              _messages.addAll(fetched);
              _isLoading = false;
            });
            _saveMessagesToCache(_messages);
            if (fetched.length > oldLen) {
              _scrollToBottom();
            }
          }
        }
      }
    } catch (_) {
      if (initial && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  String _formatMessageTime(dynamic dateValue) {
    if (dateValue == null) return '';
    try {
      final dt = DateTime.parse(dateValue.toString()).toLocal();
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } catch (_) {
      return '';
    }
  }

  void _showChatHeaderDetails() {
    final details = widget.peerProfileDetails ?? {};
    final displayName = widget.channelName;
    final photo = widget.iconUrl;
    final bio = (details['bio'] ?? (_isPublicChannel ? 'Open channel for all Sri Lankan nature travelers 🌿' : 'Exploring untamed trails 🌿')).toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 8),
              child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10))),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 90,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            gradient: AppColors.greenGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        Positioned(
                          bottom: -40,
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.forest.withOpacity(0.12),
                            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                            child: photo.isEmpty
                                ? Icon(_isPublicChannel ? Icons.hub_rounded : Icons.person_rounded, size: 36, color: AppColors.forest)
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Text(
                            displayName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.forest),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isPublicChannel ? AppColors.forest.withOpacity(0.1) : AppColors.emerald.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _isPublicChannel ? 'Public Destination Hub' : 'Direct Conversation',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _isPublicChannel ? AppColors.forest : AppColors.emerald,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.canvasBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cardStroke),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info_outline_rounded, color: AppColors.forest, size: 16),
                                SizedBox(width: 6),
                                Text("ABOUT", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.forest)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(bio, style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.textMain)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.forest,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Close", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendTextMessage() async {
    final text = _msgInputController.text.trim();
    if (text.isEmpty) return;

    _msgInputController.clear();
    final senderName = _currentName;
    final senderUid = _currentUid;
    final senderEmail = _currentEmail;
    final senderAvatar = _currentPhoto;

    final tempMsg = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'senderUid': senderUid,
      'senderEmail': senderEmail,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'text': text,
      'type': 'text',
      'mediaUrl': '',
      'createdAt': DateTime.now().toIso8601String(),
      'reactions': {},
    };

    setState(() {
      _messages.add(tempMsg);
    });
    _saveMessagesToCache(_messages);
    _scrollToBottom();

    widget.onMessageSent?.call(text);

    try {
      final uri = Uri.parse('${CommunityBackendConfig.baseUrl}/chat/channels/${widget.channelId}/messages');
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'senderUid': senderUid,
          'senderEmail': senderEmail,
          'senderName': senderName,
          'senderAvatar': senderAvatar,
          'text': text,
          'type': 'text',
        }),
      );
      _fetchMessages();
    } catch (_) {}
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(source: source, imageQuality: 75);
      if (file == null) return;

      setState(() => _isUploadingMedia = true);

      final uri = Uri.parse(CommunityBackendConfig.uploadUrl);
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final res = await http.Response.fromStream(streamedResponse);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final mediaUrl = data['url'] ?? data['imageUrl'] ?? data['fileUrl'];

        await http.post(
          Uri.parse('${CommunityBackendConfig.baseUrl}/chat/channels/${widget.channelId}/messages'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'senderUid': _currentUid,
            'senderEmail': _currentEmail,
            'senderName': _currentName,
            'senderAvatar': _currentPhoto,
            'text': 'Shared a photo',
            'type': 'image',
            'mediaUrl': mediaUrl,
          }),
        );
        widget.onMessageSent?.call("📷 Photo");
        _fetchMessages();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  Future<void> _shareCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      setState(() => _isUploadingMedia = true);
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      await http.post(
        Uri.parse('${CommunityBackendConfig.baseUrl}/chat/channels/${widget.channelId}/messages'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'senderUid': _currentUid,
          'senderEmail': _currentEmail,
          'senderName': _currentName,
          'senderAvatar': _currentPhoto,
          'text': 'Live GPS Trail Pin',
          'type': 'location',
          'latitude': pos.latitude,
          'longitude': pos.longitude,
        }),
      );
      widget.onMessageSent?.call("📍 Shared Location");
      _fetchMessages();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  void _showEmojiReactionDialog(String messageId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['❤️', '👍', '🔥', '🏕️', '🇱🇰', '⛺'].map((emoji) {
            return InkWell(
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  HapticFeedback.mediumImpact();
                  await http.post(
                    Uri.parse('${CommunityBackendConfig.baseUrl}/chat/messages/${widget.channelId}/$messageId/react'),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode({'emoji': emoji, 'userUid': _currentUid}),
                  );
                  _fetchMessages();
                } catch (_) {}
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(emoji, style: const TextStyle(fontSize: 30)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttachAction(
                  icon: Icons.camera_alt_rounded,
                  label: "Camera",
                  gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFE11D48)]),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadImage(ImageSource.camera);
                  },
                ),
                _buildAttachAction(
                  icon: Icons.photo_library_rounded,
                  label: "Gallery",
                  gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadImage(ImageSource.gallery);
                  },
                ),
                _buildAttachAction(
                  icon: Icons.location_on_rounded,
                  label: "Live GPS",
                  gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF047857)]),
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareCurrentLocation();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachAction({
    required IconData icon,
    required String label,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textMain)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      appBar: AppBar(
        elevation: 1,
        backgroundColor: AppColors.cardSurface,
        leadingWidth: 40,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.forest, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _showChatHeaderDetails,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: AppColors.forest.withOpacity(0.1),
                  backgroundImage: widget.iconUrl.isNotEmpty ? NetworkImage(widget.iconUrl) : null,
                  child: widget.iconUrl.isEmpty
                      ? Icon(_isPublicChannel ? Icons.hub_rounded : Icons.person_rounded, size: 20, color: AppColors.forest)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.channelName,
                              style: const TextStyle(color: AppColors.forest, fontWeight: FontWeight.w900, fontSize: 14.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.emerald),
                        ],
                      ),
                      Text(
                        _isPublicChannel ? "Open Destination Hub" : (widget.subtitle ?? "Direct Message"),
                        style: const TextStyle(color: AppColors.emerald, fontSize: 11, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.forest),
            onPressed: () => _fetchMessages(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isUploadingMedia)
            const LinearProgressIndicator(color: AppColors.emerald, backgroundColor: AppColors.cardStroke),
          Expanded(
            child: _isLoading && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.forest))
                : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 26),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(_isPublicChannel ? Icons.hub_rounded : Icons.chat_bubble_outline_rounded, size: 44, color: AppColors.emerald),
                              ),
                              const SizedBox(height: 12),
                              Text(widget.channelName, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.forest)),
                              const SizedBox(height: 6),
                              Text(
                                _isPublicChannel
                                    ? "Open conversation trail. Say hi to fellow explorers!"
                                    : "Send your first direct message below.",
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = _checkIsMe(msg);
                          return _buildMessageBubble(msg, isMe);
                        },
                      ),
          ),
          _buildMessageInputField(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final messageId = (msg['id'] ?? '').toString();
    final senderName = (msg['senderName'] ?? (msg['sender'] is Map ? msg['sender']['name'] : 'Explorer')).toString();
    final text = (msg['text'] ?? '').toString();
    final type = (msg['type'] ?? 'text').toString();
    final mediaUrl = (msg['mediaUrl'] ?? '').toString();
    final lat = msg['latitude'];
    final lng = msg['longitude'];
    final reactions = msg['reactions'] is Map ? msg['reactions'] as Map<String, dynamic> : <String, dynamic>{};
    final timeStr = _formatMessageTime(msg['createdAt']);
    final senderAvatar = (msg['senderAvatar'] ?? (msg['sender'] is Map ? msg['sender']['photoUrl'] : '')).toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onLongPress: () {
          if (messageId.isNotEmpty && !messageId.startsWith('temp_')) {
            _showEmojiReactionDialog(messageId);
          }
        },
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.forest.withOpacity(0.12),
                backgroundImage: senderAvatar.isNotEmpty ? NetworkImage(senderAvatar) : null,
                child: senderAvatar.isEmpty
                    ? Text(
                        senderName.isNotEmpty ? senderName[0].toUpperCase() : 'T',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.forest),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
            ],

            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 6, bottom: 4),
                      child: Text(
                        senderName,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.forest),
                      ),
                    ),

                  Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
                    decoration: BoxDecoration(
                      gradient: isMe ? AppColors.greenGradient : null,
                      color: isMe ? null : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                        bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                      ),
                      border: isMe ? null : Border.all(color: AppColors.cardStroke.withOpacity(0.8), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: isMe ? AppColors.forest.withOpacity(0.15) : Colors.black.withOpacity(0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (type == 'image' && mediaUrl.isNotEmpty) ...[
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ImageViewerScreen(imageUrl: mediaUrl),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                mediaUrl,
                                width: 220,
                                height: 160,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        if (type == 'location' && lat != null && lng != null) ...[
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: "$lat, $lng"));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('📍 Coordinates copied to clipboard!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.white.withOpacity(0.18) : AppColors.canvasBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_rounded, color: Color(0xFF10B981), size: 26),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Live Trail GPS Pin",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12.5,
                                          color: isMe ? Colors.white : AppColors.forest,
                                        ),
                                      ),
                                      Text(
                                        "${lat.toStringAsFixed(4)}° N, ${lng.toStringAsFixed(4)}° E",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isMe ? Colors.white70 : AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],

                        if (text.isNotEmpty && type != 'location')
                          Text(
                            text,
                            style: TextStyle(
                              fontSize: 14,
                              color: isMe ? Colors.white : AppColors.textMain,
                              height: 1.35,
                            ),
                          ),

                        const SizedBox(height: 4),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: isMe ? Colors.white.withOpacity(0.75) : AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.done_all_rounded, size: 13, color: Colors.white.withOpacity(0.85)),
                            ]
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (reactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                      child: Wrap(
                        spacing: 4,
                        children: reactions.entries.map((entry) {
                          final count = (entry.value is List) ? (entry.value as List).length : 1;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.cardStroke),
                            ),
                            child: Text("${entry.key} $count", style: const TextStyle(fontSize: 10.5)),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInputField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        border: const Border(top: BorderSide(color: AppColors.cardStroke, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).padding.bottom + 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_rounded, color: AppColors.forest, size: 28),
            onPressed: _showAttachmentSheet,
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F3F0),
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _msgInputController,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: "Message ${widget.channelName}...",
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              gradient: AppColors.greenGradient,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              onPressed: _sendTextMessage,
            ),
          ),
        ],
      ),
    );
  }
}

class ImageViewerScreen extends StatelessWidget {
  final String imageUrl;

  const ImageViewerScreen({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(imageUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }
}