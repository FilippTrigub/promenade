# TDD-Pure Development Plan - RustDesk Window Detection Feature

## Overview
Implementation following Test-Driven Development methodology with comprehensive unit test coverage. Each component implemented only after complete test suite is written and validated.

## Phase 1: Foundation & Data Models (Week 1-2)

### 1.1 DetectedWindow Data Model & Tests
- **Test Suite**: Complete unit tests for DetectedWindow class
  - Constructor validation tests
  - Bounds property tests  
  - Cycle position tracking tests
  - Thumbnail data validation tests
  - Category assignment tests
  - Screen percentage calculation tests
- **Implementation**: DetectedWindow class to pass all tests
- **Validation**: 100% test coverage, all tests green

### 1.2 WindowCategory Enum & Tests  
- **Test Suite**: Enum value validation tests
  - Category comparison tests
  - String representation tests
  - Category filtering logic tests
- **Implementation**: WindowCategory enum implementation
- **Validation**: Complete enum functionality verified

### 1.3 Window Size Calculation Utilities & Tests
- **Test Suite**: Size calculation algorithm tests
  - Screen area percentage calculation tests
  - Category threshold validation tests (15%, 5% boundaries)
  - Edge case handling (zero dimensions, max dimensions)
  - Floating point precision tests
- **Implementation**: Size calculation utility functions
- **Validation**: Mathematical accuracy verified through tests

## Phase 2: WindowDetectionService Core Algorithm (Week 2-3)

### 2.1 Edge Detection Algorithm Tests
- **Test Suite**: Sobel edge detection validation
  - Threshold application tests (175 value validation)
  - Image format conversion tests (RGBA to Image)
  - Edge pixel identification tests
  - Noise handling validation tests
  - Different image size handling tests
- **Mock Strategy**: Mock `img.Image` objects with predefined pixel data
- **Implementation**: Sobel edge detection with threshold application
- **Validation**: Algorithm accuracy verified with test images

### 2.2 Rectangle Finding Algorithm Tests
- **Test Suite**: Rectangle tracing and identification
  - Minimum size filtering tests (50x50 pixels)
  - Maximum size filtering tests (90% screen area)
  - Rectangle boundary detection tests
  - Overlapping rectangle handling tests
  - Performance boundary tests (skip pixel optimization)
- **Mock Strategy**: Mock edge-detected images with known rectangle patterns
- **Implementation**: Rectangle finding and tracing algorithms
- **Validation**: Rectangle detection accuracy verified

### 2.3 Window Cycling Integration Tests  
- **Test Suite**: Alt+PageUp cycling coordination
  - Keyboard event sequence tests
  - Timing delay validation tests (2.5 second delays)
  - Cycle counting accuracy tests
  - Duplicate window detection tests
  - Timeout handling tests (180 second limit)
- **Mock Strategy**: Mock `gFFI.inputModel` and `ImageModel` interactions
- **Implementation**: Window cycling coordination logic
- **Validation**: Cycling behavior verified through mocked RustDesk calls

### 2.4 Complete WindowDetectionService Tests
- **Test Suite**: End-to-end detection service validation
  - `detectAllWindowsWithCycling()` method tests
  - Error handling and timeout tests
  - Memory usage validation tests
  - Performance benchmarking tests
- **Mock Strategy**: Complete RustDesk API mocking
- **Implementation**: Full WindowDetectionService class
- **Validation**: Service functionality comprehensively tested

## Phase 3: WindowModeManager State Machine (Week 3-4)

### 3.1 State Management Core Tests
- **Test Suite**: State transition validation
  - WindowModeState enum transition tests
  - State change notification tests
  - Invalid transition handling tests
  - State persistence tests
- **Mock Strategy**: Mock ChangeNotifier functionality
- **Implementation**: Core state management logic
- **Validation**: State machine behavior verified

### 3.2 Detection Phase Logic Tests
- **Test Suite**: Detection coordination validation
  - `startWindowDetection()` method tests
  - Detection progress tracking tests
  - Detection error handling tests
  - Detection result processing tests
- **Mock Strategy**: Mock WindowDetectionService calls
- **Implementation**: Detection phase coordination
- **Validation**: Detection workflow verified

### 3.3 Selection Phase Logic Tests
- **Test Suite**: Window selection management
  - `selectWindows()` method tests
  - Cycling path calculation tests
  - Selection validation tests
  - Selection state management tests
- **Mock Strategy**: Mock window selection scenarios
- **Implementation**: Selection phase logic
- **Validation**: Selection workflow tested

### 3.4 Navigation Phase Logic Tests
- **Test Suite**: Window navigation coordination
  - `navigateToWindow()` method tests
  - Cycling command execution tests
  - Navigation error handling tests
  - Processing state management tests
- **Mock Strategy**: Mock navigation scenarios
- **Implementation**: Navigation phase logic  
- **Validation**: Navigation workflow verified

### 3.5 Error Handling & Recovery Tests
- **Test Suite**: Comprehensive error scenarios
  - Error message display tests
  - Error recovery mechanism tests
  - State cleanup on error tests
  - Restart detection functionality tests
- **Implementation**: Error handling and recovery logic
- **Validation**: Error scenarios properly handled

