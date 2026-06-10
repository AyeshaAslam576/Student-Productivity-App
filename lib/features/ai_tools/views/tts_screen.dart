import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../../../core/navigation/back_navigation.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../viewmodels/ai_viewmodel.dart';

enum _TtsPlaybackState { idle, playing, paused }

class TtsScreen extends StatefulWidget {
  const TtsScreen({super.key});

  @override
  State<TtsScreen> createState() => _TtsScreenState();
}

class _TtsScreenState extends State<TtsScreen> {
  final _textCtrl = TextEditingController();
  final FlutterTts _tts = FlutterTts();
  double _speed = 1.0;
  List<Map<String, String>> _voices = [];
  String? _selectedVoiceName;
  _TtsPlaybackState _playback = _TtsPlaybackState.idle;
  /// Character offset in full text (Android resets progress after pause).
  int _baseOffset = 0;
  int _start = 0;
  int _end = 0;

  bool get _isPlaying => _playback == _TtsPlaybackState.playing;
  bool get _isPaused => _playback == _TtsPlaybackState.paused;
  bool get _isActive => _isPlaying || _isPaused;

  bool get _useProgressOffset => !kIsWeb && Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setSpeechRate(_speed * 0.5);
    await _tts.setLanguage('en-US');
    _tts.setProgressHandler((_, start, end, __) {
      if (!mounted) return;
      setState(() {
        if (_useProgressOffset) {
          _start = _baseOffset + start;
          _end = _baseOffset + end;
        } else {
          _start = start;
          _end = end;
        }
      });
    });
    _tts.setStartHandler(() {
      if (!mounted) return;
      setState(() => _playback = _TtsPlaybackState.playing);
    });
    _tts.setContinueHandler(() {
      if (!mounted) return;
      setState(() => _playback = _TtsPlaybackState.playing);
    });
    _tts.setPauseHandler(() {
      if (!mounted) return;
      final text = _textCtrl.text;
      setState(() {
        if (_useProgressOffset) {
          _baseOffset = _start.clamp(0, text.length);
        }
        _playback = _TtsPlaybackState.paused;
      });
    });
    _tts.setCompletionHandler(() {
      if (!mounted) return;
      _resetPlayback(highlightAtEnd: true);
      if (_textCtrl.text.trim().isNotEmpty) {
        context.read<AiViewModel>().saveTtsSession(
              input: _textCtrl.text.trim(),
              metadata: {'speed': _speed, 'voice': _selectedVoiceName ?? ''},
            );
      }
    });
    _tts.setCancelHandler(() {
      if (!mounted) return;
      if (_playback != _TtsPlaybackState.paused) {
        _resetPlayback();
      }
    });

