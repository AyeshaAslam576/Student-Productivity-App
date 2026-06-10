import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/navigation/back_navigation.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/brainup_button.dart';
import '../../../core/widgets/brainup_text_field.dart';
import 'widgets/scanner_overlay.dart';

class QrScreen extends StatefulWidget {
  const QrScreen({super.key});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _input = TextEditingController();
  final _qrKey = GlobalKey();
  String _scanResult = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _shareQr() async {
    final boundary =
        _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return;
    final dir = Directory.systemTemp;
    final file = File('${dir.path}/brainup_qr.png');
    await file.writeAsBytes(data.buffer.asUint8List());
    await Share.shareXFiles([XFile(file.path)]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        automaticallyImplyLeading: false,
        leading: brainUpBackButton(context,
            fallback: '/documents',
            iconColor: context.colors.textPrimary),
        title: const Text('QR Tools'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: 'GENERATE'), Tab(text: 'SCAN')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              BrainUpTextField(
                  label: 'Enter text / URL',
                  controller: _input,
                  onChanged: (_) => setState(() {})),
              const SizedBox(height: 16),
              Center(
                child: RepaintBoundary(
                  key: _qrKey,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: QrImageView(
                      data: _input.text.isEmpty ? 'BrainUp' : _input.text,
                      size: 220,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: BrainUpButton.secondary(
                      label: 'Copy',
                      onTap: () =>
                          Clipboard.setData(ClipboardData(text: _input.text)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: BrainUpButton(label: 'Share', onTap: _shareQr)),
                ],
              ),
            ],
          ),
          Stack(
            children: [
              MobileScanner(
                onDetect: (capture) {
                  final raw = capture.barcodes.first.rawValue ?? '';
                  if (raw.isEmpty || raw == _scanResult) return;
                  setState(() => _scanResult = raw);
                },
              ),
              const Positioned.fill(child: ScannerOverlay()),
              if (_scanResult.isNotEmpty)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceCard,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Detected', style: context.text.caption),
                        const SizedBox(height: 4),
                        Text(_scanResult,
                            maxLines: 4, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: BrainUpButton.small(
                                label: 'Copy',
                                onTap: () => Clipboard.setData(
                                    ClipboardData(text: _scanResult)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: BrainUpButton.small(
                                label: 'Scan another',
                                onTap: () => setState(() => _scanResult = ''),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
