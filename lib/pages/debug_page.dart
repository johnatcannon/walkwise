import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:walkwise/app_state.dart';
import 'package:walkwise/pages/tour_completion_page.dart';

class DebugPage extends StatelessWidget {
  const DebugPage({super.key});

  void _testCompletionPage(BuildContext context) {
    final state = context.read<WalkWiseState>();
    // Use current venue if available, otherwise default to a test venue
    final venueName = state.currentVenue ?? 'Washington DC';
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TourCompletionPage(venueName: venueName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Debug',
          style: TextStyle(
            fontFamily: 'TimeBurner',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF00A896), // WalkWise primary green
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.bug_report,
                size: 64,
                color: Color(0xFF00A896),
              ),
              const SizedBox(height: 24),
              const Text(
                'Debug Tools',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'TimeBurner',
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _testCompletionPage(context),
                  icon: const Icon(Icons.check_circle, size: 28),
                  label: const Text(
                    'Test Completion Page',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'TimeBurner',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A896),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
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