    final dynamic voicesRaw = await _tts.getVoices;
    final list = (voicesRaw as List)
        .map((v) => Map<String, dynamic>.from(v as Map))
        .where((v) =>
            '${v['locale'] ?? ''}'.toLowerCase().startsWith('en') ||
            '${v['name'] ?? ''}'.toLowerCase().contains('english'))
        .map((v) => {
              'name': '${v['name']}',
              'locale': '${v['locale']}',
            })
        .toList();
    if (!mounted) return;
    setState(() {
      _voices = list;
      if (_voices.isNotEmpty) {
        _selectedVoiceName = _voices.first['name'];
      }
    });
  }

  void _resetPlayback({bool highlightAtEnd = false}) {
    final len = _textCtrl.text.length;
    setState(() {
      _playback = _TtsPlaybackState.idle;
      _baseOffset = 0;
      if (highlightAtEnd && len > 0) {
        _start = len;
        _end = len;
      } else {
        _start = 0;
        _end = 0;
      }
    });
  }

  Future<void> _applyVoiceAndRate() async {
    if (_selectedVoiceName != null) {
      final selected = _voices.firstWhere(
        (v) => v['name'] == _selectedVoiceName,
        orElse: () => {'name': _selectedVoiceName!, 'locale': 'en-US'},
      );
      await _tts.setVoice({
        'name': selected['name'] ?? _selectedVoiceName!,
        'locale': selected['locale'] ?? 'en-US',
      });
    }
    await _tts.setSpeechRate(_speed * 0.5);
  }

  Future<void> _play() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    if (_isPlaying) return;

    await _applyVoiceAndRate();
    if (_isPaused) {
      await _tts.speak(text);
      return;
    }

    setState(() {
      _baseOffset = 0;
      _start = 0;
      _end = 0;
    });
    await _tts.speak(text);
  }

  Future<void> _resume() async {
    if (!_isPaused) return;
    await _play();
  }

  Future<void> _pause() async {
    if (!_isPlaying) return;
    await _tts.pause();
    if (!mounted) return;
    setState(() {
      if (_useProgressOffset) {
        _baseOffset = _start.clamp(0, _textCtrl.text.length);
      }
      _playback = _TtsPlaybackState.paused;
    });
  }

  Future<void> _stop() async {
    await _tts.stop();
    if (!mounted) return;
    _resetPlayback();
    if (_textCtrl.text.trim().isNotEmpty) {
      await context.read<AiViewModel>().saveTtsSession(
            input: _textCtrl.text.trim(),
            metadata: {
              'speed': _speed,
              'voice': _selectedVoiceName ?? '',
            },
          );
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = _textCtrl.text;
    final safeStart = _start.clamp(0, text.length);
    final safeEnd = _end.clamp(safeStart, text.length);

    final playEnabled = !_isPlaying && !_isPaused && text.trim().isNotEmpty;
    final pauseEnabled = _isPlaying;
    final resumeEnabled = _isPaused;
    final stopEnabled = _isActive;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        automaticallyImplyLeading: false,
        leading: brainUpBackButton(
          context,
          fallback: brainupAiToolsFallback,
          iconColor: colors.textPrimary,
        ),
        title: Text('Text to Speech', style: context.text.h4),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textCtrl,
              maxLines: 8,
              enabled: !_isActive,
              style: context.text.body,
              decoration: InputDecoration(
                hintText: 'Paste text to listen...',
                filled: true,
                fillColor: colors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.surfaceBorder),
                ),
              ),
              onChanged: (_) {
                if (_isActive) return;
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            if (text.isNotEmpty)
              RichText(
                text: TextSpan(
                  style: context.text.body,
                  children: [
                    TextSpan(text: text.substring(0, safeStart)),
                    TextSpan(
                      text: text.substring(safeStart, safeEnd),
                      style: context.text.body.copyWith(
                        backgroundColor: colors.accent.withValues(alpha: 0.24),
                        color: _isPaused ? colors.warning : null,
                        fontWeight:
                            _isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    TextSpan(text: text.substring(safeEnd)),
                  ],
                ),
              ),
            if (_isPaused) ...[
              const SizedBox(height: 8),
              Text(
                'Paused — tap Resume to continue from the highlighted word.',
                style: context.text.caption.copyWith(color: colors.warning),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Speed: ${_speed.toStringAsFixed(1)}x',
                    style: context.text.bodySmall),
              ],
            ),
            Slider(
              value: _speed,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              onChanged: _isActive
                  ? null
                  : (value) async {
                      setState(() => _speed = value);
                      await _tts.setSpeechRate(_speed * 0.5);
                    },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedVoiceName,
              decoration: InputDecoration(
                labelText: 'Voice (English)',
                filled: true,
                fillColor: colors.surfaceElevated,
              ),
              items: _voices
                  .map((voice) => DropdownMenuItem<String>(
                        value: voice['name'],
                        child: Text(
                          '${voice['name']} (${voice['locale']})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: _isActive
                  ? null
                  : (value) => setState(() => _selectedVoiceName = value),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: _isPlaying ? 'Playing…' : 'Play',
                    icon: Icons.play_arrow_rounded,
                    gradient: colors.accentGradient,
                    enabled: playEnabled,
                    onTap: _play,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _isPaused
                      ? _ActionButton(
                          label: 'Resume',
                          icon: Icons.play_circle_outline_rounded,
                          gradient: LinearGradient(
                            colors: [
                              colors.success,
                              colors.success.withValues(alpha: 0.75),
                            ],
                          ),
                          enabled: resumeEnabled,
                          onTap: _resume,
                        )
                      : _ActionButton(
                          label: 'Pause',
                          icon: Icons.pause_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0D4B68), Color(0xFF146A8F)],
                          ),
                          enabled: pauseEnabled,
                          onTap: _pause,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    label: 'Stop',
                    icon: Icons.stop_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1C5E7E), Color(0xFF0A2D45)],
                    ),
                    enabled: stopEnabled,
                    onTap: _stop,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Gradient gradient;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            height: 48,
            decoration: BoxDecoration(
              gradient: enabled ? gradient : LinearGradient(
                colors: [
                  Colors.grey.shade700,
                  Colors.grey.shade800,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.button.copyWith(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
