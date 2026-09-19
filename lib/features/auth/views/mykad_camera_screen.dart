import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';

class MyKadCameraScreen extends StatefulWidget {
  const MyKadCameraScreen({super.key});

  @override
  State<MyKadCameraScreen> createState() => _MyKadCameraScreenState();
}

class _MyKadCameraScreenState extends State<MyKadCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Object? _cameraError;
  bool _initializing = true;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      final controller = _controller;
      _controller = null;
      unawaited(controller?.dispose());
      return;
    }
    if (state == AppLifecycleState.resumed && _controller == null) {
      unawaited(_initializeCamera());
    }
  }

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _initializing = true;
        _cameraError = null;
      });
    }

    CameraController? nextController;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no-camera', 'No camera is available.');
      }
      final rearCameras = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      final selectedCamera = rearCameras.isNotEmpty
          ? rearCameras.first
          : cameras.first;
      nextController = CameraController(
        selectedCamera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await nextController.initialize();
      try {
        await nextController.setFlashMode(FlashMode.off);
        await nextController.setFocusMode(FocusMode.auto);
      } on CameraException {
        // Some devices do not expose flash or focus controls. The initialized
        // camera remains usable and the user can still capture the MyKad.
      }

      if (!mounted) {
        await nextController.dispose();
        return;
      }
      final previousController = _controller;
      setState(() {
        _controller = nextController;
        _initializing = false;
      });
      if (previousController != null && previousController != nextController) {
        await previousController.dispose();
      }
    } catch (error) {
      await nextController?.dispose();
      if (!mounted) return;
      setState(() {
        _controller = null;
        _cameraError = error;
        _initializing = false;
      });
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _capturing) {
      return;
    }

    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      setState(() => _capturing = false);
      Navigator.pop(context, file);
    } on CameraException {
      if (!mounted) return;
      setState(() => _capturing = false);
      final settings = context.read<SettingsProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settings.t('Gambar tidak dapat diambil. Sila cuba semula.'),
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller != null && controller.value.isInitialized)
              _CameraPreviewSurface(controller: controller)
            else
              _CameraLoadingOrError(
                initializing: _initializing,
                error: _cameraError,
                onRetry: _initializeCamera,
              ),
            if (controller != null && controller.value.isInitialized)
              const MyKadCameraAlignmentGuide(),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton.filledTonal(
                key: const Key('close-mykad-camera-button'),
                onPressed: _capturing ? null : () => Navigator.pop(context),
                tooltip: settings.t('BATAL'),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: SizedBox(
                height: 54,
                child: FilledButton.icon(
                  key: const Key('capture-mykad-button'),
                  onPressed:
                      controller != null &&
                          controller.value.isInitialized &&
                          !_capturing
                      ? _capture
                      : null,
                  icon: _capturing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_rounded),
                  label: Text(
                    settings.t(_capturing ? 'MEMPROSES...' : 'AMBIL GAMBAR'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraPreviewSurface extends StatelessWidget {
  const _CameraPreviewSurface({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return const ColoredBox(color: Colors.black);
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: isPortrait ? previewSize.height : previewSize.width,
          height: isPortrait ? previewSize.width : previewSize.height,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class MyKadCameraAlignmentGuide extends StatelessWidget {
  const MyKadCameraAlignmentGuide({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth > constraints.maxHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(
                key: Key('mykad-camera-alignment-frame'),
                painter: MyKadCameraOverlayPainter(),
              ),
              Positioned(
                top: isLandscape ? 8 : 68,
                left: isLandscape ? 88 : 24,
                right: isLandscape ? 88 : 24,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: isLandscape ? 8 : 12,
                    ),
                    child: Column(
                      children: [
                        Text(
                          settings.t('Selaraskan MyKad di dalam bingkai'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          settings.t(
                            'Pastikan keempat-empat penjuru kelihatan, teks jelas dan tiada silau sebelum mengambil gambar.',
                          ),
                          textAlign: TextAlign.center,
                          maxLines: isLandscape ? 2 : null,
                          overflow: TextOverflow.fade,
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class MyKadCameraOverlayPainter extends CustomPainter {
  const MyKadCameraOverlayPainter();

  static const double cardAspectRatio = 1.586;

  @override
  void paint(Canvas canvas, Size size) {
    final maximumWidth = size.width * 0.9;
    final maximumHeight = size.height * 0.46;
    final frameWidth = math.min(maximumWidth, maximumHeight * cardAspectRatio);
    final frameHeight = frameWidth / cardAspectRatio;
    final isLandscape = size.width > size.height;
    final frameCentre = Offset(
      size.width / 2,
      size.height * (isLandscape ? 0.55 : 0.48),
    );
    final frameRect = Rect.fromCenter(
      center: frameCentre,
      width: frameWidth,
      height: frameHeight,
    );
    final frame = RRect.fromRectAndRadius(
      frameRect,
      Radius.circular(frameHeight * 0.055),
    );

    final shadePath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(frame);
    canvas.drawPath(
      shadePath,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant MyKadCameraOverlayPainter oldDelegate) => false;
}

class _CameraLoadingOrError extends StatelessWidget {
  const _CameraLoadingOrError({
    required this.initializing,
    required this.error,
    required this.onRetry,
  });

  final bool initializing;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    if (initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              settings.t(
                'Kamera tidak dapat dibuka. Semak kebenaran kamera dan cuba semula.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('retry-mykad-camera-button'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(settings.t('CUBA SEMULA')),
            ),
          ],
        ),
      ),
    );
  }
}
