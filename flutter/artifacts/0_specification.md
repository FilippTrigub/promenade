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

## Testing Strategy - TDD Approach

### Unit Testing Focus
**Principle**: Use Test-Driven Development (TDD) to ensure functionality without complex end-to-end testing.

**Core Testing Areas**:
1. **WindowDetectionService**: Unit tests for edge detection, threshold application, rectangle finding
2. **WindowModeManager**: Unit tests for state transitions, error handling, cycling coordination
3. **Window Selection Logic**: Unit tests for filtering, categorization, selection validation
4. **Cycling Path Management**: Unit tests for cycle counting, path mapping, duplicate detection
5. **Integration Points**: Unit tests for RustDesk method calls (mocked)

**TDD Process for Each Component**:
1. Write failing unit tests first (Red)
2. Implement minimal code to pass tests (Green) 
3. Refactor and optimize while maintaining tests (Refactor)
4. Repeat for each function/method

**Testing Framework**: Use Flutter's built-in `flutter_test` package

**Mock Strategy**: Mock external dependencies (RustDesk's `gFFI`, `InputModel`, `ImageModel`)

**No E2E Testing**: Focus purely on unit-level validation of individual functions and components

## Implementation Architecture

### Core Principles
- **Primary Principle**: Avoid rewriting RustDesk code. Build new functionality on top of existing RustDesk code
- **Architecture Pattern**: State machine to coordinate three phases: Detection, Selection, Navigation
- **TDD Focus**: Unit testing with comprehensive coverage of all components

### Components Overview
1. **WindowModeManager**: State management for detection/selection/navigation phases
2. **WindowDetectionService**: Sobel edge detection with size-based filtering
3. **WindowSelectionCarousel**: Single-view carousel for window selection
4. **WindowNavigationView**: Swipe-based navigation with copy/paste toolbar
5. **RemotePage Integration**: Extend existing page without rewriting core functionality

This specification provides a comprehensive foundation for implementing a simplified, mobile-optimized remote desktop experience focused on window-specific interactions.