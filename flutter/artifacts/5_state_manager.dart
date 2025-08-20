// State Manager Draft Implementation
// Following TDD-Pure Development approach - this is the initial draft
// Tests should be written first before this implementation is finalized

import 'package:flutter/material.dart';
import '4_detection_service.dart';

/// Window Mode States for the state machine
enum WindowModeState {
  normal, // Traditional RustDesk mode
  detecting, // Auto window detection in progress
  selecting, // User selecting windows from carousel
  navigating // Window interaction mode
}

/// State Machine Manager for Window Detection Feature
/// Coordinates the three main phases without interfering with existing RustDesk functionality
class WindowModeManager extends ChangeNotifier {
  // Private state variables
  WindowModeState _currentState = WindowModeState.normal;
  List<DetectedWindow> _detectedWindows = [];
  List<DetectedWindow> _selectedWindows = [];
  int _currentWindowIndex = 0;
  Map<int, int> _windowCyclingMap = {}; // Window index -> cycles needed
  bool _isProcessing = false;
  String _errorMessage = '';

  // Dependency injection for testing
  WindowDetectionService? _detectionService;

  // Constructor with optional dependency injection for testing
  WindowModeManager({WindowDetectionService? detectionService})
      : _detectionService = detectionService;

  // Public getters
  WindowModeState get currentState => _currentState;
  List<DetectedWindow> get detectedWindows => _detectedWindows;
  List<DetectedWindow> get selectedWindows => _selectedWindows;
  int get currentWindowIndex => _currentWindowIndex;
  bool get isProcessing => _isProcessing;
  String get errorMessage => _errorMessage;

  /// Start the window detection process
  /// This is automatically triggered after RustDesk connection
  Future<void> startWindowDetection() async {
    try {
      _currentState = WindowModeState.detecting;
      _isProcessing = true;
      _errorMessage = '';
      notifyListeners();

      // Use injected service or create new one
      final detector = _detectionService ?? WindowDetectionService();
      _detectedWindows = await detector.detectAllWindowsWithCycling();

      if (_detectedWindows.isEmpty) {
        _showError('No windows detected. Try restarting detection.');
        return;
      }

      _currentState = WindowModeState.selecting;
      _isProcessing = false;
      notifyListeners();
    } catch (e) {
      _showError('Detection failed: ${e.toString()}');
    }
  }

  /// User has selected windows from carousel - transition to navigation mode
  void selectWindows(List<DetectedWindow> windows) {
    if (windows.isEmpty) {
      _showError('No windows selected. Please select at least one window.');
      return;
    }

    _selectedWindows = windows;
    _buildCyclingMap();
    _currentState = WindowModeState.navigating;
    _currentWindowIndex = 0;
    notifyListeners();
  }

  /// Navigate to a specific window by index
  /// Performs cycling to reach the target window
  Future<void> navigateToWindow(int index) async {
    if (_isProcessing || index >= _selectedWindows.length || index < 0) return;

    try {
      _isProcessing = true;
      notifyListeners();

      final cyclesNeeded = _windowCyclingMap[index] ?? 0;
      await _performWindowCycling(cyclesNeeded);

      _currentWindowIndex = index;
      _isProcessing = false;
      notifyListeners();
    } catch (e) {
      _showError('Navigation failed: ${e.toString()}');
    }
  }

  /// Restart the detection process
  /// Clears current state and begins fresh detection
  void restartDetection() {
    _detectedWindows.clear();
    _selectedWindows.clear();
    _windowCyclingMap.clear();
    _currentWindowIndex = 0;
    _errorMessage = '';
    startWindowDetection();
  }

  /// Exit window mode and return to normal RustDesk operation
  void exitWindowMode() {
    _currentState = WindowModeState.normal;
    _detectedWindows.clear();
    _selectedWindows.clear();
    _windowCyclingMap.clear();
    _currentWindowIndex = 0;
    _isProcessing = false;
    _errorMessage = '';
    notifyListeners();
  }

