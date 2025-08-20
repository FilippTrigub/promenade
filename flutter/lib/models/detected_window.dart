import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Window size categories based on screen percentage
enum WindowCategory {
  large,   // 15%+ of screen - likely windows
  medium,  // 5-15% of screen - possible windows  
  small    // <5% of screen - filtered out
}

/// Data model for detected window with comprehensive validation
class DetectedWindow {
  final Rect bounds;
  final int cyclePosition; // Which cycle detected this window
  final Uint8List thumbnail;
  final WindowCategory category;

  DetectedWindow({
    required this.bounds,
    required this.cyclePosition,
    required this.thumbnail,
    required this.category,
  }) : assert(bounds.width > 0 && bounds.height > 0, 'Window bounds must be positive'),
       assert(cyclePosition >= 0, 'Cycle position must be non-negative'),
       assert(thumbnail.isNotEmpty, 'Thumbnail data cannot be empty');

  /// Calculate what percentage of screen this window covers
  double getScreenPercentage(int screenWidth, int screenHeight) {
    assert(screenWidth > 0 && screenHeight > 0, 'Screen dimensions must be positive');
    
    final regionArea = bounds.width * bounds.height;
    final screenArea = screenWidth * screenHeight;
    return regionArea / screenArea;
  }

  /// Check if window is within screen bounds
  bool isWithinScreen(int screenWidth, int screenHeight) {
    return bounds.left >= 0 &&
           bounds.top >= 0 &&
           bounds.right <= screenWidth &&
           bounds.bottom <= screenHeight;
  }

  /// Get window area in pixels
  double get area => bounds.width * bounds.height;

  /// Get window aspect ratio
  double get aspectRatio => bounds.width / bounds.height;

  /// Create copy with different category
  DetectedWindow copyWith({
    Rect? bounds,
    int? cyclePosition,
    Uint8List? thumbnail,
    WindowCategory? category,
  }) {
    return DetectedWindow(
      bounds: bounds ?? this.bounds,
      cyclePosition: cyclePosition ?? this.cyclePosition,
      thumbnail: thumbnail ?? this.thumbnail,
      category: category ?? this.category,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetectedWindow &&
          runtimeType == other.runtimeType &&
          bounds == other.bounds &&
          cyclePosition == other.cyclePosition &&
          category == other.category;

  @override
  int get hashCode =>
      bounds.hashCode ^ cyclePosition.hashCode ^ category.hashCode;

  @override
  String toString() =>
      'DetectedWindow(bounds: $bounds, cycle: $cyclePosition, category: $category, area: ${area.toInt()})';
}

/// Helper class for window category operations
class WindowCategoryHelper {
  /// Get display name for category
  static String getDisplayName(WindowCategory category) {
    switch (category) {
      case WindowCategory.large:
        return 'Likely Window';
      case WindowCategory.medium:
        return 'Possible Window';
      case WindowCategory.small:
        return 'Small Region';
    }
  }

  /// Get category color for UI
  static Color getColor(WindowCategory category) {
    switch (category) {
      case WindowCategory.large:
        return Colors.blue;
      case WindowCategory.medium:
        return Colors.orange;
      case WindowCategory.small:
        return Colors.grey;
    }
  }

  /// Get category priority for sorting (higher = more important)
  static int getPriority(WindowCategory category) {
    switch (category) {
      case WindowCategory.large:
        return 3;
      case WindowCategory.medium:
        return 2;
      case WindowCategory.small:
        return 1;
    }
  }

  /// Determine category from screen percentage
  static WindowCategory fromScreenPercentage(double percentage) {
    if (percentage >= 0.15) {
      return WindowCategory.large;
    } else if (percentage >= 0.05) {
      return WindowCategory.medium;
    } else {
      return WindowCategory.small;
    }
  }
}