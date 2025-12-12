import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walkwise/app_state.dart';

class VenueSelectionPage extends StatefulWidget {
  const VenueSelectionPage({super.key});

  @override
  State<VenueSelectionPage> createState() => _VenueSelectionPageState();
}

class _VenueSelectionPageState extends State<VenueSelectionPage> {
  List<Map<String, dynamic>> venues = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVenues();
  }

  Future<void> _loadVenues() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('cities')
          .where('is_active', isEqualTo: true)
          .get();

      if (mounted) {
        setState(() {
          venues = querySnapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    'name': doc.data()['name'] ?? 'Unknown',
                    'country': doc.data()['country'] ?? '',
                    'description': doc.data()['description'] ?? '',
                    'image': doc.data()['image'] ?? '',
                  })
              .toList();
          // Sort venues alphabetically by name
          venues.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading venues: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Venue'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : venues.isEmpty
              ? const Center(child: Text('No venues available'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: venues.length,
                  itemBuilder: (context, index) {
                    final venue = venues[index];
                    final imageUrl = venue['image'] as String? ?? '';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _selectVenue(venue),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Venue Image (simple thumbnail, no zoom)
                            if (imageUrl.isNotEmpty)
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.location_city,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            // Venue Info
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    venue['name'],
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    venue['country'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    venue['description'] ?? '',
                                    style: const TextStyle(fontSize: 14),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
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

  void _selectVenue(Map<String, dynamic> venue) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Get the app state and select the venue
      final state = context.read<WalkWiseState>();
      await state.selectVenue(venue['name']);

      // Check if widget is still mounted before using context
      if (mounted) {
        // Close loading dialog
        Navigator.of(context).pop();

        // Navigate to intro video page
        Navigator.pushNamed(context, '/intro-video');
      }
    } catch (e) {
      // Check if widget is still mounted before using context
      if (mounted) {
        // Close loading dialog
        Navigator.of(context).pop();

        // Show detailed error message
        String errorMessage = 'Error selecting venue: $e';
        
        // Provide more helpful error messages for common database issues
        if (e.toString().contains('No route found')) {
          errorMessage = 'No walking route is configured for ${venue['name']}. Please contact support.';
        } else if (e.toString().contains('City not found')) {
          errorMessage = 'City data is missing for ${venue['name']}. Please contact support.';
        } else if (e.toString().contains('No distance data found')) {
          errorMessage = 'Distance data is missing for ${venue['name']}. Please contact support.';
        } else if (e.toString().contains('No greeting video available')) {
          errorMessage = 'Intro video is not available for ${venue['name']}. Please contact support.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    }
  }
} 