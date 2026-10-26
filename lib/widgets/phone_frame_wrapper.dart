import 'dart:math';
import 'package:flutter/material.dart';
import 'package:studymate_classroom/utils/app_theme.dart';

/// Available mobile device models for interactive simulation.
enum SimulatedDevice {
  pixel8(
    name: 'Google Pixel 8 (Android)',
    shortName: 'Pixel 8',
    width: 412,
    height: 892,
    topPadding: 44,
    bottomPadding: 24,
    borderRadius: 42,
    isAndroid: true,
  ),
  galaxyS24(
    name: 'Samsung Galaxy S24 (Android)',
    shortName: 'Galaxy S24',
    width: 412,
    height: 915,
    topPadding: 42,
    bottomPadding: 24,
    borderRadius: 44,
    isAndroid: true,
  ),
  iphone15Pro(
    name: 'iPhone 15 Pro (iOS)',
    shortName: 'iPhone 15',
    width: 393,
    height: 852,
    topPadding: 54,
    bottomPadding: 34,
    borderRadius: 50,
    isAndroid: false,
  );

  final String name;
  final String shortName;
  final double width;
  final double height;
  final double topPadding;
  final double bottomPadding;
  final double borderRadius;
  final bool isAndroid;

  const SimulatedDevice({
    required this.name,
    required this.shortName,
    required this.width,
    required this.height,
    required this.topPadding,
    required this.bottomPadding,
    required this.borderRadius,
    required this.isAndroid,
  });
}

/// A realistic, high-fidelity smartphone frame wrapper for Flutter Web.
/// Emulates authentic Android & iOS viewports, punch-hole / notch cameras,
/// Android Material 3 status bars, and navigation pill / 3-button nav on desktop.
class PhoneFrameWrapper extends StatefulWidget {
  final Widget child;

  // Defaults to Android (Google Pixel 8)
  static final ValueNotifier<bool> isPhoneMode = ValueNotifier<bool>(true);
  static final ValueNotifier<SimulatedDevice> selectedDevice = ValueNotifier<SimulatedDevice>(SimulatedDevice.pixel8);
  static final ValueNotifier<bool> useAndroid3Buttons = ValueNotifier<bool>(false);

  static void toggle() {
    isPhoneMode.value = !isPhoneMode.value;
  }

  const PhoneFrameWrapper({super.key, required this.child});

  @override
  State<PhoneFrameWrapper> createState() => _PhoneFrameWrapperState();
}

