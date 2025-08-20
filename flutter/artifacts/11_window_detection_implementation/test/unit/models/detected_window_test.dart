import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/models/detected_window.dart';

void main() {
  group('DetectedWindow', () {
    late Uint8List mockThumbnail;

    setUp(() {
      // Create a simple mock thumbnail (1x1 pixel PNG)
      mockThumbnail = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      ]);
    });

    group('Constructor validation', () {
      test('should create valid DetectedWindow with all required properties', () {
        final window = DetectedWindow(
          bounds: const Rect.fromLTWH(100, 100, 300, 200),
          cyclePosition: 0,
          thumbnail: mockThumbnail,
          category: WindowCategory.large,
        );

        expect(window.bounds, equals(const Rect.fromLTWH(100, 100, 300, 200)));
        expect(window.cyclePosition, equals(0));
        expect(window.thumbnail, equals(mockThumbnail));
        expect(window.category, equals(WindowCategory.large));
      });

      test('should throw assertion error for invalid bounds', () {
        expect(
          () => DetectedWindow(
            bounds: const Rect.fromLTWH(100, 100, 0, 200),
            cyclePosition: 0,
            thumbnail: mockThumbnail,
            category: WindowCategory.large,
          ),
          throwsAssertionError,
        );
      });

      test('should throw assertion error for negative cycle position', () {
        expect(
          () => DetectedWindow(
            bounds: const Rect.fromLTWH(100, 100, 300, 200),
            cyclePosition: -1,
            thumbnail: mockThumbnail,
            category: WindowCategory.large,
          ),
          throwsAssertionError,
        );
      });

      test('should throw assertion error for empty thumbnail', () {
        expect(
          () => DetectedWindow(
            bounds: const Rect.fromLTWH(100, 100, 300, 200),
            cyclePosition: 0,
            thumbnail: Uint8List(0),
            category: WindowCategory.large,
          ),
          throwsAssertionError,
        );
      });
    });

    group('Screen percentage calculation', () {
      test('should calculate correct screen percentage for large window', () {
        final window = DetectedWindow(
          bounds: const Rect.fromLTWH(0, 0, 800, 600),
          cyclePosition: 0,
          thumbnail: mockThumbnail,
          category: WindowCategory.large,
        );

        // 800x600 in 1920x1080 screen = 480000/2073600 ≈ 0.2315
        final percentage = window.getScreenPercentage(1920, 1080);
        expect(percentage, closeTo(0.2315, 0.001));
      });

      test('should calculate correct screen percentage for medium window', () {
        final window = DetectedWindow(
          bounds: const Rect.fromLTWH(0, 0, 400, 300),
          cyclePosition: 0,
          thumbnail: mockThumbnail,
          category: WindowCategory.medium,
        );

        // 400x300 in 1920x1080 screen = 120000/2073600 ≈ 0.0579
        final percentage = window.getScreenPercentage(1920, 1080);
        expect(percentage, closeTo(0.0579, 0.001));
      });

      test('should throw assertion error for invalid screen dimensions', () {
        final window = DetectedWindow(
          bounds: const Rect.fromLTWH(100, 100, 300, 200),
          cyclePosition: 0,
          thumbnail: mockThumbnail,
          category: WindowCategory.large,
        );

        expect(
          () => window.getScreenPercentage(0, 1080),
          throwsAssertionError,
        );
      });
    });

    group('Screen bounds validation', () {
      test('should return true for window within screen bounds', () {
        final window = DetectedWindow(
          bounds: const Rect.fromLTWH(100, 100, 300, 200),
          cyclePosition: 0,
          thumbnail: mockThumbnail,
          category: WindowCategory.large,
        );

        expect(window.isWithinScreen(1920, 1080), isTrue);
      });

      test('should return false for window outside screen bounds', () {
        final window = DetectedWindow(
          bounds: const Rect.fromLTWH(1800, 900, 300, 200),
          cyclePosition: 0,
          thumbnail: mockThumbnail,
          category: WindowCategory.large,
        );

        expect(window.isWithinScreen(1920, 1080), isFalse);
      });
    });

    group('Computed properties', () {
      test('should calculate correct area', () {
        final window = DetectedWindow(
          bounds: const Rect.fromLTWH(100, 100, 300, 200),
          cyclePosition: 0,
          thumbnail: mockThumbnail,
          category: WindowCategory.large,
        );

        expect(window.area, equals(60000.0));
      });

      test('should calculate correct aspect ratio', () {
        final window = DetectedWindow(
          bounds: const Rect.fromLTWH(100, 100, 400, 200),
          cyclePosition: 0,
          thumbnail: mockThumbnail,
          category: WindowCategory.large,
        );

        expect(window.aspectRatio, equals(2.0));
      });
    });

    group('Equality and hashing', () {
      test('should be equal for windows with same properties', () {
        final window1 = DetectedWindow(
          bounds: const Rect.fromLTWH(100, 100, 300, 200),
          cyclePosition: 0,
          thumbnail: mockThumbnail,
          category: WindowCategory.large,
        );

        final window2 = DetectedWindow(
          bounds: const Rect.fromLTWH(100, 100, 300, 200),
          cyclePosition: 0,
          thumbnail: mockThumbnail,
          category: WindowCategory.large,
        );

        expect(window1, equals(window2));
        expect(window1.hashCode, equals(window2.hashCode));
      });

      test('should not be equal for windows with different bounds', () {
        final window1 = DetectedWindow(
          bounds: const Rect.fromLTWH(100, 100, 300, 200),
          cyclePosition: 0,
          thumbnail: mockThumbnail,
          category: WindowCategory.large,
        );

        final window2 = DetectedWindow(
          bounds: const Rect.fromLTWH(200, 200, 300, 200),
          cyclePosition: 0,
          thumbnail: mockThumbnail,
          category: WindowCategory.large,
        );

        expect(window1, isNot(equals(window2)));
      });
    });

    group('Copy with method', () {
      test('should create copy with modified category', () {
        final original = DetectedWindow(
          bounds: const Rect.fromLTWH(100, 100, 300, 200),
          cyclePosition: 0,
          thumbnail: mockThumbnail,
          category: WindowCategory.large,
        );

        final copy = original.copyWith(category: WindowCategory.medium);

        expect(copy.bounds, equals(original.bounds));
        expect(copy.cyclePosition, equals(original.cyclePosition));
        expect(copy.thumbnail, equals(original.thumbnail));
        expect(copy.category, equals(WindowCategory.medium));
      });

      test('should create identical copy when no parameters provided', () {
        final original = DetectedWindow(
          bounds: const Rect.fromLTWH(100, 100, 300, 200),
          cyclePosition: 0,
          thumbnail: mockThumbnail,
          category: WindowCategory.large,
        );

        final copy = original.copyWith();

        expect(copy, equals(original));
      });
    });
  });

  group('WindowCategoryHelper', () {
    group('Display names', () {
      test('should return correct display names for all categories', () {
        expect(WindowCategoryHelper.getDisplayName(WindowCategory.large), 
               equals('Likely Window'));
        expect(WindowCategoryHelper.getDisplayName(WindowCategory.medium), 
               equals('Possible Window'));
        expect(WindowCategoryHelper.getDisplayName(WindowCategory.small), 
               equals('Small Region'));
      });
    });

    group('Colors', () {
      test('should return distinct colors for each category', () {
        final largeColor = WindowCategoryHelper.getColor(WindowCategory.large);
        final mediumColor = WindowCategoryHelper.getColor(WindowCategory.medium);
        final smallColor = WindowCategoryHelper.getColor(WindowCategory.small);

        expect(largeColor, equals(Colors.blue));
        expect(mediumColor, equals(Colors.orange));
        expect(smallColor, equals(Colors.grey));
        
        // Ensure colors are different
        expect(largeColor, isNot(equals(mediumColor)));
        expect(mediumColor, isNot(equals(smallColor)));
        expect(largeColor, isNot(equals(smallColor)));
      });
    });

    group('Priority', () {
      test('should return correct priorities with large > medium > small', () {
        final largePriority = WindowCategoryHelper.getPriority(WindowCategory.large);
        final mediumPriority = WindowCategoryHelper.getPriority(WindowCategory.medium);
        final smallPriority = WindowCategoryHelper.getPriority(WindowCategory.small);

        expect(largePriority, equals(3));
        expect(mediumPriority, equals(2));
        expect(smallPriority, equals(1));
        
        // Verify ordering
        expect(largePriority, greaterThan(mediumPriority));
        expect(mediumPriority, greaterThan(smallPriority));
      });
    });

    group('Category from percentage', () {
      test('should classify large windows correctly (≥15%)', () {
        expect(WindowCategoryHelper.fromScreenPercentage(0.15), 
               equals(WindowCategory.large));
        expect(WindowCategoryHelper.fromScreenPercentage(0.25), 
               equals(WindowCategory.large));
        expect(WindowCategoryHelper.fromScreenPercentage(0.50), 
               equals(WindowCategory.large));
      });

      test('should classify medium windows correctly (5-15%)', () {
        expect(WindowCategoryHelper.fromScreenPercentage(0.05), 
               equals(WindowCategory.medium));
        expect(WindowCategoryHelper.fromScreenPercentage(0.10), 
               equals(WindowCategory.medium));
        expect(WindowCategoryHelper.fromScreenPercentage(0.14), 
               equals(WindowCategory.medium));
      });

      test('should classify small windows correctly (<5%)', () {
        expect(WindowCategoryHelper.fromScreenPercentage(0.01), 
               equals(WindowCategory.small));
        expect(WindowCategoryHelper.fromScreenPercentage(0.04), 
               equals(WindowCategory.small));
        expect(WindowCategoryHelper.fromScreenPercentage(0.049), 
               equals(WindowCategory.small));
      });

      test('should handle boundary cases correctly', () {
        // Exactly at thresholds
        expect(WindowCategoryHelper.fromScreenPercentage(0.15), 
               equals(WindowCategory.large));
        expect(WindowCategoryHelper.fromScreenPercentage(0.05), 
               equals(WindowCategory.medium));
        
        // Just below thresholds
        expect(WindowCategoryHelper.fromScreenPercentage(0.149), 
               equals(WindowCategory.medium));
        expect(WindowCategoryHelper.fromScreenPercentage(0.049), 
               equals(WindowCategory.small));
      });
    });
  });
}