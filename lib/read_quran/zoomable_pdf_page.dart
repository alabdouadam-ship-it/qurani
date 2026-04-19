import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:qurani/services/mushaf_pdf_service.dart';

/// Single PDF page rendered with pinch-zoom, double-tap zoom, and a
/// paper-toned background that blends the unused vertical margins.
///
/// Previously the private `_ZoomablePdfPage` inside
/// `read_quran_screen.dart`.
class ZoomablePdfPage extends StatefulWidget {
  const ZoomablePdfPage({
    super.key,
    required this.document,
    required this.pageNumber,
    required this.isFullscreen,
    required this.mushafType,
    this.onZoomChanged,
    this.onLongPress,
  });

  final PdfDocument document;
  final int pageNumber;
  final ValueChanged<bool>? onZoomChanged;
  final bool isFullscreen;
  final MushafType mushafType;
  final VoidCallback? onLongPress;

  @override
  State<ZoomablePdfPage> createState() => _ZoomablePdfPageState();
}

class _ZoomablePdfPageState extends State<ZoomablePdfPage>
    with AutomaticKeepAliveClientMixin {
  final TransformationController _transformationController =
      TransformationController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ZoomablePdfPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset transformation when page number changes.
    if (oldWidget.pageNumber != widget.pageNumber) {
      // Use post-frame callback to ensure the widget tree is stable.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _transformationController.value = Matrix4.identity();
          if (widget.onZoomChanged != null) {
            widget.onZoomChanged!(false);
          }
        }
      });
    }
  }

  void _checkZoomState() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final isZoomed = scale > 1.05;
    if (widget.onZoomChanged != null) {
      widget.onZoomChanged!(isZoomed);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;
    final pdfPageInfo = widget.document.pages[widget.pageNumber - 1];

    // In landscape, scale up the PDF to make it more readable.
    final double scale = isLandscape ? 2.8 : 1.0;

    // Always center the page perfectly to balance top and bottom margins.
    const pageAlignment = Alignment.center;

    // Paper background color chosen to blend unused vertical space.
    final Color paperColor;
    switch (widget.mushafType) {
      case MushafType.blue:
      case MushafType.green:
        paperColor = const Color(0xFFFDF7E5);
        break;
      case MushafType.tajweed:
        paperColor = const Color(0xFFF9F6EB);
        break;
    }

    return GestureDetector(
      onLongPress: widget.onLongPress,
      onDoubleTap: () {
        final currentScale =
            _transformationController.value.getMaxScaleOnAxis();

        if (currentScale > 1.5) {
          _transformationController.value = Matrix4.identity();
        } else {
          // Zoom in to 2.5x, positioned at top-right for RTL content.
          const targetScale = 2.5;

          final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final size = renderBox.size;
            final xTranslation = -(size.width * (targetScale - 1));
            const yTranslation = 0.0;

            _transformationController.value = Matrix4.identity()
              ..setTranslationRaw(xTranslation, yTranslation, 0)
              ..multiply(Matrix4.diagonal3Values(
                  targetScale, targetScale, targetScale));
          } else {
            _transformationController.value = Matrix4.identity()
              ..multiply(Matrix4.diagonal3Values(
                  targetScale, targetScale, targetScale));
          }
        }

        _checkZoomState();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Proportional scale to fill more width without breaking the
          // vertical bounds — pick the smaller axis ratio to guarantee
          // no clipping, then pad slightly up when we have vertical
          // headroom.
          final double fitWidthScale =
              constraints.maxWidth > 0 && pdfPageInfo.width > 0
                  ? (constraints.maxWidth / pdfPageInfo.width)
                  : 1.0;

          final double fitHeightScale =
              constraints.maxHeight > 0 && pdfPageInfo.height > 0
                  ? (constraints.maxHeight / pdfPageInfo.height)
                  : 1.0;

          final double portraitFullscreenScale =
              widget.isFullscreen && !isLandscape
                  ? (fitWidthScale < fitHeightScale
                          ? fitWidthScale
                          : fitHeightScale * 1.05)
                      .clamp(1.0, 1.3)
                  : 1.0;

          final pdfPage = SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: PdfPageView(
              document: widget.document,
              pageNumber: widget.pageNumber,
              alignment: pageAlignment,
            ),
          );

          final zoomableChild = isLandscape
              ? Transform.scale(
                  scale: scale,
                  alignment: pageAlignment,
                  child: pdfPage,
                )
              : Transform.scale(
                  scale: portraitFullscreenScale,
                  alignment: pageAlignment,
                  child: pdfPage,
                );

          return ClipRect(
            child: ColoredBox(
              color: paperColor,
              child: InteractiveViewer(
                transformationController: _transformationController,
                boundaryMargin: EdgeInsets.zero,
                minScale: widget.isFullscreen && !isLandscape
                    ? 0.9
                    : (isLandscape ? 0.5 : 1.0),
                maxScale: 4.0,
                panEnabled: true,
                scaleEnabled: true,
                onInteractionUpdate: (_) => _checkZoomState(),
                onInteractionEnd: (_) => _checkZoomState(),
                child: zoomableChild,
              ),
            ),
          );
        },
      ),
    );
  }
}