class _PhoneFrameWrapperState extends State<PhoneFrameWrapper> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PhoneFrameWrapper.isPhoneMode,
      builder: (context, phoneModeActive, _) {
        return ValueListenableBuilder<SimulatedDevice>(
          valueListenable: PhoneFrameWrapper.selectedDevice,
          builder: (context, device, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: PhoneFrameWrapper.useAndroid3Buttons,
              builder: (context, show3Buttons, _) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    // If the user's browser is already a mobile screen (< 560px),
                    // render natively at 100% full screen.
                    if (constraints.maxWidth < 560) {
                      return widget.child;
                    }

                    // If user toggled to Desktop Fullscreen mode
                    if (!phoneModeActive) {
                      return Material(
                        color: Colors.transparent,
                        child: Stack(
                          children: [
                            widget.child,
                            Positioned(
                              top: 14,
                              right: 18,
                              child: _buildFloatingControls(phoneModeActive: false, device: device, isCollapsed: true),
                            ),
                          ],
                        ),
                      );
                    }

                    // Available height leaving room for the top control bar
                    final double availableHeight = max(450.0, constraints.maxHeight - 88);

                    final now = DateTime.now();
                    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

                    final double bottomBarHeight = show3Buttons && device.isAndroid ? 44.0 : device.bottomPadding;

                    return Material(
                      color: const Color(0xFFE8ECE4),
                      child: Stack(
                        children: [
                          // Soothing botanical desk wallpaper
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment(0, -0.2),
                                  radius: 1.25,
                                  colors: [
                                    Color(0xFFF7FAF5),
                                    Color(0xFFE9F1E6),
                                    Color(0xFFDCE7D8),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Centered Scaled Phone Frame
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 56, bottom: 16),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: availableHeight,
                                  maxWidth: constraints.maxWidth - 32,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: Container(
                                    width: device.width + 24, // includes bezel thickness
                                    height: device.height + 24,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E3123), // Dark Forest metallic chassis
                                      borderRadius: BorderRadius.circular(device.borderRadius),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF0F4A22).withValues(alpha: 0.32),
                                          blurRadius: 45,
                                          offset: const Offset(0, 22),
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.35),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: const Color(0xFF2A4230),
                                        width: 3,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(9), // Outer bezel padding
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(device.borderRadius - 9),
                                      child: Stack(
                                        children: [
                                          // App content with authentic mobile MediaQuery
                                          Positioned.fill(
                                            child: MediaQuery(
                                              data: MediaQuery.of(context).copyWith(
                                                size: Size(device.width, device.height),
                                                padding: EdgeInsets.only(
                                                  top: device.topPadding,
                                                  bottom: bottomBarHeight,
                                                ),
                                                viewPadding: EdgeInsets.only(
                                                  top: device.topPadding,
                                                  bottom: bottomBarHeight,
                                                ),
                                              ),
                                              child: SizedBox(
                                                width: device.width,
                                                height: device.height,
                                                child: widget.child,
                                              ),
                                            ),
                                          ),

                                          // Status Bar (Android or iOS)
                                          Positioned(
                                            top: 0,
                                            left: 0,
                                            right: 0,
                                            height: device.topPadding,
                                            child: IgnorePointer(
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    // Left: Clock + Android notification icon
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          timeStr,
                                                          style: TextStyle(
                                                            fontFamily: 'sans-serif',
                                                            fontWeight: device.isAndroid ? FontWeight.w500 : FontWeight.bold,
                                                            fontSize: device.isAndroid ? 13.5 : 14,
                                                            color: const Color(0xFF0F4A22),
                                                          ),
                                                        ),
                                                        if (device.isAndroid) ...[
                                                          const SizedBox(width: 6),
                                                          const Icon(Icons.eco, size: 12, color: Color(0xFF0F4A22)),
                                                        ],
                                                      ],
                                                    ),

                                                    // Right: Android / iOS System Icons
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        if (device.isAndroid) ...[
                                                          const Icon(Icons.alarm, size: 13, color: Color(0xFF0F4A22)),
                                                          const SizedBox(width: 4),
                                                        ],
                                                        const Icon(Icons.wifi, size: 14, color: Color(0xFF0F4A22)),
                                                        const SizedBox(width: 4),
                                                        const Icon(Icons.signal_cellular_4_bar, size: 14, color: Color(0xFF0F4A22)),
                                                        const SizedBox(width: 5),
                                                        // Android vertical/pill battery
                                                        if (device.isAndroid)
                                                          const Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Text(
                                                                '95%',
                                                                style: TextStyle(fontFamily: 'sans-serif', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F4A22)),
                                                              ),
                                                              SizedBox(width: 2),
                                                              Icon(Icons.battery_full, size: 15, color: Color(0xFF0F4A22)),
                                                            ],
                                                          )
                                                        else
                                                          const Icon(Icons.battery_5_bar, size: 17, color: Color(0xFF0F4A22)),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),

                                          // Camera Cutout (Android Punch-Hole or iOS Dynamic Island)
                                          if (device.isAndroid)
                                            Positioned(
                                              top: 13,
                                              left: 0,
                                              right: 0,
                                              child: Center(
                                                child: IgnorePointer(
                                                  child: Container(
                                                    width: 13,
                                                    height: 13,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.black,
                                                      border: Border.all(color: Colors.white24, width: 0.8),
                                                    ),
                                                    child: Center(
                                                      child: Container(
                                                        width: 4,
                                                        height: 4,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          color: Colors.blueGrey.shade900,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            Positioned(
                                              top: 11,
                                              left: 0,
                                              right: 0,
                                              child: Center(
                                                child: IgnorePointer(
                                                  child: Container(
                                                    width: 116,
                                                    height: 29,
                                                    decoration: BoxDecoration(
                                                      color: Colors.black,
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      children: [
                                                        Container(
                                                          margin: const EdgeInsets.only(right: 11),
                                                          width: 10,
                                                          height: 10,
                                                          decoration: BoxDecoration(
                                                            shape: BoxShape.circle,
                                                            color: Colors.blueGrey.shade900,
                                                            border: Border.all(color: Colors.white12, width: 1),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                          // Bottom Navigation (Android Pill or Android 3-Button or iOS Bar)
                                          if (show3Buttons && device.isAndroid)
                                            Positioned(
                                              bottom: 0,
                                              left: 0,
                                              right: 0,
                                              height: 42,
                                              child: Container(
                                                color: Colors.black.withValues(alpha: 0.85),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                  children: [
                                                    // Back button
                                                    IconButton(
                                                      icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 20),
                                                      onPressed: () {
                                                        final nav = Navigator.maybeOf(context);
                                                        if (nav != null && nav.canPop()) {
                                                          nav.pop();
                                                        }
                                                      },
                                                    ),
                                                    // Home button
                                                    const Icon(Icons.circle_outlined, color: Colors.white70, size: 17),
                                                    // Recent apps button
                                                    const Icon(Icons.crop_square, color: Colors.white70, size: 18),
                                                  ],
                                                ),
                                              ),
                                            )
                                          else
                                            Positioned(
                                              bottom: 8,
                                              left: 0,
                                              right: 0,
                                              child: Center(
                                                child: IgnorePointer(
                                                  child: Container(
                                                    width: device.isAndroid ? 110 : 134,
                                                    height: device.isAndroid ? 4 : 5,
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withValues(alpha: 0.5),
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Floating Controls Bar (Top Center)
                          Positioned(
                            top: 12,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: _buildFloatingControls(phoneModeActive: true, device: device, isCollapsed: false),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFloatingControls({
    required bool phoneModeActive,
    required SimulatedDevice device,
    required bool isCollapsed,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.creamPaper.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.inkForest.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.inkForest.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Android / Phone Mode Button
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => PhoneFrameWrapper.isPhoneMode.value = true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: phoneModeActive ? AppTheme.inkForest : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    device.isAndroid ? Icons.android : Icons.phone_iphone,
                    size: 15,
                    color: phoneModeActive ? Colors.white : AppTheme.inkForest,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    phoneModeActive ? device.shortName : 'Phone Mode',
                    style: TextStyle(
                      fontFamily: AppTheme.fontZilla,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: phoneModeActive ? Colors.white : AppTheme.inkForest,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Desktop Mode Button
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => PhoneFrameWrapper.isPhoneMode.value = false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: !phoneModeActive ? AppTheme.inkForest : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.desktop_windows_outlined,
                    size: 15,
                    color: !phoneModeActive ? Colors.white : AppTheme.inkForest,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Desktop Full',
                    style: TextStyle(
                      fontFamily: AppTheme.fontZilla,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: !phoneModeActive ? Colors.white : AppTheme.inkForest,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Device Model Dropdown
          if (phoneModeActive && !isCollapsed) ...[
            const SizedBox(width: 8),
            Container(height: 16, width: 1, color: AppTheme.borderColor),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<SimulatedDevice>(
                value: device,
                icon: const Icon(Icons.arrow_drop_down, color: AppTheme.inkForest, size: 18),
                style: const TextStyle(
                  fontFamily: AppTheme.fontZilla,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppTheme.inkForest,
                ),
                dropdownColor: AppTheme.creamPaper,
                borderRadius: BorderRadius.circular(12),
                items: SimulatedDevice.values.map((d) {
                  return DropdownMenuItem(
                    value: d,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(d.isAndroid ? Icons.android : Icons.apple, size: 14, color: AppTheme.inkForest),
                        const SizedBox(width: 6),
                        Text('${d.name} (${d.width.toInt()}×${d.height.toInt()})'),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) PhoneFrameWrapper.selectedDevice.value = val;
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
