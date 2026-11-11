import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui_web;
import '../services/api_service.dart';

class WebVideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool isLooping;
  final bool showControls;
  final bool isActive;
  final double bottomControlsPadding;
  final BoxFit fit;

  const WebVideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.autoPlay = true,
    this.isLooping = true,
    this.showControls = true,
    this.isActive = true,
    this.bottomControlsPadding = 0.0,
    this.fit = BoxFit.cover,
  });

  @override
  State<WebVideoPlayerWidget> createState() => _WebVideoPlayerWidgetState();
}

class _WebVideoPlayerWidgetState extends State<WebVideoPlayerWidget> {
  late final String _viewId;
  html.VideoElement? _videoElement;

  double _currentTime = 0.0;
  double _duration = 0.0;
  bool _isPlaying = true;
  bool _isMuted = false;
  bool _isDragging = false;
  double _playbackSpeed = 1.0;
  bool _showControlsOverlay = true;
  Timer? _hideControlsTimer;

  final List<double> _speeds = [0.5, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.autoPlay && widget.isActive;
    _viewId = 'video-view-${DateTime.now().microsecondsSinceEpoch}-${widget.videoUrl.hashCode}';

    ApiService().videoPlaybackOwnerNotifier.addListener(_onGlobalPlaybackChange);
    ApiService().activeTabIndexNotifier.addListener(_onTabChanged);

    if (kIsWeb) {
      final shouldStartPlaying = widget.autoPlay && widget.isActive;
      if (shouldStartPlaying) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.isActive) {
            ApiService().videoPlaybackOwnerNotifier.value = _viewId;
          }
        });
      }

      ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
        final video = html.VideoElement()
          ..src = widget.videoUrl
          ..autoplay = shouldStartPlaying
          ..loop = widget.isLooping
          ..controls = false
          ..muted = false
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = widget.fit == BoxFit.cover ? 'cover' : 'contain'
          ..style.border = 'none'
          ..style.backgroundColor = 'black';

        video.setAttribute('playsinline', 'true');
        video.setAttribute('webkit-playsinline', 'true');

        video.onLoadedMetadata.listen((e) {
          if (mounted) {
            setState(() {
              _duration = (video.duration.isFinite && !video.duration.isNaN) ? video.duration.toDouble() : 0.0;
            });
          }
        });

        video.onTimeUpdate.listen((e) {
          if (mounted && !_isDragging) {
            setState(() {
              _currentTime = video.currentTime.toDouble();
              if (_duration <= 0 && video.duration.isFinite && !video.duration.isNaN) {
                _duration = video.duration.toDouble();
              }
            });
          }
        });

        video.onPlay.listen((e) {
          if (mounted) {
            if (!widget.isActive) {
              video.pause();
              return;
            }
            ApiService().videoPlaybackOwnerNotifier.value = _viewId;
            setState(() => _isPlaying = true);
            _scheduleAutoHide();
          }
        });

        video.onPause.listen((e) {
          if (mounted) {
            _hideControlsTimer?.cancel();
            setState(() {
              _isPlaying = false;
              _showControlsOverlay = true;
            });
          }
        });

        _videoElement = video;
        return video;
      });
    }
  }

  void _onGlobalPlaybackChange() {
    if (!mounted || _videoElement == null) return;
    if (ApiService().videoPlaybackOwnerNotifier.value != _viewId && !_videoElement!.paused) {
      _videoElement!.pause();
      setState(() => _isPlaying = false);
    }
  }

  void _onTabChanged() {
    if (!mounted || _videoElement == null) return;
    if (!widget.isActive && !_videoElement!.paused) {
      _videoElement!.pause();
      setState(() => _isPlaying = false);
    }
  }

  @override
  void didUpdateWidget(covariant WebVideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive && _videoElement != null) {
      if (!widget.isActive) {
        _videoElement!.pause();
        setState(() => _isPlaying = false);
      } else if (widget.autoPlay && _videoElement!.paused) {
        ApiService().videoPlaybackOwnerNotifier.value = _viewId;
        _videoElement!.play();
        setState(() => _isPlaying = true);
      }
    }
  }

  void _scheduleAutoHide() {
    _hideControlsTimer?.cancel();
    if (!widget.showControls) return;
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying && !_isDragging) {
        setState(() => _showControlsOverlay = false);
      }
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    ApiService().videoPlaybackOwnerNotifier.removeListener(_onGlobalPlaybackChange);
    ApiService().activeTabIndexNotifier.removeListener(_onTabChanged);
    _videoElement?.pause();
    _videoElement?.removeAttribute('src');
    _videoElement?.load();
    super.dispose();
  }

  void _togglePlay() {
    if (_videoElement == null) return;
    if (_videoElement!.paused) {
      ApiService().videoPlaybackOwnerNotifier.value = _viewId;
      _videoElement!.play();
      setState(() {
        _isPlaying = true;
        _showControlsOverlay = true;
      });
      _scheduleAutoHide();
    } else {
      _videoElement!.pause();
      setState(() {
        _isPlaying = false;
        _showControlsOverlay = true;
      });
    }
  }

  void _stopPlayback() {
    if (_videoElement == null) return;
    _hideControlsTimer?.cancel();
    _videoElement!.pause();
    _videoElement!.currentTime = 0;
    setState(() {
      _isPlaying = false;
      _currentTime = 0.0;
      _showControlsOverlay = true;
    });
  }

  void _seekRelative(double deltaSeconds) {
    if (_videoElement == null) return;
    final maxDur = _duration > 0 ? _duration : (_currentTime + 30.0);
    final next = (_currentTime + deltaSeconds).clamp(0.0, maxDur);
    _videoElement!.currentTime = next;
    setState(() => _currentTime = next);
    _scheduleAutoHide();
  }

  void _toggleMute() {
    if (_videoElement == null) return;
    _videoElement!.muted = !_videoElement!.muted;
    setState(() => _isMuted = _videoElement!.muted);
  }

  void _cycleSpeed() {
    if (_videoElement == null) return;
    final currIdx = _speeds.indexOf(_playbackSpeed);
    final nextIdx = (currIdx + 1) % _speeds.length;
    _playbackSpeed = _speeds[nextIdx];
    _videoElement!.playbackRate = _playbackSpeed;
    setState(() {});
  }

  void _seekTo(double value) {
    if (_videoElement == null) return;
    _videoElement!.currentTime = value;
    setState(() {
      _currentTime = value;
      _isDragging = false;
    });
  }

  void _toggleFullscreen() {
    if (_videoElement == null) return;
    try {
      if (html.document.fullscreenElement != null) {
        html.document.exitFullscreen();
      } else {
        _videoElement!.requestFullscreen();
      }
    } catch (_) {}
  }

  String _formatTime(double sec) {
    if (sec.isNaN || sec.isInfinite || sec <= 0) return '0:00';
    final m = (sec / 60).floor();
    final s = (sec % 60).floor();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Container(
        color: CupertinoColors.black,
        child: const Center(
          child: Icon(CupertinoIcons.play_rectangle, color: CupertinoColors.white, size: 48),
        ),
      );
    }

    return Stack(
      children: [
        // Tap Layer to Toggle Compact Controls Overlay
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              setState(() => _showControlsOverlay = !_showControlsOverlay);
              if (_showControlsOverlay && _isPlaying) {
                _scheduleAutoHide();
              }
            },
            child: HtmlElementView(viewType: _viewId),
          ),
        ),

        // Compact Facebook-style Center Controls (-10s | Play/Pause | Stop | +10s)
        if (widget.showControls && (_showControlsOverlay || !_isPlaying))
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x880C1018),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    minSize: 30,
                    onPressed: () => _seekRelative(-10),
                    child: const Icon(CupertinoIcons.gobackward_10, color: CupertinoColors.white, size: 19),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minSize: 34,
                    onPressed: _togglePlay,
                    child: Icon(
                      _isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_arrow_solid,
                      color: CupertinoColors.white,
                      size: 24,
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    minSize: 30,
                    onPressed: _stopPlayback,
                    child: const Icon(CupertinoIcons.stop_fill, color: CupertinoColors.white, size: 17),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    minSize: 30,
                    onPressed: () => _seekRelative(10),
                    child: const Icon(CupertinoIcons.goforward_10, color: CupertinoColors.white, size: 19),
                  ),
                ],
              ),
            ),
          ),

        // Slim Bottom Scrub Bar (Timeline Khār / Speed / Mute / Fullscreen)
        if (widget.showControls && (_showControlsOverlay || !_isPlaying))
          Positioned(
            left: 0,
            right: 0,
            bottom: widget.bottomControlsPadding,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.78),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        _formatTime(_currentTime),
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SizedBox(
                          height: 24,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2.5,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 11),
                              activeTrackColor: const Color(0xFF0A84FF),
                              inactiveTrackColor: Colors.white.withValues(alpha: 0.28),
                              thumbColor: CupertinoColors.white,
                            ),
                            child: Slider(
                              min: 0.0,
                              max: _duration > 0 ? _duration : 1.0,
                              value: _currentTime.clamp(0.0, _duration > 0 ? _duration : 1.0),
                              onChangeStart: (_) {
                                _hideControlsTimer?.cancel();
                                _isDragging = true;
                              },
                              onChanged: (val) {
                                setState(() => _currentTime = val);
                              },
                              onChangeEnd: (val) {
                                _seekTo(val);
                                _scheduleAutoHide();
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(_duration),
                        style: TextStyle(
                          color: CupertinoColors.white.withValues(alpha: 0.78),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            minSize: 28,
                            onPressed: _togglePlay,
                            child: Icon(
                              _isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_arrow_solid,
                              color: CupertinoColors.white,
                              size: 18,
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            minSize: 28,
                            onPressed: _stopPlayback,
                            child: const Icon(
                              CupertinoIcons.stop_fill,
                              color: CupertinoColors.white,
                              size: 15,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _cycleSpeed,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: CupertinoColors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_playbackSpeed}x',
                                style: const TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            minSize: 28,
                            onPressed: _toggleMute,
                            child: Icon(
                              _isMuted ? CupertinoIcons.volume_off : CupertinoIcons.volume_up,
                              color: CupertinoColors.white,
                              size: 18,
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            minSize: 28,
                            onPressed: _toggleFullscreen,
                            child: const Icon(
                              CupertinoIcons.fullscreen,
                              color: CupertinoColors.white,
                              size: 17,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
