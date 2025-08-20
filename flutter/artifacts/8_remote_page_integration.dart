// RemotePage Integration Draft Implementation
// Following TDD-Pure Development approach - this is the initial draft
// Tests should be written first before this implementation is finalized

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '4_detection_service.dart';
import '5_state_manager.dart';
import '6_carousel_interface.dart';
import '7_navigation_system.dart';

/// Extensions to existing RemotePage to add window detection functionality
/// IMPORTANT: This extends existing functionality without rewriting core code
mixin WindowModeIntegration {
  /// Window mode manager instance
  WindowModeManager? _windowModeManager;

  /// Whether to show window mode UI overlays
  bool get showWindowModeUI =>
      _windowModeManager?.currentState != WindowModeState.normal;

  /// Initialize window mode functionality
  /// Should be called in initState() of RemotePage
  void initializeWindowMode() {
    _windowModeManager = WindowModeManager();
    _windowModeManager!.addListener(_onWindowModeStateChanged);

    // Auto-trigger detection after connection is established
    Timer(const Duration(seconds: 2), () {
      if (_shouldTriggerAutoDetection()) {
        _windowModeManager!.startWindowDetection();
      }
    });
  }

  /// Handle window mode state changes
  /// Should trigger setState() in the parent widget
  void _onWindowModeStateChanged() {
    // This will need to be implemented by the mixing class
    onWindowModeStateChanged();
  }

  /// Override this method in the mixing class to trigger UI updates
  void onWindowModeStateChanged();

  /// Check if auto-detection should be triggered
  bool _shouldTriggerAutoDetection() {
    // NOTE: In real implementation, this would check RustDesk connection state
    // This is a placeholder that demonstrates the concept
    try {
      return gFFI.ffiModel.pi.isConnected();
    } catch (e) {
      // Fallback for testing/draft implementation
      return false;
    }
  }

  /// Build window mode overlay based on current state
  Widget buildWindowModeOverlay(BuildContext context) {
    if (_windowModeManager == null) return const SizedBox.shrink();

    return ChangeNotifierProvider.value(
      value: _windowModeManager!,
      child: Consumer<WindowModeManager>(
        builder: (context, manager, child) {
          switch (manager.currentState) {
            case WindowModeState.detecting:
              return _buildDetectionOverlay(context, manager);
            case WindowModeState.selecting:
              return _buildSelectionOverlay(context, manager);
            case WindowModeState.navigating:
              return _buildNavigationOverlay(context, manager);
            case WindowModeState.normal:
              return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  /// Build detection phase overlay
  Widget _buildDetectionOverlay(BuildContext context, WindowModeManager manager) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            const Text(
              'Detecting windows...\nThis can take up to 3 minutes',
              style: TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => manager.exitWindowMode(),
              child: const Text('Cancel'),
            ),
            const SizedBox(height: 10),
            Text(
              'Detected ${manager.detectedWindows.length} windows so far...',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }

  /// Build selection phase overlay
  Widget _buildSelectionOverlay(BuildContext context, WindowModeManager manager) {
    return WindowSelectionCarousel(
      detectedWindows: manager.detectedWindows,
      onWindowsSelected: (windows) => manager.selectWindows(windows),
      onCancel: () => manager.exitWindowMode(),
    );
  }

  /// Build navigation phase overlay
  Widget _buildNavigationOverlay(BuildContext context, WindowModeManager manager) {
    return WindowNavigationView(
      selectedWindows: manager.selectedWindows,
      currentWindowIndex: manager.currentWindowIndex,
      isProcessing: manager.isProcessing,
      onWindowSwipe: (index) => manager.navigateToWindow(index),
      onExitWindowMode: () => manager.exitWindowMode(),
      onRestartDetection: () => manager.restartDetection(),
    );
  }

  /// Build error overlay if there's an error message
  Widget buildErrorOverlay(BuildContext context) {
    if (_windowModeManager?.errorMessage.isEmpty ?? true) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 64),
            const SizedBox(height: 20),
            const Text(
              'Window Detection Error',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _windowModeManager!.errorMessage,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => _windowModeManager!.restartDetection(),
                  child: const Text('Restart Detection'),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () => _windowModeManager!.exitWindowMode(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Dispose window mode resources
  /// Should be called in dispose() of RemotePage
  void disposeWindowMode() {
    _windowModeManager?.dispose();
    _windowModeManager = null;
  }

  /// Get current window mode state for testing
  WindowModeState? get currentWindowModeState => _windowModeManager?.currentState;

  /// Get detected windows count for testing
  int get detectedWindowsCount => _windowModeManager?.detectedWindows.length ?? 0;

  /// Get selected windows count for testing
  int get selectedWindowsCount => _windowModeManager?.selectedWindows.length ?? 0;

  /// Manually trigger detection for testing
  void triggerDetection() {
    _windowModeManager?.startWindowDetection();
  }

  /// Check if window mode is processing
  bool get isWindowModeProcessing => _windowModeManager?.isProcessing ?? false;

  /// Get error message for testing
  String get windowModeErrorMessage => _windowModeManager?.errorMessage ?? '';
}

/// Example implementation showing how to integrate with existing RemotePage
/// This demonstrates the pattern without modifying the actual RustDesk code
class ExampleRemotePageWithWindowMode extends StatefulWidget {
  const ExampleRemotePageWithWindowMode({Key? key}) : super(key: key);

  @override
  State<ExampleRemotePageWithWindowMode> createState() =>
      _ExampleRemotePageWithWindowModeState();
}

class _ExampleRemotePageWithWindowModeState 
    extends State<ExampleRemotePageWithWindowMode> 
    with WindowModeIntegration {

  @override
  void initState() {
    super.initState();
    // Initialize window mode functionality
    initializeWindowMode();
  }

  @override
  void dispose() {
    // Clean up window mode resources
    disposeWindowMode();
    super.dispose();
  }

  @override
  void onWindowModeStateChanged() {
    // Trigger UI rebuild when window mode state changes
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Existing RemotePage content would go here
          _buildExistingContent(),
          
          // Window mode overlays
          if (showWindowModeUI) buildWindowModeOverlay(context),
          
          // Error overlay
          buildErrorOverlay(context),
        ],
      ),
    );
  }

  Widget _buildExistingContent() {
    // This represents the existing RustDesk remote page content
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Text(
          'RustDesk Remote Desktop Content\n(This would be the existing UI)',
          style: TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Integration helper for manual testing
class WindowModeIntegrationHelper {
  /// Create a test scenario with mock windows
  static List<DetectedWindow> createMockWindows() {
    return [
      DetectedWindow(
        bounds: const Rect.fromLTWH(100, 100, 800, 600),
        cyclePosition: 0,
        thumbnail: _createMockThumbnail(),
        category: WindowCategory.large,
      ),
      DetectedWindow(
        bounds: const Rect.fromLTWH(200, 200, 400, 300),
        cyclePosition: 1,
        thumbnail: _createMockThumbnail(),
        category: WindowCategory.medium,
      ),
      DetectedWindow(
        bounds: const Rect.fromLTWH(300, 300, 600, 400),
        cyclePosition: 2,
        thumbnail: _createMockThumbnail(),
        category: WindowCategory.large,
      ),
    ];
  }

  static Uint8List _createMockThumbnail() {
    // Create a simple mock thumbnail (1x1 pixel PNG)
    return Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
      0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0x0F, 0x00, 0x00,
      0x01, 0x00, 0x01, 0x46, 0x6E, 0x3B, 0x65, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
    ]);
  }

  /// Test connection state helper
  static bool mockIsConnected = false;

  /// Set mock connection state for testing
  static void setMockConnectionState(bool connected) {
    mockIsConnected = connected;
  }
}

/// Mock FFI implementation for testing
class MockFFI {
  MockInputModel inputModel = MockInputModel();
  MockFfiModel ffiModel = MockFfiModel();
  MockPlatformInfo pi = MockPlatformInfo();

  void invokeMethod(String method) {
    // Mock implementation for clipboard sync
    print('MockFFI: invokeMethod($method)');
  }
}

class MockInputModel {
  List<Map<String, dynamic>> keyEvents = [];

  void inputKey(String key, {bool? down, bool? press}) {
    keyEvents.add({
      'key': key,
      'down': down,
      'press': press,
    });
    print('MockInputModel: inputKey($key, down: $down, press: $press)');
  }

  void clearEvents() {
    keyEvents.clear();
  }
}

class MockFfiModel {
  MockPlatformInfo pi = MockPlatformInfo();
}

class MockPlatformInfo {
  bool isConnected() {
    return WindowModeIntegrationHelper.mockIsConnected;
  }
}

// NOTE: These references will need to be mocked/injected for testing
// In real implementation, this would be the actual RustDesk global FFI instance
external dynamic gFFI;