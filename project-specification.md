# Simplified RustDesk Mobile App - Project Specification

## Project Overview

A simplified mobile application based on RustDesk's remote desktop functionality, focused on delivering an exceptional user experience for window-specific remote interactions. Transform the traditional remote desktop experience into a window-centric, mobile-optimized interface.

## Core Concept

Users connect to a remote machine, identify specific windows through visual analysis, and interact with those windows as if they were native mobile screens with swipe navigation between them.

## Key Features

### 1. Streamlined Connection Flow
- **Instant Launch**: App opens directly to connection interface
- **Quick Connect**: Minimal steps to establish remote connection
- **Connection Persistence**: Remember and quickly reconnect to recent machines

### 2. Window Selection Interface
- **Post-Connection Window Picker**: After connecting, present visual identification of windows
- **Window Thumbnails**: Show live previews of detected window regions
- **Multi-Select Support**: Allow users to select multiple windows they want to interact with
- **False Positive Handling**: User can manually select/deselect detected regions

### 3. Mobile-Optimized Window Interaction
- **Fitted Display**: Selected windows automatically scale and fit to mobile screen dimensions
- **Swipe Navigation**: Horizontal swipes to switch between selected windows
- **Window Carousel**: Smooth transitions between windows with visual indicators
- **Full-Screen Mode**: Each window fills the mobile screen optimally

### 4. Enhanced Text Operations
- **Smart Text Selection**: Improved text selection tools optimized for touch
- **Cross-Platform Clipboard**: Seamless copy/paste between mobile device and remote machine
- **Quick Actions**: Common text operations (copy, paste, select all) easily accessible

### 5. Touch-Optimized Controls
- **Gesture Support**: Pinch to zoom, two-finger scroll, tap to click
- **Virtual Keyboard Integration**: Seamless keyboard input to remote applications
- **Context Menus**: Long-press for right-click functionality

## Technical Architecture

### Backend Integration
- **RustDesk Core**: Leverage existing RustDesk connection and communication protocols
- **Protocol Compatibility**: Maintain compatibility with RustDesk servers and peers
- **Security**: Inherit RustDesk's security model and encryption

### Mobile App Structure
- **Flutter Framework**: Build on existing Flutter mobile implementation
- **Native Performance**: Optimize rendering and input handling for mobile devices
- **Cross-Platform**: Support both iOS and Android

## Window Identification Implementation

### Current RustDesk Capabilities
Based on codebase analysis, RustDesk provides:

1. **Image Processing Infrastructure**
   - **ImageModel class** (`flutter/lib/models/model.dart:1499`): Handles RGBA frame data
   - **Image Processing Library**: Uses `image: ^4.0.17` package for manipulation
   - **Real-time Frame Streaming**: `onRgba(int display, Uint8List rgba)` receives desktop frames
   - **RGBA Pixel Data**: Direct access to raw pixel data as `Uint8List`

2. **Existing Capabilities**
   - **Clipboard Integration**: `try_sync_clipboard` method already implemented
   - **Gesture System**: Comprehensive multi-finger gesture support in `CustomTouchGestureRecognizer`
   - **Touch Input**: Full touch-to-remote input translation

### Window Detection Strategy - Simplified Approach

**Core Method: Canny Edge Detection**
- **Primary Algorithm**: Canny edge detection - most robust and widely used for rectangular region identification
- **Rationale**: Proven accuracy for window border detection, handles noise well, works across different desktop themes
- **Implementation**: Use Flutter's `image` package with Sobel fallback if Canny unavailable

**Size-Based Window Filtering Strategy**
1. **Large Windows (Likely Candidates)**: 
   - Regions covering 15%+ of total screen area
   - Most likely to be actual application windows users want to interact with
   - Presented as primary selection options
   
2. **Medium Windows (Secondary Candidates)**:
   - Regions covering 5-15% of screen area
   - Could be dialog boxes, tool panels, or smaller applications
   - Available via "Show More Windows" submenu
   
3. **Small Regions (Filtered Out)**:
   - Regions <5% of screen area
   - Likely UI elements, buttons, or noise
   - Not presented to avoid clutter

**Window Overlap Handling - Research Findings**
- **Problem**: Overlapping windows hide content behind them, limiting detection to visible windows only
- **Solution**: Automated window cycling to reveal all available windows during detection phase
- **Keyboard Method**: Use Alt+PageUp/Alt+PageDown combinations (more reliable than Alt+Tab in remote desktop)
  - Alt+PageUp: Cycle forward through applications
  - Alt+PageDown: Cycle backward through applications  
  - Alternative: Alt+Insert for one-at-a-time cycling
- **Implementation**: Send keyboard commands through RustDesk's input system
- **Process**: 
  1. Initial screenshot and detection
  2. Send Alt+PageUp to switch to next window
  3. Capture new screenshot and run detection
  4. Repeat for 10-15 cycles to cover most applications
  5. Aggregate all detected regions, removing duplicates
  6. Present combined results to user

**User Selection Flow**
1. **Automatic Detection**: System detects rectangles via Canny edge detection
2. **Size Filtering**: Categorize by screen area percentage
3. **Primary Presentation**: Show large windows (15%+ of screen) as main candidates
4. **User Selection**: User selects desired windows from primary candidates
5. **Secondary Access**: "More Windows" option reveals medium-sized candidates (5-15%)
6. **Manual Fallback**: Allow manual region drawing if needed

**Simplified Advantages**
- **Single Algorithm**: Reduces complexity and processing overhead
- **Size-Based Intelligence**: Automatically prioritizes relevant windows
- **User-Friendly**: Clear distinction between likely and unlikely candidates
- **Performance**: Faster processing with single detection method

## Execution-Ready Implementation Plan

### Core Architecture & Guiding Principles

**Primary Principle**: Avoid rewriting RustDesk code. Build new functionality on top of existing RustDesk code to ensure easy merging of future updates.

**Architecture Pattern**: State machine to coordinate three phases:
1. **Detection Phase**: Auto-triggered window cycling and detection
2. **Selection Phase**: Carousel-based window selection
3. **Navigation Phase**: Window interaction with cycling coordination

