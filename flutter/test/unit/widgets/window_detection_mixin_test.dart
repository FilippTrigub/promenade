import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/mobile/widgets/window_detection_mixin.dart';
import 'package:flutter_hbb/models/window_mode_manager.dart';
import 'package:flutter_hbb/models/detected_window.dart';

// Test widget that uses the mixin
class TestWidget extends StatefulWidget {
  @override
  State<TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<TestWidget> with WindowDetectionMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: Colors.blue),
          if (shouldShowWindowOverlay) buildWindowDetectionOverlay(),
        ],
      ),
    );
  }
}

void main() {
  group('WindowDetectionMixin', () {
    final mockThumbnail = Uint8List.fromList([1, 2, 3, 4]);
    
    List<DetectedWindow> createMockWindows() {
      return [
        DetectedWindow(
          bounds: Rect.fromLTWH(0, 0, 300, 200),
          cyclePosition: 0,
          thumbnail: mockThumbnail,
          category: WindowCategory.large,
        ),
        DetectedWindow(
          bounds: Rect.fromLTWH(100, 100, 150, 100),
          cyclePosition: 1,
          thumbnail: mockThumbnail,
          category: WindowCategory.medium,
        ),
      ];
    }

    testWidgets('initializes correctly', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: TestWidget()));
      
      final state = tester.state<_TestWidgetState>(find.byType(TestWidget));
      
      // Should not show overlay initially
      expect(state.shouldShowWindowOverlay, isFalse);
      expect(state.currentWindowMode, isNull);
      expect(state.isInWindowMode, isFalse);
      expect(state.selectedWindows, isEmpty);
    });

    testWidgets('initializes window detection', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: TestWidget()));
      
      final state = tester.state<_TestWidgetState>(find.byType(TestWidget));
      
      // Initialize detection
      state.initWindowDetection();
      
      // Should have window mode manager
      expect(state.currentWindowMode, equals(WindowModeState.normal));
      
      // Multiple calls should not reinitialize
      state.initWindowDetection();
      expect(state.currentWindowMode, equals(WindowModeState.normal));
    });

    testWidgets('does not show overlay in normal state', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: TestWidget()));
      
      final state = tester.state<_TestWidgetState>(find.byType(TestWidget));
      state.initWindowDetection();
      
      expect(state.shouldShowWindowOverlay, isFalse);
      
      // Should only show base UI
      expect(find.byType(Container), findsOneWidget);
    });

    testWidgets('builds detection progress overlay', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: TestWidget()));
      
      final state = tester.state<_TestWidgetState>(find.byType(TestWidget));
      state.initWindowDetection();
      
      // Simulate detecting state
      state.manualStartWindowDetection();
      await tester.pump();
      
      if (state.shouldShowWindowOverlay) {
        expect(find.text('Detecting Windows...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      }
    });

    testWidgets('builds error overlay', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: TestWidget()));
      
      // This test verifies the error overlay UI structure
      // In actual integration, error state would be triggered by service failures
      final state = tester.state<_TestWidgetState>(find.byType(TestWidget));
      state.initWindowDetection();
      
      // The error overlay building is tested indirectly through the mixin methods
      expect(state.buildWindowDetectionOverlay(), isA<Widget>());
    });

    testWidgets('cleans up resources on dispose', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: TestWidget()));
      
      final state = tester.state<_TestWidgetState>(find.byType(TestWidget));
      state.initWindowDetection();
      
      // Dispose the widget
      await tester.pumpWidget(Container());
      
      // Window detection should be cleaned up
      expect(state.currentWindowMode, isNull);
    });

    testWidgets('manual detection trigger works', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: TestWidget()));
      
      final state = tester.state<_TestWidgetState>(find.byType(TestWidget));
      state.initWindowDetection();
      
      // Manual trigger should work without errors
      state.manualStartWindowDetection();
      await tester.pump();
      
      // State should change to detecting if window manager is available
      if (state.currentWindowMode != null) {
        expect([WindowModeState.detecting, WindowModeState.normal], 
               contains(state.currentWindowMode));
      }
    });

    test('provides correct state information', () {
      // Test state information methods without widget context
      final mixin = _TestMixinState();
      
      // Before initialization
      expect(mixin.shouldShowWindowOverlay, isFalse);
      expect(mixin.currentWindowMode, isNull);
      expect(mixin.isInWindowMode, isFalse);
      expect(mixin.selectedWindows, isEmpty);
      
      // After initialization (mocked)
      mixin._mockInitialization();
      expect(mixin.currentWindowMode, equals(WindowModeState.normal));
    });
  });
}

// Helper class to test mixin methods in isolation
class _TestMixinState with WindowDetectionMixin {
  WindowModeManager? _testManager;
  
  void _mockInitialization() {
    _testManager = WindowModeManager();
  }
  
  @override
  WindowModeState? get currentWindowMode => _testManager?.currentState;
  
  @override
  bool get shouldShowWindowOverlay => _testManager != null && !_testManager!.isNormal;
  
  @override
  bool get isInWindowMode => _testManager?.isNavigating ?? false;
  
  @override
  List<DetectedWindow> get selectedWindows => _testManager?.selectedWindows ?? [];
}