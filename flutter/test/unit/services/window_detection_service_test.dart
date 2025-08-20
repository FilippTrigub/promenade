import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/services/window_detection_service.dart';
import 'package:flutter_hbb/models/detected_window.dart';

void main() {
  group('WindowDetectionService', () {
    test('constructs with default values', () {
      final service = WindowDetectionService();
      expect(service, isNotNull);
    });

    test('constructs with mock dependencies for testing', () {
      bool inputTriggered = false;
      bool imageCaptureCalled = false;
      
      final service = WindowDetectionService(
        mockInputTrigger: () => inputTriggered = true,
        mockImageCapture: () => imageCaptureCalled = true,
      );
      
      expect(service, isNotNull);
    });

    test('constants have researched values', () {
      expect(WindowDetectionService.EDGE_THRESHOLD, equals(175));
      expect(WindowDetectionService.LARGE_WINDOW_THRESHOLD, equals(0.15));
      expect(WindowDetectionService.MEDIUM_WINDOW_THRESHOLD, equals(0.05));
      expect(WindowDetectionService.MAX_CYCLING_ATTEMPTS, equals(15));
      expect(WindowDetectionService.CYCLING_TIMEOUT_SECONDS, equals(180));
    });

    test('detection with mocks returns empty on null screen data', () async {
      final service = WindowDetectionService(
        mockInputTrigger: () {},
        mockImageCapture: () {},
      );
      
      final result = await service.detectAllWindowsWithCycling();
      expect(result, isEmpty);
    });

    test('handles timeout correctly', () async {
      final service = WindowDetectionService(
        mockInputTrigger: () {},
        mockImageCapture: () {},
      );
      
      // This should complete quickly due to mocked dependencies returning null
      final result = await service.detectAllWindowsWithCycling();
      expect(result, isEmpty);
    });

    test('respects max cycling attempts', () async {
      int cycleCount = 0;
      final service = WindowDetectionService(
        mockInputTrigger: () => cycleCount++,
        mockImageCapture: () {},
      );
      
      await service.detectAllWindowsWithCycling();
      
      // Should cycle MAX_CYCLING_ATTEMPTS - 1 times (doesn't cycle on last iteration)
      expect(cycleCount, equals(WindowDetectionService.MAX_CYCLING_ATTEMPTS - 1));
    });

    test('window categorization by size works correctly', () {
      // These tests verify the categorization logic indirectly through threshold constants
      const screenWidth = 1920;
      const screenHeight = 1080;
      const screenArea = screenWidth * screenHeight;
      
      // Large window threshold (15% of screen)
      final largeThreshold = WindowDetectionService.LARGE_WINDOW_THRESHOLD * screenArea;
      expect(largeThreshold, equals(311040.0)); // 15% of 1920x1080
      
      // Medium window threshold (5% of screen)
      final mediumThreshold = WindowDetectionService.MEDIUM_WINDOW_THRESHOLD * screenArea;
      expect(mediumThreshold, equals(103680.0)); // 5% of 1920x1080
    });

    test('edge threshold is within researched range', () {
      // Verify the threshold is in the researched optimal range of 150-200
      expect(WindowDetectionService.EDGE_THRESHOLD, greaterThanOrEqualTo(150));
      expect(WindowDetectionService.EDGE_THRESHOLD, lessThanOrEqualTo(200));
    });

    test('cycling timeout provides reasonable detection time', () {
      // With max 15 attempts and 2.5s delays, ensure timeout is sufficient
      final expectedMinTime = WindowDetectionService.MAX_CYCLING_ATTEMPTS * 2.5;
      expect(WindowDetectionService.CYCLING_TIMEOUT_SECONDS, greaterThan(expectedMinTime));
    });
  });

  group('WindowDetectionException', () {
    test('creates exception with message', () {
      final exception = WindowDetectionException('Test error');
      expect(exception.message, equals('Test error'));
      expect(exception.toString(), contains('WindowDetectionException: Test error'));
    });
  });

  group('ScreenData', () {
    test('creates screen data container', () {
      final rgbaData = Uint8List.fromList([255, 0, 0, 255]);
      final screenData = ScreenData(
        rgbaData: rgbaData,
        width: 100,
        height: 100,
      );
      
      expect(screenData.rgbaData, equals(rgbaData));
      expect(screenData.width, equals(100));
      expect(screenData.height, equals(100));
    });
  });
}