import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/theme.dart';
import 'models/inventory_item.dart';

class DigitalCatalogScreen extends StatefulWidget {
  final List<InventoryItem> items;
  final String empresa;
  final String telefono;

  const DigitalCatalogScreen({
    super.key,
    required this.items,
    required this.empresa,
    required this.telefono,
  });

  @override
  State<DigitalCatalogScreen> createState() => _DigitalCatalogScreenState();
}

class _DigitalCatalogScreenState extends State<DigitalCatalogScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  final GlobalKey _shareImageButtonKey = GlobalKey();

  List<InventoryItem> get publicItems => widget.items.where((i) => i.isPublic).toList();

  Future<void> _shareAsImage() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final Uint8List? image = await _screenshotController.captureFromWidget(
        _buildCatalogTemplateForCapture(),
        delay: const Duration(milliseconds: 200),
        pixelRatio: 2.0,
      );

      if (image != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = await File('${directory.path}/catalogo_rentafest.png').create();
        await imagePath.writeAsBytes(image);

        if (mounted) {
          Navigator.pop(context);
          // iOS cancela el share sheet si se presenta mientras el dialog
          // aún está animando su salida. Esperamos a que termine.
          await Future.delayed(const Duration(milliseconds: 400));
        }

        if (mounted) {
          final box = _shareImageButtonKey.currentContext?.findRenderObject() as RenderBox?;
          final origin = box != null
              ? box.localToGlobal(Offset.zero) & box.size
              : const Rect.fromLTWH(0, 400, 200, 50);
          await Share.shareXFiles(
            [XFile(imagePath.path)],
            text: 'Nuestro Catálogo de Artículos - RentaFest',
            sharePositionOrigin: origin,
          );
        }
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('Error al generar imagen: $e');
    }
  }

  Future<void> _shareAsPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('CATÁLOGO DE ARTÍCULOS', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.Text(widget.empresa, style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.SizedBox(height: 30),
          // Listado tipo Menú en lugar de Cards
          ...publicItems.map((item) {
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 12),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(item.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      pw.Text(item.category, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                    ],
                  ),
                  pw.Text('\$${item.price.toInt()} / evento', 
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blueAccent700)
                  ),
                ],
              ),
            );
          }),
          pw.SizedBox(height: 40),
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Center(child: pw.Text('Para contrataciones contactar vía WhatsApp al ${widget.telefono}', style: const pw.TextStyle(fontSize: 10),),),
          pw.Footer(margin: const pw.EdgeInsets.only(top: 20), trailing: pw.Text('Documento generado por RentaFest', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo Digital', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text('VISTA PREVIA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _buildCatalogTemplateForPreview(),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: _shareImageButtonKey,
                    onPressed: _shareAsImage,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Compartir Imagen', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _shareAsPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Generar PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF39C12),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Plantilla optimizada para PREVISUALIZACIÓN (con Scroll si es necesario)
  Widget _buildCatalogTemplateForPreview() {
    return _buildCatalogContent(isCapture: false);
  }

  // Plantilla optimizada para CAPTURA (sin elementos que causen overflow infinito)
  Widget _buildCatalogTemplateForCapture() {
    return Material( // Asegura estilos
      child: Container(
        width: 400, // Ancho fijo para captura
        color: Colors.white,
        child: _buildCatalogContent(isCapture: true),
      ),
    );
  }

  Widget _buildCatalogContent({required bool isCapture}) {
    return Container(
      padding: const EdgeInsets.all(32),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎪', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          const Text('NUESTRO CATÁLOGO', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.accent)),
          Text(widget.empresa, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey)),
          const SizedBox(height: 32),
          // Usamos Wrap o Column para evitar el problema de altura infinita de GridView durante la captura
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: publicItems.map((item) => _buildCatalogItem(item, 150)).toList(),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Text('¡Contáctanos para tu próximo evento!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54)),
          Text('WhatsApp: ${widget.telefono}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCatalogItem(InventoryItem item, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(item.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(item.name, 
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.black87)
          ),
          const SizedBox(height: 4),
          Text('\$${item.price.toInt()}', 
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.accent)
          ),
        ],
      ),
    );
  }
}
