import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/api_constants.dart';
import '../../core/api_service.dart';
import '../../main.dart';
import '../../core/theme.dart';
import '../dashboard/widgets/stat_card.dart';
import '../auth/plans_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {

  bool _isLoading = true;

  List<dynamic> porMes = [];
  List<dynamic> porCategoria = [];

  String titulo = '';
  double totalIngresos = 0;
  int totalPedidos = 0;
  double gasto = 0;
  double utilidad = 0;
  double ticketPromedio = 0;
  double tasaEntrega = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = RentaFestApp.of(context);
      if (appState.isAtLeastBasic) {
        _loadData();
      } else {
        setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.get(ApiConstants.reportes);
      final data = jsonDecode(response.body);

      if (data['ok'] == true) {

        final meses = data['porMes'] as List;
        final categorias = data['porCategoria'] as List;

        double ingresos = 0;
        double pedidos = 0;
        double gastos = 0;
        double utilidades = 0;

        titulo = meses.isNotEmpty ? meses[0]['titulo'] : '';
        tasaEntrega = (meses.isNotEmpty && meses[0]['tasaEntrega'] is num) ? (meses[0]['tasaEntrega'] as num).toDouble() : 0;

        for (var m in meses) {
          final ingreso = (m['ingresos'] is num) ? (m['ingresos'] as num).toDouble() : 0.0;
          final pedidosMes = (m['totalPedidos'] is num) ? (m['totalPedidos'] as num).toDouble() : 0.0;
          final gasto = (m['gastos'] is num) ? (m['gastos'] as num).toDouble() : 0.0;
          final utilidadMes = (m['utilidad'] is num) ? (m['utilidad'] as num).toDouble() : 0.0;

          ingresos += ingreso;
          pedidos += pedidosMes;
          gastos += gasto;
          utilidades += utilidadMes;
        }

        setState(() {
          porMes = meses;
          porCategoria = categorias;
          totalIngresos = ingresos;
          totalPedidos = pedidos.toInt();
          ticketPromedio = pedidos == 0 ? 0 : ingresos / pedidos;
          utilidad = utilidades;
          gasto = gastos;
          _isLoading = false;
        });

      } else {
        throw Exception();
      }
    } catch (e) {
      // opcional log
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showLimitReached(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🚀 Función Pro', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            const Text('La exportación de reportes detallados en PDF está disponible a partir del Plan Básico.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PlansScreen()));
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Ver Planes Disponibles', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadReport(BuildContext context, bool isPremium) async {
    final pdf = pw.Document();
    final currency = NumberFormat.simpleCurrency(decimalDigits: 0);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('REPORTE FINANCIERO ${DateTime.now().year}', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),),
                pw.Text('RENTAFEST - Gestión de Eventos', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey),),
                if (titulo.isNotEmpty)
                  pw.Text(titulo, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 20),
                pw.Text('KPIs GENERALES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),),
                pw.SizedBox(height: 10),
                pw.Text('- Ingresos Año: ${currency.format(totalIngresos)}'),
                pw.Text('- Pedidos Totales: $totalPedidos'),
                pw.Text('- Tasa de Entrega: ${tasaEntrega.toStringAsFixed(0)}%'),
                pw.Text('- Ticket Promedio: ${currency.format(ticketPromedio)}'),
                if (isPremium) pw.Text('- Utilidad Neta: ${currency.format(utilidad)}'),
                pw.SizedBox(height: 30),
                pw.Text('INGRESOS POR CATEGORÍA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                pw.SizedBox(height: 10),
                ...porCategoria.map((c) {
                  final nombre = (c['categoria'] ?? '').toString();
                  final ingreso = (c['ingresoTotal'] is num) ? (c['ingresoTotal'] as num).toDouble() : 0.0;

                  return pw.Container(
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('- $nombre'),
                        pw.Text(currency.format(ingreso), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  );
                }).toList(),
                pw.SizedBox(height: 30),
                pw.Text('DETALLE MENSUAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                pw.SizedBox(height: 10),
                ...porMes.map((m) {
                  final mes = (m['nombreMes'] ?? '').toString();
                  final ingreso = (m['ingresos'] is num) ? (m['ingresos'] as num).toDouble() : 0.0;
                  final gasto = isPremium && m['gananciaReal'] is num ? (m['gananciaReal'] as num).toDouble() : null;

                  return _buildPdfRow(mes, currency.format(ingreso), gasto != null ? currency.format(gasto) : null,);
                }).toList(),
                pw.SizedBox(height: 40),
                pw.Divider(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('Generado el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  pw.Widget _buildPdfRow(String month, String income, String? expense) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: const pw.BoxDecoration( // Corregido: border debe ir dentro de decoration
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(month, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Ingreso: $income'),
              if (expense != null) pw.Text('Gasto: $expense', style: const pw.TextStyle(color: PdfColors.red)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final appState = RentaFestApp.of(context);
    final isPremium = appState.isPremium;
    final isAtLeastBasic = appState.isAtLeastBasic;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final formatter = NumberFormat.simpleCurrency(decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reportes', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            Text(titulo, style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              if (!isAtLeastBasic) {
                if (!isIOS) {
                  _showLimitReached(context);
                }
                return;
              }
              _downloadReport(context, isPremium);
            },
            icon: Icon(Icons.download_rounded, color: isAtLeastBasic ? null : Colors.grey),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // KPI Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.4,
              children: [
                StatCard(emoji: '💰', val: formatter.format(totalIngresos), label: 'Ingresos año', delta: 'Monto Bruto', isPositive: true),
                StatCard(emoji: '📋', val: '$totalPedidos', label: 'Pedidos totales', delta: 'No Cancelado', isPositive: true),
                StatCard(emoji: '🎯', val: tasaEntrega.toStringAsFixed(0) + '%', label: 'Tasa entrega', delta: '', isPositive: true),
                isPremium ?
                StatCard(emoji: '📈', val: formatter.format(utilidad), label: 'Utilidad Total', delta: 'Gasto: ' + formatter.format(gasto), isPositive: true) :
                StatCard(emoji: '💵', val: formatter.format(ticketPromedio), label: 'Ticket prom.', delta: 'Monto Bruto', isPositive: true),
              ],
            ),
            const SizedBox(height: 20),

            _buildChartSection(context, isPremium ? 'Ingresos vs Gastos' : 'Ingresos por mes', isPremium),
            const SizedBox(height: 20),

            _buildCategorySection(context, 'Top categorías'),
            const SizedBox(height: 20),

            _buildMonthlyDetailTable(context, 'Detalle mensual', isPremium),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(BuildContext context, String title, bool isPremium) {
    final theme = Theme.of(context);
    final max = porMes.isEmpty ? 1.0 : porMes
        .map((e) => ((e['ingresos'] ?? 0) as num).toDouble())
        .reduce((a, b) => a > b ? a : b);

    final incomeValues = porMes.map((e) {
      final val = (e['ingresos'] is num) ? (e['ingresos'] as num).toDouble() : 0.0;
      return max == 0 ? 0.0 : val / max;
    }).toList();

    final expenseValues = porMes.map((e) {
      final val = (e['gastos'] is num) ? (e['gastos'] as num).toDouble() : 0.0;
      return max == 0 ? 0.0 : val / max;
    }).toList();

    final months = porMes.map((e) => '${e['nombreMes']}').toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(months.length, (index) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: isPremium ? 15 : 30,
                          height: 80 * incomeValues[index],
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(index == 3 ? 1.0 : 0.4),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                        if (isPremium) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 15,
                            height: 80 * expenseValues[index],
                            decoration: BoxDecoration(
                              color: AppColors.coral.withOpacity(index == 3 ? 1.0 : 0.4),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(months[index], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey)),
                  ],
                );
              }),
            ),
          ),
          if (isPremium) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Ingresos', theme.colorScheme.primary),
                const SizedBox(width: 20),
                _buildLegendItem('Gastos', AppColors.coral),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCategorySection(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          ...porCategoria.map((c) {
            final total = porCategoria.fold<double>(0.0, (sum, e) => sum + ((e['ingresoTotal'] is num) ? (e['ingresoTotal'] as num).toDouble() : 0.0));
            final ingreso = (c['ingresoTotal'] is num) ? (c['ingresoTotal'] as num).toDouble() : 0.0;
            final pct = total == 0 ? 0.0 : ingreso / total;

            return _buildCategoryBar(c['emoji'] + ' ' + c['categoria'], pct, NumberFormat.simpleCurrency(decimalDigits: 0).format(ingreso), AppColors.accent);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(String label, double pct, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.grey.withOpacity(0.1),
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyDetailTable(BuildContext context, String title, bool isPremium) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ...porMes.map((m) {
            final ingreso = (m['ingresos'] is num) ? (m['ingresos'] as num).toDouble() : 0.0;
            final gasto = (m['gastos'] is num) ? (m['gastos'] as num).toDouble() : 0.0;

            return _buildTableRow(
                m['nombreMes'],
                '${m['totalPedidos']} pedidos',
                NumberFormat.simpleCurrency(decimalDigits: 0).format(ingreso),
                isPremium ? NumberFormat.simpleCurrency(decimalDigits: 0).format(gasto) : null
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTableRow(String month, String count, String income, String? expense, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(month, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text(count, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(income, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.accent)),
                    if (expense != null)
                      Text('-$expense', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.redAccent)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
