import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'app_core.dart';

// ============================================================================
// 1. DATA MODELS: PARTNER LISTING & COMMUNITY REVIEWS
// ============================================================================
class PartnerReview {
  final String id;
  final String authorName;
  final double rating;
  final String comment;
  final List<String> tags;
  final DateTime createdAt;

  PartnerReview({
    required this.id,
    required this.authorName,
    required this.rating,
    required this.comment,
    required this.tags,
    required this.createdAt,
  });

  factory PartnerReview.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PartnerReview(
      id: doc.id,
      authorName: data['authorName'] ?? 'Explorer',
      rating: (data['rating'] is num) ? (data['rating'] as num).toDouble() : 5.0,
      comment: data['comment'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorName': authorName,
      'rating': rating,
      'comment': comment,
      'tags': tags,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class PartnerListing {
  final String id;
  final String ownerUid;
  final String name;
  final String category; // 'guide', 'stay', 'gear', 'eatery'
  final String categoryLabel;
  final String location;
  final double? latitude;
  final double? longitude;
  final String pricing;
  final String phone;
  final String email;
  final String whatsapp;
  final String imageUrl;
  final String description;
  final double rating;
  final int reviewsCount;
  final bool isVerified;
  final bool isTopPick;
  final List<String> features;
  
  // Custom Category Attributes
  final String experienceOrPolicy; // Guide exp / Hotel check-in policy
  final String licensesOrAmenities; // Guide certs / Hotel amenities
  final String menuOrGearInventory; // Eatery menu / Rental gear stock
  final String spokenLanguages; // Spoken languages for guides

  PartnerListing({
    required this.id,
    required this.ownerUid,
    required this.name,
    required this.category,
    required this.categoryLabel,
    required this.location,
    this.latitude,
    this.longitude,
    required this.pricing,
    required this.phone,
    required this.email,
    required this.whatsapp,
    required this.imageUrl,
    required this.description,
    this.rating = 5.0,
    this.reviewsCount = 0,
    this.isVerified = true,
    this.isTopPick = false,
    this.features = const [],
    this.experienceOrPolicy = '',
    this.licensesOrAmenities = '',
    this.menuOrGearInventory = '',
    this.spokenLanguages = '',
  });

  factory PartnerListing.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PartnerListing(
      id: doc.id,
      ownerUid: data['ownerUid'] ?? '',
      name: data['name'] ?? 'Wilderness Partner',
      category: data['category'] ?? 'guide',
      categoryLabel: data['categoryLabel'] ?? 'Service Provider',
      location: data['location'] ?? 'Sri Lanka',
      latitude: (data['latitude'] is num) ? (data['latitude'] as num).toDouble() : null,
      longitude: (data['longitude'] is num) ? (data['longitude'] as num).toDouble() : null,
      pricing: data['pricing'] ?? 'Contact for rates',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      whatsapp: data['whatsapp'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      description: data['description'] ?? '',
      rating: (data['rating'] is num) ? (data['rating'] as num).toDouble() : 5.0,
      reviewsCount: (data['reviewsCount'] is num) ? (data['reviewsCount'] as num).toInt() : 0,
      isVerified: data['isVerified'] ?? true,
      isTopPick: data['isTopPick'] ?? false,
      features: List<String>.from(data['features'] ?? []),
      experienceOrPolicy: data['experienceOrPolicy'] ?? '',
      licensesOrAmenities: data['licensesOrAmenities'] ?? '',
      menuOrGearInventory: data['menuOrGearInventory'] ?? '',
      spokenLanguages: data['spokenLanguages'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerUid': ownerUid,
      'name': name,
      'category': category,
      'categoryLabel': categoryLabel,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'pricing': pricing,
      'phone': phone,
      'email': email,
      'whatsapp': whatsapp,
      'imageUrl': imageUrl,
      'description': description,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'isVerified': isVerified,
      'isTopPick': isTopPick,
      'features': features,
      'experienceOrPolicy': experienceOrPolicy,
      'licensesOrAmenities': licensesOrAmenities,
      'menuOrGearInventory': menuOrGearInventory,
      'spokenLanguages': spokenLanguages,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

// ============================================================================
// 2. MAIN HUB SCREENS & EXPORTS
// ============================================================================

/// Primary Hub Screen for main.dart
class NatureHubPage extends StatefulWidget {
  const NatureHubPage({super.key});

  @override
  State<NatureHubPage> createState() => _NatureHubPageState();
}

/// Routing alias ensuring LiveProfilePage navigation compiles cleanly
class TravelDirectoryPage extends StatelessWidget {
  const TravelDirectoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const NatureHubPage();
  }
}

class _NatureHubPageState extends State<NatureHubPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'all';

  // Current logged in user info
  String _currentUserRole = 'explorer';
  PartnerListing? _existingPartnerListing;
  StreamSubscription<DocumentSnapshot>? _userRoleSub;
  StreamSubscription<QuerySnapshot>? _myPartnerListingSub;

  static const Color forest = Color(0xFF0F3E2E);
  static const Color emerald = Color(0xFF10B981);
  static const Color canvasBg = Color(0xFFF4F7F5);
  static const Color cardStroke = Color(0xFFE2EBE5);
  static const Color amberGold = Color(0xFFF59E0B);

  final List<Map<String, String>> _filterCategories = [
    {'key': 'all', 'label': 'All Guilds', 'icon': '🌟'},
    {'key': 'stay', 'label': 'Eco Stays', 'icon': '🏕️'},
    {'key': 'guide', 'label': 'Tour Guides', 'icon': '🏔️'},
    {'key': 'gear', 'label': 'Gear Rentals', 'icon': '🎒'},
    {'key': 'eatery', 'label': 'Trail Eateries', 'icon': '🛖'},
  ];

  @override
  void initState() {
    super.initState();
    _listenToUserRoleAndListing();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _userRoleSub?.cancel();
    _myPartnerListingSub?.cancel();
    super.dispose();
  }

  void _listenToUserRoleAndListing() {
    final user = AuthController.I.currentUser;
    if (user == null || user.uid.isEmpty) return;

    // Listen to logged in user role
    _userRoleSub = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((snap) {
      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        final role = (data['role'] ?? 'explorer').toString();
        if (mounted) {
          setState(() => _currentUserRole = role);
        }
      }
    });

    // Check if the current user already has an active partner listing
    _myPartnerListingSub = FirebaseFirestore.instance
        .collection('partners')
        .where('ownerUid', isEqualTo: user.uid)
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (snap.docs.isNotEmpty && mounted) {
        setState(() {
          _existingPartnerListing = PartnerListing.fromFirestore(snap.docs.first);
        });
      }
    });
  }

  bool get _isPartnerAccount => _currentUserRole != 'explorer';

  // ============================================================================
  // COMMUNICATION & EXTERNAL ACTIONS
  // ============================================================================
  Future<void> _makeDirectCall(String phone) async {
    if (phone.isEmpty) return;
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await Clipboard.setData(ClipboardData(text: cleanPhone));
        _showToast("Phone number copied: $cleanPhone");
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: cleanPhone));
      _showToast("Phone number copied: $cleanPhone");
    }
  }

  Future<void> _launchWhatsApp(String phone, String partnerName) async {
    if (phone.isEmpty) return;
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final message = Uri.encodeComponent(
      "Hello $partnerName! I found your verified listing on Nature Travels Explorer app and would like to inquire about booking/availability.",
    );
    final uri = Uri.parse("https://wa.me/$cleanPhone?text=$message");

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: cleanPhone));
        _showToast("WhatsApp contact copied: $cleanPhone");
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: cleanPhone));
      _showToast("WhatsApp contact copied: $cleanPhone");
    }
  }

  Future<void> _sendDirectEmail(String email, String partnerName) async {
    if (email.isEmpty) return;
    final uri = Uri.parse("mailto:$email?subject=Nature%20Travels%20Inquiry%20for%20$partnerName");
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await Clipboard.setData(ClipboardData(text: email));
        _showToast("Email address copied: $email");
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: email));
      _showToast("Email address copied: $email");
    }
  }

  Future<void> _openGoogleMapsCoordinates(double lat, double lng, String label) async {
    final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showToast("Coordinates: $lat, $lng");
    }
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: forest,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ============================================================================
  // PARTNER ONBOARDING & LISTING MANAGER (HOTEL, GUIDE, GEAR, EATERY)
  // ============================================================================
  void _openPartnerActivationSheet(BuildContext context) {
    HapticFeedback.heavyImpact();
    final user = AuthController.I.currentUser;
    if (user == null) {
      _showToast("Please sign in to manage your partner listing.");
      return;
    }

    final listing = _existingPartnerListing;

    final nameCtrl = TextEditingController(text: listing?.name ?? user.name);
    final locationCtrl = TextEditingController(text: listing?.location ?? '');
    final priceCtrl = TextEditingController(text: listing?.pricing ?? '');
    final phoneCtrl = TextEditingController(text: listing?.phone ?? '');
    final emailCtrl = TextEditingController(text: listing?.email ?? user.email);
    final whatsappCtrl = TextEditingController(text: listing?.whatsapp ?? '');
    final imgUrlCtrl = TextEditingController(text: listing?.imageUrl ?? '');
    final descCtrl = TextEditingController(text: listing?.description ?? '');
    final featuresCtrl = TextEditingController(text: listing?.features.join(', ') ?? '');

    // Category-specific controllers
    final expOrPolicyCtrl = TextEditingController(text: listing?.experienceOrPolicy ?? '');
    final licOrAmenitiesCtrl = TextEditingController(text: listing?.licensesOrAmenities ?? '');
    final menuOrInventoryCtrl = TextEditingController(text: listing?.menuOrGearInventory ?? '');
    final languagesCtrl = TextEditingController(text: listing?.spokenLanguages ?? 'English, Sinhala');

    double? selectedLat = listing?.latitude;
    double? selectedLng = listing?.longitude;
    bool isLocating = false;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          Future<void> fetchCurrentLocation() async {
            setModalState(() => isLocating = true);
            try {
              LocationPermission permission = await Geolocator.checkPermission();
              if (permission == LocationPermission.denied) {
                permission = await Geolocator.requestPermission();
              }
              if (permission == LocationPermission.deniedForever) {
                _showToast("Location permissions are permanently denied.");
                setModalState(() => isLocating = false);
                return;
              }
              final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
              setModalState(() {
                selectedLat = pos.latitude;
                selectedLng = pos.longitude;
                isLocating = false;
              });
              _showToast("GPS coordinates pinned successfully!");
            } catch (e) {
              setModalState(() => isLocating = false);
              _showToast("Could not fetch GPS. Please ensure Location is enabled.");
            }
          }

          String getCategoryTitle() {
            switch (_currentUserRole) {
              case 'stay':
                return "Eco Stay & Lodging Profile";
              case 'guide':
                return "Mountain Guide Credentials";
              case 'gear':
                return "Camping Gear Outfitter Hub";
              case 'eatery':
                return "Trail Eatery & Food Post";
              default:
                return "Wilderness Service Listing";
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 12,
              left: 20,
              right: 20,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: emerald.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.verified_rounded, color: forest, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(getCategoryTitle(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: forest)),
                            const Text("Configure how travelers discover and contact your service", style: TextStyle(color: Color(0xFF6B7280), fontSize: 11.5)),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildInput(controller: nameCtrl, label: "Business / Entity Name", hint: "e.g. Ella Forest Glamping / Knuckles Trek Leader", icon: Icons.badge_rounded),
                  _buildInput(controller: locationCtrl, label: "Operating Base / Region", hint: "e.g. Ohiya, Central Highlands", icon: Icons.map_rounded),

                  // 1-Tap GPS Location Button
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: canvasBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: cardStroke)),
                    child: Row(
                      children: [
                        const Icon(Icons.my_location_rounded, color: forest, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Basecamp GPS Coordinates", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: forest)),
                              Text(
                                selectedLat != null ? "${selectedLat!.toStringAsFixed(4)}, ${selectedLng!.toStringAsFixed(4)}" : "Pin precise location for travelers",
                                style: TextStyle(fontSize: 11, color: selectedLat != null ? emerald : const Color(0xFF6B7280), fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          icon: isLocating
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: forest))
                              : const Icon(Icons.gps_fixed_rounded, size: 16, color: forest),
                          label: Text(selectedLat != null ? "Update" : "Pin GPS", style: const TextStyle(color: forest, fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: isLocating ? null : fetchCurrentLocation,
                        ),
                      ],
                    ),
                  ),

                  _buildInput(controller: priceCtrl, label: "Pricing Structure / Starting Rates", hint: "e.g. LKR 8,500 / Night or Day Trek", icon: Icons.payments_rounded),
                  _buildInput(controller: phoneCtrl, label: "Direct Phone Number", hint: "e.g. +94 77 123 4567", icon: Icons.phone_rounded, keyboard: TextInputType.phone),
                  _buildInput(controller: whatsappCtrl, label: "WhatsApp Number (For instant inquiries)", hint: "e.g. +94 77 123 4567", icon: Icons.chat_rounded, keyboard: TextInputType.phone),
                  _buildInput(controller: emailCtrl, label: "Inquiry Email", hint: "e.g. info@wildstay.lk", icon: Icons.alternate_email_rounded, keyboard: TextInputType.emailAddress),
                  _buildInput(controller: imgUrlCtrl, label: "Cover Image URL", hint: "Direct image URL (R2 or Web)", icon: Icons.image_rounded),
                  _buildInput(controller: featuresCtrl, label: "Key Highlights (Comma separated)", hint: "e.g. Solar Power, Hot Water, Bonfire, Tent Included", icon: Icons.star_outline_rounded),

                  // Category Specific Form Fields
                  if (_currentUserRole == 'stay') ...[
                    _buildInput(controller: licOrAmenitiesCtrl, label: "Amenities & Campsite Facilities", hint: "e.g. Attached Bath, Wi-Fi, Stargazing Deck, Breakfast", icon: Icons.hotel_rounded),
                    _buildInput(controller: expOrPolicyCtrl, label: "Check-in Times & Stay Guidelines", hint: "e.g. Check-in 2 PM / Eco-rules: Leave No Trace", icon: Icons.policy_rounded),
                  ] else if (_currentUserRole == 'guide') ...[
                    _buildInput(controller: licOrAmenitiesCtrl, label: "Guide Licenses & Certifications", hint: "e.g. SLTDA Certified / Red Cross First Aid #4920", icon: Icons.military_tech_rounded),
                    _buildInput(controller: expOrPolicyCtrl, label: "Experience & Track Record", hint: "e.g. 8+ Years in Knuckles Range & Adam's Peak", icon: Icons.hiking_rounded),
                    _buildInput(controller: languagesCtrl, label: "Languages Spoken", hint: "e.g. English, Sinhala, German", icon: Icons.translate_rounded),
                  ] else if (_currentUserRole == 'eatery') ...[
                    _buildInput(controller: menuOrInventoryCtrl, label: "Signature Trail Menu Highlights", hint: "e.g. Village Claypot Rice & Curry, Rotti, Herbal Tea", icon: Icons.restaurant_menu_rounded, maxLines: 2),
                    _buildInput(controller: expOrPolicyCtrl, label: "Operating Hours & Meal Schedule", hint: "e.g. Open 6:00 AM - 9:30 PM Daily", icon: Icons.access_time_rounded),
                  ] else if (_currentUserRole == 'gear') ...[
                    _buildInput(controller: menuOrInventoryCtrl, label: "Available Gear Inventory", hint: "e.g. 2-4 Person Tents, Sleeping Bags, Gas Stoves, Trek Poles", icon: Icons.backpack_rounded, maxLines: 2),
                    _buildInput(controller: expOrPolicyCtrl, label: "Rental Terms & Security Deposit", hint: "e.g. NIC Copy or LKR 2,000 Refundable Deposit", icon: Icons.handshake_outlined),
                  ],

                  _buildInput(controller: descCtrl, label: "Detailed Overview Narrative", hint: "Tell explorers what makes your wilderness service memorable...", icon: Icons.notes_rounded, maxLines: 3),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                      label: Text(
                        isSaving ? "Saving Listing..." : (listing != null ? "Update Active Guild Listing" : "Publish Verified Guild Listing"),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: forest,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (nameCtrl.text.trim().isEmpty || locationCtrl.text.trim().isEmpty) {
                                _showToast("Please provide both name and location.");
                                return;
                              }

                              setModalState(() => isSaving = true);

                              final featuresList = featuresCtrl.text
                                  .split(',')
                                  .map((e) => e.trim())
                                  .where((e) => e.isNotEmpty)
                                  .toList();

                              final String catLabel = _currentUserRole == 'stay'
                                  ? 'Eco Stay & Lodge'
                                  : (_currentUserRole == 'guide'
                                      ? 'Certified Mountain Guide'
                                      : (_currentUserRole == 'gear' ? 'Gear Outfitter' : 'Trail Eatery & Food'));

                              final updatedListing = PartnerListing(
                                id: listing?.id ?? '',
                                ownerUid: user.uid,
                                name: nameCtrl.text.trim(),
                                category: _currentUserRole,
                                categoryLabel: catLabel,
                                location: locationCtrl.text.trim(),
                                latitude: selectedLat,
                                longitude: selectedLng,
                                pricing: priceCtrl.text.trim().isEmpty ? 'Contact for rates' : priceCtrl.text.trim(),
                                phone: phoneCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                whatsapp: whatsappCtrl.text.trim().isNotEmpty ? whatsappCtrl.text.trim() : phoneCtrl.text.trim(),
                                imageUrl: imgUrlCtrl.text.trim().isNotEmpty
                                    ? imgUrlCtrl.text.trim()
                                    : 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800',
                                description: descCtrl.text.trim(),
                                rating: listing?.rating ?? 5.0,
                                reviewsCount: listing?.reviewsCount ?? 0,
                                isVerified: true,
                                isTopPick: listing?.isTopPick ?? false,
                                features: featuresList.isNotEmpty ? featuresList : ['Verified Host', 'Wilderness Safe'],
                                experienceOrPolicy: expOrPolicyCtrl.text.trim(),
                                licensesOrAmenities: licOrAmenitiesCtrl.text.trim(),
                                menuOrGearInventory: menuOrInventoryCtrl.text.trim(),
                                spokenLanguages: languagesCtrl.text.trim(),
                              );

                              try {
                                if (listing != null && listing.id.isNotEmpty) {
                                  await FirebaseFirestore.instance.collection('partners').doc(listing.id).update(updatedListing.toMap());
                                } else {
                                  await FirebaseFirestore.instance.collection('partners').add(updatedListing.toMap());
                                }

                                if (mounted) {
                                  Navigator.pop(ctx);
                                  _showToast("Guild listing published live! 🌿");
                                }
                              } catch (e) {
                                setModalState(() => isSaving = false);
                                _showToast("Failed to save. Check your connection.");
                              }
                            },
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

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboard,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF13221B)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
          hintText: hint,
          hintStyle: TextStyle(fontSize: 12, color: Colors.grey.withOpacity(0.6)),
          prefixIcon: Icon(icon, color: forest, size: 19),
          filled: true,
          fillColor: canvasBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: forest, width: 1.4),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // LEAVE A REVIEW & FEEDBACK MODAL
  // ============================================================================
  void _openAddReviewSheet(BuildContext context, PartnerListing partner) {
    HapticFeedback.lightImpact();
    final nameCtrl = TextEditingController(text: AuthController.I.currentUser?.name ?? 'Explorer');
    final commentCtrl = TextEditingController();
    double selectedRating = 5.0;
    final List<String> selectedTags = [];

    final availableTags = [
      "Punctual",
      "Authentic Food",
      "Fair Pricing",
      "Clean Campsite",
      "First Aid Ready",
      "Great Hospitality",
      "Friendly Host",
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 14,
              left: 20,
              right: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10))),
                ),
                const SizedBox(height: 14),
                Text("Review: ${partner.name}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: forest)),
                const Text("Share your expedition feedback with fellow travelers", style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starVal = index + 1.0;
                    return IconButton(
                      icon: Icon(
                        selectedRating >= starVal ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: amberGold,
                        size: 34,
                      ),
                      onPressed: () => setModalState(() => selectedRating = starVal),
                    );
                  }),
                ),
                Center(
                  child: Text("$selectedRating / 5.0 Stars", style: const TextStyle(fontWeight: FontWeight.w800, color: amberGold, fontSize: 14)),
                ),
                const SizedBox(height: 14),

                const Text("Experience Highlights", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF4B5563))),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: availableTags.map((t) {
                    final isSel = selectedTags.contains(t);
                    return FilterChip(
                      label: Text(t, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isSel ? Colors.white : forest)),
                      selected: isSel,
                      selectedColor: forest,
                      backgroundColor: canvasBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSel ? forest : cardStroke)),
                      onSelected: (val) {
                        setModalState(() {
                          if (val) {
                            selectedTags.add(t);
                          } else {
                            selectedTags.remove(t);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: commentCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    labelText: "Your Experience Review",
                    hintText: "How was the guidance, hospitality, or amenities?",
                    filled: true,
                    fillColor: canvasBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    label: const Text("Post Community Review", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: forest, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: () async {
                      if (commentCtrl.text.trim().isEmpty) {
                        _showToast("Please write a short comment about your experience.");
                        return;
                      }

                      final review = PartnerReview(
                        id: '',
                        authorName: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'Explorer',
                        rating: selectedRating,
                        comment: commentCtrl.text.trim(),
                        tags: selectedTags,
                        createdAt: DateTime.now(),
                      );

                      Navigator.pop(ctx);

                      try {
                        final partnerDoc = FirebaseFirestore.instance.collection('partners').doc(partner.id);
                        await partnerDoc.collection('reviews').add(review.toMap());

                        final newCount = partner.reviewsCount + 1;
                        final newAvg = ((partner.rating * partner.reviewsCount) + selectedRating) / newCount;

                        await partnerDoc.update({
                          'reviewsCount': newCount,
                          'rating': double.parse(newAvg.toStringAsFixed(1)),
                        });

                        _showToast("Review submitted! Thank you for supporting wilderness hosts 🌿");
                      } catch (e) {
                        _showToast("Could not submit review. Please try again.");
                      }
                    },
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
  // FULL RICH PROFILE MODAL (EXPLORER PERSPECTIVE)
  // ============================================================================
  void _openPartnerDetails(BuildContext context, PartnerListing partner) {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.90,
        minChildSize: 0.50,
        maxChildSize: 0.96,
        expand: false,
        builder: (sheetCtx, scrollCtrl) {
          return ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              Center(
                child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 14),

              // Hero Image & Badges
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    Image.network(
                      partner.imageUrl.isNotEmpty ? partner.imageUrl : 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800',
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(height: 220, color: canvasBg, child: const Icon(Icons.nature_rounded, size: 40, color: forest)),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_rounded, color: emerald, size: 15),
                            const SizedBox(width: 5),
                            Text(partner.categoryLabel, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Title, Location, Rating
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(partner.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: forest)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, size: 14, color: emerald),
                            const SizedBox(width: 4),
                            Expanded(child: Text(partner.location, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 13, fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: canvasBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: cardStroke)),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: amberGold, size: 18),
                            const SizedBox(width: 4),
                            Text("${partner.rating}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: forest)),
                          ],
                        ),
                        Text("${partner.reviewsCount} reviews", style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Direct Communication Action Strip
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 17),
                      label: const Text("WhatsApp", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _launchWhatsApp(partner.whatsapp.isNotEmpty ? partner.whatsapp : partner.phone, partner.name),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 17),
                    label: const Text("Call", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: forest,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _makeDirectCall(partner.phone),
                  ),
                  if (partner.email.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.alternate_email_rounded, color: forest),
                      onPressed: () => _sendDirectEmail(partner.email, partner.name),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Rates & Pricing Strip
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: canvasBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: cardStroke)),
                child: Row(
                  children: [
                    const Icon(Icons.payments_rounded, color: emerald, size: 20),
                    const SizedBox(width: 10),
                    const Text("Rates: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF6B7280))),
                    Text(partner.pricing, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: forest)),
                    const Spacer(),
                    if (partner.latitude != null && partner.longitude != null)
                      GestureDetector(
                        onTap: () => _openGoogleMapsCoordinates(partner.latitude!, partner.longitude!, partner.name),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: emerald.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                          child: const Row(
                            children: [
                              Icon(Icons.directions_rounded, size: 14, color: forest),
                              SizedBox(width: 4),
                              Text("Maps GPS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: forest)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Category-Specific Profile Details
              if (partner.category == 'guide') ...[
                if (partner.experienceOrPolicy.isNotEmpty)
                  _buildDetailTile(Icons.military_tech_rounded, "Experience & Field Track", partner.experienceOrPolicy),
                if (partner.licensesOrAmenities.isNotEmpty)
                  _buildDetailTile(Icons.verified_user_rounded, "Official Licenses & First Aid", partner.licensesOrAmenities),
                if (partner.spokenLanguages.isNotEmpty)
                  _buildDetailTile(Icons.translate_rounded, "Languages Spoken", partner.spokenLanguages),
              ] else if (partner.category == 'stay') ...[
                if (partner.licensesOrAmenities.isNotEmpty)
                  _buildDetailTile(Icons.hotel_rounded, "Amenities & Basecamp Facilities", partner.licensesOrAmenities),
                if (partner.experienceOrPolicy.isNotEmpty)
                  _buildDetailTile(Icons.policy_rounded, "Check-in Times & Guidelines", partner.experienceOrPolicy),
              ] else if (partner.category == 'eatery') ...[
                if (partner.menuOrGearInventory.isNotEmpty)
                  _buildDetailTile(Icons.restaurant_menu_rounded, "Menu Highlights & Trail Rations", partner.menuOrGearInventory),
                if (partner.experienceOrPolicy.isNotEmpty)
                  _buildDetailTile(Icons.access_time_rounded, "Operating Hours", partner.experienceOrPolicy),
              ] else if (partner.category == 'gear') ...[
                if (partner.menuOrGearInventory.isNotEmpty)
                  _buildDetailTile(Icons.backpack_rounded, "Equipment Available for Rent", partner.menuOrGearInventory),
                if (partner.experienceOrPolicy.isNotEmpty)
                  _buildDetailTile(Icons.handshake_outlined, "Rental Terms & Security Deposit", partner.experienceOrPolicy),
              ],

              // General Highlights
              if (partner.features.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text("Key Highlights", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: forest)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: partner.features.map((f) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: emerald.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 12, color: emerald),
                          const SizedBox(width: 5),
                          Text(f, style: const TextStyle(color: forest, fontSize: 11.5, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],

              if (partner.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text("Overview & Guidelines", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: forest)),
                const SizedBox(height: 6),
                Text(partner.description, style: const TextStyle(color: Color(0xFF374151), fontSize: 13, height: 1.45)),
              ],

              const SizedBox(height: 20),
              const Divider(color: cardStroke),
              const SizedBox(height: 8),

              // Reviews Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Explorer Reviews", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: forest)),
                  TextButton.icon(
                    icon: const Icon(Icons.rate_review_rounded, size: 16, color: forest),
                    label: const Text("Write Review", style: TextStyle(color: forest, fontWeight: FontWeight.bold, fontSize: 12.5)),
                    onPressed: () => _openAddReviewSheet(context, partner),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('partners')
                    .doc(partner.id)
                    .collection('reviews')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: forest)));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: canvasBg, borderRadius: BorderRadius.circular(14)),
                      child: const Center(
                        child: Text("No explorer reviews yet. Be the first to leave feedback! 🌿", style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      ),
                    );
                  }

                  return Column(
                    children: docs.map((d) {
                      final rev = PartnerReview.fromFirestore(d);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: canvasBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cardStroke),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(rev.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: forest)),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, color: amberGold, size: 14),
                                    const SizedBox(width: 2),
                                    Text("${rev.rating}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: forest)),
                                  ],
                                ),
                              ],
                            ),
                            if (rev.tags.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                children: rev.tags.map((t) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                                  child: Text(t, style: const TextStyle(fontSize: 10, color: emerald, fontWeight: FontWeight.bold)),
                                )).toList(),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(rev.comment, style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151), height: 1.35)),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: canvasBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: cardStroke)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: forest, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6B7280))),
                const SizedBox(height: 2),
                Text(content, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: forest)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // MAIN BUILD
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: canvasBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Atmospheric Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [forest, emerald]),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(color: forest.withOpacity(0.18), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.travel_explore_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Wilderness Guild', style: TextStyle(color: forest, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                        Text('Verified Guides, Eco Stays & Outfitters', style: TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),

                  // ONLY DISPLAY ACTIVATION/SETUP BUTTON FOR PARTNER ACCOUNTS
                  if (_isPartnerAccount)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.business_center_rounded, color: Colors.white, size: 14),
                      label: Text(
                        _existingPartnerListing != null ? "Manage Listing" : "Activate Hub",
                        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: forest,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      onPressed: () => _openPartnerActivationSheet(context),
                    ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardStroke, width: 1.2),
                  boxShadow: [
                    BoxShadow(color: forest.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF13221B)),
                  decoration: InputDecoration(
                    hintText: "Search guides, stays, camping gear...",
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12.5),
                    prefixIcon: const Icon(Icons.search_rounded, color: forest, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () => setState(() => _searchCtrl.clear()))
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            // Category Filter Pills
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                scrollDirection: Axis.horizontal,
                itemCount: _filterCategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _filterCategories[index];
                  final isSel = _selectedCategory == cat['key'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat['key']!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? forest : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSel ? forest : cardStroke),
                      ),
                      child: Row(
                        children: [
                          Text(cat['icon']!, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 6),
                          Text(
                            cat['label']!,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isSel ? Colors.white : const Color(0xFF4B5563),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Realtime Stream of Registered Partners
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('partners').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: forest));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  List<PartnerListing> partners = docs.map((d) => PartnerListing.fromFirestore(d)).toList();

                  if (_selectedCategory != 'all') {
                    partners = partners.where((p) => p.category == _selectedCategory).toList();
                  }

                  final query = _searchCtrl.text.trim().toLowerCase();
                  if (query.isNotEmpty) {
                    partners = partners.where((p) {
                      return p.name.toLowerCase().contains(query) ||
                          p.location.toLowerCase().contains(query) ||
                          p.categoryLabel.toLowerCase().contains(query) ||
                          p.features.any((f) => f.toLowerCase().contains(query));
                    }).toList();
                  }

                  if (partners.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    physics: const BouncingScrollPhysics(),
                    itemCount: partners.length,
                    itemBuilder: (context, index) {
                      final item = partners[index];
                      return _buildPartnerCard(item);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.travel_explore_rounded, size: 48, color: Colors.black26),
            ),
            const SizedBox(height: 14),
            const Text("No Verified Guild Services Found", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: forest)),
            const SizedBox(height: 6),
            const Text(
              "Check back soon or search for another region to explore verified stays, guides, and outfitters.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerCard(PartnerListing partner) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardStroke, width: 1.2),
        boxShadow: [
          BoxShadow(color: forest.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: InkWell(
        onTap: () => _openPartnerDetails(context, partner),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  partner.imageUrl.isNotEmpty ? partner.imageUrl : 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800',
                  width: 90,
                  height: 95,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 90, height: 95, color: canvasBg, child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(partner.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: forest)),
                        ),
                        if (partner.isVerified)
                          const Icon(Icons.verified_rounded, color: emerald, size: 16),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(partner.categoryLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6B7280))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 12, color: emerald),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(partner.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(partner.pricing, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: forest)),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: amberGold, size: 14),
                            const SizedBox(width: 2),
                            Text("${partner.rating}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5, color: forest)),
                            Text(" (${partner.reviewsCount})", style: const TextStyle(fontSize: 10.5, color: Color(0xFF9CA3AF))),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
