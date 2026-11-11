import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class ResponsiveLayout {
  static double widthOf(BuildContext context) => MediaQuery.of(context).size.width;

  static bool isCompact(BuildContext context) => widthOf(context) < 370;

  static bool isTabletOrLarger(BuildContext context) => widthOf(context) >= 600;

  static double horizontalPadding(BuildContext context) {
    final w = widthOf(context);
    if (w < 360) return 10;
    if (w < 430) return 14;
    if (w < 700) return 18;
    return 24;
  }

  static double bottomDockClearance(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return 94 + bottomInset;
  }

  static int marketplaceColumns(double availableWidth) {
    if (availableWidth >= 820) return 4;
    if (availableWidth >= 520) return 3;
    return 2;
  }
}

class LiquidGlassAmbientBackground extends StatelessWidget {
  final Widget child;

  const LiquidGlassAmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppTheme.ambientBgColors,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -90,
                    left: -60,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            (dark ? const Color(0xFF0A84FF) : const Color(0xFF60A5FA))
                                .withValues(alpha: dark ? 0.16 : 0.22),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 180,
                    right: -80,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            (dark ? const Color(0xFF5E5CE6) : const Color(0xFF818CF8))
                                .withValues(alpha: dark ? 0.14 : 0.16),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -100,
                    left: 40,
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            (dark ? const Color(0xFF30D158) : const Color(0xFF38BDF8))
                                .withValues(alpha: dark ? 0.08 : 0.12),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blurSigma;
  final Color? tintColor;
  final Color? borderColor;
  final bool elevated;
  final double? width;
  final double? height;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 22,
    this.padding,
    this.margin,
    this.blurSigma = 20,
    this.tintColor,
    this.borderColor,
    this.elevated = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    final radius = BorderRadius.circular(borderRadius);
    final baseTint = tintColor ?? (elevated ? AppTheme.glassElevatedBg : AppTheme.glassBg);
    final rimColor = borderColor ?? AppTheme.glassSpecularTop;

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppTheme.glassShadow,
            blurRadius: elevated ? 26 : 18,
            offset: Offset(0, elevated ? 10 : 5),
            spreadRadius: elevated ? -2 : -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: dark ? 0.10 : 0.42),
                  baseTint,
                  baseTint.withValues(alpha: dark ? 0.92 : 0.88),
                ],
                stops: const [0.0, 0.35, 1.0],
              ),
              border: Border.all(
                color: rimColor,
                width: dark ? 0.9 : 1.15,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class LiquidGlassPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final HitTestBehavior behavior;

  const LiquidGlassPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<LiquidGlassPressable> createState() => _LiquidGlassPressableState();
}

class _LiquidGlassPressableState extends State<LiquidGlassPressable> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed != value && mounted) {
      setState(() => _isPressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _isPressed ? widget.pressedScale : 1.0,
        duration: Duration(milliseconds: _isPressed ? 90 : 210),
        curve: _isPressed ? Curves.easeOut : Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: _isPressed ? 0.86 : 1.0,
          duration: const Duration(milliseconds: 110),
          child: widget.child,
        ),
      ),
    );
  }
}

enum LiquidButtonVariant { primary, neutral, danger, subtle }

class LiquidGlassButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final LiquidButtonVariant variant;
  final Color? accentColor;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final bool expand;
  final bool isLoading;
  final double fontSize;

  const LiquidGlassButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = LiquidButtonVariant.primary,
    this.accentColor,
    this.padding,
    this.borderRadius = 20,
    this.expand = false,
    this.isLoading = false,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    final tint = accentColor ?? AppTheme.accentBlue;

    late Color bgStart;
    late Color bgEnd;
    late Color border;
    late Color fg;

    switch (variant) {
      case LiquidButtonVariant.primary:
        bgStart = tint.withValues(alpha: 0.92);
        bgEnd = Color.lerp(tint, AppTheme.accentIndigo, 0.35)!.withValues(alpha: 0.96);
        border = Colors.white.withValues(alpha: dark ? 0.35 : 0.55);
        fg = Colors.white;
        break;
      case LiquidButtonVariant.danger:
        bgStart = AppTheme.accentCrimson.withValues(alpha: 0.90);
        bgEnd = const Color(0xFFD92D20).withValues(alpha: 0.96);
        border = Colors.white.withValues(alpha: 0.40);
        fg = Colors.white;
        break;
      case LiquidButtonVariant.neutral:
        bgStart = dark ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.86);
        bgEnd = dark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.65);
        border = dark ? Colors.white.withValues(alpha: 0.22) : Colors.white;
        fg = AppTheme.primaryText;
        break;
      case LiquidButtonVariant.subtle:
        bgStart = tint.withValues(alpha: dark ? 0.22 : 0.12);
        bgEnd = tint.withValues(alpha: dark ? 0.14 : 0.08);
        border = tint.withValues(alpha: 0.35);
        fg = dark ? Color.lerp(tint, Colors.white, 0.35)! : tint;
        break;
    }

    final radius = BorderRadius.circular(borderRadius);
    final inner = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [bgStart, bgEnd],
            ),
            border: Border.all(color: border, width: 1),
            boxShadow: variant == LiquidButtonVariant.primary || variant == LiquidButtonVariant.danger
                ? [
                    BoxShadow(
                      color: bgEnd.withValues(alpha: 0.32),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: AppTheme.glassShadow,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CupertinoActivityIndicator(color: fg, radius: 8),
                )
              else if (icon != null)
                Padding(
                  padding: EdgeInsets.only(right: label.isEmpty ? 0 : 7),
                  child: Icon(icon, size: fontSize + 3, color: fg),
                ),
              if (label.isNotEmpty)
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return LiquidGlassPressable(
      onTap: isLoading ? null : onPressed,
      child: expand ? SizedBox(width: double.infinity, child: inner) : inner,
    );
  }
}

class LiquidGlassPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final Color? activeColor;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? padding;

  const LiquidGlassPill({
    super.key,
    required this.label,
    this.icon,
    required this.isSelected,
    this.activeColor,
    required this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    final tint = activeColor ?? AppTheme.accentBlue;
    final radius = BorderRadius.circular(22);

    return LiquidGlassPressable(
      onTap: onTap,
      pressedScale: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tint.withValues(alpha: dark ? 0.92 : 0.94),
                    Color.lerp(tint, AppTheme.accentIndigo, 0.30)!,
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: dark ? 0.10 : 0.78),
                    AppTheme.glassPillBg,
                  ],
                ),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: dark ? 0.42 : 0.65)
                : (dark ? Colors.white.withValues(alpha: 0.15) : Colors.white),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? tint.withValues(alpha: 0.28) : AppTheme.glassShadow,
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : AppTheme.primaryText,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.primaryText,
                letterSpacing: -0.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LiquidGlassSegmentItem<T> {
  final T value;
  final String label;
  final IconData? icon;

  const LiquidGlassSegmentItem({
    required this.value,
    required this.label,
    this.icon,
  });
}

class LiquidGlassSegmentControl<T> extends StatefulWidget {
  final T groupValue;
  final List<LiquidGlassSegmentItem<T>> items;
  final ValueChanged<T> onValueChanged;

  const LiquidGlassSegmentControl({
    super.key,
    required this.groupValue,
    required this.items,
    required this.onValueChanged,
  });

  @override
  State<LiquidGlassSegmentControl<T>> createState() => _LiquidGlassSegmentControlState<T>();
}

class _LiquidGlassSegmentControlState<T> extends State<LiquidGlassSegmentControl<T>> {
  double? _dragX;
  bool _isDragging = false;

