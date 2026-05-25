import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../data/repositories/invites_repository.dart';
import '../../core/colors.dart';
import '../../core/routes.dart';
import '../../core/spacing.dart';

// Ninho — Fase 4.6: leitura de QR Code de convite via câmera.
//
// Fluxo:
//   1. MobileScanner pede permissão de câmera no primeiro `start()`.
//   2. Cada frame com QR decodificado é submetido a `_handleDetection`.
//   3. Aceita apenas QRs no formato esperado de link (`/i/<token>`); ignora
//      texto livre, vCard, URLs alheias. `InvitesRepository.tokenFromLink`
//      centraliza o parse.
//   4. Ao casar, navega pra `/i/:token` e a tela de Accept lida com preview
//      + estado expirado/revogado/usado.
//
// Detector é registrado de forma defensiva: `_handled` evita rotear duas
// vezes se a câmera emitir o mesmo QR em frames consecutivos.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key, this.controller, this.tokenParser});

  final MobileScannerController? controller;
  // Injetável p/ testes — default usa InvitesRepository.tokenFromLink.
  final String? Function(String raw)? tokenParser;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  late final MobileScannerController _controller;
  bool _handled = false;
  String? _hint;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        MobileScannerController(
          formats: const [BarcodeFormat.qrCode],
          detectionSpeed: DetectionSpeed.normal,
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetection(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;
    final parser = widget.tokenParser ?? InvitesRepository.tokenFromLink;
    final token = parser(raw);
    if (token == null) {
      // QR não-Ninho — não roteia, só sinaliza.
      if (!mounted) return;
      setState(() {
        _hint = 'Esse QR não é um convite do Ninho.';
      });
      return;
    }
    _handled = true;
    _controller.stop();
    context.go('${NinhoRoutes.acceptInvite}/$token');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          key: const Key('qr_scan_back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(NinhoRoutes.home),
        ),
        title: Text(
          'Escanear convite',
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            key: const Key('qr_scan_camera'),
            controller: _controller,
            onDetect: _handleDetection,
            errorBuilder: (_, error) => _PermissionDenied(error: error),
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: _ViewfinderPainter(),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 56,
            child: Column(
              children: [
                if (_hint != null) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: NinhoSpacing.marginMobile,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(NinhoRadii.lg),
                    ),
                    child: Text(
                      _hint!,
                      key: const Key('qr_scan_hint'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: NinhoSpacing.stackSm),
                ],
                Text(
                  'Aponte para o QR do convite',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionDenied extends StatelessWidget {
  const _PermissionDenied({required this.error});
  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Liberar a câmera nas configurações p/ ler o QR.',
      MobileScannerErrorCode.unsupported =>
        'Esse dispositivo não suporta leitura de QR.',
      _ => 'Não foi possível abrir a câmera agora.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NinhoSpacing.marginMobile),
        child: Text(
          message,
          key: const Key('qr_scan_error'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final boxSide = size.shortestSide * 0.7;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: boxSide,
      height: boxSide,
    );
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(24)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlay);

    final border = Paint()
      ..color = NinhoColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(24)),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