  /// Build cycling map that tracks how many cycles needed to reach each window
  void _buildCyclingMap() {
    // Simple index-based approach: each window has a cycle count
    for (int i = 0; i < _selectedWindows.length; i++) {
      _windowCyclingMap[i] = _selectedWindows[i].cyclePosition;
    }
  }

  /// Perform the actual window cycling using Alt+PageUp commands
  Future<void> _performWindowCycling(int cycles) async {
    // NOTE: This will need to be mocked in tests
    final inputModel = gFFI.inputModel;

    for (int i = 0; i < cycles; i++) {
      // Send Alt+PageUp using RustDesk's input system
      inputModel.inputKey('Alt', down: true);
      inputModel.inputKey('Page Up', down: true, press: true);
      inputModel.inputKey('Alt', down: false);

      // Critical delay for remote desktop response - researched value
      await Future.delayed(Duration(milliseconds: 2500));
    }
  }

  /// Show error and reset to normal state
  void _showError(String message) {
    _currentState = WindowModeState.normal;
    _errorMessage = message;
    _isProcessing = false;
    notifyListeners();
  }

  /// Get current state as string for debugging
  String get currentStateString {
    switch (_currentState) {
      case WindowModeState.normal:
        return 'normal';
      case WindowModeState.detecting:
        return 'detecting';
      case WindowModeState.selecting:
        return 'selecting';
      case WindowModeState.navigating:
        return 'navigating';
    }
  }

  /// Validate that we can navigate to a specific window
  bool canNavigateToWindow(int index) {
    return !_isProcessing &&
        index >= 0 &&
        index < _selectedWindows.length &&
        _currentState == WindowModeState.navigating;
  }

  /// Get the number of detected windows by category
  Map<WindowCategory, int> getWindowCountsByCategory() {
    final counts = <WindowCategory, int>{
      WindowCategory.large: 0,
      WindowCategory.medium: 0,
      WindowCategory.small: 0,
    };

    for (final window in _detectedWindows) {
      counts[window.category] = (counts[window.category] ?? 0) + 1;
    }

    return counts;
  }

  /// Check if detection is in progress
  bool get isDetecting => _currentState == WindowModeState.detecting;

  /// Check if user is selecting windows
  bool get isSelecting => _currentState == WindowModeState.selecting;

  /// Check if user is navigating between windows
  bool get isNavigating => _currentState == WindowModeState.navigating;

  /// Check if we're in normal RustDesk mode
  bool get isNormal => _currentState == WindowModeState.normal;

  /// Get the currently visible window
  DetectedWindow? get currentWindow {
    if (!isNavigating || _currentWindowIndex >= _selectedWindows.length) {
      return null;
    }
    return _selectedWindows[_currentWindowIndex];
  }

  /// Validation method for testing state consistency
  bool validateState() {
    // Check state consistency
    switch (_currentState) {
      case WindowModeState.normal:
        return _detectedWindows.isEmpty &&
            _selectedWindows.isEmpty &&
            !_isProcessing &&
            _currentWindowIndex == 0;

      case WindowModeState.detecting:
        return _isProcessing && _selectedWindows.isEmpty;

      case WindowModeState.selecting:
        return _detectedWindows.isNotEmpty && !_isProcessing;

      case WindowModeState.navigating:
        return _selectedWindows.isNotEmpty &&
            _currentWindowIndex >= 0 &&
            _currentWindowIndex < _selectedWindows.length;
    }
  }

  @override
  void dispose() {
    // Clean up any resources
    _detectedWindows.clear();
    _selectedWindows.clear();
    _windowCyclingMap.clear();
    super.dispose();
  }

  @override
  String toString() {
    return 'WindowModeManager('
        'state: $_currentState, '
        'detected: ${_detectedWindows.length}, '
        'selected: ${_selectedWindows.length}, '
        'processing: $_isProcessing'
        ')';
  }
}

// NOTE: This reference will need to be mocked/injected for testing
// This is a placeholder for the actual RustDesk global FFI instance
external dynamic gFFI;