**What to Ignore for MVP**:
- Complex error recovery mechanisms
- Performance optimizations beyond basic functionality  
- Platform-specific implementations
- Automatic re-detection triggers
- Advanced testing beyond unit tests
- Analytics and feedback collection
- Deployment considerations

### Implementation Structure

#### 1. State Management - WindowModeManager

**Purpose**: Coordinate the three main phases without interfering with existing RustDesk functionality.

```dart
// New file: flutter/lib/models/window_mode_manager.dart
enum WindowModeState {
  normal,        // Traditional RustDesk mode
  detecting,     // Auto window detection in progress
  selecting,     // User selecting windows from carousel
  navigating     // Window interaction mode
}

class WindowModeManager extends ChangeNotifier {
  WindowModeState _currentState = WindowModeState.normal;
  List<DetectedWindow> _detectedWindows = [];
  List<DetectedWindow> _selectedWindows = [];
  int _currentWindowIndex = 0;
  Map<int, int> _windowCyclingMap = {}; // Window index -> cycles needed
  bool _isProcessing = false;
  String _errorMessage = '';
  
  // Getters
  WindowModeState get currentState => _currentState;
  List<DetectedWindow> get detectedWindows => _detectedWindows;
  List<DetectedWindow> get selectedWindows => _selectedWindows;
  int get currentWindowIndex => _currentWindowIndex;
  bool get isProcessing => _isProcessing;
  String get errorMessage => _errorMessage;
  
  // State transitions
  Future<void> startWindowDetection() async {
    try {
      _currentState = WindowModeState.detecting;
      _isProcessing = true;
      _errorMessage = '';
      notifyListeners();
      
      final detector = WindowDetectionService();
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
  
  void selectWindows(List<DetectedWindow> windows) {
    _selectedWindows = windows;
    _buildCyclingMap();
    _currentState = WindowModeState.navigating;
    _currentWindowIndex = 0;
    notifyListeners();
  }
  
  Future<void> navigateToWindow(int index) async {
    if (_isProcessing || index >= _selectedWindows.length) return;
    
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
  
  void restartDetection() {
    _detectedWindows.clear();
    _selectedWindows.clear();
    _windowCyclingMap.clear();
    _currentWindowIndex = 0;
    _errorMessage = '';
    startWindowDetection();
  }
  
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
  
  void _buildCyclingMap() {
    // Simple index-based approach: each window has a cycle count
    for (int i = 0; i < _selectedWindows.length; i++) {
      _windowCyclingMap[i] = _selectedWindows[i].cyclePosition;
    }
  }
  
  Future<void> _performWindowCycling(int cycles) async {
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
  
  void _showError(String message) {
    _currentState = WindowModeState.normal;
    _errorMessage = message;
    _isProcessing = false;
    notifyListeners();
  }
}
```

#### 2. Window Detection Service - Core Algorithm

**Purpose**: Implement Sobel edge detection with researched threshold value and size-based filtering.

