import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../models/detected_window.dart';
import '../common.dart';

/// Window Detection Service implementing Sobel edge detection
/// Core algorithm for detecting windows on remote desktop
class WindowDetectionService {
  // Researched constants from specification
  static const int EDGE_THRESHOLD = 175; // Researched optimal value
  static const double LARGE_WINDOW_THRESHOLD = 0.15; // 15%+ screen area
  static const double MEDIUM_WINDOW_THRESHOLD = 0.05; // 5-15% screen area
  static const int MAX_CYCLING_ATTEMPTS = 15;
  static const int CYCLING_TIMEOUT_SECONDS = 180;

  // Dependency injection for testing
  final Function()? _mockInputTrigger;
  final Function()? _mockImageCapture;

  WindowDetectionService({
    Function()? mockInputTrigger,
    Function()? mockImageCapture,
  }) : _mockInputTrigger = mockInputTrigger,
       _mockImageCapture = mockImageCapture;

  /// Main detection method with comprehensive error handling
  Future<List<DetectedWindow>> detectAllWindowsWithCycling() async {
    try {
      final future = _performDetectionCycles();
      return await future.timeout(const Duration(seconds: CYCLING_TIMEOUT_SECONDS));
    } catch (e) {
      throw WindowDetectionException('Detection failed: $e');
    }
  }

  /// Perform the actual detection cycles
  Future<List<DetectedWindow>> _performDetectionCycles() async {
    final List<DetectedWindow> allWindows = [];
    final Set<String> seenRegions = {};

    for (int cycle = 0; cycle < MAX_CYCLING_ATTEMPTS; cycle++) {
      final imageData = await _captureScreen();
      if (imageData == null) continue;

      final currentWindows = await _detectWindowsInFrame(
        imageData.rgbaData,
        imageData.width,
        imageData.height,
        cycle,
      );

      // Add unique windows
      for (final window in currentWindows) {
        final regionKey = _generateRegionKey(window.bounds);
        if (!seenRegions.contains(regionKey)) {
          seenRegions.add(regionKey);
          allWindows.add(window);
        }
      }

      // Cycle to next window if not last iteration
      if (cycle < MAX_CYCLING_ATTEMPTS - 1) {
        await _performWindowCycle();
        await Future.delayed(const Duration(milliseconds: 2500));
      }
    }

    return _filterAndSortWindows(allWindows);
  }

  /// Capture screen data (mockable for testing)
  Future<ScreenData?> _captureScreen() async {
    if (_mockImageCapture != null) {
      _mockImageCapture!();
      return null; // Mock implementations handle this differently
    }

    try {
      final imageModel = gFFI.imageModel;
      if (imageModel.image == null) return null;

      final rgbaData = await _extractRgbaFromImage(imageModel.image!);
      return ScreenData(
        rgbaData: rgbaData,
        width: imageModel.image!.width,
        height: imageModel.image!.height,
      );
    } catch (e) {
      return null;
    }
  }

  /// Perform window cycling (mockable for testing)
  Future<void> _performWindowCycle() async {
    if (_mockInputTrigger != null) {
      _mockInputTrigger!();
      return;
    }

    final inputModel = gFFI.inputModel;
    inputModel.inputKey('Alt', down: true);
    inputModel.inputKey('Page Up', down: true, press: true);
    inputModel.inputKey('Alt', down: false);
  }

  /// Generate unique key for region deduplication
  String _generateRegionKey(Rect bounds) {
    return '${bounds.left.toInt()}_${bounds.top.toInt()}_${bounds.width.toInt()}_${bounds.height.toInt()}';
  }

