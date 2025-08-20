import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/detected_window.dart';
import '../../models/model.dart';
import '../../common.dart';

/// Window Navigation View - Main navigation interface
/// Swipe-based window navigation with contextual copy/paste toolbar and cycling coordination
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
  State<WindowNavigationView> createState() => _WindowNavigationViewState();
}

class _WindowNavigationViewState extends State<WindowNavigationView> {
  final PageController _pageController = PageController();
  bool _showCopyPasteToolbar = false;
  Timer? _toolbarHideTimer;

  @override
  void initState() {
    super.initState();
    // Sync page controller with current window index
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.currentWindowIndex < widget.selectedWindows.length) {
        _pageController.jumpToPage(widget.currentWindowIndex);
      }
    });
  }

  @override
  void didUpdateWidget(WindowNavigationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update page controller when window index changes externally
    if (oldWidget.currentWindowIndex != widget.currentWindowIndex) {
      _updatePageController();
    }
  }

  @override
  void dispose() {
    _toolbarHideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// Update page controller to match current window index
  void _updatePageController() {
    if (widget.currentWindowIndex >= 0 &&
        widget.currentWindowIndex < widget.selectedWindows.length &&
        _pageController.hasClients) {
      _pageController.animateToPage(
        widget.currentWindowIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedWindows.isEmpty) {
      return _buildEmptyState();
    }

    return Stack(
      children: [
        _buildMainNavigation(),
        if (widget.isProcessing) _buildProcessingOverlay(),
        if (_showCopyPasteToolbar && !widget.isProcessing)
          _buildCopyPasteToolbar(),
        _buildTopNavigationBar(),
      ],
    );
  }

  /// Build main window navigation PageView
  Widget _buildMainNavigation() {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.selectedWindows.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final window = widget.selectedWindows[index];
        return _buildWindowView(window, index);
      },
    );
  }

  /// Build individual window view
  Widget _buildWindowView(DetectedWindow window, int index) {
    return GestureDetector(
      onLongPress: _showContextualToolbar,
      child: Container(
        color: Colors.black,
        child: _buildWindowContent(window),
      ),
    );
  }

  /// Build window content - cropped from remote desktop
  Widget _buildWindowContent(DetectedWindow window) {
    return Consumer<ImageModel>(
      builder: (context, imageModel, child) {
        if (imageModel.image == null) {
          return const Center(
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
    );
  }

  /// Build processing overlay during window cycling
  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            const Text(
              'Switching windows...\nThis can take a couple seconds!',
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build contextual copy/paste toolbar
  Widget _buildCopyPasteToolbar() {
    return Positioned(
      bottom: 50,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
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
              onPressed: _hideCopyPasteToolbar,
            ),
          ],
        ),
      ),
    );
  }

  /// Build individual toolbar button
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
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  /// Build top navigation bar with window counter and menu
  Widget _buildTopNavigationBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Window ${widget.currentWindowIndex + 1} of ${widget.selectedWindows.length}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: _handleMenuSelection,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'restart',
                    child: Text('Restart Detection'),
                  ),
                  const PopupMenuItem(
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

  /// Build empty state when no windows selected
  Widget _buildEmptyState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.window, color: Colors.white, size: 64),
            const SizedBox(height: 20),
            const Text(
              'No windows selected',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 10),
            const Text(
              'Go back to select windows to interact with.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: widget.onExitWindowMode,
              child: const Text('Exit Window Mode'),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle page changes in the carousel
  void _onPageChanged(int index) {
    if (index != widget.currentWindowIndex && !widget.isProcessing) {
      widget.onWindowSwipe(index);
    }
  }

  /// Show contextual copy/paste toolbar
  void _showContextualToolbar() {
    setState(() {
      _showCopyPasteToolbar = true;
    });

    // Cancel previous timer
    _toolbarHideTimer?.cancel();

    // Auto-hide after 5 seconds
    _toolbarHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _hideCopyPasteToolbar();
      }
    });
  }

  /// Hide copy/paste toolbar
  void _hideCopyPasteToolbar() {
    setState(() {
      _showCopyPasteToolbar = false;
    });
    _toolbarHideTimer?.cancel();
  }

  /// Perform copy operation using RustDesk's input system
  void _performCopy() {
    try {
      // Trigger copy operation using RustDesk's existing system
      final inputModel = gFFI.inputModel;
      inputModel.inputKey('Ctrl', down: true);
      inputModel.inputKey('C', down: true, press: true);
      inputModel.inputKey('Ctrl', down: false);

      // Sync clipboard using researched RustDesk method
      Timer(const Duration(milliseconds: 500), () {
        _trySyncClipboard();
      });

      _hideCopyPasteToolbar();
      _showFeedback('Copied to clipboard');
    } catch (e) {
      _showFeedback('Copy failed: ${e.toString()}');
    }
  }

  /// Perform paste operation using RustDesk's input system
  void _performPaste() {
    try {
      // First sync clipboard from mobile to remote
      _trySyncClipboard();

      // Then trigger paste operation
      Timer(const Duration(milliseconds: 500), () {
        final inputModel = gFFI.inputModel;
        inputModel.inputKey('Ctrl', down: true);
        inputModel.inputKey('V', down: true, press: true);
        inputModel.inputKey('Ctrl', down: false);
      });

      _hideCopyPasteToolbar();
      _showFeedback('Pasted from clipboard');
    } catch (e) {
      _showFeedback('Paste failed: ${e.toString()}');
    }
  }

  /// Handle menu selection
  void _handleMenuSelection(String value) {
    switch (value) {
      case 'restart':
        widget.onRestartDetection();
        break;
      case 'exit':
        widget.onExitWindowMode();
        break;
    }
  }

  /// Use existing RustDesk clipboard method as researched
  void _trySyncClipboard() {
    gFFI.invokeMethod("try_sync_clipboard");
  }

  /// Show user feedback via snackbar
  void _showFeedback(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.black87,
        ),
      );
    }
  }

  // Testing helper methods
  bool get isToolbarVisible => _showCopyPasteToolbar;

  DetectedWindow? getCurrentWindow() {
    if (widget.currentWindowIndex >= 0 &&
        widget.currentWindowIndex < widget.selectedWindows.length) {
      return widget.selectedWindows[widget.currentWindowIndex];
    }
    return null;
  }
}

/// Custom painter for cropped window display
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

    final paint = Paint()..filterQuality = FilterQuality.medium;

    canvas.drawImageRect(image, srcRect, dstRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! CroppedWindowPainter ||
        oldDelegate.image != image ||
        oldDelegate.cropRegion != cropRegion;
  }
}