```dart
// New file: flutter/lib/services/window_detection_service.dart
import 'package:image/image.dart' as img;

class WindowDetectionService {
  static const int EDGE_THRESHOLD = 175; // Researched optimal value
  static const double LARGE_WINDOW_THRESHOLD = 0.15; // 15%+ screen area
  static const double MEDIUM_WINDOW_THRESHOLD = 0.05; // 5-15% screen area
  static const int MAX_CYCLING_ATTEMPTS = 15;
  static const int CYCLING_TIMEOUT_SECONDS = 180;
  
  Future<List<DetectedWindow>> detectAllWindowsWithCycling() async {
    final List<DetectedWindow> allWindows = [];
    final Set<String> seenRegions = {};
    
    try {
      // Timeout protection for entire detection process
      return await Future.timeout(
        Duration(seconds: CYCLING_TIMEOUT_SECONDS),
        () async {
          for (int cycle = 0; cycle < MAX_CYCLING_ATTEMPTS; cycle++) {
            // Capture current screen from ImageModel
            final imageModel = gFFI.imageModel;
            if (imageModel.image == null) continue;
            
            final rgbaData = await _extractRgbaFromImage(imageModel.image!);
            final screenWidth = imageModel.image!.width;
            final screenHeight = imageModel.image!.height;
            
            // Detect windows in current state
            final currentWindows = await _detectWindowsInFrame(
              rgbaData, screenWidth, screenHeight, cycle
            );
            
            // Add unique windows to collection
            for (final window in currentWindows) {
              final regionKey = '${window.bounds.left}_${window.bounds.top}_${window.bounds.width}_${window.bounds.height}';
              if (!seenRegions.contains(regionKey)) {
                seenRegions.add(regionKey);
                allWindows.add(window);
              }
            }
            
            // Cycle to next window if not last iteration
            if (cycle < MAX_CYCLING_ATTEMPTS - 1) {
              await _sendAltPageUp();
              await Future.delayed(Duration(milliseconds: 2500));
            }
          }
          
          return _filterAndSortWindows(allWindows);
        },
      );
    } catch (e) {
      throw Exception('Detection timeout or error: $e');
    }
  }
  
  Future<List<DetectedWindow>> _detectWindowsInFrame(
    Uint8List rgbaData, 
    int width, 
    int height,
    int cyclePosition
  ) async {
    try {
      // Convert RGBA to Image format
      final image = img.decodeImage(rgbaData);
      if (image == null) return [];
      
      // Apply Sobel edge detection with researched threshold
      final edges = img.sobel(image);
      final thresholded = _applyThreshold(edges, EDGE_THRESHOLD);
      
      // Find rectangular regions
      final regions = await _findRectangularRegions(thresholded, width, height);
      
      // Convert to DetectedWindow objects
      return regions.map((region) => DetectedWindow(
        bounds: region,
        cyclePosition: cyclePosition,
        thumbnail: _extractThumbnail(image, region),
        category: _categorizeBySize(region, width, height),
      )).toList();
      
    } catch (e) {
      print('Detection error in frame: $e');
      return [];
    }
  }
  
  img.Image _applyThreshold(img.Image edges, int threshold) {
    final thresholded = img.Image.from(edges);
    
    for (int y = 0; y < thresholded.height; y++) {
      for (int x = 0; x < thresholded.width; x++) {
        final pixel = thresholded.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        
        // Apply threshold - researched value of 175
        final newValue = luminance > threshold ? 255 : 0;
        thresholded.setPixel(x, y, img.ColorRgba8(newValue, newValue, newValue, 255));
      }
    }
    
    return thresholded;
  }
  
  Future<List<Rect>> _findRectangularRegions(img.Image edges, int width, int height) async {
    final List<Rect> regions = [];
    final visited = List.generate(height, (_) => List.filled(width, false));
    
    // Simple rectangular region detection
    for (int y = 0; y < height - 10; y += 5) { // Skip pixels for performance
      for (int x = 0; x < width - 10; x += 5) {
        if (visited[y][x]) continue;
        
        final region = _traceRectangle(edges, x, y, width, height, visited);
        if (region != null && 
            region.width > 50 && region.height > 50 && // Minimum size filter
            region.width < width * 0.9 && region.height < height * 0.9) { // Maximum size filter
          regions.add(region);
        }
      }
    }
    
    return regions;
  }
  
  Rect? _traceRectangle(img.Image edges, int startX, int startY, int maxWidth, int maxHeight, List<List<bool>> visited) {
    // Simplified rectangle tracing - look for continuous edge patterns
    int minX = startX, maxX = startX;
    int minY = startY, maxY = startY;
    
    // Expand rectangle bounds by following edge pixels
    // This is a simplified implementation - can be enhanced
    
    for (int dy = 0; dy < 200 && startY + dy < maxHeight; dy++) {
      for (int dx = 0; dx < 200 && startX + dx < maxWidth; dx++) {
        final pixel = edges.getPixel(startX + dx, startY + dy);
        if (img.getLuminance(pixel) > 128) { // Edge pixel found
          maxX = math.max(maxX, startX + dx);
          maxY = math.max(maxY, startY + dy);
          visited[startY + dy][startX + dx] = true;
        }
      }
    }
    
    final width = maxX - minX;
    final height = maxY - minY;
    
    return width > 50 && height > 50 
        ? Rect.fromLTWH(minX.toDouble(), minY.toDouble(), width.toDouble(), height.toDouble())
        : null;
  }
  
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
  
  List<DetectedWindow> _filterAndSortWindows(List<DetectedWindow> windows) {
    // Filter out small windows and sort by size (largest first)
    return windows
        .where((w) => w.category != WindowCategory.small)
        .toList()
      ..sort((a, b) => {
        // Primary sort by category (large windows first)
        if (a.category != b.category) {
          return a.category == WindowCategory.large ? -1 : 1;
        }
        // Secondary sort by area (largest first)
        final aArea = a.bounds.width * a.bounds.height;
        final bArea = b.bounds.width * b.bounds.height;
        return bArea.compareTo(aArea);
      });
  }
  
  Future<void> _sendAltPageUp() async {
    final inputModel = gFFI.inputModel;
    
    // Researched key combination for window cycling
    inputModel.inputKey('Alt', down: true);
    inputModel.inputKey('Page Up', down: true, press: true);
    inputModel.inputKey('Alt', down: false);
  }
  
  Uint8List _extractThumbnail(img.Image source, Rect region) {
    // Extract thumbnail for carousel display
    final cropped = img.copyCrop(source, 
        x: region.left.toInt(), 
        y: region.top.toInt(),
        width: region.width.toInt(), 
        height: region.height.toInt());
    
    // Resize for thumbnail display
    final thumbnail = img.copyResize(cropped, width: 200, height: 150);
    return Uint8List.fromList(img.encodePng(thumbnail));
  }
  
  Future<Uint8List> _extractRgbaFromImage(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }
}

// Data classes
class DetectedWindow {
  final Rect bounds;
  final int cyclePosition;  // Which cycle detected this window
  final Uint8List thumbnail;
  final WindowCategory category;
  
  DetectedWindow({
    required this.bounds,
    required this.cyclePosition,
    required this.thumbnail,
    required this.category,
  });
  
  double getScreenPercentage(int screenWidth, int screenHeight) {
    final regionArea = bounds.width * bounds.height;
    final screenArea = screenWidth * screenHeight;
    return regionArea / screenArea;
  }
}

enum WindowCategory {
  large,   // 15%+ of screen - likely windows
  medium,  // 5-15% of screen - possible windows
  small    // <5% of screen - filtered out
}
```

#### 3. Extended RemotePage Integration

**Purpose**: Extend existing RemotePage without rewriting core functionality. Add window mode UI elements.

```dart
// Modify existing: flutter/lib/mobile/pages/remote_page.dart
// Add imports and new methods - DO NOT rewrite existing code

class _RemotePageState extends State<RemotePage> {
  // ADD these new fields to existing class
  WindowModeManager? _windowModeManager;
  bool _showWindowModeUI = false;
  
  @override
  void initState() {
    super.initState();
    // ADD this initialization to existing initState()
    _initializeWindowMode();
  }
  
  // ADD this new method
  void _initializeWindowMode() {
    _windowModeManager = WindowModeManager();
    _windowModeManager!.addListener(_onWindowModeStateChanged);
    
    // Auto-trigger detection after connection is established
    Timer(Duration(seconds: 2), () {
      if (mounted && gFFI.ffiModel.pi.isConnected()) {
        _windowModeManager!.startWindowDetection();
      }
    });
  }
  
  // ADD this new method
  void _onWindowModeStateChanged() {
    setState(() {
      _showWindowModeUI = _windowModeManager!.currentState != WindowModeState.normal;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // MODIFY existing build method to add window mode overlay
    return Scaffold(
      // ... existing scaffold content ...
      body: Stack(
        children: [
          // ... existing body content ...
          
          // ADD this overlay at the end of children list
          if (_showWindowModeUI)
            _buildWindowModeOverlay(),
        ],
      ),
    );
  }
  
  // ADD this new method
  Widget _buildWindowModeOverlay() {
    if (_windowModeManager == null) return SizedBox.shrink();
    
    return Consumer<WindowModeManager>(
      builder: (context, manager, child) {
        switch (manager.currentState) {
          case WindowModeState.detecting:
            return _buildDetectionOverlay(manager);
          case WindowModeState.selecting:
            return _buildSelectionOverlay(manager);
          case WindowModeState.navigating:
            return _buildNavigationOverlay(manager);
          default:
            return SizedBox.shrink();
        }
      },
    );
  }
  
  // ADD this new method
  Widget _buildDetectionOverlay(WindowModeManager manager) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'Detecting windows...\nThis can take up to 3 minutes',
              style: TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => manager.exitWindowMode(),
              child: Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
  
  // ADD this new method
  Widget _buildSelectionOverlay(WindowModeManager manager) {
    return WindowSelectionCarousel(
      detectedWindows: manager.detectedWindows,
      onWindowsSelected: (windows) => manager.selectWindows(windows),
      onCancel: () => manager.exitWindowMode(),
    );
  }
  
  // ADD this new method  
  Widget _buildNavigationOverlay(WindowModeManager manager) {
    return WindowNavigationView(
      selectedWindows: manager.selectedWindows,
      currentWindowIndex: manager.currentWindowIndex,
      isProcessing: manager.isProcessing,
      onWindowSwipe: (index) => manager.navigateToWindow(index),
      onExitWindowMode: () => manager.exitWindowMode(),
      onRestartDetection: () => manager.restartDetection(),
    );
  }
  
  @override
  void dispose() {
    // ADD this cleanup to existing dispose()
    _windowModeManager?.dispose();
    super.dispose();
  }
}
```