  /// Detect windows in single frame - core algorithm
  Future<List<DetectedWindow>> _detectWindowsInFrame(
    Uint8List rgbaData,
    int width,
    int height,
    int cyclePosition,
  ) async {
    try {
      final image = img.decodeImage(rgbaData);
      if (image == null) return [];

      // Apply Sobel edge detection with researched threshold
      final edges = img.sobel(image);
      final thresholded = _applyThreshold(edges, EDGE_THRESHOLD);

      // Find rectangular regions
      final regions = await _findRectangularRegions(thresholded, width, height);

      // Convert to DetectedWindow objects
      return regions
          .map((region) => DetectedWindow(
                bounds: region,
                cyclePosition: cyclePosition,
                thumbnail: _extractThumbnail(image, region),
                category: _categorizeBySize(region, width, height),
              ))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Apply threshold to edge-detected image
  img.Image _applyThreshold(img.Image edges, int threshold) {
    final thresholded = img.Image.from(edges);

    for (int y = 0; y < thresholded.height; y++) {
      for (int x = 0; x < thresholded.width; x++) {
        final pixel = thresholded.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        final newValue = luminance > threshold ? 255 : 0;
        thresholded.setPixel(
            x, y, img.ColorRgba8(newValue, newValue, newValue, 255));
      }
    }

    return thresholded;
  }

  /// Find rectangular regions in edge-detected image
  Future<List<Rect>> _findRectangularRegions(
      img.Image edges, int width, int height) async {
    final List<Rect> regions = [];
    final visited = List.generate(height, (_) => List.filled(width, false));

    for (int y = 0; y < height - 10; y += 5) {
      for (int x = 0; x < width - 10; x += 5) {
        if (visited[y][x]) continue;

        final region = _traceRectangle(edges, x, y, width, height, visited);
        if (_isValidRegion(region, width, height)) {
          regions.add(region!);
        }
      }
    }

    return regions;
  }

  /// Validate if region meets size requirements
  bool _isValidRegion(Rect? region, int screenWidth, int screenHeight) {
    if (region == null) return false;
    return region.width > 50 &&
        region.height > 50 &&
        region.width < screenWidth * 0.9 &&
        region.height < screenHeight * 0.9;
  }

  /// Trace rectangle boundaries from edge pixels
  Rect? _traceRectangle(img.Image edges, int startX, int startY, int maxWidth,
      int maxHeight, List<List<bool>> visited) {
    int minX = startX, maxX = startX;
    int minY = startY, maxY = startY;

    for (int dy = 0; dy < 200 && startY + dy < maxHeight; dy++) {
      for (int dx = 0; dx < 200 && startX + dx < maxWidth; dx++) {
        final pixel = edges.getPixel(startX + dx, startY + dy);
        if (img.getLuminance(pixel) > 128) {
          maxX = math.max(maxX, startX + dx);
          maxY = math.max(maxY, startY + dy);
          visited[startY + dy][startX + dx] = true;
        }
      }
    }

    final width = maxX - minX;
    final height = maxY - minY;

    return width > 50 && height > 50
        ? Rect.fromLTWH(
            minX.toDouble(), minY.toDouble(), width.toDouble(), height.toDouble())
        : null;
  }

  /// Categorize window by size using researched thresholds
  WindowCategory _categorizeBySize(Rect region, int screenWidth, int screenHeight) {
    final regionArea = region.width * region.height;
    final screenArea = screenWidth * screenHeight;
    final percentage = regionArea / screenArea;

    if (percentage >= LARGE_WINDOW_THRESHOLD) {
      return WindowCategory.large;
    } else if (percentage >= MEDIUM_WINDOW_THRESHOLD) {
      return WindowCategory.medium;
    } else {
      return WindowCategory.small;
    }
  }

  /// Filter and sort windows by priority
  List<DetectedWindow> _filterAndSortWindows(List<DetectedWindow> windows) {
    return windows
        .where((w) => w.category != WindowCategory.small)
        .toList()
      ..sort((a, b) {
        if (a.category != b.category) {
          return a.category == WindowCategory.large ? -1 : 1;
        }
        final aArea = a.bounds.width * a.bounds.height;
        final bArea = b.bounds.width * b.bounds.height;
        return bArea.compareTo(aArea);
      });
  }

  /// Extract thumbnail for carousel display
  Uint8List _extractThumbnail(img.Image source, Rect region) {
    final cropped = img.copyCrop(source,
        x: region.left.toInt(),
        y: region.top.toInt(),
        width: region.width.toInt(),
        height: region.height.toInt());

    final thumbnail = img.copyResize(cropped, width: 200, height: 150);
    return Uint8List.fromList(img.encodePng(thumbnail));
  }

  /// Extract RGBA data from Flutter UI Image
  Future<Uint8List> _extractRgbaFromImage(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }
}

/// Screen data container for testing
class ScreenData {
  final Uint8List rgbaData;
  final int width;
  final int height;

  ScreenData({
    required this.rgbaData,
    required this.width,
    required this.height,
  });
}

/// Custom exception for window detection errors
class WindowDetectionException implements Exception {
  final String message;
  WindowDetectionException(this.message);

  @override
  String toString() => 'WindowDetectionException: $message';
}