import 'package:go_router/go_router.dart';

import '../pages/debug_page.dart';
import '../pages/intro_video_page.dart';
import '../pages/location_image_page.dart';
import '../pages/route_map_page.dart';
import '../pages/tour_completion_page.dart';
import '../pages/venue_selection_page.dart';
import '../pages/walking_page.dart';

class WalkWiseAppRoutes {
  static List<GoRoute> routes() {
    return [
      GoRoute(
        path: '/venue-selection',
        builder: (context, state) => const VenueSelectionPage(),
      ),
      GoRoute(
        path: '/walking',
        builder: (context, state) => const WalkingPage(),
      ),
      GoRoute(
        path: '/intro-video',
        builder: (context, state) => const IntroVideoPage(),
      ),
      GoRoute(
        path: '/route-map',
        builder: (context, state) => const RouteMapPage(),
      ),
      GoRoute(
        path: '/debug',
        builder: (context, state) => const DebugPage(),
      ),
      // These two pages require parameters; we support them via query params.
      GoRoute(
        path: '/location-image',
        builder: (context, state) {
          final name = state.uri.queryParameters['name'] ?? '';
          return LocationImagePage(locationName: name);
        },
      ),
      GoRoute(
        path: '/completion-video',
        builder: (context, state) {
          final venueName = state.uri.queryParameters['venue'] ?? '';
          return TourCompletionPage(venueName: venueName);
        },
      ),
    ];
  }
}


