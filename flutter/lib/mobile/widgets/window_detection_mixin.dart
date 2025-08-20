import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/window_mode_manager.dart';
import '../../models/detected_window.dart';
import '../../common/widgets/window_selection_carousel.dart';
import '../../common/widgets/window_navigation_view.dart';
import '../../common.dart';

/// Window Detection Mixin for RustDesk RemotePage
/// Provides window detection functionality without modifying core RustDesk code
mixin WindowDetectionMixin<T extends StatefulWidget> on State<T> {
  WindowModeManager? _windowModeManager;
  bool _windowDetectionInitialized = false;
  
  /// Initialize window detection after connection is established
  void initWindowDetection() {
    if (_windowDetectionInitialized) return;
    
    _windowModeManager = WindowModeManager();
    _windowDetectionInitialized = true;
    
    // Start detection automatically after first image is received
    gFFI.imageModel.addCallbackOnFirstImage((String peerId) {
      _startWindowDetectionDelayed();
    });
  }
  
  /// Start window detection with delay to ensure stable connection
  void _startWindowDetectionDelayed() {
    Timer(const Duration(seconds: 3), () {
      if (mounted && _windowModeManager != null) {
        _windowModeManager!.startWindowDetection();
      }
    });
  }
  
  /// Get window detection overlay widget for integration into existing UI
  Widget buildWindowDetectionOverlay() {
    if (_windowModeManager == null) return const SizedBox.shrink();
    
    return ChangeNotifierProvider<WindowModeManager>.value(
      value: _windowModeManager!,
      child: Consumer<WindowModeManager>(
        builder: (context, windowManager, child) {
          // Show window selection carousel
          if (windowManager.isSelecting) {
            return WindowSelectionCarousel(
              detectedWindows: windowManager.detectedWindows,
              onWindowsSelected: (selectedWindows) {
                windowManager.selectWindows(selectedWindows);
              },
              onCancel: () {
                windowManager.exitWindowMode();
              },
            );
          }
          
          // Show window navigation interface
          if (windowManager.isNavigating) {
            return WindowNavigationView(
              selectedWindows: windowManager.selectedWindows,
              currentWindowIndex: windowManager.currentWindowIndex,
              isProcessing: windowManager.isProcessing,
              onWindowSwipe: (index) {
                windowManager.navigateToWindow(index);
              },
              onExitWindowMode: () {
                windowManager.exitWindowMode();
              },
              onRestartDetection: () {
                windowManager.restartDetection();
              },
            );
          }
          
          // Show error state with retry option
          if (windowManager.errorMessage.isNotEmpty) {
            return _buildErrorOverlay(
              windowManager.errorMessage,
              () => windowManager.restartDetection(),
            );
          }
          
          // Show detection progress
          if (windowManager.isDetecting) {
            return _buildDetectionProgressOverlay();
          }
          
          return const SizedBox.shrink();
        },
      ),
    );
  }
  
  /// Build error overlay with retry functionality
  Widget _buildErrorOverlay(String errorMessage, VoidCallback onRetry) {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 20),
            const Text(
              'Window Detection Error',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 10),
            Text(
              errorMessage,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
                const SizedBox(width: 20),
                TextButton(
                  onPressed: () => _windowModeManager?.exitWindowMode(),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  /// Build detection progress overlay
  Widget _buildDetectionProgressOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            const Text(
              'Detecting Windows...',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 10),
            const Text(
              'This process cycles through windows\nto detect interface elements.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            TextButton(
              onPressed: () => _windowModeManager?.exitWindowMode(),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Check if window detection overlay should be shown
  bool get shouldShowWindowOverlay {
    return _windowModeManager != null && !_windowModeManager!.isNormal;
  }
  
  /// Manual trigger for window detection (for testing/debugging)
  void manualStartWindowDetection() {
    if (_windowModeManager != null) {
      _windowModeManager!.restartDetection();
    }
  }
  
  /// Get current window mode state for UI decisions
  WindowModeState? get currentWindowMode {
    return _windowModeManager?.currentState;
  }
  
  /// Cleanup window detection resources
  void disposeWindowDetection() {
    _windowModeManager?.dispose();
    _windowModeManager = null;
    _windowDetectionInitialized = false;
  }
  
  /// Check if we're currently in window navigation mode
  bool get isInWindowMode {
    return _windowModeManager?.isNavigating ?? false;
  }
  
  /// Get selected windows for external access
  List<DetectedWindow> get selectedWindows {
    return _windowModeManager?.selectedWindows ?? [];
  }
}