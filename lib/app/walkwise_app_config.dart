import 'package:flutter/material.dart';
import 'package:games_afoot_framework/games_afoot_framework.dart';

/// WalkWise configuration for the Games Afoot framework.
class WalkWiseAppConfig {
  static AppConfig build() {
    return const AppConfig(
      appName: 'WalkWise',
      appId: 'walkwise',
      primaryColor: Color(0xFF00A896), // Matches WalkWise web/app accent
      logoPath: 'assets/images/WalkWise-Green-logo.png',
      helpUrl: 'https://gowalkwise.com/instructions/',
      supportUrl: 'https://gowalkwise.com/support/',
      privacyPolicyUrl: 'https://gowalkwise.com/privacy-policy/',
      mainDestinationRoute: '/venue-selection',
      resumeDestinationRoute: '/walking',
      tagline: '#Every Step a Story',
      packageName: 'com.gowalkwise.walkwise',
      supportsBetaFeatures: false, // WalkWise is not in beta
      howToPlayContent: HowToPlayContent(
        instructions: [
          'Select a venue to explore',
          'You will be taken on a guided tour and presented fun facts along the way',
          'Begin walking',
          'View your progress by selecting the Menu → Map',
        ],
      ),
      showReadyToPlayMenuItem: false, // Hide from menu (Help will navigate to it)
      showHowToPlayMenuItem: false, // Hide from menu
      helpNavigatesToReadyToPlay: true, // Help menu item goes to Ready to Play page
    );
  }
}


