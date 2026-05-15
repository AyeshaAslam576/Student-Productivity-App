import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../viewmodels/ai_viewmodel.dart';

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
  bool _isSpeaking = false;
  int _start = 0;
  int _end = 0;

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
        _start = start;
        _end = end;
      });
    });
    _tts.setStartHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = true);
    });
    _tts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
      if (_textCtrl.text.trim().isNotEmpty) {
        context.read<AiViewModel>().saveTtsSession(
          input: _textCtrl.text.trim(),
          metadata: {'speed': _speed, 'voice': _selectedVoiceName ?? ''},
        );
      }
    });
    _tts.setCancelHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
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

  Future<void> _play() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
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
    await _tts.speak(text);
  }

  Future<void> _pause() async {
    await _tts.pause();
    if (!mounted) return;
    setState(() => _isSpeaking = false);
  }

  Future<void> _stop() async {
    await _tts.stop();
    if (!mounted) return;
    setState(() => _isSpeaking = false);
    await context.read<AiViewModel>().saveTtsSession(
          input: _textCtrl.text.trim(),
          metadata: {
            'speed': _speed,
            'voice': _selectedVoiceName ?? '',
          },
        );
  }

  @override
  void dispose() {
    _tts.stop();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _textCtrl.text;
    final safeStart = _start.clamp(0, text.length);
    final safeEnd = _end.clamp(safeStart, text.length);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Text to Speech', style: AppTextStyles.h4),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textCtrl,
              maxLines: 8,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: 'Paste text to listen...',
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (text.isNotEmpty)
              RichText(
                text: TextSpan(
                  style: AppTextStyles.body,
                  children: [
                    TextSpan(text: text.substring(0, safeStart)),
                    TextSpan(
                      text: text.substring(safeStart, safeEnd),
                      style: AppTextStyles.body.copyWith(
                        backgroundColor: AppColors.accent.withOpacity(0.24),
                      ),
                    ),
                    TextSpan(text: text.substring(safeEnd)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Speed: ${_speed.toStringAsFixed(1)}x',
                    style: AppTextStyles.bodySmall),
              ],
            ),
            Slider(
              value: _speed,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              onChanged: (value) async {
                setState(() => _speed = value);
                await _tts.setSpeechRate(_speed * 0.5);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedVoiceName,
              decoration: const InputDecoration(
                labelText: 'Voice (English)',
                filled: true,
                fillColor: AppColors.surfaceElevated,
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
              onChanged: (value) => setState(() => _selectedVoiceName = value),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: _isSpeaking ? 'Playing...' : 'Play',
                    icon: Icons.play_arrow_rounded,
                    gradient: AppColors.accentGradient,
                    onTap: _play,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    label: 'Pause',
                    icon: Icons.pause_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D4B68), Color(0xFF146A8F)],
                    ),
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
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.button.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
