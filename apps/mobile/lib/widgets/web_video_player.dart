import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui_web;

class WebVideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool isLooping;
  final bool showControls;
  final BoxFit fit;

  const WebVideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.autoPlay = true,
    this.isLooping = true,
    this.showControls = true,
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

  final List<double> _speeds = [1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.autoPlay;
    _viewId = 'video-view-${DateTime.now().microsecondsSinceEpoch}-${widget.videoUrl.hashCode}';

    if (kIsWeb) {
      ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
        final video = html.VideoElement()
          ..src = widget.videoUrl
          ..autoplay = widget.autoPlay
          ..loop = widget.isLooping
          ..controls = false // Custom responsive Cupertino overlay controls
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
          if (mounted) setState(() => _isPlaying = true);
        });

        video.onPause.listen((e) {
          if (mounted) setState(() => _isPlaying = false);
        });

        _videoElement = video;
        return video;
      });
    }
  }

  @override
  void dispose() {
    _videoElement?.pause();
    _videoElement?.removeAttribute('src');
    _videoElement?.load();
    super.dispose();
  }

  void _togglePlay() {
    if (_videoElement == null) return;
    if (_videoElement!.paused) {
      _videoElement!.play();
      setState(() => _isPlaying = true);
    } else {
      _videoElement!.pause();
      setState(() => _isPlaying = false);
    }
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
        // Native HTML5 Video Element
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              setState(() => _showControlsOverlay = !_showControlsOverlay);
            },
            child: HtmlElementView(viewType: _viewId),
          ),
        ),

        // Controls Overlay (Timeline Scrubber / Speed / Mute / Fullscreen)
        if (widget.showControls && _showControlsOverlay)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.85),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Scrubber Timeline Scope Slider
                  Row(
                    children: [
                      Text(
                        _formatTime(_currentTime),
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CupertinoSlider(
                          min: 0.0,
                          max: _duration > 0 ? _duration : 1.0,
                          value: _currentTime.clamp(0.0, _duration > 0 ? _duration : 1.0),
                          activeColor: const Color(0xFF007AFF),
                          thumbColor: CupertinoColors.white,
                          onChangeStart: (_) => _isDragging = true,
                          onChanged: (val) {
                            setState(() => _currentTime = val);
                          },
                          onChangeEnd: _seekTo,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(_duration),
                        style: TextStyle(
                          color: CupertinoColors.white.withOpacity(0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  // Bottom Controls Row: Play/Pause, Speed Chip, Mute, Fullscreen
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Play / Pause
                      CupertinoButton(
                        padding: const EdgeInsets.all(6),
                        onPressed: _togglePlay,
                        child: Icon(
                          _isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_arrow_solid,
                          color: CupertinoColors.white,
                          size: 22,
                        ),
                      ),

                      Row(
                        children: [
                          // Speed Selector (0.5x, 1x, 1.25x, 1.5x, 2x)
                          GestureDetector(
                            onTap: _cycleSpeed,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: CupertinoColors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_playbackSpeed}x',
                                style: const TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),

                          // Mute / Unmute
                          CupertinoButton(
                            padding: const EdgeInsets.all(6),
                            onPressed: _toggleMute,
                            child: Icon(
                              _isMuted ? CupertinoIcons.volume_off : CupertinoIcons.volume_up,
                              color: CupertinoColors.white,
                              size: 20,
                            ),
                          ),

                          // Fullscreen
                          CupertinoButton(
                            padding: const EdgeInsets.all(6),
                            onPressed: _toggleFullscreen,
                            child: const Icon(
                              CupertinoIcons.fullscreen,
                              color: CupertinoColors.white,
                              size: 20,
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
