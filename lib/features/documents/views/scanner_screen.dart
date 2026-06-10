import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/brainup_button.dart';
import '../models/scanner_editor_route_args.dart';
import '../services/scanner_service.dart';
import 'widgets/scanner_overlay.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _camera;
  List<CameraDescription> _cameras = [];

  final List<File> _pages = [];
  bool _flashOn = false;
  bool _edgeDetected = false;
  bool _isCapturing = false;

  bool _isBurstMode = false;
  int _burstCountdown = 0;
  Timer? _burstCountdownTimer;
  Timer? _burstCaptureTimer;
  Timer? _edgeSimTimer;

  late final AnimationController _shutterController;

  @override
  void initState() {
    super.initState();
    _shutterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      await _attachCamera(_cameras.first);
      _startEdgeSimulation();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera unavailable. $e')),
        );
      }
    }
  }

  Future<void> _attachCamera(CameraDescription description) async {
    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await controller.initialize();
    if (_flashOn) {
      await controller.setFlashMode(FlashMode.torch);
    }
    final previous = _camera;
    _camera = controller;
    if (mounted) setState(() {});
    await previous?.dispose();
  }

  void _startEdgeSimulation() {
    // Placeholder edge-detection signal. A future ML pipeline can replace this.
    _edgeSimTimer?.cancel();
    _edgeSimTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _edgeDetected = true);
    });
  }

  @override
  void dispose() {
    _stopBurstMode();
    _edgeSimTimer?.cancel();
    _shutterController.dispose();
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    if (_camera == null || !_camera!.value.isInitialized) return;
    _flashOn = !_flashOn;
    try {
      await _camera!.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
    } catch (_) {
      _flashOn = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _importFromGallery() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 95);
    if (images.isEmpty) return;
    setState(() => _isCapturing = true);
    try {
      for (final pick in images) {
        final filtered = await ScannerService.applyFilter(
          File(pick.path),
          ScanFilter.auto,
        );
        _pages.add(filtered);
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _captureAndAdd() async {
    if (_camera == null || !_camera!.value.isInitialized) return;
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    _shutterController.forward(from: 0).then((_) {
      _shutterController.reverse();
    });
    HapticFeedback.lightImpact();

    try {
      final shot = await _camera!.takePicture();
      final filtered =
          await ScannerService.applyFilter(File(shot.path), ScanFilter.auto);
      if (!mounted) return;
      setState(() {
        _pages.add(filtered);
      });
      HapticFeedback.selectionClick();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed. $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _toggleBurstMode() {
    setState(() => _isBurstMode = !_isBurstMode);
    if (_isBurstMode) {
      _startBurstCycle();
    } else {
      _stopBurstMode();
    }
  }

  void _startBurstCycle() {
    _burstCountdown = 2;
    setState(() {});
    _burstCountdownTimer?.cancel();
    _burstCountdownTimer =
        Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isBurstMode || !mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _burstCountdown =
            _burstCountdown > 0 ? _burstCountdown - 1 : 0;
      });
    });

    _burstCaptureTimer?.cancel();
    _burstCaptureTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
      if (!_isBurstMode || !mounted) {
        t.cancel();
        return;
      }
      await _captureAndAdd();
      if (!mounted || !_isBurstMode) return;
      setState(() => _burstCountdown = 2);
    });
  }

  void _stopBurstMode() {
    _burstCountdownTimer?.cancel();
    _burstCaptureTimer?.cancel();
    _burstCountdownTimer = null;
    _burstCaptureTimer = null;
    if (mounted) {
      setState(() {
        _isBurstMode = false;
        _burstCountdown = 0;
      });
    }
  }

  void _navigateToEditor() {
    if (_pages.isEmpty) return;
    _stopBurstMode();
    final snapshot = List<File>.from(_pages);
    context.push(
      '/documents/scanner-editor',
      extra: ScannerEditorRouteArgs(pages: snapshot, processOnLoad: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.accent;
    final cameraReady = _camera != null && _camera!.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (cameraReady)
            Positioned.fill(child: CameraPreview(_camera!))
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          Positioned.fill(
            child: ScannerOverlay(edgeDetected: _edgeDetected),
          ),
          _ShutterFlash(controller: _shutterController),
          if (_isBurstMode)
            _BurstCountdownOverlay(countdown: _burstCountdown, accent: accent),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopControls(
              flashOn: _flashOn,
              onClose: () {
                _stopBurstMode();
                context.pop();
              },
              onToggleFlash: _toggleFlash,
              onImportGallery: _importFromGallery,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            right: 12,
            child: _BatchModeToggle(
              active: _isBurstMode,
              accent: accent,
              onTap: _toggleBurstMode,
            ),
          ),
          Positioned(
            bottom: 140,
            left: 0,
            right: 0,
            child: _EdgeDetectionBadge(visible: _edgeDetected),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomControls(
              pages: _pages,
              isCapturing: _isCapturing,
              accent: accent,
              onCapture: _captureAndAdd,
              onLongPressCapture: () {
                if (!_isBurstMode) _toggleBurstMode();
              },
              onThumbnailsTap: _navigateToEditor,
              onDone: _navigateToEditor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Top Controls ───────────────────────────────────────────────────────────

class _TopControls extends StatelessWidget {
  final bool flashOn;
  final VoidCallback onClose;
  final VoidCallback onToggleFlash;
  final VoidCallback onImportGallery;

  const _TopControls({
    required this.flashOn,
    required this.onClose,
    required this.onToggleFlash,
    required this.onImportGallery,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        color: Colors.black.withOpacity(0.45),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _CircleIconButton(
              icon: Icons.close_rounded,
              color: Colors.white,
              onTap: onClose,
              tooltip: 'Close',
            ),
            _CircleIconButton(
              icon: flashOn
                  ? Icons.flash_on_rounded
                  : Icons.flash_off_rounded,
              color: flashOn ? context.colors.warning : Colors.white70,
              onTap: onToggleFlash,
              tooltip: 'Flash',
            ),
            _CircleIconButton(
              icon: Icons.photo_library_outlined,
              color: Colors.white,
              onTap: onImportGallery,
              tooltip: 'Import from gallery',
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;

  const _CircleIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = InkResponse(
      onTap: onTap,
      radius: 26,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: color, size: 24),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

// ─── Batch Mode Toggle ──────────────────────────────────────────────────────

class _BatchModeToggle extends StatelessWidget {
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  const _BatchModeToggle({
    required this.active,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? accent.withOpacity(0.85) : Colors.black54,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? accent : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.burst_mode_rounded,
              size: 18,
              color: active ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              active ? 'Auto' : 'Batch',
              style: context.text.labelSmall.copyWith(
                color: active ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Burst Countdown Overlay ────────────────────────────────────────────────

class _BurstCountdownOverlay extends StatelessWidget {
  final int countdown;
  final Color accent;

  const _BurstCountdownOverlay({
    required this.countdown,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Container(
            key: ValueKey(countdown),
            width: 110,
            height: 110,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 3),
            ),
            child: Text(
              countdown > 0 ? '$countdown' : '·',
              style: context.text.display.copyWith(
                color: Colors.white,
                fontSize: 56,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Edge Detection Badge ───────────────────────────────────────────────────

class _EdgeDetectionBadge extends StatelessWidget {
  final bool visible;

  const _EdgeDetectionBadge({required this.visible});

  @override
  Widget build(BuildContext context) {
    final success = context.colors.success;
    return IgnorePointer(
      child: Center(
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: success.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: success.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  'Edge detected',
                  style: context.text.labelSmall.copyWith(
                    color: Colors.white,
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

// ─── Bottom Controls ────────────────────────────────────────────────────────

class _BottomControls extends StatelessWidget {
  final List<File> pages;
  final bool isCapturing;
  final Color accent;
  final VoidCallback onCapture;
  final VoidCallback onLongPressCapture;
  final VoidCallback onThumbnailsTap;
  final VoidCallback onDone;

  const _BottomControls({
    required this.pages,
    required this.isCapturing,
    required this.accent,
    required this.onCapture,
    required this.onLongPressCapture,
    required this.onThumbnailsTap,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 14 + bottomInset),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: pages.isEmpty
                ? const SizedBox.shrink()
                : _ThumbnailStack(
                    pages: pages,
                    accent: accent,
                    onTap: onThumbnailsTap,
                  ),
          ),
          Expanded(
            child: Center(
              child: _CaptureButton(
                accent: accent,
                isCapturing: isCapturing,
                onTap: onCapture,
                onLongPress: onLongPressCapture,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: pages.isEmpty
                  ? const SizedBox.shrink()
                  : BrainUpButton.small(
                      label: 'Done',
                      onTap: onDone,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbnailStack extends StatelessWidget {
  final List<File> pages;
  final Color accent;
  final VoidCallback onTap;

  const _ThumbnailStack({
    required this.pages,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final visible = pages.length > 3 ? pages.sublist(pages.length - 3) : pages;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 60,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (int i = 0; i < visible.length; i++)
              Positioned(
                left: i * 6.0,
                top: i * 6.0,
                child: Container(
                  width: 44,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.file(
                      visible[i],
                      width: 44,
                      height: 56,
                      fit: BoxFit.cover,
                      cacheWidth: 88,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: (visible.length - 1) * 6.0 + 32,
              top: (visible.length - 1) * 6.0 - 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 22),
                child: Text(
                  '${pages.length}',
                  textAlign: TextAlign.center,
                  style: context.text.labelSmall
                      .copyWith(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final Color accent;
  final bool isCapturing;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CaptureButton({
    required this.accent,
    required this.isCapturing,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isCapturing ? null : onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.4),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: isCapturing ? 48 : 58,
            height: isCapturing ? 48 : 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
            ),
            child: isCapturing
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

// ─── Shutter Flash Overlay ──────────────────────────────────────────────────

class _ShutterFlash extends StatelessWidget {
  final AnimationController controller;
  const _ShutterFlash({required this.controller});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) => Positioned.fill(
          child: Opacity(
            opacity: controller.value * 0.85,
            child: Container(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