#### 4. Window Selection Carousel

**Purpose**: Single-view carousel as specified by user, with cropped window content.

```dart
// New file: flutter/lib/widgets/window_selection_carousel.dart
class WindowSelectionCarousel extends StatefulWidget {
  final List<DetectedWindow> detectedWindows;
  final Function(List<DetectedWindow>) onWindowsSelected;
  final VoidCallback onCancel;
  
  const WindowSelectionCarousel({
    Key? key,
    required this.detectedWindows,
    required this.onWindowsSelected,
    required this.onCancel,
  }) : super(key: key);
  
  @override
  _WindowSelectionCarouselState createState() => _WindowSelectionCarouselState();
}

class _WindowSelectionCarouselState extends State<WindowSelectionCarousel> {
  final PageController _pageController = PageController();
  final Set<DetectedWindow> _selectedWindows = {};
  int _currentIndex = 0;
  
  @override
  Widget build(BuildContext context) {
    // Organize windows: large first, then medium (per user specification)
    final organizedWindows = [...widget.detectedWindows];
    organizedWindows.sort((a, b) => {
      if (a.category != b.category) {
        return a.category == WindowCategory.large ? -1 : 1;
      }
      return 0;
    });
    
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Column(
        children: [
          // Header with selection count
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Windows (${_selectedWindows.length} selected)',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: widget.onCancel,
                        child: Text('Cancel', style: TextStyle(color: Colors.white)),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _selectedWindows.isNotEmpty 
                            ? () => widget.onWindowsSelected(_selectedWindows.toList())
                            : null,
                        child: Text('Done'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Single-view carousel as specified
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: organizedWindows.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                final window = organizedWindows[index];
                final isSelected = _selectedWindows.contains(window);
                
                return GestureDetector(
                  onTap: () => _toggleWindowSelection(window),
                  child: Container(
                    margin: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.green : 
                               (window.category == WindowCategory.large ? Colors.blue : Colors.orange),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          // Cropped window content as specified
                          Center(
                            child: Image.memory(
                              window.thumbnail,
                              fit: BoxFit.contain,
                            ),
                          ),
                          
                          // Category badge
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: window.category == WindowCategory.large 
                                    ? Colors.blue 
                                    : Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                window.category == WindowCategory.large 
                                    ? 'Likely (${(window.getScreenPercentage(1920, 1080) * 100).toInt()}%)'
                                    : 'Possible (${(window.getScreenPercentage(1920, 1080) * 100).toInt()}%)',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ),
                          
                          // Selection indicator
                          if (isSelected)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.check, color: Colors.white, size: 30),
                              ),
                            ),
                          
                          // Tap instruction overlay
                          Positioned(
                            bottom: 20,
                            left: 20,
                            right: 20,
                            child: Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Tap to ${isSelected ? "deselect" : "select"} • Swipe for more windows',
                                style: TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Page indicator
          Container(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                organizedWindows.length,
                (index) => Container(
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _currentIndex ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _toggleWindowSelection(DetectedWindow window) {
    setState(() {
      if (_selectedWindows.contains(window)) {
        _selectedWindows.remove(window);
      } else {
        _selectedWindows.add(window);
      }
    });
  }
}
```

#### 5. Window Navigation with Copy/Paste Integration

**Purpose**: Swipe-based window navigation with contextual copy/paste toolbar and cycling coordination.

