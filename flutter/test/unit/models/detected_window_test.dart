import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/models/detected_window.dart';

void main() {
  group('DetectedWindow', () {
    final mockThumbnail = Uint8List.fromList([1, 2, 3, 4]);
    final testBounds = Rect.fromLTWH(10, 20, 100, 80);
    
    test('creates valid DetectedWindow with all required properties', () {
      final window = DetectedWindow(
        bounds: testBounds,
        cyclePosition: 2,
        thumbnail: mockThumbnail,
        category: WindowCategory.large,
      );
      
      expect(window.bounds, equals(testBounds));
      expect(window.cyclePosition, equals(2));
      expect(window.thumbnail, equals(mockThumbnail));
      expect(window.category, equals(WindowCategory.large));
    });

    test('calculates screen percentage correctly', () {
      final window = DetectedWindow(
        bounds: Rect.fromLTWH(0, 0, 100, 50), // 5000 pixels
        cyclePosition: 0,
        thumbnail: mockThumbnail,
        category: WindowCategory.medium,
      );
      
      // Screen of 1000x100 = 100,000 pixels
      // Window of 100x50 = 5,000 pixels
      // Expected percentage: 0.05 (5%)
      expect(window.getScreenPercentage(1000, 100), equals(0.05));
    });

    test('validates window bounds are positive', () {
      expect(
        () => DetectedWindow(
          bounds: Rect.fromLTWH(0, 0, -10, 20),
          cyclePosition: 0,
          thumbnail: mockThumbnail,
          category: WindowCategory.small,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('validates cycle position is non-negative', () {
      expect(
        () => DetectedWindow(
          bounds: testBounds,
          cyclePosition: -1,
          thumbnail: mockThumbnail,
          category: WindowCategory.large,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('validates thumbnail data is not empty', () {
      expect(
        () => DetectedWindow(
          bounds: testBounds,
          cyclePosition: 0,
          thumbnail: Uint8List(0),
          category: WindowCategory.medium,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('checks if window is within screen bounds correctly', () {
      final window = DetectedWindow(
        bounds: Rect.fromLTWH(10, 10, 100, 100),
        cyclePosition: 0,
        thumbnail: mockThumbnail,
        category: WindowCategory.large,
      );
      
      expect(window.isWithinScreen(1920, 1080), isTrue);
      expect(window.isWithinScreen(50, 50), isFalse);
    });

    test('calculates area correctly', () {
      final window = DetectedWindow(
        bounds: Rect.fromLTWH(0, 0, 100, 80),
        cyclePosition: 0,
        thumbnail: mockThumbnail,
        category: WindowCategory.large,
      );
      
      expect(window.area, equals(8000.0));
    });

    test('calculates aspect ratio correctly', () {
      final window = DetectedWindow(
        bounds: Rect.fromLTWH(0, 0, 200, 100),
        cyclePosition: 0,
        thumbnail: mockThumbnail,
        category: WindowCategory.large,
      );
      
      expect(window.aspectRatio, equals(2.0));
    });

    test('creates copy with different properties', () {
      final original = DetectedWindow(
        bounds: testBounds,
        cyclePosition: 1,
        thumbnail: mockThumbnail,
        category: WindowCategory.medium,
      );
      
      final copy = original.copyWith(
        category: WindowCategory.large,
        cyclePosition: 3,
      );
      
      expect(copy.bounds, equals(original.bounds));
      expect(copy.thumbnail, equals(original.thumbnail));
      expect(copy.category, equals(WindowCategory.large));
      expect(copy.cyclePosition, equals(3));
    });

    test('equality comparison works correctly', () {
      final window1 = DetectedWindow(
        bounds: testBounds,
        cyclePosition: 1,
        thumbnail: mockThumbnail,
        category: WindowCategory.large,
      );
      
      final window2 = DetectedWindow(
        bounds: testBounds,
        cyclePosition: 1,
        thumbnail: Uint8List.fromList([5, 6, 7, 8]), // Different thumbnail
        category: WindowCategory.large,
      );
      
      final window3 = DetectedWindow(
        bounds: Rect.fromLTWH(0, 0, 50, 50), // Different bounds
        cyclePosition: 1,
        thumbnail: mockThumbnail,
        category: WindowCategory.large,
      );
      
      expect(window1 == window2, isTrue); // Same bounds, cycle, category
      expect(window1 == window3, isFalse); // Different bounds
    });

    test('hash code consistency', () {
      final window1 = DetectedWindow(
        bounds: testBounds,
        cyclePosition: 1,
        thumbnail: mockThumbnail,
        category: WindowCategory.large,
      );
      
      final window2 = DetectedWindow(
        bounds: testBounds,
        cyclePosition: 1,
        thumbnail: Uint8List.fromList([9, 10, 11, 12]),
        category: WindowCategory.large,
      );
      
      expect(window1.hashCode, equals(window2.hashCode));
    });

    test('toString provides readable output', () {
      final window = DetectedWindow(
        bounds: Rect.fromLTWH(10, 20, 100, 80),
        cyclePosition: 2,
        thumbnail: mockThumbnail,
        category: WindowCategory.large,
      );
      
      final result = window.toString();
      expect(result, contains('DetectedWindow'));
      expect(result, contains('cycle: 2'));
      expect(result, contains('large'));
      expect(result, contains('area: 8000'));
    });
  });

  group('WindowCategoryHelper', () {
    test('returns correct display names', () {
      expect(WindowCategoryHelper.getDisplayName(WindowCategory.large), 
             equals('Likely Window'));
      expect(WindowCategoryHelper.getDisplayName(WindowCategory.medium), 
             equals('Possible Window'));
      expect(WindowCategoryHelper.getDisplayName(WindowCategory.small), 
             equals('Small Region'));
    });

    test('returns correct colors', () {
      expect(WindowCategoryHelper.getColor(WindowCategory.large), 
             equals(Colors.blue));
      expect(WindowCategoryHelper.getColor(WindowCategory.medium), 
             equals(Colors.orange));
      expect(WindowCategoryHelper.getColor(WindowCategory.small), 
             equals(Colors.grey));
    });

    test('returns correct priorities', () {
      expect(WindowCategoryHelper.getPriority(WindowCategory.large), equals(3));
      expect(WindowCategoryHelper.getPriority(WindowCategory.medium), equals(2));
      expect(WindowCategoryHelper.getPriority(WindowCategory.small), equals(1));
    });

    test('determines category from screen percentage correctly', () {
      expect(WindowCategoryHelper.fromScreenPercentage(0.20), 
             equals(WindowCategory.large)); // 20% >= 15%
      expect(WindowCategoryHelper.fromScreenPercentage(0.10), 
             equals(WindowCategory.medium)); // 10% between 5-15%
      expect(WindowCategoryHelper.fromScreenPercentage(0.03), 
             equals(WindowCategory.small)); // 3% < 5%
      expect(WindowCategoryHelper.fromScreenPercentage(0.15), 
             equals(WindowCategory.large)); // Exactly 15%
      expect(WindowCategoryHelper.fromScreenPercentage(0.05), 
             equals(WindowCategory.medium)); // Exactly 5%
    });
  });
}