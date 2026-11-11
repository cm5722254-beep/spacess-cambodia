import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../services/theme_service.dart';

class VoiceMessageBubble extends StatefulWidget {
  final String audioUrl;
  final int durationSec;
  final bool isMe;

  const VoiceMessageBubble({
    super.key,
    required this.audioUrl,
    required this.durationSec,
    required this.isMe,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  html.AudioElement? _audio;
  bool _isPlaying = false;
  double _progress = 0.0;
  int _currentSec = 0;
  double _speed = 1.0;
  StreamSubscription? _timeSub;
  StreamSubscription? _endSub;

  @override
  void initState() {
    super.initState();
    if (kIsWeb && widget.audioUrl.isNotEmpty) {
      _audio = html.AudioElement(widget.audioUrl);
      _audio!.preload = 'metadata';
      _timeSub = _audio!.onTimeUpdate.listen((_) {
        if (!mounted || _audio == null) return;
        final dur = (_audio!.duration.isNaN || _audio!.duration <= 0)
            ? (widget.durationSec > 0 ? widget.durationSec.toDouble() : 1.0)
            : _audio!.duration;
        final cur = _audio!.currentTime;
        setState(() {
          _currentSec = cur.floor();
          _progress = (cur / dur).clamp(0.0, 1.0);
        });
      });
      _endSub = _audio!.onEnded.listen((_) {
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _progress = 0.0;
          _currentSec = 0;
        });
      });
    }
  }

  @override
  void dispose() {
    _timeSub?.cancel();
    _endSub?.cancel();
    _audio?.pause();
    super.dispose();
  }

  void _togglePlay() {
    if (_audio == null) return;
    if (_isPlaying) {
      _audio!.pause();
      setState(() => _isPlaying = false);
    } else {
      _audio!.playbackRate = _speed;
      _audio!.play();
      setState(() => _isPlaying = true);
    }
  }

  void _toggleSpeed() {
    if (_audio == null) return;
    setState(() {
      _speed = _speed == 1.0 ? 1.5 : 1.0;
      _audio!.playbackRate = _speed;
    });
  }

  void _seekFraction(double fraction) {
    if (_audio == null) return;
    final dur = (_audio!.duration.isNaN || _audio!.duration <= 0)
        ? (widget.durationSec > 0 ? widget.durationSec.toDouble() : 1.0)
        : _audio!.duration;
    final nextTime = (dur * fraction.clamp(0.0, 1.0));
    _audio!.currentTime = nextTime;
    setState(() {
      _progress = fraction.clamp(0.0, 1.0);
      _currentSec = nextTime.floor();
    });
  }

  String _formatSec(int s) {
    final m = s ~/ 60;
    final rem = s % 60;
    return '$m:${rem.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.isMe ? CupertinoColors.white : const Color(0xFF007AFF);
    final bgWave = widget.isMe
        ? CupertinoColors.white.withOpacity(0.35)
        : const Color(0xFF007AFF).withOpacity(0.2);

    final bars = [8.0, 14.0, 20.0, 12.0, 22.0, 16.0, 10.0, 18.0, 14.0, 20.0, 11.0, 15.0, 9.0, 17.0];
    final activeBars = (_progress * bars.length).round();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: widget.isMe ? CupertinoColors.white.withOpacity(0.22) : const Color(0xFF007AFF).withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
              color: fg,
              size: 16,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(bars.length, (i) {
            final isLit = i < activeBars || (_isPlaying && i == activeBars);
            return GestureDetector(
              onTap: () => _seekFraction((i + 0.5) / bars.length),
              child: Container(
                width: 3,
                height: bars[i],
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: isLit ? fg : bgWave,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(width: 8),
        Text(
          _isPlaying ? _formatSec(_currentSec) : _formatSec(widget.durationSec > 0 ? widget.durationSec : 1),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: widget.isMe ? CupertinoColors.white.withOpacity(0.9) : AppTheme.secondaryText,
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: _toggleSpeed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: widget.isMe ? CupertinoColors.white.withOpacity(0.22) : const Color(0xFF007AFF).withOpacity(0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _speed == 1.0 ? '1x' : '1.5x',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