```dart
// New file: flutter/lib/widgets/window_navigation_view.dart
class WindowNavigationView extends StatefulWidget {
  final List<DetectedWindow> selectedWindows;
  final int currentWindowIndex;
  final bool isProcessing;
  final Function(int) onWindowSwipe;
  final VoidCallback onExitWindowMode;
  final VoidCallback onRestartDetection;
  
  const WindowNavigationView({
    Key? key,
    required this.selectedWindows,
    required this.currentWindowIndex,
    required this.isProcessing,
    required this.onWindowSwipe,
    required this.onExitWindowMode,
    required this.onRestartDetection,
  }) : super(key: key);
  
  @override
  _WindowNavigationViewState createState() => _WindowNavigationViewState();
}

class _WindowNavigationViewState extends State<WindowNavigationView> {
  final PageController _pageController = PageController();
  bool _showCopyPasteToolbar = false;
  bool _isLongPressing = false;
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main window navigation
        PageView.builder(
          controller: _pageController,
          itemCount: widget.selectedWindows.length,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) {
            final window = widget.selectedWindows[index];
            return _buildWindowView(window, index);
          },
        ),
        
        // Processing overlay during cycling
        if (widget.isProcessing)
          _buildProcessingOverlay(),
        
        // Contextual copy/paste toolbar
        if (_showCopyPasteToolbar && !widget.isProcessing)
          _buildCopyPasteToolbar(),
        
        // Top navigation bar
        _buildTopNavigationBar(),
      ],
    );
  }
  
  Widget _buildWindowView(DetectedWindow window, int index) {
    return GestureDetector(
      onLongPress: () => _showContextualToolbar(),
      child: Container(
        color: Colors.black,
        child: Consumer<ImageModel>(
          builder: (context, imageModel, child) {
            if (imageModel.image == null) {
              return Center(
                child: CircularProgressIndicator(),
              );
            }
            
            // Display cropped window region from current remote desktop image
            return CustomPaint(
              painter: CroppedWindowPainter(
                image: imageModel.image!,
                cropRegion: window.bounds,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Switching windows...\nThis can take a couple seconds!',
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCopyPasteToolbar() {
    return Positioned(
      bottom: 50,
      left: 20,
      right: 20,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildToolbarButton(
              icon: Icons.copy,
              label: 'Copy',
              onPressed: _performCopy,
            ),
            _buildToolbarButton(
              icon: Icons.paste,
              label: 'Paste',
              onPressed: _performPaste,
            ),
            _buildToolbarButton(
              icon: Icons.close,
              label: 'Close',
              onPressed: () => setState(() => _showCopyPasteToolbar = false),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
  
  Widget _buildTopNavigationBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Window ${widget.currentWindowIndex + 1} of ${widget.selectedWindows.length}',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.white),
                onSelected: _handleMenuSelection,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'restart',
                    child: Text('Restart Detection'),
                  ),
                  PopupMenuItem(
                    value: 'exit',
                    child: Text('Exit Window Mode'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _onPageChanged(int index) {
    if (index != widget.currentWindowIndex && !widget.isProcessing) {
      widget.onWindowSwipe(index);
    }
  }
  
  void _showContextualToolbar() {
    setState(() {
      _showCopyPasteToolbar = true;
    });
    
    // Auto-hide after 5 seconds
    Timer(Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showCopyPasteToolbar = false);
      }
    });
  }
  
  void _performCopy() {
    // Trigger copy operation using RustDesk's existing system
    gFFI.inputModel.inputKey('Ctrl', down: true);
    gFFI.inputModel.inputKey('C', down: true, press: true);
    gFFI.inputModel.inputKey('Ctrl', down: false);
    
    // Sync clipboard using researched RustDesk method
    Timer(Duration(milliseconds: 500), () {
      trySyncClipboard(); // Use existing RustDesk clipboard sync
    });
    
    setState(() => _showCopyPasteToolbar = false);
  }
  
  void _performPaste() {
    // First sync clipboard from mobile to remote
    trySyncClipboard();
    
    // Then trigger paste operation
    Timer(Duration(milliseconds: 500), () {
      gFFI.inputModel.inputKey('Ctrl', down: true);
      gFFI.inputModel.inputKey('V', down: true, press: true);
      gFFI.inputModel.inputKey('Ctrl', down: false);
    });
    
    setState(() => _showCopyPasteToolbar = false);
  }
  
  void _handleMenuSelection(String value) {
    switch (value) {
      case 'restart':Moved out after school (was 19). Best decision ever.

Was tough, yes. My mum isn't rich and we are migrants, so I was organizing everything myself. Accomodation, scholarship, uni, friends.

Taught me self-organization and discipline. Seems basic now, but was world-changing then.
        widget.onRestartDetection();
        break;
      case 'exit':
        widget.onExitWindowMode();
        break;
    }
  }
  
  // Use existing RustDesk clipboard method as researched
  void trySyncClipboard() {
    gFFI.invokeMethod("try_sync_clipboard");
  }
}

// Custom painter for cropped window display
class CroppedWindowPainter extends CustomPainter {
  final ui.Image image;
  final Rect cropRegion;
  
  CroppedWindowPainter({
    required this.image,
    required this.cropRegion,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Draw only the cropped window region, scaled to fit screen
    final srcRect = cropRegion;
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    
    final paint = Paint()
      ..filterQuality = FilterQuality.medium;
    
    canvas.drawImageRect(image, srcRect, dstRect, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! CroppedWindowPainter ||
           oldDelegate.image != image ||
           oldDelegate.cropRegion != cropRegion;
  }
}
```

### Integration Points Summary

1. **Add WindowModeManager to pubspec.yaml dependencies** (if using external state management)
2. **Import new files in RemotePage**: Import the new service and widget files
3. **Initialize WindowModeManager in RemotePage.initState()**: Add the initialization code
4. **Add overlay to RemotePage.build()**: Include the window mode overlay
5. **Use existing RustDesk methods**: Leverage `inputKey()`, `try_sync_clipboard()`, and `ImageModel`

### Error Handling Strategy

- **Detection Errors**: Show error message with restart button
- **Navigation Errors**: Show error message with restart button  
- **Timeout Errors**: 180-second timeout for entire detection process
- **No Manual Recovery**: Keep it simple - any error requires restarting detection

This implementation plan follows the core principle of building on existing RustDesk functionality without rewriting core code, ensuring easier maintenance and updates.

## Alternative Approaches (Addendum)

While this specification focuses on Canny edge detection for simplicity, the following approaches could enhance or replace the core detection method in future versions:

### Color-Based Segmentation
- **Region-Based Segmentation**: Group pixels by color similarity, texture, or intensity
- **K-means Clustering**: Use clustering algorithms to group similar pixels  
- **Background Detection**: Leverage consistent desktop wallpaper colors vs window content
- **Use Case**: Better for detecting windows with distinct color schemes

### Advanced Computer Vision
- **Multiple Edge Detectors**: Combine Canny with Sobel and Prewitt operators
- **Contour Analysis**: Use OpenCV-style contour detection for complex shapes
- **Template Matching**: Detect common window UI elements (title bars, buttons)
- **Use Case**: Higher accuracy at cost of complexity

### Machine Learning Approaches  
- **Object Detection Models**: Use TensorFlow Lite models trained on desktop screenshots
- **Custom Training**: Train models specifically on various OS window styles
- **Flutter ML Kit**: Integrate Google ML Kit for enhanced detection capabilities
- **Use Case**: Highest accuracy but requires model training and larger app size

### Hybrid Approaches
- **Multi-Method Voting**: Combine edge detection with color segmentation results
- **Adaptive Selection**: Choose detection method based on desktop characteristics  
- **User Learning**: Improve detection based on user selection feedback
- **Use Case**: Best of all approaches but increased complexity

