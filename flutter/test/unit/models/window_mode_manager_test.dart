import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/models/window_mode_manager.dart';
import 'package:flutter_hbb/models/detected_window.dart';
import 'package:flutter_hbb/services/window_detection_service.dart';

// Mock detection service for testing
class MockWindowDetectionService extends WindowDetectionService {
  List<DetectedWindow>? mockResult;
  bool shouldThrow = false;
  String? errorMessage;
  
  MockWindowDetectionService({this.mockResult, this.shouldThrow = false, this.errorMessage});
  
  @override
  Future<List<DetectedWindow>> detectAllWindowsWithCycling() async {
    if (shouldThrow) {
      throw WindowDetectionException(errorMessage ?? 'Mock error');
    }
    return mockResult ?? [];
  }
}

void main() {
  group('WindowModeManager', () {
    final mockThumbnail = Uint8List.fromList([1, 2, 3, 4]);
    
    List<DetectedWindow> createMockWindows() {
      return [
        DetectedWindow(
          bounds: Rect.fromLTWH(0, 0, 300, 200), // Large window
          cyclePosition: 0,
          thumbnail: mockThumbnail,
          category: WindowCategory.large,
        ),
        DetectedWindow(
          bounds: Rect.fromLTWH(100, 100, 150, 100), // Medium window
          cyclePosition: 1,
          thumbnail: mockThumbnail,
          category: WindowCategory.medium,
        ),
      ];
    }

    test('initializes with normal state', () {
      final manager = WindowModeManager();
      
      expect(manager.currentState, equals(WindowModeState.normal));
      expect(manager.isNormal, isTrue);
      expect(manager.isDetecting, isFalse);
      expect(manager.isSelecting, isFalse);
      expect(manager.isNavigating, isFalse);
      expect(manager.detectedWindows, isEmpty);
      expect(manager.selectedWindows, isEmpty);
      expect(manager.currentWindowIndex, equals(0));
      expect(manager.isProcessing, isFalse);
      expect(manager.errorMessage, isEmpty);
    });

    test('starts window detection successfully', () async {
      final mockService = MockWindowDetectionService(mockResult: createMockWindows());
      final manager = WindowModeManager(detectionService: mockService);
      
      expect(manager.currentState, equals(WindowModeState.normal));
      
      // Start detection
      final future = manager.startWindowDetection();
      
      // Should immediately transition to detecting state
      expect(manager.currentState, equals(WindowModeState.detecting));
      expect(manager.isProcessing, isTrue);
      
      await future;
      
      // Should transition to selecting state with detected windows
      expect(manager.currentState, equals(WindowModeState.selecting));
      expect(manager.isProcessing, isFalse);
      expect(manager.detectedWindows, hasLength(2));
      expect(manager.errorMessage, isEmpty);
    });

    test('handles detection failure gracefully', () async {
      final mockService = MockWindowDetectionService(
        shouldThrow: true, 
        errorMessage: 'Connection failed'
      );
      final manager = WindowModeManager(detectionService: mockService);
      
      await manager.startWindowDetection();
      
      // Should return to normal state with error
      expect(manager.currentState, equals(WindowModeState.normal));
      expect(manager.isProcessing, isFalse);
      expect(manager.errorMessage, contains('Connection failed'));
      expect(manager.detectedWindows, isEmpty);
    });

    test('handles empty detection results', () async {
      final mockService = MockWindowDetectionService(mockResult: []);
      final manager = WindowModeManager(detectionService: mockService);
      
      await manager.startWindowDetection();
      
      // Should return to normal state with error message
      expect(manager.currentState, equals(WindowModeState.normal));
      expect(manager.errorMessage, contains('No windows detected'));
      expect(manager.detectedWindows, isEmpty);
    });

    test('selects windows and transitions to navigation', () {
      final manager = WindowModeManager();
      final windows = createMockWindows();
      
      // Simulate being in selecting state
      manager.selectWindows(windows);
      
      expect(manager.currentState, equals(WindowModeState.navigating));
      expect(manager.selectedWindows, equals(windows));
      expect(manager.currentWindowIndex, equals(0));
    });

    test('rejects empty window selection', () {
      final manager = WindowModeManager();
      
      manager.selectWindows([]);
      
      expect(manager.currentState, equals(WindowModeState.normal));
      expect(manager.errorMessage, contains('No windows selected'));
    });

    test('validates navigation constraints', () {
      final manager = WindowModeManager();
      final windows = createMockWindows();
      manager.selectWindows(windows);
      
      expect(manager.canNavigateToWindow(0), isTrue);
      expect(manager.canNavigateToWindow(1), isTrue);
      expect(manager.canNavigateToWindow(2), isFalse); // Out of bounds
      expect(manager.canNavigateToWindow(-1), isFalse); // Negative index
    });

    test('restarts detection clears state', () async {
      final mockService = MockWindowDetectionService(mockResult: createMockWindows());
      final manager = WindowModeManager(detectionService: mockService);
      
      // Set up some state
      await manager.startWindowDetection();
      await manager.selectWindows(createMockWindows());
      
      // Restart detection
      manager.restartDetection();
      
      expect(manager.currentState, equals(WindowModeState.detecting));
      expect(manager.selectedWindows, isEmpty);
      expect(manager.currentWindowIndex, equals(0));
    });

    test('exits window mode returns to normal', () {
      final manager = WindowModeManager();
      final windows = createMockWindows();
      manager.selectWindows(windows);
      
      expect(manager.currentState, equals(WindowModeState.navigating));
      
      manager.exitWindowMode();
      
      expect(manager.currentState, equals(WindowModeState.normal));
      expect(manager.selectedWindows, isEmpty);
      expect(manager.detectedWindows, isEmpty);
      expect(manager.currentWindowIndex, equals(0));
      expect(manager.isProcessing, isFalse);
      expect(manager.errorMessage, isEmpty);
    });

    test('gets window counts by category', () async {
      final windows = [
        DetectedWindow(
          bounds: Rect.fromLTWH(0, 0, 300, 200),
          cyclePosition: 0,
          thumbnail: mockThumbnail,
          category: WindowCategory.large,
        ),
        DetectedWindow(
          bounds: Rect.fromLTWH(100, 100, 300, 200),
          cyclePosition: 1,
          thumbnail: mockThumbnail,
          category: WindowCategory.large,
        ),
        DetectedWindow(
          bounds: Rect.fromLTWH(200, 200, 100, 100),
          cyclePosition: 2,
          thumbnail: mockThumbnail,
          category: WindowCategory.medium,
        ),
      ];
      
      final mockService = MockWindowDetectionService(mockResult: windows);
      final manager = WindowModeManager(detectionService: mockService);
      
      await manager.startWindowDetection();
      
      final counts = manager.getWindowCountsByCategory();
      expect(counts[WindowCategory.large], equals(2));
      expect(counts[WindowCategory.medium], equals(1));
      expect(counts[WindowCategory.small], equals(0));
    });

    test('returns current window correctly', () {
      final manager = WindowModeManager();
      final windows = createMockWindows();
      
      expect(manager.currentWindow, isNull);
      
      manager.selectWindows(windows);
      expect(manager.currentWindow, equals(windows[0]));
    });

    test('state validation works correctly', () {
      final manager = WindowModeManager();
      
      // Normal state validation
      expect(manager.validateState(), isTrue);
      
      // Navigate to selecting state
      manager.selectWindows(createMockWindows());
      expect(manager.validateState(), isTrue);
    });

    test('state string representation is correct', () {
      final manager = WindowModeManager();
      
      expect(manager.currentStateString, equals('normal'));
      
      manager.selectWindows(createMockWindows());
      expect(manager.currentStateString, equals('navigating'));
    });

    test('toString provides useful debugging info', () {
      final manager = WindowModeManager();
      final result = manager.toString();
      
      expect(result, contains('WindowModeManager'));
      expect(result, contains('state:'));
      expect(result, contains('detected:'));
      expect(result, contains('selected:'));
      expect(result, contains('processing:'));
    });

    test('notifies listeners on state changes', () {
      final manager = WindowModeManager();
      bool notified = false;
      
      manager.addListener(() {
        notified = true;
      });
      
      manager.selectWindows(createMockWindows());
      expect(notified, isTrue);
    });

    test('prevents navigation during processing', () async {
      final manager = WindowModeManager();
      final windows = createMockWindows();
      manager.selectWindows(windows);
      
      // Start navigation (this will set processing to true)
      final future = manager.navigateToWindow(1);
      
      // Try to navigate again while processing
      expect(manager.canNavigateToWindow(0), isFalse);
      
      await future;
      
      // Should be able to navigate again after processing
      expect(manager.canNavigateToWindow(0), isTrue);
    });
  });
}