## Phase 4: UI Components (Week 4-5)

### 4.1 WindowSelectionCarousel Tests
- **Test Suite**: Carousel UI component validation
  - PageView navigation tests
  - Window selection/deselection tests
  - Thumbnail display tests
  - Category badge display tests
  - Selection indicator tests
- **Mock Strategy**: Mock DetectedWindow data
- **Implementation**: WindowSelectionCarousel widget
- **Validation**: UI behavior verified through widget tests

### 4.2 WindowNavigationView Tests
- **Test Suite**: Navigation UI component validation
  - Swipe navigation tests
  - Copy/paste toolbar tests
  - Processing overlay tests  
  - Menu interaction tests
  - Long-press gesture tests
- **Mock Strategy**: Mock navigation data and callbacks
- **Implementation**: WindowNavigationView widget
- **Validation**: Navigation UI functionality tested

### 4.3 CroppedWindowPainter Tests
- **Test Suite**: Custom painter validation
  - Image cropping tests
  - Scaling calculation tests
  - Paint operation tests
  - Repaint trigger tests
- **Mock Strategy**: Mock ui.Image objects
- **Implementation**: CroppedWindowPainter class
- **Validation**: Custom painting behavior verified

## Phase 5: RustDesk Integration (Week 5-6)

### 5.1 RemotePage Integration Tests
- **Test Suite**: RustDesk integration validation
  - WindowModeManager initialization tests
  - State change listener tests
  - Overlay display logic tests
  - Connection trigger tests
- **Mock Strategy**: Mock RustDesk connection states
- **Implementation**: RemotePage extension methods
- **Validation**: Integration points verified

### 5.2 Copy/Paste Integration Tests
- **Test Suite**: Clipboard functionality validation
  - Copy operation tests (`Ctrl+C` sequence)
  - Paste operation tests (`Ctrl+V` sequence) 
  - Clipboard sync tests (`try_sync_clipboard`)
  - Timing coordination tests
- **Mock Strategy**: Mock `gFFI.inputModel` and clipboard methods
- **Implementation**: Copy/paste functionality
- **Validation**: Clipboard operations verified

### 5.3 Input Model Integration Tests
- **Test Suite**: Keyboard input validation
  - Alt+PageUp sequence tests
  - Key timing coordination tests
  - Modifier key handling tests
  - Input model method call tests
- **Mock Strategy**: Mock `gFFI.inputModel.inputKey` calls
- **Implementation**: Keyboard input integration
- **Validation**: Input sequences verified

## Phase 6: Integration & Validation (Week 6-7)

### 6.1 Component Integration Tests
- **Test Suite**: Cross-component integration
  - WindowModeManager + WindowDetectionService integration
  - UI component + state manager integration
  - Complete workflow integration tests
- **Implementation**: Integration coordination
- **Validation**: End-to-end component interaction verified

### 6.2 Error Scenario Integration Tests
- **Test Suite**: System-wide error handling
  - Detection failure scenarios
  - Navigation failure scenarios
  - RustDesk disconnection scenarios
  - Recovery workflow tests
- **Implementation**: System error handling
- **Validation**: Error scenarios properly managed

### 6.3 Performance & Memory Tests
- **Test Suite**: Performance validation
  - Memory usage tests (500MB limit compliance)
  - Detection timing tests
  - UI responsiveness tests
  - Resource cleanup tests
- **Validation**: Performance requirements met

## TDD Process Details

### Red-Green-Refactor Cycle
1. **Red Phase**: Write failing test for next piece of functionality
2. **Green Phase**: Write minimal code to make test pass
3. **Refactor Phase**: Improve code quality while maintaining tests

### Test Coverage Requirements
- **Target**: 100% unit test coverage for all business logic
- **Exclusions**: UI rendering code, external library calls
- **Validation**: Use Flutter's coverage tools to verify

### Mock Strategy
- **RustDesk APIs**: Mock `gFFI`, `inputModel`, `ImageModel`
- **Flutter Framework**: Mock `ChangeNotifier`, `PageController`
- **External Libraries**: Mock `img.Image` operations

### Quality Gates
- All tests must pass before moving to next component
- Code coverage must be >95% for each component
- No skipped or pending tests allowed
- Performance tests must meet specified benchmarks

## Deliverables per Phase

### Phase 1 Deliverables
- Complete test suite for data models
- Implemented DetectedWindow and WindowCategory classes
- Size calculation utilities with tests

### Phase 2 Deliverables  
- Complete WindowDetectionService with tests
- Edge detection algorithm with validation
- Window cycling coordination logic

### Phase 3 Deliverables
- Complete WindowModeManager with comprehensive tests
- State machine with all transitions tested
- Error handling with recovery scenarios

### Phase 4 Deliverables
- All UI components with widget tests
- Carousel and navigation UI fully tested
- Custom painter implementations

### Phase 5 Deliverables
- RustDesk integration extensions with tests
- Copy/paste functionality with validation
- Input coordination with mocked verification

### Phase 6 Deliverables
- Integrated system with cross-component tests
- Performance validation
- Complete feature ready for deployment

This development plan ensures comprehensive test coverage while building functionality incrementally following TDD principles.