These alternatives remain as future enhancement options while keeping the initial implementation simple and focused.

## User Experience Flow

### Stage 1: Connection & Auto-Detection
1. **Connection Establishment**
   - User opens app and connects to remote machine using standard RustDesk flow
   - Connection triggers automatic window detection process

2. **Background Detection Process**
   - Window detection algorithm runs automatically in background
   - System cycles through windows using Alt+PageUp keyboard shortcuts
   - Detection compiles two categories:
     - **Likely Candidates**: Large windows (15%+ of screen area)
     - **Unlikely Candidates**: Medium windows (5-15% of screen area)
   - User sees progress indicator during detection/cycling process

### Stage 2: Window Selection via Carousel
3. **Candidate Presentation**
   - Likely candidates presented first in a carousel interface
   - Each candidate shows window thumbnail with size percentage badge
   - User flips through carousel to review all likely candidates
   - "Show More" option reveals unlikely candidates in same carousel
   - Unlikely candidates clearly marked as "secondary" with different styling

4. **Window Selection Process**
   - User taps on carousel items to select/deselect desired windows
   - Selected windows are marked with checkmarks and green highlights
   - System tracks the **cycling path** to each selected window:
     - Records how many Alt+PageUp presses needed to reach each window from any other
     - Maintains a cycling map: Window A → Window B (3 cycles), Window B → Window C (2 cycles), etc.
   - User confirms selection to proceed to interaction stage

### Stage 3: Window Interaction Mode
5. **Initial Window Display**
   - System displays first selected window, scaled to fit mobile screen
   - Only the selected window content is visible (cropped from full desktop)
   - Bottom indicator shows current window position (1 of N)

6. **Window Navigation via Swiping**
   - User swipes left/right to switch between selected windows
   - **Swipe triggers window cycling**: System sends the correct number of Alt+PageUp commands to reach target window
   - During cycling transition:
     - Spinning/loading indicator displayed
     - Touch interaction disabled to prevent accidental input
     - "Switching to [Window Name]..." message shown
   - Once cycling complete, display updates to show new window content (cropped and scaled)

7. **Primary Interactions**
   - **Button Pressing**: Direct tap-to-click on buttons and UI elements
   - **Copy/Paste Operations**: 
     - Easily accessible copy/paste toolbar always visible
     - Long-press text selection with copy option
     - Paste button prominently displayed
     - Cross-device clipboard synchronization
   - **Text Input**: Virtual keyboard integration for typing in remote applications

8. **Submenu Access**
   - **Re-trigger Detection**: Option to restart window detection process if layout changes
   - **RustDesk Standard Options**: 
     - Disconnect from remote machine
     - Connection settings
     - Audio controls
     - File transfer access
     - Other standard RustDesk mobile features
   - **Return to Full Desktop**: Exit window mode and return to traditional remote desktop view

### Stage 4: Ongoing Session Management
9. **Dynamic Window Management**
   - If user triggers re-detection, system updates window list and cycling paths
   - Previously selected windows remain selected if still detected
   - New windows can be added to selection
   - Cycling paths automatically recalculated

10. **Session Persistence**
    - Selected windows and cycling paths remembered during session
    - Quick reconnection maintains window selection if desktop layout unchanged
    - User can modify selection without losing current window position

## Technical Constraints & Solutions

- **Performance**: Process detection every Nth frame, not every frame
- **Accuracy**: False positives acceptable, user makes final selection
- **Simplicity**: No platform-specific APIs, only image processing
- **Battery**: Optimize detection frequency and image processing

## Development Phases

### Phase 1: Core Detection (4-6 weeks)
- Implement basic edge detection using `image` package
- Create WindowDetectionService and WindowRegion classes
- Build window selection overlay UI
- Test with various desktop environments

### Phase 2: Navigation & Interaction (3-4 weeks)  
- Implement PageView-based window navigation
- Add touch input handling within window bounds
- Integrate clipboard functionality
- Performance optimization

### Phase 3: Polish & Enhancement (2-3 weeks)
- Improve detection algorithms
- Add manual region selection tools
- UI/UX refinements
- unit-testing

## Risk Mitigation

- **Detection Accuracy**: User can manually select regions, false positives acceptable
- **Performance Impact**: Limit detection frequency, optimize algorithms
- **Complex Layouts**: Provide manual selection fallback
- **Platform Differences**: Pure image processing approach works across all platforms

This specification provides a practical implementation path using RustDesk's existing capabilities without requiring complex platform-specific window management APIs.

## Open Questions for MVP Implementation

The following questions need to be resolved before beginning implementation. These cover technical feasibility, integration points, user experience decisions, and scope limitations for the MVP.

### Technical Integration Questions

**1. Edge Detection Implementation** *(Research completed)*
- **RESOLVED**: Flutter's `image` package (v4.0.17) includes `sobel()` function for edge detection
- **RESOLVED**: Alternative packages available: `edge_detection`, `flutter_image_processing`, `canny_edge_detection`
- Q: Should we use the built-in `image.sobel()` function or integrate a dedicated edge detection package for better rectangle detection?
Anwer: lets start with the built-in function.
- Q: What edge detection threshold values work best for window border detection across different desktop themes?
**RESEARCHED**: Typical Sobel edge detection uses threshold values of 150-200 for separating edges from background. Research shows γ = 200 is commonly used, with adaptive thresholding recommended. For desktop themes, consider starting with threshold 150-200 and implementing adaptive adjustment based on image characteristics. If detection accuracy is poor, add theme detection (light/dark mode) or user-selectable sensitivity settings.

**2. RustDesk Input Integration** *(Research completed)*
- **RESOLVED**: RustDesk has `InputModel` with `inputKey()` and `inputRawKey()` functions for sending keyboard events
- **RESOLVED**: Input model tracks modifier keys (Alt, Ctrl, Shift) and handles raw key events
- Q: How do we integrate with RustDesk's existing input model to send Alt+PageUp sequences programmatically?
**RESEARCHED**: RustDesk's `InputModel` has `inputKey(String name, {bool? down, bool? press})` function for sending keyboard events. Code analysis shows Alt key tracking with `alt` boolean flag and key event handling for `LogicalKeyboardKey.altLeft/altRight`. For Alt+PageUp combination, call:
```dart
inputModel.inputKey('Alt', down: true);  // Alt down
inputModel.inputKey('Page Up', down: true, press: true);  // PageUp press
inputModel.inputKey('Alt', down: false);  // Alt up
```
However, research revealed known issues with Alt combinations in RustDesk - users report Alt+Tab problems and modifier key combinations not working properly. May require testing and potential workarounds.