  int _indexFromPosition(double localX, double totalWidth) {
    if (widget.items.isEmpty || totalWidth <= 0) return 0;
    final slotW = totalWidth / widget.items.length;
    final idx = (localX / slotW).floor();
    return idx.clamp(0, widget.items.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    final activeIdx = widget.items.indexWhere((i) => i.value == widget.groupValue).clamp(0, widget.items.length - 1);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: dark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.56),
            border: Border.all(
              color: dark ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.95),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.glassShadow,
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalW = constraints.maxWidth;
              final segWidth = totalW / widget.items.length;

              double indicatorLeft;
              if (_isDragging && _dragX != null) {
                indicatorLeft = (_dragX! - segWidth / 2).clamp(0.0, totalW - segWidth);
              } else {
                indicatorLeft = activeIdx * segWidth;
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (details) {
                  setState(() {
                    _isDragging = true;
                    _dragX = details.localPosition.dx;
                  });
                },
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _dragX = details.localPosition.dx;
                  });
                },
                onHorizontalDragEnd: (details) {
                  if (_dragX != null) {
                    final targetIdx = _indexFromPosition(_dragX!, totalW);
                    widget.onValueChanged(widget.items[targetIdx].value);
                  }
                  setState(() {
                    _isDragging = false;
                    _dragX = null;
                  });
                },
                onHorizontalDragCancel: () {
                  setState(() {
                    _isDragging = false;
                    _dragX = null;
                  });
                },
                child: Stack(
                  children: [
                    // Fluid Specular Water-Droplet Indicator
                    AnimatedPositioned(
                      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      left: indicatorLeft,
                      top: 0,
                      bottom: 0,
                      width: segWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: dark
                                ? [
                                    Colors.white.withValues(alpha: _isDragging ? 0.30 : 0.20),
                                    Colors.white.withValues(alpha: _isDragging ? 0.18 : 0.11),
                                  ]
                                : [
                                    Colors.white,
                                    _isDragging ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
                                  ],
                          ),
                          border: Border.all(
                            color: dark
                                ? Colors.white.withValues(alpha: 0.32)
                                : Colors.white,
                            width: 1.1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: dark ? 0.40 : 0.10),
                              blurRadius: _isDragging ? 12 : 8,
                              offset: Offset(0, _isDragging ? 4 : 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: widget.items.map((item) {
                        final active = item.value == widget.groupValue;
                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => widget.onValueChanged(item.value),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (item.icon != null) ...[
                                        Icon(
                                          item.icon,
                                          size: 14,
                                          color: active ? AppTheme.primaryText : AppTheme.secondaryText,
                                        ),
                                        const SizedBox(width: 5),
                                      ],
                                      Text(
                                        item.label,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                          color: active ? AppTheme.primaryText : AppTheme.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class LiquidGlassDockItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isCreateButton;

  const LiquidGlassDockItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.isCreateButton = false,
  });
}

class LiquidGlassDockBar extends StatefulWidget {
  final int currentIndex;
  final List<LiquidGlassDockItem> items;
  final ValueChanged<int> onTap;

  const LiquidGlassDockBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  State<LiquidGlassDockBar> createState() => _LiquidGlassDockBarState();
}

class _LiquidGlassDockBarState extends State<LiquidGlassDockBar> {
  double? _dragX;
  bool _isDragging = false;

  int _indexFromPosition(double localX, double totalWidth) {
    if (widget.items.isEmpty || totalWidth <= 0) return 0;
    final slotW = totalWidth / widget.items.length;
    final idx = (localX / slotW).floor();
    return idx.clamp(0, widget.items.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    final compact = ResponsiveLayout.isCompact(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final dockH = compact ? 62.0 : 66.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 10 : 14, 0, compact ? 10 : 14, 10 + bottomInset),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            height: dockH,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? [
                        const Color(0xFF20283B).withValues(alpha: 0.78),
                        const Color(0xFF0E131F).withValues(alpha: 0.86),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.88),
                        const Color(0xFFF1F5FF).withValues(alpha: 0.78),
                      ],
              ),
              border: Border.all(
                color: dark ? Colors.white.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.95),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.55 : 0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalW = constraints.maxWidth;
                final slotW = totalW / widget.items.length;
                final activeIsCreate = widget.items[widget.currentIndex].isCreateButton;

                double indicatorLeft;
                if (_isDragging && _dragX != null) {
                  indicatorLeft = (_dragX! - slotW / 2).clamp(2.0, totalW - slotW + 2);
                } else {
                  indicatorLeft = widget.currentIndex * slotW + 2;
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (details) {
                    setState(() {
                      _isDragging = true;
                      _dragX = details.localPosition.dx;
                    });
                  },
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _dragX = details.localPosition.dx;
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_dragX != null) {
                      final targetIdx = _indexFromPosition(_dragX!, totalW);
                      widget.onTap(targetIdx);
                    }
                    setState(() {
                      _isDragging = false;
                      _dragX = null;
                    });
                  },
                  onHorizontalDragCancel: () {
                    setState(() {
                      _isDragging = false;
                      _dragX = null;
                    });
                  },
                  child: Stack(
                    children: [
                      if (!activeIsCreate || _isDragging)
                        AnimatedPositioned(
                          duration: _isDragging ? Duration.zero : const Duration(milliseconds: 280),
                          curve: Curves.easeOutBack,
                          left: indicatorLeft,
                          top: 2,
                          bottom: 2,
                          width: slotW - 4,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: dark
                                    ? [
                                        AppTheme.accentBlue.withValues(alpha: _isDragging ? 0.38 : 0.28),
                                        AppTheme.accentBlue.withValues(alpha: _isDragging ? 0.22 : 0.14),
                                      ]
                                    : [
                                        AppTheme.accentBlue.withValues(alpha: _isDragging ? 0.22 : 0.15),
                                        AppTheme.accentBlue.withValues(alpha: _isDragging ? 0.12 : 0.08),
                                      ],
                              ),
                              border: Border.all(
                                color: AppTheme.accentBlue.withValues(alpha: dark ? 0.55 : 0.35),
                                width: 1.1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accentBlue.withValues(alpha: dark ? 0.35 : 0.18),
                                  blurRadius: _isDragging ? 16 : 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Row(
                        children: List.generate(widget.items.length, (i) {
                          final item = widget.items[i];
                          final selected = i == widget.currentIndex;
                          if (item.isCreateButton) {
                            return Expanded(
                              child: LiquidGlassPressable(
                                pressedScale: 0.90,
                                onTap: () => widget.onTap(i),
                                child: Center(
                                  child: Container(
                                    width: compact ? 44 : 48,
                                    height: compact ? 44 : 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppTheme.accentBlue,
                                          AppTheme.accentIndigo,
                                        ],
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.55),
                                        width: 1.3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.accentBlue.withValues(alpha: 0.42),
                                          blurRadius: 14,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(item.icon, color: Colors.white, size: compact ? 24 : 26),
                                  ),
                                ),
                              ),
                            );
                          }

                          final color = selected ? AppTheme.accentBlue : AppTheme.secondaryText;
                          return Expanded(
                            child: LiquidGlassPressable(
                              pressedScale: 0.92,
                              onTap: () => widget.onTap(i),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    selected ? item.activeIcon : item.icon,
                                    size: compact ? 20 : 22,
                                    color: color,
                                  ),
                                  const SizedBox(height: 2),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        item.label,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: compact ? 9.5 : 10.5,
                                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                          color: color,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class LiquidGlassSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double initialHeightFraction;

  const LiquidGlassSheet({
    super.key,
    required this.child,
    this.padding,
    this.initialHeightFraction = 0.85,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final maxH = MediaQuery.of(context).size.height * initialHeightFraction;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            padding: padding ??
                EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  16 + viewInsets + MediaQuery.of(context).padding.bottom,
                ),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? [
                        const Color(0xFF1A2234).withValues(alpha: 0.90),
                        const Color(0xFF0B0F18).withValues(alpha: 0.95),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.92),
                        const Color(0xFFF3F6FC).withValues(alpha: 0.95),
                      ],
              ),
              border: Border(
                top: BorderSide(
                  color: dark ? Colors.white.withValues(alpha: 0.25) : Colors.white,
                  width: 1.3,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4.5,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryText.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

