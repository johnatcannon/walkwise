import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class AwtyService {
  static const MethodChannel _channel = MethodChannel('awty_engine');
  static const EventChannel _eventChannel = EventChannel('awty_events');
  
  // Callback for milestone reached
  static void Function()? _onMilestoneReached;
  
  // Set callback for milestone reached
  static void setMilestoneCallback(void Function() callback) {
    _onMilestoneReached = callback;
  }
  
  // Initialize event listeners
  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'milestoneReached':
          debugPrint('AWTY: Milestone reached callback received!');
          // Trigger the callback to auto-deliver fun fact
          _onMilestoneReached?.call();
          break;
        default:
          debugPrint('AWTY: Unknown method call: ${call.method}');
      }
    });
  }
} 