- Q: What's the correct key code/event sequence for Alt+PageUp in RustDesk's input system?
**RESOLVED**: Same as above - use `inputKey()` with proper key names. Key labels are mapped through `physicalKeyMap`, `logicalKeyMap`, or `keyLabel`. For PageUp, likely uses "Page Up" or similar string identifier. Need to verify exact string through testing or source code analysis of key mappings.

**3. Window Cycling Coordination**
- Q: What's the optimal delay between sending Alt+PageUp and capturing the screen state for detection?
**RESEARCHED**: Remote desktop research shows Alt+Tab switching delays of 1.5-2 seconds in typical scenarios. Window switching response times vary based on network latency and system performance. For reliable detection, recommend **2.5-3 second delay** (base 2 seconds + 50% buffer) between sending Alt+PageUp and capturing screen state. This accounts for:
- Network latency in remote desktop connections
- Window switching animation time  
- System processing delays
- Buffer for varying performance conditions
Consider making delay configurable for different network conditions.
- Q: How do we detect if a window cycling operation failed (no window change occurred)?
Answer: Ignore this for now. This ownt be relevant for the MVP.
- Q: Should we implement a "cycling queue" to batch multiple window switches, or send them individually?
Answer: When the user switches the window, a pin appears to block the user from doing another switch. Therefore no queue is required.

**4. Window Cycling Path Management** *(Core architecture question)*
- Q: Should we use a circular linked list, directed graph, or simple index-based approach for tracking cycling paths?
Answer: If no additional package is required, ise a directed graph. Otherwise use a simple index based approach. The user will likely select only a small number of windows, so performance is not relevant.
- Q: How do we handle the case where Alt+PageUp cycles through windows in different order during detection vs interaction?
Answer: This shall not be a concern for the MVP. The cycling direction is assumed to be static.
- Q: What's the most efficient algorithm for calculating shortest cycling paths between selected windows?
Answer: The number of window switch processes to reach a target window from any starting window is recorded and the cycling direction is assumed tot be static. I dont see the necessity to calculate the shortest cycling path.
- Q: How do we detect and recover when the cycling path becomes invalid (windows opened/closed)?
Answer: This shall not be a concern for the MVP.

### User Experience Questions

**5. Carousel Selection Interface** *(Research completed)*
- **RESOLVED**: Flutter's `PageView.builder()` and `carousel_slider` package provide swipe-based carousel functionality
- **RESOLVED**: PageView supports indicators, custom viewport fractions, and swipe navigation
- Q: Should carousel show single window at a time (full screen) or multiple windows with partial views (viewport fraction 0.75)?
Answer: single view at a time
- Q: How should we display window thumbnails in carousel - cropped window content, full desktop with highlight, or simplified previews?
Answer: cropped window content
- Q: Should unlikely candidates be mixed in the same carousel or presented in a separate "More Windows" section?
Answer: same carousel, but placed after the likely ones in the items list

**6. Window Cycling During Swipe Navigation**
- Q: What's the acceptable delay for cycling transitions during swipe navigation (target: <2 seconds)?
**CRITICAL FOR UX**: Research showed 1.5-2s delays are common for remote desktop. For swipe navigation, users expect <1s response. This creates tension - cycling needs 2.5-3s delay but users expect <1s swipe response. Need to address this performance gap.
Answer: Display a spin with a text stating "Switching windows. This can take a coupel seconds!"
- Q: Should we implement predictive cycling (pre-cycle to next likely window during user interaction)?
**PERFORMANCE CONSIDERATION**: Could reduce perceived delay by pre-cycling to adjacent windows, but risks unnecessary cycling overhead and potential sync issues.
Answer: no, this is not required fro the MVP
- Q: How do we handle rapid swipes that could trigger multiple cycling operations simultaneously?
**RESOLVED**: User answered that spinner/blocking prevents multiple operations, so queue not needed.
- Q: What visual feedback should we provide during cycling - progress bar, window previews, or simple spinner?
spinner with text explainig the delay

**7. Copy/Paste Toolbar Integration**
- Q: Should copy/paste toolbar be persistent (always visible) or contextual (appears on text selection)?
Answer: contextual
- Q: How do we integrate with RustDesk's existing clipboard synchronization system?
**RESEARCHED**: RustDesk has `try_sync_clipboard()` method in mobile remote page that calls `gFFI.invokeMethod("try_sync_clipboard")`. RustDesk 1.3.3 introduced mobile clipboard support for seamless copy/paste between devices. Current implementation supports text and file clipboard sync. Integration approach: leverage existing `try_sync_clipboard()` function and build mobile-optimized UI around it rather than reimplementing clipboard functionality.
- Q: Should we implement custom text selection UI optimized for mobile, or use standard remote desktop text selection?
Answer: this is an MVP, so let's start with the standard one
- Q: What's the priority order for mobile-optimized buttons: Copy, Paste, Select All, or additional actions?
Answer: Copy and Paste. No Select All as the bahaviour might be unreliable. 

### Scope and Limitations

**8. MVP Scope Definition**
- Q: Should MVP focus on automatic detection + carousel selection, or also include manual region drawing fallback?
Answer: This is an MVO, so no fallback required.
- Q: Do we need full submenu integration with RustDesk standard options, or can we start with basic disconnect functionality?
Answer: basic one to start with
- Q: Should we support detection on all platforms (Windows, macOS, Linux) simultaneously, or validate on one platform first?
Answer: the solution shall be platform agnostic, just as rustdesk is. We need to avoid platform sepcific apporaches.
- Q: What's the minimum viable feature set: detection + carousel + basic navigation, or do we need copy/paste toolbar from v1?
Answer: We need the copy / paste tool bar as well. 

