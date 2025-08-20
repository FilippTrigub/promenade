// Carousel Interface Draft Implementation
// Following TDD-Pure Development approach - this is the initial draft
// Tests should be written first before this implementation is finalized

import 'package:flutter/material.dart';
import '4_detection_service.dart';

/// Window Selection Carousel Widget
/// Single-view carousel as specified by user, with cropped window content
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
  State<WindowSelectionCarousel> createState() =>
      _WindowSelectionCarouselState();
}

class _WindowSelectionCarouselState extends State<WindowSelectionCarousel> {
  final PageController _pageController = PageController();
  final Set<DetectedWindow> _selectedWindows = {};
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Pre-select large windows as likely candidates
    for (final window in widget.detectedWindows) {
      if (window.category == WindowCategory.large) {
        _selectedWindows.add(window);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Organize windows: large first, then medium (per user specification)
    final organizedWindows = _organizeWindows(widget.detectedWindows);

    if (organizedWindows.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      color: Colors.black.withOpacity(0.9),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildCarousel(organizedWindows)),
            _buildPageIndicator(organizedWindows.length),
            _buildInstructionText(),
          ],
        ),
      ),
    );
  }

  /// Organize windows with large windows first, then medium
  List<DetectedWindow> _organizeWindows(List<DetectedWindow> windows) {
    final organized = [...windows];
    organized.sort((a, b) {
      if (a.category != b.category) {
        return a.category == WindowCategory.large ? -1 : 1;
      }
      // Secondary sort by area within same category
      final aArea = a.bounds.width * a.bounds.height;
      final bArea = b.bounds.width * b.bounds.height;
      return bArea.compareTo(aArea);
    });
    return organized;
  }

  /// Build the header with selection count and action buttons
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Select Windows (${_selectedWindows.length} selected)',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          Row(
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _selectedWindows.isNotEmpty
                    ? () => widget.onWindowsSelected(_selectedWindows.toList())
                    : null,
                child: const Text('Done'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build the main carousel showing windows one at a time
  Widget _buildCarousel(List<DetectedWindow> organizedWindows) {
    return PageView.builder(
      controller: _pageController,
      itemCount: organizedWindows.length,
      onPageChanged: (index) => setState(() => _currentIndex = index),
      itemBuilder: (context, index) {
        final window = organizedWindows[index];
        return _buildWindowCard(window);
      },
    );
  }

  /// Build individual window card for carousel
  Widget _buildWindowCard(DetectedWindow window) {
    final isSelected = _selectedWindows.contains(window);
    final borderColor = _getBorderColor(window, isSelected);

    return GestureDetector(
      onTap: () => _toggleWindowSelection(window),
      child: Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              _buildWindowThumbnail(window),
              _buildCategoryBadge(window),
              if (isSelected) _buildSelectionIndicator(),
              _buildTapInstructions(isSelected),
            ],
          ),
        ),
      ),
    );
  }

  /// Get border color based on selection and category
  Color _getBorderColor(DetectedWindow window, bool isSelected) {
    if (isSelected) return Colors.green;
    return window.category == WindowCategory.large
        ? Colors.blue
        : Colors.orange;
  }

  /// Build window thumbnail display
  Widget _buildWindowThumbnail(DetectedWindow window) {
    return Center(
      child: Image.memory(
        window.thumbnail,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[800],
            child: const Center(
              child: Icon(Icons.error, color: Colors.white, size: 48),
            ),
          );
        },
      ),
    );
  }

  /// Build category badge showing window type and size percentage
  Widget _buildCategoryBadge(DetectedWindow window) {
    final isLarge = window.category == WindowCategory.large;
    final percentage = (window.getScreenPercentage(1920, 1080) * 100).toInt();

    return Positioned(
      top: 10,
      left: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isLarge ? Colors.blue : Colors.orange,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          isLarge ? 'Likely ($percentage%)' : 'Possible ($percentage%)',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  /// Build selection indicator (checkmark)
  Widget _buildSelectionIndicator() {
    return Positioned(
      top: 10,
      right: 10,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 30),
      ),
    );
  }

  /// Build tap instructions overlay
  Widget _buildTapInstructions(bool isSelected) {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Tap to ${isSelected ? "deselect" : "select"} • Swipe for more windows',
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Build page indicator dots
  Widget _buildPageIndicator(int totalPages) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          totalPages,
          (index) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index == _currentIndex ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  /// Build instruction text at bottom
  Widget _buildInstructionText() {
    return Container(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(
        'Blue windows are likely targets, orange are possible.\nSelect windows you want to interact with.',
        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Build empty state when no windows detected
  Widget _buildEmptyState() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.window, color: Colors.white, size: 64),
            const SizedBox(height: 20),
            const Text(
              'No windows detected',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 10),
            const Text(
              'The window detection process found no suitable windows.\nTry restarting detection.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: widget.onCancel,
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  /// Toggle selection state of a window
  void _toggleWindowSelection(DetectedWindow window) {
    setState(() {
      if (_selectedWindows.contains(window)) {
        _selectedWindows.remove(window);
      } else {
        _selectedWindows.add(window);
      }
    });
  }

  /// Get currently visible window for testing
  DetectedWindow? getCurrentWindow() {
    final organizedWindows = _organizeWindows(widget.detectedWindows);
    if (_currentIndex >= 0 && _currentIndex < organizedWindows.length) {
      return organizedWindows[_currentIndex];
    }
    return null;
  }

  /// Get selection count for testing
  int get selectionCount => _selectedWindows.length;

  /// Check if window is selected for testing
  bool isWindowSelected(DetectedWindow window) {
    return _selectedWindows.contains(window);
  }

  /// Navigate to specific page for testing
  void navigateToPage(int index) {
    if (index >= 0 && index < widget.detectedWindows.length) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
}

/// Category Priority Helper
class WindowCategoryHelper {
  /// Get display name for category
  static String getCategoryDisplayName(WindowCategory category) {
    switch (category) {
      case WindowCategory.large:
        return 'Likely';
      case WindowCategory.medium:
        return 'Possible';
      case WindowCategory.small:
        return 'Unlikely';
    }
  }

  /// Get category color
  static Color getCategoryColor(WindowCategory category) {
    switch (category) {
      case WindowCategory.large:
        return Colors.blue;
      case WindowCategory.medium:
        return Colors.orange;
      case WindowCategory.small:
        return Colors.grey;
    }
  }

  /// Get category priority for sorting
  static int getCategoryPriority(WindowCategory category) {
    switch (category) {
      case WindowCategory.large:
        return 3;
      case WindowCategory.medium:
        return 2;
      case WindowCategory.small:
        return 1;
    }
  }
}