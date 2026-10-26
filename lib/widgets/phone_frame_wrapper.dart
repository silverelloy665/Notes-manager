import 'dart:math';
import 'package:flutter/material.dart';
import 'package:studymate_classroom/utils/app_theme.dart';

/// Available mobile device models for interactive simulation.
enum SimulatedDevice {
  iphone15Pro(
    name: 'iPhone 15 Pro',
    width: 393,
    height: 852,
    topPadding: 54,
    bottomPadding: 34,
    borderRadius: 50,
  ),
  pixel8(
    name: 'Google Pixel 8',
    width: 412,
    height: 892,
    topPadding: 48,
    bottomPadding: 28,
    borderRadius: 44,
  );

  final String name;
  final double width;
  final double height;
  final double topPadding;
  final double bottomPadding;
  final double borderRadius;

  const SimulatedDevice({
    required this.name,
    required this.width,
    required this.height,
    required this.topPadding,
    required this.bottomPadding,
    required this.borderRadius,
  });
}

/// A realistic, high-fidelity smartphone frame wrapper for Flutter Web.
/// Emulates authentic mobile viewports, dynamic notch / punch hole,
/// mobile status bar, and home indicator bar on desktop browsers.
class PhoneFrameWrapper extends StatefulWidget {
  final Widget child;

  static final ValueNotifier<bool> isPhoneMode = ValueNotifier<bool>(true);
  static final ValueNotifier<SimulatedDevice> selectedDevice = ValueNotifier<SimulatedDevice>(SimulatedDevice.iphone15Pro);

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
                                              bottom: device.bottomPadding,
                                            ),
                                            viewPadding: EdgeInsets.only(
                                              top: device.topPadding,
                                              bottom: device.bottomPadding,
                                            ),
                                          ),
                                          child: SizedBox(
                                            width: device.width,
                                            height: device.height,
                                            child: widget.child,
                                          ),
                                        ),
                                      ),

                                      // Mobile Status Bar (Time, Wifi, Signal, Battery)
                                      Positioned(
                                        top: 0,
                                        left: 0,
                                        right: 0,
                                        height: device.topPadding,
                                        child: IgnorePointer(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 24),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  timeStr,
                                                  style: const TextStyle(
                                                    fontFamily: 'sans-serif',
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: Color(0xFF0F4A22),
                                                  ),
                                                ),
                                                const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.signal_cellular_4_bar, size: 14, color: Color(0xFF0F4A22)),
                                                    SizedBox(width: 4),
                                                    Icon(Icons.wifi, size: 14, color: Color(0xFF0F4A22)),
                                                    SizedBox(width: 4),
                                                    Icon(Icons.battery_5_bar, size: 17, color: Color(0xFF0F4A22)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Dynamic Island / Camera cutout
                                      if (device == SimulatedDevice.iphone15Pro)
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
                                        )
                                      else
                                        Positioned(
                                          top: 14,
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
                                                  border: Border.all(color: Colors.white24, width: 1),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                      // Home Swipe Indicator Bar
                                      Positioned(
                                        bottom: 8,
                                        left: 0,
                                        right: 0,
                                        child: Center(
                                          child: IgnorePointer(
                                            child: Container(
                                              width: 134,
                                              height: 5,
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
          // Phone Mode Button
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
                    Icons.smartphone,
                    size: 15,
                    color: phoneModeActive ? Colors.white : AppTheme.inkForest,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Phone Frame',
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
                    child: Text('${d.name} (${d.width.toInt()}×${d.height.toInt()})'),
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