**9. Error Handling & Recovery**
- Q: How should we handle zero detections during the cycling phase - show error, manual selection, or retry with different parameters?
Answer: show error. This is an MVP. Keep it simple.
- Q: What's the recovery strategy when cycling paths become invalid mid-session (windows opened/closed)?
Answer: show error with button to restart detection
- Q: Should we implement automatic re-detection triggers, or require manual user action to refresh window list?
Answer: there should be no automatic redetecton triggers. The user can restart detection via submenu or in case of error.
- Q: How do we handle partial failures (some windows detected, some cycling operations fail)?
Answer: no partial errors: any error means, the user must restart detection

**10. Performance & Resource Management**
- Q: What are reasonable memory limits for storing window thumbnails and cycling path data during a session?
Answer: we assume, the user has access to a normal smarkphone in 2025. Apps can use up to 500 MB RAM. We will assume the thumbnails will not pose a memory problem.  
- Q: Should we implement thumbnail caching strategies, or generate them on-demand during carousel navigation?
Answer: Generate on demand. This is an MVP. No extras required.
- Q: What's the acceptable processing time for the complete detection cycle (target: 10-15 seconds for
 10-15 windows)?
Answer: The processing time can be large, so no need to worry. In general there should be a timeout after 180 seconds
- Q: Should cycling path calculations be optimized for speed or memory efficiency?
Answer: speed

### Integration Architecture

**11. Architecture & Code Organization**
- Q: Should window detection be a separate service class, or integrated directly into the existing `ImageModel`?
**NEEDS CLARIFICATION**: Based on code analysis, `ImageModel` handles RGBA frame processing via `onRgba()`. Adding window detection here could impact performance. Consider separate `WindowDetectionService` class that receives frames from `ImageModel` to maintain separation of concerns.
Answer: correct, it should be a separate class
- Q: How do we structure the relationship between detection, carousel selection, and window navigation phases?
**NEEDS CLARIFICATION**: Three distinct phases need coordination: 1) Detection with window cycling, 2) Carousel selection UI, 3) Navigation with window switching. Consider state machine pattern or coordinating service to manage phase transitions.
Answer: Choose the more reliable and simple pattern: this would seem to be the state machine
- Q: Should we extend the existing `RemotePage` or create a new `WindowNavigationPage` for the interaction mode?
Answer: I would suggest to extend the RemotePage as functions might be required and other classes might expect a RemotePage type.
- Q: How do we maintain clean separation between RustDesk core functionality and our window detection features?
- Answer: High priority: avoid rewriting rustdesk code. Instead write new code building on rustdesk code. This will make merging updates easier. This needs to be a core guiding principle for this project.

**12. Data Persistence & State Management**
- Q: Should detected windows and cycling paths be stored in memory only, or persist across app restarts?
**NEEDS CLARIFICATION**: For MVP, recommend memory-only storage to avoid complexity. Cycling paths become invalid if remote desktop layout changes, so persistence across app restarts may cause issues.
Answer: memory only
- Q: How do we handle state management during app backgrounding/foregrounding while in window interaction mode?
**NEEDS CLARIFICATION**: Critical for mobile apps. When backgrounded during window interaction, need to preserve current window state and cycling position. Consider saving current window index and cycling path state to handle resume gracefully.
Answer: saving current window index and cycling path seems like a sensible approach
- Q: Should we save user's selected windows per connection for quick reconnection, or start fresh each session?
Answer: start fresh each session. This is an MVP.
- Q: What data structure is most appropriate for storing and accessing cycling path relationships efficiently?
**RESEARCHED**: User answered to use simple index-based approach or directed graph if no additional packages needed. For small number of windows (typically 2-5), simple Map<WindowId, CyclingDistance> structure sufficient.

### Testing and Validation

**13. Testing & Validation Strategy** 
- Q: What desktop environments and window managers should we prioritize for testing (Windows 11, macOS Ventura+, GNOME, KDE)?
Answer: ignore this level of testing
- Q: How do we create reproducible test scenarios for different window layouts and cycling behaviors?
Answer: ignore this level of testing
- Q: Should we implement automated testing for edge detection accuracy, or focus on manual testing with real desktop scenarios?
Answer: I will conduct manual testing. Implement unit tests to validate functions, but avoid complex testing.
- Q: What test cases do we need for cycling path validation and error recovery?
Answer: Ignore high level testing. Write unittests to validate functions, but nothign more.

**14. Success Criteria & Metrics**
- Q: What constitutes "successful" detection for MVP - 60% accurate window identification, or user satisfaction-based?
Answer: It's better to detect too many windows than too few. The user will select the relevant ones.
- Q: How do we measure cycling path accuracy - successful navigation to target window in expected number of cycles?
Answer: successful navigation would be good. This can potentially be achieved, by storing the window dimensions and comparing the expected dimensions with the ones of the window after cycling is completed
- Q: What performance benchmarks should we target: detection cycle <15 seconds, swipe-to-window <2 seconds, memory <50MB?
Answer: Ignore for now. This is an MVP. It just needs to work.
- Q: How do we quantify user experience improvement over traditional full-desktop remote access?
Answer: Ignore this.

### Deployment Considerations

**15. Deployment & Distribution**
- Q: Should this be integrated into main RustDesk mobile app with feature toggle, or distributed as separate "RustDesk WindowMode" app?
Answer: Ignore this
- Q: Do we need gradual rollout strategy (beta testing, phased release) given the complexity of window cycling functionality?
Answer: ignore this
- Q: How do we provide fallback to traditional full-desktop mode if window detection fails or user prefers it?
Answer: ignore this
- Q: Should window detection mode be opt-in, opt-out, or automatically triggered based on connection type?
Answer: should be automatic

**16. Feedback & Iteration**
- Q: What analytics should we collect to improve detection accuracy - failed detections, cycling errors, user selections?
Answer: ignore this for the MVP
- Q: How do we gather feedback on cycling path accuracy and user satisfaction with window navigation?
Answer: Ignore this for the MVP
- Q: Should we implement in-app feedback mechanisms for users to report detection issues or suggest improvements?
Answer: Ignore this for the MVP
- Q: What's our strategy for iterating on detection algorithms based on real-world usage data?
Answer: Ignore this for the MVP
