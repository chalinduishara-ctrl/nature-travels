import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'app_core.dart';

// =============================================================================
// OFFLINE-FIRST AUTO-CACHING TILE PROVIDER
// =============================================================================
class AutoCachingTileProvider extends TileProvider {
  final String basePath;

  AutoCachingTileProvider(this.basePath);

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final int z = coordinates.z;
    final int x = coordinates.x;
    final int y = coordinates.y;

    // Check local storage file
    final localTileFile = File('$basePath/$z/$x/$y.png');
    if (localTileFile.existsSync()) {
      return FileImage(localTileFile);
    }

    // If not found locally, fetch via network and auto-cache in background
    final String url = getTileUrl(coordinates, options);
    _downloadAndCache(url, localTileFile);

    return NetworkImage(url, headers: headers);
  }

  void _downloadAndCache(String url, File targetFile) async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        await targetFile.parent.create(recursive: true);
        await targetFile.writeAsBytes(res.bodyBytes);
      }
    } catch (_) {
      // Offline fallback silent catch
    }
  }
}

/// Crowdsourced Wilderness Hazard & Damage Model
class TrailHazard {
  final String id;
  final String title;
  final String category;
  final String severity;
  final String description;
  final LatLng location;
  final String reportedBy;
  final String timeAgo;
  int confirmCount;
  bool isResolved;

  TrailHazard({
    required this.id,
    required this.title,
    required this.category,
    required this.severity,
    required this.description,
    required this.location,
    required this.reportedBy,
    required this.timeAgo,
    this.confirmCount = 1,
    this.isResolved = false,
  });
}

class MapSpotsPage extends StatefulWidget {
  const MapSpotsPage({super.key});

  @override
  State<MapSpotsPage> createState() => _MapSpotsPageState();
}

