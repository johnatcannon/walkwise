import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

class RouteMapPage extends StatefulWidget {
  const RouteMapPage({super.key});

  @override
  State<RouteMapPage> createState() => _RouteMapPageState();
}

class _RouteMapPageState extends State<RouteMapPage> {
  int _venueId = 0;
  List<LocationPoint> _locations = [];
  List<RouteSegment> _segments = [];
  int _currentSegmentIndex = 0;
  bool _isLoading = true;
  String? _error;
  double _handicap = 1.0;
  final Map<String, String> _locationImages = {};
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    final state = Provider.of<WalkWiseState>(context, listen: false);
    _venueId = state.currentCityId;
    print('[RouteMapPage] Initializing with venue_id: $_venueId');
    _loadRouteData();
  }

  Future<void> _loadRouteData() async {
    try {
      print('[RouteMapPage] Loading route data for venue: $_venueId');
      // Get handicap from player profile
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        final profileDoc = await FirebaseFirestore.instance
            .collection('player_profile')
            .doc(user.uid)
            .get();
        
        if (profileDoc.exists) {
          _handicap = (profileDoc.data()?['handicap'] ?? 1.0).toDouble();
        }
      }

      if (_venueId == 0) {
        throw Exception('No active venue selected.');
      }

      // Load images from locations collection for this venue (used in popups)
      final locationsSnap = await FirebaseFirestore.instance
          .collection('locations')
          .where('city_id', isEqualTo: _venueId)
          .get();
      for (var doc in locationsSnap.docs) {
        final data = doc.data();
        final name = data['name'] ?? data['location_name'];
        final imageUrl = data['image'] ??
            data['imageURL'] ??
            data['imageUrl'] ??
            data['photo'];
        if (name != null && imageUrl != null) {
          _locationImages[name] = imageUrl;
        }
      }

      // Load venue routes with coordinates (including starting point order 0)
      final routesSnapshot = await FirebaseFirestore.instance
          .collection('venue_routes')
          .where('venue_id', isEqualTo: _venueId)
          .orderBy('route_order')
          .get();

      print('[RouteMapPage] Found ${routesSnapshot.docs.length} route documents');

      final locations = <LocationPoint>[];
      for (var doc in routesSnapshot.docs) {
        final data = doc.data();
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();

        if (lat != null && lng != null) {
          locations.add(
            LocationPoint(
              name: data['location_name'],
              order: data['route_order'],
              latLng: LatLng(lat, lng),
            ),
          );
          print('[RouteMapPage] Added location: ${data['location_name']} (${data['route_order']}) at ($lat, $lng)');
        } else {
          print('[RouteMapPage] ⚠️  Location ${data['location_name']} missing coordinates');
        }
      }

      print('[RouteMapPage] Total locations with coordinates: ${locations.length}');

      if (locations.isEmpty) {
        throw Exception('No route locations found for venue $_venueId.');
      }

      // Load ALL distances for this venue at once (batch query)
      final allDistancesSnapshot = await FirebaseFirestore.instance
          .collection('distances')
          .where('city_id', isEqualTo: _venueId)
          .get();
      
      // Create a lookup map for faster access
      final distanceMap = <String, int>{};
      for (var doc in allDistancesSnapshot.docs) {
        final data = doc.data();
        final key = '${data['from_location']}_${data['to_location']}';
        distanceMap[key] = data['steps'] ?? 500;
      }

      // Build segments using the cached distance data
      final segments = <RouteSegment>[];
      for (int i = 0; i < locations.length - 1; i++) {
        final fromLoc = locations[i];
        final toLoc = locations[i + 1];
        
        // Lookup distance from map
        final key = '${fromLoc.name}_${toLoc.name}';
        int steps = distanceMap[key] ?? 500;

        // Apply handicap
        final adjustedSteps = (steps * _handicap).round();

        segments.add(RouteSegment(
          from: fromLoc,
          to: toLoc,
          baseSteps: steps,
          adjustedSteps: adjustedSteps,
        ));
      }

      print('[RouteMapPage] ✅ Loaded ${locations.length} locations and ${segments.length} segments');
      
      setState(() {
        _locations = locations;
        _segments = segments;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('[RouteMapPage] ❌ Error loading route data: $e');
      print('[RouteMapPage] Stack trace: $stackTrace');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WalkWiseState>();
    _currentSegmentIndex = state.currentSegmentIndex;
    final hasCurrentSegment = _segments.isNotEmpty &&
        _currentSegmentIndex >= 0 &&
        _currentSegmentIndex < _segments.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Map'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'Error loading route:\n$_error',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Map with north button overlay
                    Expanded(
                      child: Stack(
                        children: [
                          // Standard FlutterMap with OpenStreetMap tiles
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _locations.isNotEmpty
                                  ? _locations.first.latLng
                                  : const LatLng(41.0082, 28.9784),
                              initialZoom: 13.0,
                              minZoom: 11.0,
                              maxZoom: 18.0,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.all,
                              ),
                            ),
                            children: [
                              // OpenStreetMap tiles for all real-world venues
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.gamesafoot.walkwise',
                              ),
                              // Route lines
                              PolylineLayer(
                                polylines: _segments.map((segment) {
                                  return Polyline(
                                    points: [segment.from.latLng, segment.to.latLng],
                                    strokeWidth: 4.0,
                                    color: const Color(0xFFE74C3C),
                                  );
                                }).toList(),
                              ),
                              // Location markers
                              MarkerLayer(
                                markers: _locations.map((location) {
                                  final isStart = location.order == 0;
                                  final isEnd = location.order == _locations.length - 1;
                                  final isVisited = location.order < _currentSegmentIndex;
                                  final isCurrent = location.order == _currentSegmentIndex;
                                  final markerColor = isVisited
                                      ? Colors.green
                                      : isCurrent
                                          ? Colors.orange
                                          : Colors.grey;
                                  
                                  return Marker(
                                    point: location.latLng,
                                    width: isCurrent ? 46 : 36,
                                    height: isCurrent ? 46 : 36,
                                    child: GestureDetector(
                                      onTap: () => _showLocationDialog(location),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: markerColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${location.order}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              // Step count labels
                              MarkerLayer(
                                markers: [
                                  if (hasCurrentSegment) ...[
                                    () {
                                      final segment = _segments[_currentSegmentIndex];
                                      final midLat = (segment.from.latLng.latitude +
                                              segment.to.latLng.latitude) /
                                          2;
                                      final midLng = (segment.from.latLng.longitude +
                                              segment.to.latLng.longitude) /
                                          2;
                                      return Marker(
                                        point: LatLng(midLat, midLng),
                                        width: 120,
                                        height: 34,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: Theme.of(context).colorScheme.primary,
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.2),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${segment.adjustedSteps} steps',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }(),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          // North orientation button
                          Positioned(
                            bottom: 20,
                            right: 20,
                            child: FloatingActionButton(
                              mini: true,
                              backgroundColor: Colors.white,
                              onPressed: () {
                                // Reset to initial center and zoom
                                if (_locations.isNotEmpty) {
                                  _mapController.move(
                                    _locations.first.latLng,
                                    13.0,
                                  );
                                }
                              },
                              child: const Icon(
                                Icons.navigation,
                                color: Color(0xFF00A896),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  void _showLocationDialog(LocationPoint location) {
    final imageUrl = _locationImages[location.name];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(location.name),
        content: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 360,
            maxHeight: 500,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Stop #${location.order}'),
              if (location.order == 0)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    '🏁 START',
                    style: TextStyle(
                      color: Color(0xFFF39C12),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (location.order == _locations.length - 1)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    '🏁 FINISH',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (imageUrl != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 180,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class LocationPoint {
  final String name;
  final int order;
  final LatLng latLng;

  LocationPoint({
    required this.name,
    required this.order,
    required this.latLng,
  });
}

class RouteSegment {
  final LocationPoint from;
  final LocationPoint to;
  final int baseSteps;
  final int adjustedSteps;

  RouteSegment({
    required this.from,
    required this.to,
    required this.baseSteps,
    required this.adjustedSteps,
  });
}