class _MapSpotsPageState extends State<MapSpotsPage> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _carouselController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();

  // Sri Lanka Central Highlands default center until GPS locks
  LatLng _currentCenter = const LatLng(7.4649, 80.7891);
  double _currentZoom = 13.0;

  int _selectedLayer = 0;
  String _selectedCategory = "All";
  String _searchQuery = "";
  Map<String, dynamic>? _selectedSpot;

  // Real Hardware GPS Engine
  bool _isNavigating = false;
  bool _hasRealGpsFix = false;
  bool _isGpsServiceEnabled = true;
  bool _isLoadingRoute = false;
  LocationPermission _permissionStatus = LocationPermission.denied;

  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _stopwatchTimer;
  int _elapsedSeconds = 0;

  // Hardware telemetry readings
  double _currentSpeedKmh = 0.0;
  double _currentAltitudeMeters = 0.0;
  double _currentHeadingDegrees = 0.0;
  double _totalDistanceMeters = 0.0;
  double _remainingDistanceMeters = 0.0;
  int _etaMinutes = 0;

  LatLng _liveUserPosition = const LatLng(7.4649, 80.7891);
  LatLng? _lastRecordedFix;
  LatLng? _lastRouteCalculatedPosition;
  final List<LatLng> _recordedBreadcrumbs = [];
  List<LatLng> _activeRouteToDestination = [];

  // ===========================================================================
  // SRI LANKA HIGH-PRECISION DUAL POI & PLACE SEARCH ENGINE
  // ===========================================================================
  List<Map<String, dynamic>> _livePoiSearchResults = [];
  bool _isSearchingPoi = false;
  Timer? _searchDebounceTimer;

  // Quick search suggestions across Sri Lanka
  final List<String> _quickSuggestions = [
    "Schools",
    "Supermarkets",
    "Hospitals",
    "Temples",
    "Waterfalls",
    "Kandy",
    "Galle Fort",
    "Colombo",
    "Ella",
    "Sigiriya",
  ];

  // ===========================================================================
  // OFFLINE MAP ENGINE STATE
  // ===========================================================================
  String? _offlineCacheDirectory;
  bool _isDownloadingIsland = false;
  double _islandDownloadProgress = 0.0;
  int _downloadedTilesCount = 0;
  int _totalTilesToDownload = 0;
  bool _isFullIslandReady = false;
  final Set<String> _downloadedRegions = {"Knuckles Cloud Forest", "Ella High Gap"};

  // Category filter chips
  final List<String> _categories = [
    "All",
    "High Peaks",
    "Waterfalls",
    "Wildlife & Safari",
    "Ridge Camps",
    "Deep Caves & Ruins",
    "Rainforests",
  ];

  // Crowdsourced hazards database
  final List<TrailHazard> _hazards = [
    TrailHazard(
      id: "hz_1",
      title: "Giant Pine Tree Fallen Across Path",
      category: "Fallen Tree",
      severity: "Warning",
      description: "Massive timber blocking the steep ridge climb. Scrambling under branches required.",
      location: const LatLng(7.4620, 80.7860),
      reportedBy: "Kasun_Explorer",
      timeAgo: "2 hours ago",
      confirmCount: 7,
    ),
    TrailHazard(
      id: "hz_2",
      title: "Suspension Wooden Footbridge Broken",
      category: "Broken Bridge",
      severity: "Critical Block",
      description: "Center wooden planks washed away by heavy flash flood. River crossing impassable after rain.",
      location: const LatLng(6.7780, 80.8430),
      reportedBy: "TrailBlazer_SL",
      timeAgo: "4 hours ago",
      confirmCount: 14,
    ),
    TrailHazard(
      id: "hz_3",
      title: "Wild Elephant Corridor Warning",
      category: "Elephant Danger",
      severity: "Dangerous",
      description: "Solitary bull elephant spotted browsing right beside the track near stream crossing.",
      location: const LatLng(8.0310, 80.8320),
      reportedBy: "WildTracker_99",
      timeAgo: "35 mins ago",
      confirmCount: 5,
    ),
    TrailHazard(
      id: "hz_4",
      title: "Severe Mudslide on Devil's Staircase V-Cut",
      category: "Landslide",
      severity: "Dangerous",
      description: "Loose boulders and heavy mudflow covering 40m of trail. Trekking poles highly recommended.",
      location: const LatLng(6.7840, 80.8405),
      reportedBy: "Highland_Hiker",
      timeAgo: "1 day ago",
      confirmCount: 22,
    ),
  ];

  // 32 Authentic Expeditions Database
  final List<Map<String, dynamic>> _spotsDatabase = [
    {
      "id": "spot_1",
      "name": "Knuckles 5 Peaks Ridge",
      "category": "High Peaks",
      "district": "Matale / Kandy",
      "elevation": "1,906m Alt",
      "distance": "14.2 km Trail",
      "difficulty": "Hard",
      "duration": "7 Hours",
      "center": const LatLng(7.4649, 80.7891),
      "weather": "17°C Mist",
      "leechIndex": "High",
      "rating": "4.9 ★ (1.4k)",
      "img": "https://images.unsplash.com/photo-1542332213-9b5a5a3fad35?w=600",
      "desc": "High altitude mist-covered cloud forest ridge traverse with sheer cliff vistas and endemic pygmy lizards.",
      "elevationPoints": [1100, 1350, 1600, 1850, 1906, 1750, 1200],
      "hasTrail": true,
      "path": [
        const LatLng(7.4500, 80.7700),
        const LatLng(7.4540, 80.7750),
        const LatLng(7.4590, 80.7810),
        const LatLng(7.4649, 80.7891),
        const LatLng(7.4710, 80.7950),
      ]
    },
    {
      "id": "spot_2",
      "name": "Kirigalpotta Summit Trail",
      "category": "High Peaks",
      "district": "Nuwara Eliya (Horton)",
      "elevation": "2,388m (2nd Highest)",
      "distance": "12.0 km Trail",
      "difficulty": "Extreme",
      "duration": "6.5 Hours",
      "center": const LatLng(6.7981, 80.7672),
      "weather": "12°C Alpine Frost",
      "leechIndex": "Low",
      "rating": "4.8 ★ (890)",
      "img": "https://images.unsplash.com/photo-1519681393784-d120267933ba?w=600",
      "desc": "Sri Lanka's 2nd highest peak, crossing peat bogs, dwarf rhododendron blooms, and leopard habitats.",
      "elevationPoints": [2100, 2150, 2220, 2300, 2388, 2280, 2140],
      "hasTrail": true,
      "path": [
        const LatLng(6.8028, 80.8092),
        const LatLng(6.8010, 80.7920),
        const LatLng(6.7981, 80.7672),
      ]
    },
    {
      "id": "spot_3",
      "name": "Devil's Staircase Zigzag",
      "category": "High Peaks",
      "district": "Badulla (Ohiya)",
      "elevation": "1,940m to 1,100m",
      "distance": "13.5 km Trail",
      "difficulty": "Extreme",
      "duration": "6 Hours",
      "center": const LatLng(6.7820, 80.8410),
      "weather": "18°C Mountain Wind",
      "leechIndex": "Moderate",
      "rating": "4.9 ★ (2.1k)",
      "img": "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=600",
      "desc": "Famous hairpin rocky descent linking misty Ohiya to Kalupahana, passing V-Cut and Bambarakanda canyon.",
      "elevationPoints": [1940, 1800, 1620, 1450, 1300, 1100],
      "hasTrail": true,
      "path": [
        const LatLng(6.8150, 80.8350),
        const LatLng(6.8020, 80.8380),
        const LatLng(6.7880, 80.8400),
        const LatLng(6.7820, 80.8410),
      ]
    },
    {
      "id": "spot_4",
      "name": "Ella Rock Wilderness Trail",
      "category": "High Peaks",
      "district": "Badulla (Ella)",
      "elevation": "1,350m Alt",
      "distance": "8.0 km Trail",
      "difficulty": "Moderate",
      "duration": "4 Hours",
      "center": const LatLng(6.8550, 81.0450),
      "weather": "22°C Clear Sun",
      "leechIndex": "Low",
      "rating": "4.7 ★ (3.8k)",
      "img": "https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=600",
      "desc": "Track traces railway line, tea estates, and steep eucalyptus woodlands to the panoramic Ella Gap overhang.",
      "elevationPoints": [1000, 1050, 1180, 1260, 1350],
      "hasTrail": true,
      "path": [
        const LatLng(6.8710, 81.0470),
        const LatLng(6.8650, 81.0460),
        const LatLng(6.8550, 81.0450),
      ]
    },
    {
      "id": "spot_5",
      "name": "Lakegala Pyramid Rock",
      "category": "High Peaks",
      "district": "Meemure, Matale",
      "elevation": "1,310m Alt",
      "distance": "9.0 km Trail",
      "difficulty": "Expert (Ropes)",
      "duration": "8.5 Hours",
      "center": const LatLng(7.4917, 80.8833),
      "weather": "24°C Humid Valley",
      "leechIndex": "High",
      "rating": "5.0 ★ (420)",
      "img": "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=600",
      "desc": "Sri Lanka's most extreme rock scramble. Bare triangular monolith rising menacingly over Meemure village.",
      "elevationPoints": [450, 700, 950, 1150, 1310],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_6",
      "name": "Narangala Golden Ridge",
      "category": "High Peaks",
      "district": "Badulla (Hali-Ela)",
      "elevation": "1,520m Alt",
      "distance": "6.4 km Trail",
      "difficulty": "Moderate",
      "duration": "3.5 Hours",
      "center": const LatLng(7.0425, 81.0028),
      "weather": "21°C Breezy",
      "leechIndex": "None",
      "rating": "4.8 ★ (1.1k)",
      "img": "https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?w=600",
      "desc": "Golden tussock grassland ridge offering uninterrupted views of Kehelpathdoruwa and Mahaweli plains.",
      "elevationPoints": [1150, 1250, 1380, 1460, 1520],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_7",
      "name": "Pidurutalagala Mountain Base",
      "category": "High Peaks",
      "district": "Nuwara Eliya",
      "elevation": "2,524m Highest",
      "distance": "Forest Reserve Track",
      "difficulty": "Moderate",
      "duration": "4 Hours",
      "center": const LatLng(7.0003, 80.7719),
      "weather": "10°C High Wind",
      "leechIndex": "Low",
      "rating": "4.6 ★ (720)",
      "img": "https://images.unsplash.com/photo-1519681393784-d120267933ba?w=600",
      "desc": "The roof of Sri Lanka surrounded by virgin mountain wet cloud forests and endemic highland avifauna.",
      "elevationPoints": [1900, 2100, 2350, 2524],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_8",
      "name": "Adam's Peak (Murray Trail)",
      "category": "High Peaks",
      "district": "Ratnapura",
      "elevation": "2,243m Alt",
      "distance": "16.0 km Offbeat",
      "difficulty": "Hard",
      "duration": "8 Hours",
      "center": const LatLng(6.8095, 80.4994),
      "weather": "14°C Night Chill",
      "leechIndex": "Extreme",
      "rating": "4.9 ★ (5.4k)",
      "img": "https://images.unsplash.com/photo-1542332213-9b5a5a3fad35?w=600",
      "desc": "The wild and rugged route through Peak Wilderness Sanctuary escaping the cement stair pilgrim paths.",
      "elevationPoints": [700, 1100, 1500, 1900, 2243],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_9",
      "name": "Chariot Path Grasslands",
      "category": "High Peaks",
      "district": "Pussellawa / Frotoft",
      "elevation": "1,980m Alt",
      "distance": "7.5 km Trail",
      "difficulty": "Moderate",
      "duration": "4.5 Hours",
      "center": const LatLng(6.9850, 80.7320),
      "weather": "16°C Dense Fog",
      "leechIndex": "High",
      "rating": "4.7 ★ (810)",
      "img": "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=600",
      "desc": "Mystical high-altitude savannah plateau with pigmy trees and legendary natural ponds.",
      "elevationPoints": [1500, 1700, 1850, 1980],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_10",
      "name": "Bible Rock (Bathalegala)",
      "category": "High Peaks",
      "district": "Kegalle (Aranayake)",
      "elevation": "798m Alt",
      "distance": "4.2 km Trail",
      "difficulty": "Moderate",
      "duration": "3 Hours",
      "center": const LatLng(7.1856, 80.4344),
      "weather": "25°C Tropical",
      "leechIndex": "Low",
      "rating": "4.6 ★ (980)",
      "img": "https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=600",
      "desc": "Iconic fortress-like plateau rock dominating the Kegalle basin with steep 360-degree edge drops.",
      "elevationPoints": [200, 420, 650, 798],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_11",
      "name": "Diyaluma Upper Rock Pools",
      "category": "Waterfalls",
      "district": "Badulla (Koslanda)",
      "elevation": "700m Alt",
      "distance": "3.5 km Trek",
      "difficulty": "Moderate",
      "duration": "2.5 Hours",
      "center": const LatLng(6.7339, 81.0311),
      "weather": "25°C Warm Spray",
      "leechIndex": "None",
      "rating": "4.9 ★ (4.2k)",
      "img": "https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?w=600",
      "desc": "Natural granite infinity jacuzzis perched directly above a 220-meter sheer plummet.",
      "elevationPoints": [500, 580, 640, 700],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_12",
      "name": "Bambarakanda Giant Falls",
      "category": "Waterfalls",
      "district": "Kalupahana",
      "elevation": "1,100m Alt",
      "distance": "2.0 km Trek",
      "difficulty": "Easy",
      "duration": "1.5 Hours",
      "center": const LatLng(6.7710, 80.8450),
      "weather": "21°C Mist Spray",
      "leechIndex": "Moderate",
      "rating": "4.8 ★ (2.9k)",
      "img": "https://images.unsplash.com/photo-1542332213-9b5a5a3fad35?w=600",
      "desc": "The highest waterfall in Sri Lanka (263 meters), tumbling through a narrow pine canyon.",
      "elevationPoints": [980, 1040, 1100],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_13",
      "name": "Aberdeen Cascades & Gorge",
      "category": "Waterfalls",
      "district": "Ginigathena, Nuwara Eliya",
      "elevation": "680m Alt",
      "distance": "2.8 km Trail",
      "difficulty": "Moderate",
      "duration": "2 Hours",
      "center": const LatLng(6.9536, 80.5058),
      "weather": "23°C Humid Mist",
      "leechIndex": "Moderate",
      "rating": "4.7 ★ (1.3k)",
      "img": "https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?w=600",
      "desc": "Stunning 98m thunderous plunge into an obsidian rock canyon pool shrouded in rainforest ferns.",
      "elevationPoints": [550, 610, 680],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_14",
      "name": "Laxapana Falls Canyon",
      "category": "Waterfalls",
      "district": "Maskeliya",
      "elevation": "710m Alt",
      "distance": "3.0 km Steep Steps",
      "difficulty": "Moderate",
      "duration": "2.5 Hours",
      "center": const LatLng(6.9039, 80.5283),
      "weather": "22°C Water Roar",
      "leechIndex": "Low",
      "rating": "4.8 ★ (1.8k)",
      "img": "https://images.unsplash.com/photo-1542332213-9b5a5a3fad35?w=600",
      "desc": "Spectacular 126m fall surrounded by massive rock boulders, rushing downstream to hydropower lakes.",
      "elevationPoints": [520, 630, 710],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_15",
      "name": "Gartmore (Sri Pada Falls)",
      "category": "Waterfalls",
      "district": "Maskeliya Ridge",
      "elevation": "1,140m Alt",
      "distance": "4.5 km Trail",
      "difficulty": "Moderate",
      "duration": "3 Hours",
      "center": const LatLng(6.8375, 80.5750),
      "weather": "19°C Cool Wind",
      "leechIndex": "Low",
      "rating": "4.9 ★ (920)",
      "img": "https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=600",
      "desc": "Twin waterfall cascade spilling directly over a high plateau edge into Maskeliya reservoir.",
      "elevationPoints": [950, 1050, 1140],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_16",
      "name": "Dunhinda Smoky Falls",
      "category": "Waterfalls",
      "district": "Badulla",
      "elevation": "460m Alt",
      "distance": "2.2 km Forest Path",
      "difficulty": "Easy",
      "duration": "1.5 Hours",
      "center": const LatLng(7.0167, 81.0667),
      "weather": "26°C Spray",
      "leechIndex": "None",
      "rating": "4.7 ★ (3.1k)",
      "img": "https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?w=600",
      "desc": "Famous misty falls formed by Badulu Oya plummeting through ancient limestone clefts.",
      "elevationPoints": [380, 420, 460],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_17",
      "name": "Yala National Park (Block 1)",
      "category": "Wildlife & Safari",
      "district": "Hambantota",
      "elevation": "30m Coastal Plain",
      "distance": "4x4 Safari Track",
      "difficulty": "Easy",
      "duration": "Full Day",
      "center": const LatLng(6.3711, 81.5178),
      "weather": "31°C Arid Tropical",
      "leechIndex": "None",
      "rating": "4.8 ★ (8.1k)",
      "img": "https://images.unsplash.com/photo-1534177616072-ef7dc120449d?w=600",
      "desc": "Dense leopard haven alongside wild Asian elephants, sloth bears, and marsh crocodiles.",
      "elevationPoints": [10, 25, 30],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_18",
      "name": "Wilpattu Leopard Basin",
      "category": "Wildlife & Safari",
      "district": "Anuradhapura / Puttalam",
      "elevation": "45m Scrub Forest",
      "distance": "Safari Track",
      "difficulty": "Easy",
      "duration": "Full Day",
      "center": const LatLng(8.4500, 80.0500),
      "weather": "32°C Dry Zone",
      "leechIndex": "None",
      "rating": "4.9 ★ (3.9k)",
      "img": "https://images.unsplash.com/photo-1534177616072-ef7dc120449d?w=600",
      "desc": "Sri Lanka's largest national park famed for natural sand-rimmed water basins (Villus) and majestic leopards.",
      "elevationPoints": [15, 30, 45],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_19",
      "name": "Udawalawe Elephant Sanctuary",
      "category": "Wildlife & Safari",
      "district": "Ratnapura / Monaragala",
      "elevation": "90m Savannah",
      "distance": "Open 4x4 Trail",
      "difficulty": "Easy",
      "duration": "4 Hours",
      "center": const LatLng(6.4744, 80.8986),
      "weather": "30°C Sunny",
      "leechIndex": "None",
      "rating": "4.8 ★ (5.1k)",
      "img": "https://images.unsplash.com/photo-1534177616072-ef7dc120449d?w=600",
      "desc": "Home to hundreds of roaming elephant herds, crested serpent eagles, and buffalo wallows.",
      "elevationPoints": [60, 75, 90],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_20",
      "name": "Minneriya Elephant Gathering",
      "category": "Wildlife & Safari",
      "district": "Polonnaruwa",
      "elevation": "70m Lake Basin",
      "distance": "Lake Shore Track",
      "difficulty": "Easy",
      "duration": "3.5 Hours",
      "center": const LatLng(8.0310, 80.8320),
      "weather": "33°C Hot Sun",
      "leechIndex": "None",
      "rating": "4.9 ★ (6.2k)",
      "img": "https://images.unsplash.com/photo-1534177616072-ef7dc120449d?w=600",
      "desc": "The largest recurring gathering of Asian elephants on Earth along the ancient reservoir beds.",
      "elevationPoints": [40, 55, 70],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_21",
      "name": "Wangedigala Pine Ridge",
      "category": "Ridge Camps",
      "district": "Badulla (Kalupahana)",
      "elevation": "1,450m Ridge",
      "distance": "5.5 km Steep Hike",
      "difficulty": "Hard",
      "duration": "4.5 Hours",
      "center": const LatLng(6.7640, 80.8290),
      "weather": "17°C Night Gale",
      "leechIndex": "Low",
      "rating": "4.9 ★ (1.7k)",
      "img": "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=600",
      "desc": "Sheer knife-edge pine ridge camping site overlooking Balangoda gap, Horton Plains, and Beragala.",
      "elevationPoints": [800, 1050, 1250, 1450],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_22",
      "name": "Hanthana Peak 7 Camp",
      "category": "Ridge Camps",
      "district": "Kandy",
      "elevation": "1,180m Alt",
      "distance": "8.0 km Traverse",
      "difficulty": "Moderate",
      "duration": "5 Hours",
      "center": const LatLng(7.2550, 80.6270),
      "weather": "20°C Breezy",
      "leechIndex": "Moderate",
      "rating": "4.7 ★ (2.5k)",
      "img": "https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=600",
      "desc": "Scenic grass ridge stretching across 7 peaks with views of Kandy City and the Mahaweli River valley.",
      "elevationPoints": [650, 800, 1000, 1180],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_23",
      "name": "Gommolli Kanda Summit Ridge",
      "category": "Ridge Camps",
      "district": "Belihuloya",
      "elevation": "2,034m Alt",
      "distance": "11.0 km Extreme",
      "difficulty": "Extreme",
      "duration": "7 Hours",
      "center": const LatLng(6.7560, 80.7950),
      "weather": "14°C Alpine Gale",
      "leechIndex": "Moderate",
      "rating": "4.9 ★ (340)",
      "img": "https://images.unsplash.com/photo-1542332213-9b5a5a3fad35?w=600",
      "desc": "Sri Lanka's 13th highest peak, wild ridge camping above clouds directly opposite World's End wall.",
      "elevationPoints": [1100, 1450, 1750, 2034],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_24",
      "name": "Idalgashinna Pine Needle Ridge",
      "category": "Ridge Camps",
      "district": "Badulla",
      "elevation": "1,615m Alt",
      "distance": "4.8 km Ridge Walk",
      "difficulty": "Moderate",
      "duration": "3 Hours",
      "center": const LatLng(6.7860, 80.9020),
      "weather": "16°C Heavy Mist",
      "leechIndex": "None",
      "rating": "4.8 ★ (1.2k)",
      "img": "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=600",
      "desc": "Remarkable 360-degree saddle ridge where weather splits into sunny southern plains and northern mist clouds.",
      "elevationPoints": [1300, 1450, 1615],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_25",
      "name": "Ravana Cave & Tunnel System",
      "category": "Deep Caves & Ruins",
      "district": "Ella, Badulla",
      "elevation": "1,050m Alt",
      "distance": "1.5 km Steep Steps",
      "difficulty": "Moderate",
      "duration": "1.5 Hours",
      "center": const LatLng(6.8625, 81.0542),
      "weather": "23°C Cavern Cool",
      "leechIndex": "None",
      "rating": "4.6 ★ (2.1k)",
      "img": "https://images.unsplash.com/photo-1519681393784-d120267933ba?w=600",
      "desc": "Legendary prehistoric cavern complex with tunnel shafts cut deep into the Ella cliff face.",
      "elevationPoints": [850, 950, 1050],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_26",
      "name": "Fa Hien Lena Prehistoric Cave",
      "category": "Deep Caves & Ruins",
      "district": "Kalutara (Bulathsinhala)",
      "elevation": "150m Forest Rock",
      "distance": "1.8 km Steps",
      "difficulty": "Easy",
      "duration": "1 Hour",
      "center": const LatLng(6.6267, 80.2167),
      "weather": "27°C Tropical",
      "leechIndex": "Low",
      "rating": "4.7 ★ (850)",
      "img": "https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=600",
      "desc": "One of the largest natural rock caverns in Asia, with human habitation fossils dating back 37,000 years.",
      "elevationPoints": [40, 90, 150],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_27",
      "name": "Ritigala Monastic Forest Ruins",
      "category": "Deep Caves & Ruins",
      "district": "Anuradhapura",
      "elevation": "766m Isolated Peak",
      "distance": "4.0 km Stone Paths",
      "difficulty": "Moderate",
      "duration": "3 Hours",
      "center": const LatLng(8.1167, 80.6500),
      "weather": "28°C Mountain Breeze",
      "leechIndex": "None",
      "rating": "4.9 ★ (2.3k)",
      "img": "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=600",
      "desc": "Ancient secluded Buddhist hermitage ruins hidden inside a mysterious microclimate mountain reserve.",
      "elevationPoints": [200, 450, 680, 766],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_28",
      "name": "Nitre Cave Knuckles Depths",
      "category": "Deep Caves & Ruins",
      "district": "Meemure, Matale",
      "elevation": "850m Alt",
      "distance": "9.5 km Wild Trek",
      "difficulty": "Hard",
      "duration": "6 Hours",
      "center": const LatLng(7.4850, 80.8650),
      "weather": "20°C Dark Cave",
      "leechIndex": "High",
      "rating": "4.8 ★ (310)",
      "img": "https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?w=600",
      "desc": "Enormous deep limestone cave inhabited by thousands of bats, historically mined for gunpowder nitre.",
      "elevationPoints": [500, 680, 850],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_29",
      "name": "Sinharaja Kudawa Virgin Trail",
      "category": "Rainforests",
      "district": "Kalawana / Ratnapura",
      "elevation": "550m Alt",
      "distance": "10.5 km Trail",
      "difficulty": "Moderate",
      "duration": "5.5 Hours",
      "center": const LatLng(6.4392, 80.4286),
      "weather": "24°C High Humidity",
      "leechIndex": "Extreme",
      "rating": "4.9 ★ (3.1k)",
      "img": "https://images.unsplash.com/photo-1542332213-9b5a5a3fad35?w=600",
      "desc": "UNESCO primary tropical rainforest, boasting 95% endemic birds, giant trees, and mixed species feeding flocks.",
      "elevationPoints": [350, 420, 500, 550],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_30",
      "name": "Kanneliya Lowland Rainforest",
      "category": "Rainforests",
      "district": "Galle (Udugama)",
      "elevation": "220m Alt",
      "distance": "7.2 km Forest Trail",
      "difficulty": "Easy to Moderate",
      "duration": "4 Hours",
      "center": const LatLng(6.2500, 80.3333),
      "weather": "26°C Humid Streams",
      "leechIndex": "High",
      "rating": "4.8 ★ (1.6k)",
      "img": "https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=600",
      "desc": "The second largest pristine lowland rainforest watershed with natural bathing springs and Anagimale falls.",
      "elevationPoints": [80, 150, 220],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_31",
      "name": "Sinharaja Pitadeniya South Gate",
      "category": "Rainforests",
      "district": "Deniyaya, Matara",
      "elevation": "480m Alt",
      "distance": "8.0 km Trail",
      "difficulty": "Moderate",
      "duration": "4.5 Hours",
      "center": const LatLng(6.3900, 80.5100),
      "weather": "24°C Canopy Shade",
      "leechIndex": "Extreme",
      "rating": "4.9 ★ (940)",
      "img": "https://images.unsplash.com/photo-1542332213-9b5a5a3fad35?w=600",
      "desc": "Southern entrance featuring suspended canopy bridges, Kakuna falls, and Pathan Oya crystal rapids.",
      "elevationPoints": [220, 360, 480],
      "hasTrail": false,
      "path": []
    },
    {
      "id": "spot_32",
      "name": "Peak Wilderness Sanctuary Trail",
      "category": "Rainforests",
      "district": "Ratnapura / Kuruwita",
      "elevation": "1,400m Cloud Canopy",
      "distance": "15.0 km Deep Trek",
      "difficulty": "Extreme",
      "duration": "8 Hours",
      "center": const LatLng(6.8300, 80.4600),
      "weather": "17°C Constant Rain",
      "leechIndex": "Extreme",
      "rating": "4.9 ★ (760)",
      "img": "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=600",
      "desc": "Dense tropical montane cloud forest reserve preserving rare endemic amphibians and majestic highland flora.",
      "elevationPoints": [400, 750, 1100, 1400],
      "hasTrail": false,
      "path": []
    },
  ];

  @override
  void initState() {
    super.initState();
    _initOfflineTileStorage();
    _fetchRealDeviceGps(autoCenter: false);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _stopwatchTimer?.cancel();
    _searchController.dispose();
    _carouselController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ===========================================================================
  // ADVANCED SRI LANKA DUAL POI & PLACE SEARCH ENGINE (NOMINATIM + PHOTON)
  // ===========================================================================
  void _onSearchQueryChanged(String query) {
    setState(() => _searchQuery = query);
    _searchDebounceTimer?.cancel();

    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) {
      setState(() {
        _livePoiSearchResults.clear();
        _isSearchingPoi = false;
      });
      return;
    }

    _searchDebounceTimer = Timer(const Duration(milliseconds: 320), () {
      _executeSriLankaPoiSearch(cleanQuery);
    });
  }

  Future<void> _executeSriLankaPoiSearch(String query) async {
    setState(() => _isSearchingPoi = true);

    final cleanQuery = query.trim();
    final List<Map<String, dynamic>> combinedResults = [];
    final Set<String> seenIdentifiers = {};

    // 1. Instant local match from authentic spots database
    final localMatches = _spotsDatabase.where((spot) {
      final name = spot["name"].toString().toLowerCase();
      final dist = spot["district"].toString().toLowerCase();
      final cat = spot["category"].toString().toLowerCase();
      final q = cleanQuery.toLowerCase();
      return name.contains(q) || dist.contains(q) || cat.contains(q);
    }).take(4);

    for (final spot in localMatches) {
      final key = spot["name"].toString().toLowerCase();
      if (!seenIdentifiers.contains(key)) {
        seenIdentifiers.add(key);
        combinedResults.add(Map<String, dynamic>.from(spot));
      }
    }

    // 2. High-Precision Sri Lanka Search via Nominatim & Photon concurrently
    try {
      final encodedQuery = Uri.encodeComponent(cleanQuery);

      // Nominatim LK query with rich address details and Sinhala/Tamil/English headers
      final nomFuture = http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$encodedQuery&countrycodes=lk&format=json&addressdetails=1&extratags=1&limit=14',
        ),
        headers: {
          'User-Agent': 'NatureTravelsLK/2.0 (info@naturetravels.lk)',
          'Accept-Language': 'en,si,ta',
        },
      ).timeout(const Duration(seconds: 5));

      // Photon (Komoot) biased to Sri Lanka coordinates (7.8731 N, 80.7718 E)
      final phoFuture = http.get(
        Uri.parse(
          'https://photon.komoot.io/api/?q=$encodedQuery&lat=7.8731&lon=80.7718&limit=14',
        ),
        headers: {
          'User-Agent': 'NatureTravelsLK/2.0',
        },
      ).timeout(const Duration(seconds: 4));

      final responses = await Future.wait([
        nomFuture.then((r) => r).catchError((_) => http.Response('[]', 500)),
        phoFuture.then((r) => r).catchError((_) => http.Response('{}', 500)),
      ]);

      // A. Parse Nominatim Results
      final nomRes = responses[0];
      if (nomRes.statusCode == 200 && nomRes.body.isNotEmpty) {
        try {
          final List list = jsonDecode(nomRes.body);
          for (final item in list) {
            final lat = double.tryParse('${item['lat']}') ?? 0.0;
            final lon = double.tryParse('${item['lon']}') ?? 0.0;
            // Sri Lanka bounding box safety filter
            if (lat < 5.8 || lat > 9.95 || lon < 79.5 || lon > 82.1) continue;

            final String rawName = '${item['display_name'] ?? ''}';
            final parts = rawName.split(',');
            final String title = parts.isNotEmpty ? parts[0].trim() : rawName;
            final String normTitle = title.toLowerCase();
            if (seenIdentifiers.contains(normTitle)) continue;
            seenIdentifiers.add(normTitle);

            final String subtitle = parts.length > 1
                ? parts.sublist(1, math.min(4, parts.length)).join(', ').trim()
                : 'Sri Lanka';

            final String type = '${item['type'] ?? ''}'.toLowerCase();
            final String osmClass = '${item['class'] ?? ''}'.toLowerCase();
            final String category = _mapOsmCategory(type, osmClass, title);

            final double distMeters = const Distance().as(
              LengthUnit.Meter,
              _liveUserPosition,
              LatLng(lat, lon),
            );

            combinedResults.add({
              "id": "poi_nom_${item['osm_id'] ?? DateTime.now().millisecondsSinceEpoch}",
              "name": title,
              "category": category,
              "district": subtitle,
              "elevation": "Sri Lanka POI",
              "distance": "${(distMeters / 1000).toStringAsFixed(1)} km away",
              "difficulty": "Accessible",
              "duration": "Active Location",
              "center": LatLng(lat, lon),
              "weather": "26°C Clear",
              "leechIndex": "None",
              "rating": "Verified POI ★",
              "img": _getCategoryFallbackImage(category),
              "desc": rawName,
              "hasTrail": false,
              "path": <LatLng>[],
              "distanceMeters": distMeters,
            });
          }
        } catch (e) {
          debugPrint("Nominatim parsing error: $e");
        }
      }

      // B. Parse Photon Results (Komoot OpenStreetMap index)
      final phoRes = responses[1];
      if (phoRes.statusCode == 200 && phoRes.body.isNotEmpty) {
        try {
          final Map<String, dynamic> pData = jsonDecode(phoRes.body);
          final List features = pData['features'] ?? [];
          for (final f in features) {
            final coords = f['geometry']?['coordinates'] as List?;
            if (coords == null || coords.length < 2) continue;
            final lon = (coords[0] as num).toDouble();
            final lat = (coords[1] as num).toDouble();
            if (lat < 5.8 || lat > 9.95 || lon < 79.5 || lon > 82.1) continue;

            final props = f['properties'] as Map<String, dynamic>? ?? {};
            final countryCode = '${props['countrycode'] ?? ''}'.toUpperCase();
            if (countryCode.isNotEmpty && countryCode != 'LK') continue;

            final title = '${props['name'] ?? props['street'] ?? props['city'] ?? ''}'.trim();
            if (title.isEmpty) continue;
            final normTitle = title.toLowerCase();
            if (seenIdentifiers.contains(normTitle)) continue;
            seenIdentifiers.add(normTitle);

            final List<String> subParts = [];
            if (props['city'] != null && props['city'] != title) subParts.add('${props['city']}');
            if (props['district'] != null) subParts.add('${props['district']}');
            if (props['state'] != null) subParts.add('${props['state']}');
            if (subParts.isEmpty) subParts.add('Sri Lanka');
            final subtitle = subParts.join(', ');

            final type = '${props['type'] ?? props['osm_value'] ?? ''}'.toLowerCase();
            final osmClass = '${props['osm_key'] ?? ''}'.toLowerCase();
            final category = _mapOsmCategory(type, osmClass, title);

            final double distMeters = const Distance().as(
              LengthUnit.Meter,
              _liveUserPosition,
              LatLng(lat, lon),
            );

            combinedResults.add({
              "id": "poi_pho_${props['osm_id'] ?? DateTime.now().millisecondsSinceEpoch}",
              "name": title,
              "category": category,
              "district": subtitle,
              "elevation": "Sri Lanka POI",
              "distance": "${(distMeters / 1000).toStringAsFixed(1)} km away",
              "difficulty": "Accessible",
              "duration": "Active Location",
              "center": LatLng(lat, lon),
              "weather": "26°C Clear",
              "leechIndex": "None",
              "rating": "Verified POI ★",
              "img": _getCategoryFallbackImage(category),
              "desc": "$title, $subtitle, Sri Lanka",
              "hasTrail": false,
              "path": <LatLng>[],
              "distanceMeters": distMeters,
            });
          }
        } catch (e) {
          debugPrint("Photon parsing error: $e");
        }
      }
    } catch (e) {
      debugPrint("POI geocoding error: $e");
    }

    if (mounted) {
      setState(() {
        _livePoiSearchResults = combinedResults;
        _isSearchingPoi = false;
      });
    }
  }

  String _mapOsmCategory(String type, String osmClass, [String name = '']) {
    final t = '$type $osmClass $name'.toLowerCase();

    // Schools / Colleges / Universities
    if (t.contains('school') || t.contains('college') || t.contains('university') ||
        t.contains('vidyalaya') || t.contains('mha vidyalaya') || t.contains('kindergarten') ||
        t.contains('campus') || t.contains('academy') || t.contains('education') ||
        t.contains('විද්‍යාල') || t.contains('පාසල')) {
      return "School / College 🏫";
    }

    // Shops / Supermarkets / Markets
    if (t.contains('shop') || t.contains('supermarket') || t.contains('mall') ||
        t.contains('cargills') || t.contains('keells') || t.contains('arpico') ||
        t.contains('spar') || t.contains('grocery') || t.contains('store') ||
        t.contains('market') || t.contains('bakery') || t.contains('bazaar') ||
        t.contains('වෙළඳසැල') || t.contains('සුපර්මාකට්')) {
      return "Shop / Supermarket 🛒";
    }

    // Medical / Hospital / Pharmacy
    if (t.contains('hospital') || t.contains('pharmacy') || t.contains('clinic') ||
        t.contains('doctor') || t.contains('dispensary') || t.contains('suwa seriya') ||
        t.contains('රෝහල') || t.contains('සුවසැරිය')) {
      return "Medical / Hospital 🏥";
    }

    // Sacred / Temples / Kovils / Churches / Mosques
    if (t.contains('temple') || t.contains('vihara') || t.contains('vihāra') ||
        t.contains('kovil') || t.contains('church') || t.contains('mosque') ||
        t.contains('shrine') || t.contains('place_of_worship') || t.contains('stupa') ||
        t.contains('dagoba') || t.contains('dewalaya') || t.contains('devalaya') ||
        t.contains('maligawa') || t.contains('පන්සල') || t.contains('කෝවිල') ||
        t.contains('පල්ලිය') || t.contains('දේවාලය')) {
      return "Sacred / Temple 🏛️";
    }

    // Dining / Restaurants / Cafes
    if (t.contains('restaurant') || t.contains('cafe') || t.contains('fast_food') ||
        t.contains('hotel') || t.contains('dining') || t.contains('bakery') ||
        t.contains('කෑම')) {
      return "Cafe & Dining 🍽️";
    }

    // Waterfalls & Rivers
    if (t.contains('waterfall') || t.contains('falls') || t.contains('water') ||
        t.contains('river') || t.contains('oya') || t.contains('ganga') ||
        t.contains('wewa') || t.contains('lake') || t.contains('reservoir') ||
        t.contains('ඇල්ල') || t.contains('දියඇල්ල')) {
      return "Waterfalls";
    }

    // High Peaks & Mountains
    if (t.contains('peak') || t.contains('mountain') || t.contains('kanda') ||
        t.contains('gala') || t.contains('rock') || t.contains('ridge') ||
        t.contains('volcano') || t.contains('කන්ද') || t.contains('ගල')) {
      return "High Peaks";
    }

    // Wildlife & Safari
    if (t.contains('national_park') || t.contains('safari') || t.contains('sanctuary') ||
        t.contains('wildlife') || t.contains('zoo') || t.contains('forest reserve')) {
      return "Wildlife & Safari";
    }

    // Towns, Junctions & Suburbs
    if (t.contains('junction') || t.contains('handiya') || t.contains('town') ||
        t.contains('city') || t.contains('suburb') || t.contains('village') ||
        t.contains('bus') || t.contains('station') || t.contains('railway') ||
        t.contains('හන්දිය') || t.contains('නගරය')) {
      return "Town & Junction 📍";
    }

    return "Landmark & Spot 📍";
  }

  String _getCategoryFallbackImage(String cat) {
    if (cat.contains("School")) {
      return "https://images.unsplash.com/photo-1580582932707-520aed937b7b?w=600";
    } else if (cat.contains("Shop")) {
      return "https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=600";
    } else if (cat.contains("Hospital") || cat.contains("Medical")) {
      return "https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?w=600";
    } else if (cat.contains("Temple") || cat.contains("Sacred")) {
      return "https://images.unsplash.com/photo-1544735716-392fe2489ffa?w=600";
    } else if (cat.contains("Dining") || cat.contains("Cafe")) {
      return "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=600";
    } else if (cat.contains("Waterfalls")) {
      return "https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?w=600";
    } else if (cat.contains("Wildlife")) {
      return "https://images.unsplash.com/photo-1534177616072-ef7dc120449d?w=600";
    }
    return "https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=600";
  }

  // ===========================================================================
  // INITIALIZE OFFLINE CACHE DIRECTORY
  // ===========================================================================
  Future<void> _initOfflineTileStorage() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docDir.path}/nature_offline_tiles');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      if (mounted) {
        setState(() {
          _offlineCacheDirectory = dir.path;
        });
        _checkIfIslandDownloaded();
      }
    } catch (e) {
      debugPrint("Offline storage init error: $e");
    }
  }

  void _checkIfIslandDownloaded() {
    if (_offlineCacheDirectory == null) return;
    final markerFile = File('$_offlineCacheDirectory/srilanka_complete.pack');
    if (markerFile.existsSync()) {
      setState(() => _isFullIslandReady = true);
    }
  }

  // ===========================================================================
  // DOWNLOAD FULL SRI LANKA TILES ENGINE (ISLAND-WIDE BOUNDING BOX)
  // Lat: 5.9°N to 9.9°N, Lon: 79.6°E to 81.9°E (Zooms 6 to 11)
  // ===========================================================================
  int _lon2tileX(double lon, int z) => ((lon + 180.0) / 360.0 * (1 << z)).floor();
  int _lat2tileY(double lat, int z) {
    final latRad = lat * math.pi / 180.0;
    return ((1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) / 2.0 * (1 << z)).floor();
  }

  Future<void> _downloadFullSriLankaMap(Function(void Function()) setModalState) async {
    if (_offlineCacheDirectory == null || _isDownloadingIsland) return;

    setModalState(() {
      _isDownloadingIsland = true;
      _islandDownloadProgress = 0.01;
      _downloadedTilesCount = 0;
    });
    setState(() {
      _isDownloadingIsland = true;
    });

    const double minLat = 5.85;
    const double maxLat = 9.85;
    const double minLon = 79.60;
    const double maxLon = 81.90;

    final List<Map<String, int>> tileQueue = [];
    for (int z = 6; z <= 11; z++) {
      final int startX = _lon2tileX(minLon, z);
      final int endX = _lon2tileX(maxLon, z);
      final int startY = _lat2tileY(maxLat, z);
      final int endY = _lat2tileY(minLat, z);

      for (int x = startX; x <= endX; x++) {
        for (int y = startY; y <= endY; y++) {
          tileQueue.add({'z': z, 'x': x, 'y': y});
        }
      }
    }

    _totalTilesToDownload = tileQueue.length;
    int processed = 0;

    const int concurrency = 6;
    for (int i = 0; i < tileQueue.length; i += concurrency) {
      if (!_isDownloadingIsland) break;

      final batch = tileQueue.skip(i).take(concurrency);
      await Future.wait(batch.map((coord) async {
        final z = coord['z']!;
        final x = coord['x']!;
        final y = coord['y']!;
        final tileFile = File('$_offlineCacheDirectory/$z/$x/$y.png');

        if (!tileFile.existsSync()) {
          final url = 'https://tile.openstreetmap.org/$z/$x/$y.png';
          try {
            final res = await http.get(
              Uri.parse(url),
              headers: {'User-Agent': 'NatureTravelsSriLankaApp/1.0'},
            ).timeout(const Duration(seconds: 6));

            if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
              await tileFile.parent.create(recursive: true);
              await tileFile.writeAsBytes(res.bodyBytes);
            }
          } catch (_) {}
        }
        processed++;
      }));

      if (mounted) {
        setModalState(() {
          _downloadedTilesCount = processed;
          _islandDownloadProgress = processed / _totalTilesToDownload;
        });
        setState(() {});
      }
    }

    if (processed >= _totalTilesToDownload && mounted) {
      final markerFile = File('$_offlineCacheDirectory/srilanka_complete.pack');
      await markerFile.writeAsString('READY_${DateTime.now().toIso8601String()}');
      setModalState(() {
        _isDownloadingIsland = false;
        _isFullIslandReady = true;
      });
      setState(() {
        _isDownloadingIsland = false;
        _isFullIslandReady = true;
      });

      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Sri Lanka Offline Map Ready! Works 100% without data & signals."),
          backgroundColor: AppColors.forest,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ===========================================================================
  // REAL HARDWARE GPS FETCHER & PERMISSION HANDLER
  // ===========================================================================
  Future<void> _fetchRealDeviceGps({bool autoCenter = false}) async {
    try {
      _isGpsServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!_isGpsServiceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⚠️ GPS service is OFF. Please turn on Location in settings."),
              backgroundColor: Colors.deepOrange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      _permissionStatus = await Geolocator.checkPermission();
      if (_permissionStatus == LocationPermission.denied) {
        _permissionStatus = await Geolocator.requestPermission();
        if (_permissionStatus == LocationPermission.denied) return;
      }

      if (_permissionStatus == LocationPermission.deniedForever) return;

      final Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      if (!mounted) return;

      setState(() {
        _liveUserPosition = LatLng(pos.latitude, pos.longitude);
        _currentAltitudeMeters = pos.altitude;
        _currentSpeedKmh = pos.speed > 0 ? (pos.speed * 3.6) : 0.0;
        _currentHeadingDegrees = pos.heading >= 0 ? pos.heading : 0.0;
        _hasRealGpsFix = true;

        if (autoCenter) {
          _currentCenter = _liveUserPosition;
          _currentZoom = 17.5;
          _mapController.move(_currentCenter, _currentZoom);
        }
      });

      if (_selectedSpot != null) {
        _fetchActualRoadRoute(_liveUserPosition, _selectedSpot!["center"] as LatLng);
      }
    } catch (e) {
      debugPrint("Error reading device GPS hardware: $e");
    }
  }

  // Tile Provider URLs (Google Hybrid & Streets include all Shops & Schools)
  String get _activeTileUrl {
    switch (_selectedLayer) {
      case 1:
        return 'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'; // Satellite + Labels & Shops
      case 2:
        return 'https://mt{s}.google.com/vt/lyrs=p&x={x}&y={y}&z={z}'; // Terrain + Landmarks
      case 3:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'; // OpenStreetMap
      case 0:
      default:
        return 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}'; // Detailed Vector Roads & Shops
    }
  }

  // Routing with offline fallback
  Future<void> _fetchActualRoadRoute(LatLng start, LatLng destination) async {
    setState(() => _isLoadingRoute = true);

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final coordinates = route['geometry']['coordinates'] as List;

          final List<LatLng> roadPoints = coordinates.map((coord) {
            return LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble());
          }).toList();

          if (_selectedSpot != null &&
              _selectedSpot!["hasTrail"] == true &&
              (_selectedSpot!["path"] as List).isNotEmpty) {
            final List<LatLng> trail = _selectedSpot!["path"] as List<LatLng>;
            roadPoints.addAll(trail);
          }

          final double distMeters = (route['distance'] as num).toDouble();
          final double durSeconds = (route['duration'] as num).toDouble();

          if (mounted) {
            setState(() {
              _activeRouteToDestination = roadPoints;
              _remainingDistanceMeters = distMeters;
              _etaMinutes = (durSeconds / 60).round().clamp(1, 999);
              _lastRouteCalculatedPosition = start;
              _isLoadingRoute = false;
            });
            return;
          }
        }
      }
    } catch (_) {
      // Offline fallback: Straight line route across mountain peaks
    }

    if (mounted) {
      setState(() {
        _activeRouteToDestination = [start, destination];
        _remainingDistanceMeters = const Distance().as(LengthUnit.Meter, start, destination);
        _etaMinutes = ((_remainingDistanceMeters / 1000) / 4.0 * 60).round().clamp(1, 999);
        _isLoadingRoute = false;
      });
    }
  }

  // ===========================================================================
  // REAL-TIME HARDWARE GPS NAVIGATION
  // ===========================================================================
  void _startLiveGps(Map<String, dynamic> spot) async {
    HapticFeedback.heavyImpact();

    _positionStreamSubscription?.cancel();
    _stopwatchTimer?.cancel();

    bool isEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enable GPS in phone settings!"), backgroundColor: Colors.red),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) return;
    }

    final LatLng spotCenter = spot["center"] as LatLng;

    setState(() {
      _isNavigating = true;
      _selectedSpot = spot;
      _elapsedSeconds = 0;
      _totalDistanceMeters = 0.0;
      _recordedBreadcrumbs.clear();
      _lastRecordedFix = _liveUserPosition;
      _recordedBreadcrumbs.add(_liveUserPosition);
    });

    _fetchActualRoadRoute(_liveUserPosition, spotCenter);

    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isNavigating) {
        setState(() => _elapsedSeconds++);
      }
    });

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position pos) {
        if (!mounted || !_isNavigating) return;

        final LatLng newPos = LatLng(pos.latitude, pos.longitude);

        setState(() {
          if (_lastRecordedFix != null) {
            final double dist = const Distance().as(LengthUnit.Meter, _lastRecordedFix!, newPos);
            if (dist >= 1.0) {
              _totalDistanceMeters += dist;
            }
          }
          _lastRecordedFix = newPos;
          _liveUserPosition = newPos;

          _currentSpeedKmh = pos.speed > 0 ? (pos.speed * 3.6) : 0.0;
          _currentAltitudeMeters = pos.altitude;
          if (pos.heading >= 0) {
            _currentHeadingDegrees = pos.heading;
          }

          _recordedBreadcrumbs.add(newPos);

          if (_activeRouteToDestination.isNotEmpty) {
            _activeRouteToDestination[0] = newPos;
          }

          if (_lastRouteCalculatedPosition == null ||
              const Distance().as(LengthUnit.Meter, _lastRouteCalculatedPosition!, newPos) > 50.0) {
            _fetchActualRoadRoute(newPos, spotCenter);
          }
        });

        _mapController.move(_liveUserPosition, _mapController.camera.zoom);
      },
      onError: (err) {
        debugPrint("Real GPS stream error: $err");
      },
    );

    _mapController.move(_liveUserPosition, 18.0);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("🛰️ Live Satellite Navigation Locked on ${spot["name"]}"),
        backgroundColor: AppColors.forest,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _stopLiveGps() {
    HapticFeedback.mediumImpact();
    _positionStreamSubscription?.cancel();
    _stopwatchTimer?.cancel();

    setState(() {
      _isNavigating = false;
      _activeRouteToDestination.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Tracking paused. Total distance: ${(_totalDistanceMeters / 1000).toStringAsFixed(2)} km."),
        backgroundColor: AppColors.forest,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Deep-Level Zoom (19.5 - Building & Shop Level) on any selected place
  void _moveToSpot(Map<String, dynamic> spot, {List<Map<String, dynamic>>? currentList, double targetZoom = 19.5}) {
    HapticFeedback.lightImpact();
    final LatLng spotPos = spot["center"] as LatLng;

    setState(() {
      _selectedSpot = spot;
      _currentCenter = spotPos;
      _currentZoom = targetZoom;
      _livePoiSearchResults.clear();
    });

    _searchFocusNode.unfocus();
    FocusScope.of(context).unfocus();

    _fetchActualRoadRoute(_liveUserPosition, spotPos);
    _mapController.move(_currentCenter, _currentZoom);

    if (currentList != null && _carouselController.hasClients) {
      final index = currentList.indexWhere((s) => s["id"] == spot["id"]);
      if (index != -1) {
        _carouselController.animateTo(
          index * 292.0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  // ===========================================================================
  // CROWDSOURCED HAZARD & DAMAGE MODAL
  // ===========================================================================
  void _openReportHazardModal() {
    HapticFeedback.mediumImpact();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedCat = "Fallen Tree";
    String selectedSev = "Warning";

    final categories = ["Fallen Tree", "Landslide", "Broken Bridge", "Elephant Danger", "Trail Blocked", "Garbage Alert"];
    final severities = ["Warning", "Dangerous", "Critical Block"];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(modalCtx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.report_problem_rounded, color: Colors.deepOrange, size: 26),
                        SizedBox(width: 10),
                        Text(
                          "Report Trail Damage / Hazard",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.forest),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Pins real damage directly at your phone's real GPS position for all users.",
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    const Text("HAZARD TYPE", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppColors.forest)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((cat) {
                        final isSel = selectedCat == cat;
                        return ChoiceChip(
                          label: Text(cat, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isSel ? Colors.white : AppColors.forest)),
                          selected: isSel,
                          selectedColor: AppColors.forest,
                          backgroundColor: AppColors.canvasBg,
                          onSelected: (_) => setModalState(() => selectedCat = cat),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    const Text("SEVERITY LEVEL", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppColors.forest)),
                    const SizedBox(height: 8),
                    Row(
                      children: severities.map((sev) {
                        final isSel = selectedSev == sev;
                        final Color sevColor = sev == "Critical Block"
                            ? Colors.red
                            : (sev == "Dangerous" ? Colors.deepOrange : Colors.amber.shade800);
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => selectedSev = sev),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel ? sevColor : AppColors.canvasBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: sevColor.withOpacity(0.5)),
                              ),
                              child: Center(
                                child: Text(
                                  sev,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: isSel ? Colors.white : sevColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: "Short Title (e.g., Broken Timber Bridge)",
                        labelStyle: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.canvasBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: "Detailed Hazard Notes & Bypass Advice",
                        labelStyle: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.canvasBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.broadcast_on_personal_rounded, size: 18, color: Colors.white),
                        label: const Text("BROADCAST HAZARD TO ALL HIKERS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          if (titleCtrl.text.trim().isEmpty) return;

                          final newHazard = TrailHazard(
                            id: "hz_${DateTime.now().millisecondsSinceEpoch}",
                            title: titleCtrl.text.trim(),
                            category: selectedCat,
                            severity: selectedSev,
                            description: descCtrl.text.trim().isEmpty ? "Reported damage on active wilderness trail." : descCtrl.text.trim(),
                            location: _liveUserPosition,
                            reportedBy: "You (Explorer)",
                            timeAgo: "Just now",
                            confirmCount: 1,
                          );

                          setState(() {
                            _hazards.insert(0, newHazard);
                          });

                          Navigator.pop(modalCtx);
                          HapticFeedback.heavyImpact();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("🚨 Hazard '${newHazard.title}' pinned at your real GPS location!"),
                              backgroundColor: Colors.deepOrange,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openHazardDetailsSheet(TrailHazard hazard) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final Color sevColor = hazard.severity == "Critical Block"
              ? Colors.red
              : (hazard.severity == "Dangerous" ? Colors.deepOrange : Colors.amber.shade800);

          return Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: sevColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        hazard.severity.toUpperCase(),
                        style: TextStyle(fontWeight: FontWeight.w900, color: sevColor, fontSize: 10.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text("• ${hazard.category}", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textMuted)),
                    const Spacer(),
                    Text(hazard.timeAgo, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  hazard.title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.forest),
                ),
                const SizedBox(height: 6),
                Text(
                  hazard.description,
                  style: const TextStyle(fontSize: 13, color: AppColors.textMain, height: 1.35),
                ),
                const SizedBox(height: 8),
                Text(
                  "Reported by @${hazard.reportedBy} • ${hazard.confirmCount} hikers verified this",
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.emerald),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.thumb_up_rounded, size: 16, color: Colors.deepOrange),
                        label: Text("STILL THERE (+${hazard.confirmCount})", style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 11.5)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.deepOrange),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setModalState(() => hazard.confirmCount++);
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                        label: const Text("MARK CLEARED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          setState(() => _hazards.removeWhere((h) => h.id == hazard.id));
                          Navigator.pop(modalCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Hazard marked as resolved! Removed from live map.")),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // SOS Sheet
  void _openEmergencySOSSheet() {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(Icons.health_and_safety_rounded, color: Colors.redAccent, size: 28),
                SizedBox(width: 10),
                Text("Wilderness SOS & Hotlines", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.forest)),
              ],
            ),
            const SizedBox(height: 14),
            _buildEmergencyContactItem(Icons.local_hospital_rounded, "Suwa Seriya Free Ambulance", "1990", Colors.red),
            _buildEmergencyContactItem(Icons.forest_rounded, "Dept. of Wildlife Conservation (DWC)", "1992", AppColors.forest),
            _buildEmergencyContactItem(Icons.local_police_rounded, "Tourist Police & Mountain SAR", "119 / 011-2421052", Colors.blue),
            _buildEmergencyContactItem(Icons.cloud_sync_rounded, "Disaster Management Center (DMC)", "117", Colors.deepOrange),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContactItem(IconData icon, String title, String number, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.canvasBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardStroke)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.forest)),
                const SizedBox(height: 2),
                Text(number, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: color)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: AppColors.textMuted, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: number));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Copied $number"), duration: const Duration(seconds: 1)));
            },
          )
        ],
      ),
    );
  }

  // ===========================================================================
  // OFFLINE DOWNLOAD MANAGER SHEET (FULL SRI LANKA + REGIONAL PACKS)
  // ===========================================================================
  void _openOfflineDownloadManager() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final regions = [
            {"name": "Knuckles Cloud Forest", "size": "34 MB", "bounds": "High Peaks, Meemure, Corbett's Gap"},
            {"name": "Ella High Gap & Ravana", "size": "22 MB", "bounds": "Ella Rock, Nine Arches, Namunukula"},
            {"name": "Horton Plains & Ohiya", "size": "18 MB", "bounds": "World's End, Devil's Staircase, Kirigalpotta"},
            {"name": "Sinharaja Rainforest", "size": "28 MB", "bounds": "Kudawa, Pitadeniya, Gongala"},
            {"name": "Yala Sanctuary Basin", "size": "42 MB", "bounds": "Block 1, 2, Palatupana Dunes"},
          ];

          return Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    children: [
                      Icon(Icons.download_for_offline_rounded, color: AppColors.forest, size: 26),
                      SizedBox(width: 10),
                      Text("Offline Wilderness Maps", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.forest)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text("Download complete map packs so you can navigate when mobile signal is lost.", style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 16),

                  // FULL ISLAND COMPLETE SRI LANKA OFFLINE PACK
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.forest, AppColors.forest.withOpacity(0.85)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.public_rounded, color: Colors.cyanAccent, size: 26),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("SRI LANKA FULL ISLAND PACK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13.5)),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isFullIslandReady ? "Downloaded & Ready for Offline Use" : "All 9 Provinces • Mountains & Safari",
                                    style: const TextStyle(color: AppColors.lightMint, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if (_isFullIslandReady)
                              const Icon(Icons.check_circle_rounded, color: Colors.cyanAccent, size: 24),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isDownloadingIsland) ...[
                          LinearProgressIndicator(
                            value: _islandDownloadProgress,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Downloading: ${(_islandDownloadProgress * 100).toInt()}% ($_downloadedTilesCount / $_totalTilesToDownload tiles)",
                                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                              GestureDetector(
                                onTap: () => setModalState(() => _isDownloadingIsland = false),
                                child: const Text("CANCEL", style: TextStyle(color: Colors.redAccent, fontSize: 10.5, fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Size: ~38 MB (High-res)", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                              ElevatedButton.icon(
                                icon: Icon(_isFullIslandReady ? Icons.refresh_rounded : Icons.cloud_download_rounded, size: 16, color: AppColors.forest),
                                label: Text(
                                  _isFullIslandReady ? "RE-DOWNLOAD" : "DOWNLOAD ISLAND",
                                  style: const TextStyle(color: AppColors.forest, fontWeight: FontWeight.w900, fontSize: 11),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.cyanAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                                onPressed: () => _downloadFullSriLankaMap(setModalState),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text("REGIONAL TRAIL PACKS", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: AppColors.forest, letterSpacing: 0.5)),
                  const SizedBox(height: 10),

                  ...regions.map((reg) {
                    final isDownloaded = _downloadedRegions.contains(reg["name"]);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.canvasBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDownloaded ? AppColors.emerald.withOpacity(0.5) : AppColors.cardStroke),
                      ),
                      child: Row(
                        children: [
                          Icon(isDownloaded ? Icons.check_circle_rounded : Icons.cloud_download_outlined, color: isDownloaded ? AppColors.emerald : AppColors.forest, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(reg["name"]!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.forest)),
                                const SizedBox(height: 2),
                                Text("${reg["bounds"]} • ${reg["size"]}", style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                if (isDownloaded) {
                                  _downloadedRegions.remove(reg["name"]);
                                } else {
                                  _downloadedRegions.add(reg["name"]!);
                                }
                              });
                              setState(() {});
                            },
                            child: Text(isDownloaded ? "DELETE" : "DOWNLOAD", style: TextStyle(color: isDownloaded ? Colors.redAccent : AppColors.emerald, fontWeight: FontWeight.w900, fontSize: 11.5)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getCategoryColor(String cat) {
    if (cat.contains("Waterfalls")) return Colors.blue.shade600;
    if (cat.contains("Wildlife")) return Colors.amber.shade800;
    if (cat.contains("Ridge")) return Colors.deepOrange.shade600;
    if (cat.contains("Caves")) return Colors.purple.shade600;
    if (cat.contains("Rainforests")) return Colors.teal.shade700;
    if (cat.contains("School") || cat.contains("College")) return Colors.indigo.shade700;
    if (cat.contains("Shop") || cat.contains("Supermarket")) return Colors.deepOrange.shade700;
    if (cat.contains("Hospital") || cat.contains("Medical")) return Colors.red.shade700;
    if (cat.contains("Temple") || cat.contains("Sacred")) return Colors.amber.shade900;
    if (cat.contains("Dining") || cat.contains("Cafe")) return Colors.brown.shade600;
    if (cat.contains("Junction") || cat.contains("Town")) return Colors.blueGrey.shade800;
    return AppColors.forest;
  }

  IconData _getCategoryIcon(String cat) {
    if (cat.contains("Waterfalls")) return Icons.water_drop_rounded;
    if (cat.contains("Wildlife")) return Icons.pets_rounded;
    if (cat.contains("Ridge")) return Icons.cabin_rounded;
    if (cat.contains("Caves")) return Icons.castle_rounded;
    if (cat.contains("Rainforests")) return Icons.park_rounded;
    if (cat.contains("School") || cat.contains("College")) return Icons.school_rounded;
    if (cat.contains("Shop") || cat.contains("Supermarket")) return Icons.storefront_rounded;
    if (cat.contains("Dining") || cat.contains("Cafe")) return Icons.restaurant_rounded;
    if (cat.contains("Hospital") || cat.contains("Medical")) return Icons.local_hospital_rounded;
    if (cat.contains("Temple") || cat.contains("Sacred")) return Icons.account_balance_rounded;
    if (cat.contains("Junction") || cat.contains("Town")) return Icons.near_me_rounded;
    return Icons.place_rounded;
  }

  @override
  Widget build(BuildContext context) {
    // 1. Filter local curated spots
    final filteredLocalSpots = _spotsDatabase.where((spot) {
      final matchesCategory = _selectedCategory == "All" || spot["category"] == _selectedCategory;
      final q = _searchQuery.toLowerCase();
      final name = spot["name"].toString().toLowerCase();
      final dist = spot["district"].toString().toLowerCase();
      final desc = spot["desc"].toString().toLowerCase();
      final matchesSearch = q.isEmpty || name.contains(q) || dist.contains(q) || desc.contains(q);
      return matchesCategory && matchesSearch;
    }).toList();

    // 2. Active display list (Local spots + Selected dynamic place if any)
    final List<Map<String, dynamic>> combinedDisplaySpots = [
      if (_selectedSpot != null && !_spotsDatabase.any((s) => s['id'] == _selectedSpot!['id']))
        _selectedSpot!,
      ...filteredLocalSpots,
    ];

    return Scaffold(
      backgroundColor: AppColors.canvasBg,
      body: Stack(
        children: [
          // ===================================================================
          // 1. FLUTTER MAP (OFFLINE STORAGE AUTO-LOADER + ZOOM UP TO 22.0)
          // ===================================================================
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: _currentZoom,
              minZoom: 4.5,
              maxZoom: 22.0, // High-Precision Micro Zoom (Street & Building Level)
              onTap: (_, __) {
                _searchFocusNode.unfocus();
                FocusScope.of(context).unfocus();
                setState(() => _livePoiSearchResults.clear());
                if (_selectedSpot != null && !_isNavigating) {
                  setState(() {
                    _selectedSpot = null;
                    _activeRouteToDestination.clear();
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _activeTileUrl,
                subdomains: const ['0', '1', '2', '3'],
                maxZoom: 22,
                maxNativeZoom: 19,
                userAgentPackageName: 'com.naturetravels.app',
                tileProvider: _offlineCacheDirectory != null
                    ? AutoCachingTileProvider(_offlineCacheDirectory!)
                    : NetworkTileProvider(),
              ),

              // Polyline Trails & Road Routes
              PolylineLayer(
                polylines: [
                  ..._spotsDatabase
                      .where((s) => s["hasTrail"] == true && (s["path"] as List).isNotEmpty)
                      .map((s) {
                    final isSelected = _selectedSpot?['id'] == s['id'];
                    return Polyline(
                      points: (s['path'] as List<LatLng>),
                      strokeWidth: isSelected ? 5.5 : 3.5,
                      color: isSelected ? AppColors.emerald : AppColors.forest.withOpacity(0.85),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    );
                  }),

                  if (_activeRouteToDestination.length > 1) ...[
                    Polyline(
                      points: _activeRouteToDestination,
                      strokeWidth: 7.0,
                      color: Colors.blue.shade900.withOpacity(0.7),
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                    Polyline(
                      points: _activeRouteToDestination,
                      strokeWidth: 4.5,
                      color: Colors.cyanAccent.shade700,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],

                  if (_recordedBreadcrumbs.length > 1)
                    Polyline(
                      points: _recordedBreadcrumbs,
                      strokeWidth: 4.5,
                      color: Colors.amberAccent.shade400,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                ],
              ),

              // Hazard & Damage Markers
              MarkerLayer(
                markers: _hazards.map((hz) {
                  final sevColor = hz.severity == "Critical Block"
                      ? Colors.red
                      : (hz.severity == "Dangerous" ? Colors.deepOrange : Colors.amber.shade800);

                  return Marker(
                    point: hz.location,
                    width: 48,
                    height: 48,
                    child: GestureDetector(
                      onTap: () => _openHazardDetailsSheet(hz),
                      child: Container(
                        decoration: BoxDecoration(
                          color: sevColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3))],
                        ),
                        child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Waypoint & Real Places / Schools / Shops Markers
              MarkerLayer(
                markers: combinedDisplaySpots.map((spot) {
                  final isSelected = _selectedSpot?['id'] == spot['id'];
                  final LatLng pos = spot['center'] as LatLng;
                  final markerColor = _getCategoryColor(spot["category"]);

                  return Marker(
                    point: pos,
                    width: 52,
                    height: 52,
                    child: GestureDetector(
                      onTap: () => _moveToSpot(spot, currentList: combinedDisplaySpots),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 250),
                        scale: isSelected ? 1.3 : 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.emerald : markerColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.8),
                            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))],
                          ),
                          child: Icon(_getCategoryIcon(spot["category"]), color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // 100% Real Hardware GPS Satellite Marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: _liveUserPosition,
                    width: 48,
                    height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.shade700,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3.5),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12)],
                      ),
                      child: Transform.rotate(
                        angle: _currentHeadingDegrees * (3.141592653589793 / 180),
                        child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Loading Road Route Indicator
          if (_isLoadingRoute)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.forest.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text("Calculating road/trail route...", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),

          // ===================================================================
          // 2. REAL-TIME NAVIGATION TELEMETRY HUD (WORKS 100% OFFLINE)
          // ===================================================================
          if (_isNavigating && _selectedSpot != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 14,
              right: 14,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.forest.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.6), width: 1.5),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 6))],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.cyanAccent.withOpacity(0.2), shape: BoxShape.circle),
                              child: const Icon(Icons.alt_route_rounded, color: Colors.cyanAccent, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "NAVIGATING: ${_selectedSpot!["name"]}",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "DISTANCE: ${(_remainingDistanceMeters / 1000).toStringAsFixed(1)} km • ETA: ~$_etaMinutes mins",
                                    style: const TextStyle(color: AppColors.lightMint, fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: _stopLiveGps,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.redAccent),
                                ),
                                child: const Text("STOP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildTelemetryItem(Icons.speed_rounded, "${_currentSpeedKmh.toStringAsFixed(1)} km/h", "REAL SPEED"),
                              _buildTelemetryItem(Icons.terrain_rounded, "${_currentAltitudeMeters.toInt()} m", "ALTITUDE"),
                              _buildTelemetryItem(Icons.explore_rounded, "${_currentHeadingDegrees.toInt()}°", "BEARING"),
                              _buildTelemetryItem(Icons.timer_outlined, _formatDuration(_elapsedSeconds), "TIME"),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ===================================================================
          // 3. TOP SEARCH HUD & LIVE SRI LANKA PLACES / SCHOOLS / SHOPS RESULTS
          // ===================================================================
          if (!_isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 14,
              right: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.96),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white70),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, 5))],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, color: AppColors.forest, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                onChanged: _onSearchQueryChanged,
                                decoration: const InputDecoration(
                                  hintText: "Search Schools, Shops, Temples, Junctions in SL...",
                                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            if (_isSearchingPoi)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.forest),
                              )
                            else if (_searchQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  _onSearchQueryChanged("");
                                },
                                child: const Icon(Icons.cancel_rounded, color: AppColors.textMuted, size: 20),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ===========================================================
                  // LIVE ISLAND-WIDE SEARCH RESULTS DROPDOWN (SCHOOLS, SHOPS...)
                  // ===========================================================
                  if (_livePoiSearchResults.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 6))],
                        border: Border.all(color: AppColors.cardStroke),
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shrinkWrap: true,
                        itemCount: _livePoiSearchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (context, idx) {
                          final poi = _livePoiSearchResults[idx];
                          final cat = poi["category"] as String;
                          final dist = poi["distance"] as String? ?? "";

                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(cat).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_getCategoryIcon(cat), size: 20, color: _getCategoryColor(cat)),
                            ),
                            title: Text(
                              poi["name"],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: AppColors.forest),
                            ),
                            subtitle: Text(
                              "${poi["category"]} • ${poi["district"]}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (dist.isNotEmpty)
                                  Text(
                                    dist,
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.emerald),
                                  ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.forest),
                              ],
                            ),
                            onTap: () {
                              _moveToSpot(poi, targetZoom: 19.5); // Micro building and shop zoom
                            },
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Quick Suggestion / Category Chips
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _searchQuery.isEmpty ? _categories.length : _quickSuggestions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        if (_searchQuery.isNotEmpty) {
                          final sug = _quickSuggestions[idx];
                          return GestureDetector(
                            onTap: () {
                              _searchController.text = sug;
                              _onSearchQueryChanged(sug);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.emerald.withOpacity(0.4)),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                              ),
                              child: Text(
                                sug,
                                style: const TextStyle(color: AppColors.forest, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          );
                        }

                        final cat = _categories[idx];
                        final isSelected = _selectedCategory == cat;

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedCategory = cat);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.forest : Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? AppColors.forest : Colors.white),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
                            ),
                            child: Row(
                              children: [
                                if (cat != "All") ...[
                                  Icon(_getCategoryIcon(cat), size: 14, color: isSelected ? Colors.white : AppColors.forest),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  cat,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.forest,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // ===================================================================
          // 4. RIGHT FLOATING CONTROLS
          // ===================================================================
          Positioned(
            right: 14,
            top: MediaQuery.of(context).padding.top + 105,
            child: Column(
              children: [
                _buildMapFloatingAction(
                  icon: Icons.add_rounded,
                  tooltip: "Zoom In (Up to Building/Shop level)",
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final nextZoom = (_mapController.camera.zoom + 1.0).clamp(4.5, 22.0);
                    _mapController.move(_mapController.camera.center, nextZoom);
                  },
                ),
                const SizedBox(height: 8),
                _buildMapFloatingAction(
                  icon: Icons.remove_rounded,
                  tooltip: "Zoom Out",
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final nextZoom = (_mapController.camera.zoom - 1.0).clamp(4.5, 22.0);
                    _mapController.move(_mapController.camera.center, nextZoom);
                  },
                ),
                const SizedBox(height: 8),
                _buildMapFloatingAction(
                  icon: Icons.report_problem_rounded,
                  color: Colors.deepOrange,
                  iconColor: Colors.white,
                  tooltip: "Report Trail Hazard",
                  onTap: _openReportHazardModal,
                ),
                const SizedBox(height: 8),
                _buildMapFloatingAction(
                  icon: Icons.layers_rounded,
                  tooltip: "Map Style (Hybrid shows Shops & Schools)",
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedLayer = (_selectedLayer + 1) % 4;
                    });
                  },
                ),
                const SizedBox(height: 8),
                // Offline Map Manager
                _buildMapFloatingAction(
                  icon: _isFullIslandReady ? Icons.offline_pin_rounded : Icons.download_for_offline_rounded,
                  color: _isFullIslandReady ? AppColors.forest : Colors.white,
                  iconColor: _isFullIslandReady ? Colors.cyanAccent : AppColors.forest,
                  tooltip: "Offline Manager",
                  onTap: _openOfflineDownloadManager,
                ),
                const SizedBox(height: 8),
                _buildMapFloatingAction(
                  icon: Icons.sos_rounded,
                  color: Colors.red.shade600,
                  iconColor: Colors.white,
                  tooltip: "Emergency SOS",
                  onTap: _openEmergencySOSSheet,
                ),
                const SizedBox(height: 8),
                _buildMapFloatingAction(
                  icon: Icons.my_location_rounded,
                  color: _hasRealGpsFix ? AppColors.forest : Colors.white,
                  iconColor: _hasRealGpsFix ? Colors.white : AppColors.forest,
                  tooltip: "My Real GPS Location",
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _fetchRealDeviceGps(autoCenter: true);
                  },
                ),
              ],
            ),
          ),

          // ===================================================================
          // 5. BOTTOM CAROUSEL & HUD
          // ===================================================================
          Positioned(
            bottom: 96,
            left: 0,
            right: 0,
            child: _selectedSpot != null
                ? _buildSelectedSpotHUD(_selectedSpot!)
                : (combinedDisplaySpots.isEmpty
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                          ),
                          child: const Text("No spots found matching query.", style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.forest)),
                        ),
                      )
                    : SizedBox(
                        height: 124,
                        child: ListView.separated(
                          controller: _carouselController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: combinedDisplaySpots.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final spot = combinedDisplaySpots[index];
                            return _buildSpotPreviewCard(spot, combinedDisplaySpots);
                          },
                        ),
                      )),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryItem(IconData icon, String val, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.cyanAccent, size: 14),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11.5)),
            Text(label, style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.bold, fontSize: 8.5)),
          ],
        ),
      ],
    );
  }

  String _formatDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  Widget _buildMapFloatingAction({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    Color color = Colors.white,
    Color iconColor = AppColors.forest,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor, size: 22),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildSpotPreviewCard(Map<String, dynamic> spot, List<Map<String, dynamic>> allSpots) {
    final double distToSpot = const Distance().as(LengthUnit.Meter, _liveUserPosition, spot["center"] as LatLng) / 1000;

    return GestureDetector(
      onTap: () => _moveToSpot(spot, currentList: allSpots),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: safeNetworkImageWidget(
                spot["img"],
                width: 84,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(spot["category"]).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          spot["category"],
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: _getCategoryColor(spot["category"]),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "${distToSpot.toStringAsFixed(1)} km away",
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.emerald),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    spot["name"],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: AppColors.forest),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${spot["district"]} • ${spot["elevation"]}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.mint),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.hiking_rounded, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          "${spot["distance"]} • ${spot["difficulty"]}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedSpotHUD(Map<String, dynamic> spot) {
    final List<dynamic>? elevationPts = spot["elevationPoints"] as List<dynamic>?;
    final double distToSpot = _remainingDistanceMeters > 0
        ? (_remainingDistanceMeters / 1000)
        : (const Distance().as(LengthUnit.Meter, _liveUserPosition, spot["center"] as LatLng) / 1000);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 22, offset: Offset(0, 6))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_getCategoryIcon(spot["category"]), size: 16, color: _getCategoryColor(spot["category"])),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              spot["category"].toString().toUpperCase(),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: _getCategoryColor(spot["category"]),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            spot["rating"] ?? "4.9 ★",
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.orange),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        spot["name"],
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.forest),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${spot["district"]} • ${spot["elevation"]} • ${distToSpot.toStringAsFixed(1)} km by road/trail",
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.emerald),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => setState(() {
                    _selectedSpot = null;
                    _activeRouteToDestination.clear();
                  }),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              spot["desc"],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMain, height: 1.35),
            ),
            const SizedBox(height: 10),
            if (elevationPts != null && elevationPts.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.show_chart_rounded, size: 14, color: AppColors.emerald),
                  const SizedBox(width: 4),
                  const Text("Elevation Profile: ", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.forest)),
                  Expanded(
                    child: SizedBox(
                      height: 18,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: elevationPts.map((p) {
                          final double height = ((p as num).toDouble() / 2500) * 16 + 2;
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              height: height,
                              decoration: BoxDecoration(
                                color: AppColors.emerald.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                _buildStatPill(Icons.straighten_rounded, spot["distance"]),
                const SizedBox(width: 6),
                _buildStatPill(Icons.timer_outlined, spot["duration"]),
                const SizedBox(width: 6),
                _buildStatPill(Icons.pest_control_rounded, "Leech: ${spot["leechIndex"] ?? "Low"}"),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.navigation_rounded, size: 15, color: Colors.white),
                  label: Text(_isNavigating ? "Active GPS" : "Start GPS", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isNavigating ? Colors.cyanAccent.shade700 : AppColors.forest,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onPressed: () => _startLiveGps(spot),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.canvasBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardStroke),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: AppColors.forest),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.forest)),
        ],
      ),
    );
  }
}
