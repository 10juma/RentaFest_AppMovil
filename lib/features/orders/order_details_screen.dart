import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/api_constants.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../main.dart';
import '../../core/ui_notifications.dart';
import '../auth/plans_screen.dart';
import '../reports/expense_screen.dart';
import 'models/order_model.dart';
import 'new_order_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  final OrderModel order;
  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();

  OrderModel? _order;
  bool _isLoading = true;
  bool _isUpdatingStatus = false;
  bool _isProcessing = false;

  OrderExpense _expense = OrderExpense.empty();

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _loadOrder();
    _loadExpense();
  }

  Future<void> _loadOrder() async {
    try {
      final response = await ApiService.get(
        '${ApiConstants.pedidos}/${widget.order.id}',
      );

      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        if (!mounted) return;
        setState(() {
          _order = OrderModel.fromApi(data['data']);
          _isLoading = false;
        });
      } else {
        throw Exception(data['mensaje'] ?? 'Error desconocido');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppNotifications.showError(context, 'Error al actualizar detalles: $e');
    }
  }

  Future<void> _loadExpense() async {
    try {
      final response = await ApiService.get(
        '${ApiConstants.pedidos}/${widget.order.id}/utilidad',
      );

      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        if (!mounted) return;

        setState(() {
          _expense = OrderExpense.fromApi(data['data']);
        });
      } else {
        throw Exception(data['mensaje']);
      }
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showError(context, 'Error utilidad: $e');
    }
  }

  Future<void> _cambiarEstatus(String nuevoEstatus) async {
    if (_isUpdatingStatus) return;

    setState(() => _isUpdatingStatus = true);

    try {
      final response = await ApiService.post(
        '${ApiConstants.pedidos}/${_order!.id}/estatus',
        {"estatus": nuevoEstatus},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['ok'] == true) {
        if (!mounted) return;
        Navigator.pop(context, true);
        AppNotifications.showSuccess(context, 'Estatus actualizado');
      } else {
        throw Exception(data['mensaje'] ?? 'Error al cambiar estatus');
      }
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showError(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  void _handleStatusChange() {
    if (_order == null) return;

    switch (_order!.status) {
      case OrderStatus.nuevo:
        _cambiarEstatus('Confirmado');
        break;
      case OrderStatus.confirmado:
        _cambiarEstatus('EnCamino');
        break;
      case OrderStatus.enCamino:
        _cambiarEstatus('Entregado');
        break;
      case OrderStatus.entregado:
        _showCerrarPedidoDialog();
        break;
      default:
        break;
    }
  }

  Future<void> _cancelarPedido(double porcentaje) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final response = await ApiService.post(
        '${ApiConstants.pedidos}/${_order!.id}/cancelar',
        {"porcentajeRetencion": porcentaje},
      );

      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        if (!mounted) return;
        Navigator.pop(context, true);
        AppNotifications.showSuccess(context, 'Pedido cancelado');
      } else {
        throw Exception(data['mensaje']);
      }
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _eliminarPedido() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final response = await ApiService.delete(
        '${ApiConstants.pedidos}/${_order!.id}',
      );

      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        if (!mounted) return;
        Navigator.pop(context, true);
        AppNotifications.showSuccess(context, 'Pedido eliminado');
      } else {
        throw Exception(data['mensaje']);
      }
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _cerrarPedido(List items, String notas) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      /// 🔥 TRANSFORMACIÓN A FORMATO API
      final detalle = items.map((e) => {
        "articuloId": e["articuloId"],
        "devueltos": e["devueltos"],
      }).toList();

      final response = await ApiService.post(
        '${ApiConstants.pedidos}/${_order!.id}/cerrar',
        {
          "detalle": detalle, // 👈 CAMBIO CLAVE
          "notas": notas.trim()
        },
      );

      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        if (!mounted) return;
        Navigator.pop(context, true);
        AppNotifications.showSuccess(context, 'Pedido cerrado correctamente');
      } else {
        throw Exception(data['mensaje']);
      }
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showError(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showPremiumBlocked(BuildContext context, String message, {bool isForPremium = false}) {
    // En iOS mostramos un mensaje neutral sin mencionar planes ni precios.
    if (Platform.isIOS) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta función no está disponible en tu cuenta'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isForPremium ? '👑 Exclusivo Premium' : '⭐ Función Pro',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.grey, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const PlansScreen()));
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Ver Planes',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _handleCancelAction() {
    if (_order!.status == OrderStatus.nuevo) {
      _showFlexibleCancelDialog();
    } else {
      _showStrictCancelDialog();
    }
  }

  void _showFlexibleCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Cancelar Pedido', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pedido no confirmado aún. Selecciona la política de retención a discreción:', 
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 13)
            ),
            const SizedBox(height: 20),
            _buildCancelOption('Reembolso Total (0%)', 0),
            _buildCancelOption('Retención del 25%', 0.25),
            _buildCancelOption('Retención del 50%', 0.50),
            _buildCancelOption('Retención del 75%', 0.75),
            _buildCancelOption('Retención del 100%', 1.0),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Atrás', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showStrictCancelDialog() {
    final currencyFormatter = NumberFormat.simpleCurrency(decimalDigits: 0);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Confirmar Cancelación', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
            const SizedBox(height: 16),
            const Text('Este pedido ya está en curso.', 
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
            ),
            const SizedBox(height: 8),
            Text('Se aplicará una retención obligatoria del 100% por un monto de ${currencyFormatter.format(_order?.total ?? _order!.total)}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13)
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Atrás', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelarPedido(1);
            },
            child: const Text('Confirmar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Eliminar Cotización', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('Esta acción eliminará el registro por completo del sistema. No se generará historial de cancelación ni cargos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _eliminarPedido();
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _showCerrarPedidoDialog() {
    final items = _order!.items.map((e) => {
      "articuloId": e.articuloId,
      "name": e.name,
      "total": e.quantity,
      "devueltos": e.quantity
    }).toList();

    final controllerNotas = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF161A2E),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Cerrar Pedido', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,),),
                      const SizedBox(height: 8),
                      const Text('Confirma los artículos devueltos', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600,),),
                      const SizedBox(height: 20),

                      /// ITEMS
                      ...items.map((item) {
                        final devueltos = item["devueltos"] as int;
                        final total = item["total"] as int;
                        final faltan = total - devueltos;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              /// NOMBRE
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item["name"].toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13,),),
                                    if (faltan > 0)
                                      Text('Faltan $faltan', style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600,),),
                                  ],
                                ),
                              ),

                              /// CONTROLES
                              Row(
                                children: [
                                  _qtyButton(
                                    icon: Icons.remove,
                                    enabled: devueltos > 0,
                                    onTap: () {
                                      setStateDialog(() {
                                        item["devueltos"] = devueltos - 1;
                                      });
                                    },
                                  ),
                                  Padding(
                                    padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                    child: Text('$devueltos', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900,),),
                                  ),
                                  _qtyButton(
                                    icon: Icons.add,
                                    enabled: devueltos < total,
                                    onTap: () {
                                      setStateDialog(() {
                                        item["devueltos"] = devueltos + 1;
                                      });
                                    },
                                  ),
                                ],
                              )
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 16),

                      /// INPUT NOTAS
                      TextField(
                        controller: controllerNotas,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Notas (opcional)',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),

                      /// BOTONES
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar', style: TextStyle(color: Colors.grey),),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isProcessing ? null : () async {
                                Navigator.pop(context);
                                await _cerrarPedido(items, controllerNotas.text);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: _isProcessing ?
                              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,),) :
                              const Text('Cerrar Pedido', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCancelOption(String label, double percentage) {
    final currencyFormatter = NumberFormat.simpleCurrency(decimalDigits: 0);
    final amountToCharge = _order!.total * percentage;

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _cancelarPedido(percentage);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if (percentage > 0) 
              Text(currencyFormatter.format(amountToCharge), 
                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.red, fontSize: 13)
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAndShowPdf() async {
    final appState = RentaFestApp.of(context);
    final empresa = appState.empresa ?? 'Tu Empresa';
    final telefono = appState.telefono ?? '';

    final pdf = pw.Document();
    final currencyFormatter = NumberFormat.simpleCurrency(decimalDigits: 0);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('CONTRATO DE ARRENDAMIENTO DE EQUIPO', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text(empresa, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 20),
                pw.Text('DETALLES DEL CLIENTE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('Nombre: ${_order!.clientName}'),
                pw.Text('Pedido: #${widget.order.NoPedido}'),
                pw.Text('Fecha del Evento: ${_order!.fechaEventoFormateada}'),
                pw.SizedBox(height: 20),
                pw.Text('ARTÍCULOS RENTADOS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(widget.order.itemsSummary),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL A PAGAR:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    pw.Text(currencyFormatter.format(_order!.total), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  ],
                ),
                pw.SizedBox(height: 40),
                pw.Text('POLÍTICA DE CANCELACIÓN:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.SizedBox(height: 8),
                pw.Text('- Cancelaciones previas a la confirmación: Retención a discreción del dueño.', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('- Una vez confirmado el pedido, se retendrá el 100% del cobro total.', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('- El arrendatario acepta los cargos por cancelación al firmar este documento.', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Contacto: $telefono', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),),
                pw.SizedBox(height: 60),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(children: [
                      pw.Container(width: 150, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide()))),
                      pw.Text('Firma del Negocio', style: const pw.TextStyle(fontSize: 10)),
                    ]),
                    pw.Column(children: [
                      pw.Container(width: 150, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide()))),
                      pw.Text('Firma del Cliente', style: const pw.TextStyle(fontSize: 10)),
                    ]),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _shareReceiptImage() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final Uint8List? image = await _screenshotController.captureFromWidget(
        _buildReceiptImageTemplate(),
        delay: const Duration(milliseconds: 50),
      );

      if (image != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = await File('${directory.path}/recibo_${widget.order.NoPedido}.png').create();
        await imagePath.writeAsBytes(image);

        if (mounted)
          Navigator.pop(context);

        final box = context.findRenderObject() as RenderBox?;

        await Share.shareXFiles(
          [XFile(imagePath.path)],
          text: 'Comprobante de Pedido #${widget.order.NoPedido} - RentaFest',
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar imagen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    if (_order == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final order = _order!;
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.simpleCurrency(decimalDigits: 0);
    final appState = RentaFestApp.of(context);
    final isAtLeastBasic = appState.isAtLeastBasic;
    final isPremium = appState.isPremium;
    final isCancelado = order.status == OrderStatus.cancelado;
    final isCerrado = order.status == OrderStatus.cerrado;
    final isNuevo = order.status == OrderStatus.nuevo;
    final noPedido = order.NoPedido.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text('Pedido #${noPedido}', style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (!isCancelado && !isCerrado) ...[
            IconButton(
              onPressed: () {
                if (!isAtLeastBasic) {
                  if (!isIOS) {
                    _showPremiumBlocked(context,
                        'La edición de eventos está disponible a partir del Plan Básico.');
                  }
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NewOrderScreen(order: _order),
                  ),
                );
              },
              icon: Icon(
                Icons.edit_outlined,
                color: isAtLeastBasic ? null : Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadOrder(),
            _loadExpense(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // DETALLES DEL PEDIDO
            _buildOrderStepper(context, order),
            const SizedBox(height: 24),

            // BOTONES PREMIUM (PDF Y GASTOS)
            Row(
              children: [
                Expanded(
                  child: _buildPremiumActionTile(
                    context,
                    label: 'Contrato PDF',
                    onTap: () {
                      if (!isPremium) {
                        if (!isIOS) {
                          _showPremiumBlocked(context,
                              'La generación de contratos PDF es exclusiva de Premium.',
                              isForPremium: true);
                        }
                        return;
                      }
                      _generateAndShowPdf();
                    },
                    color: const Color(0xFFF39C12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPremiumActionTile(
                    context,
                    label: 'Ver Gastos',
                    onTap: () async {
                      if (!isPremium) {
                        if (!isIOS) {
                          _showPremiumBlocked(context,
                              'El control de gastos y utilidad es exclusivo de Premium.',
                              isForPremium: true);
                        }
                        return;
                      }
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExpenseScreen(pedidoId: order.id, noPedido: order.NoPedido),
                        ),
                      );

                      if (mounted) {
                        await _loadExpense();
                        await _loadOrder();
                      }
                    },
                    color: AppColors.coral,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // CLIENTE
            _buildSectionTitle('Cliente'),
            _buildCard(context, [
              _buildDetailRow('Nombre', order.clientName),
              _buildDetailRow('Teléfono', order.clientPhone ?? 'N/A'),
              _buildDetailRow('Dirección', order.address ?? 'N/A'),
              _buildDetailRow('Fecha evento', order.fechaEventoFormateada),
            ]),
            const SizedBox(height: 20),

            // SECCIÓN DE RENTABILIDAD (Solo Premium)
            if (isPremium) ...[
              _buildSectionTitle('Rentabilidad Real'),
              if (_expense.totalGastos == 0)
                _buildEmptyExpenseCard(context)
              else
                _buildCard(context, [
                  _buildDetailRow('Ingreso Bruto', currencyFormatter.format(_order!.total)),
                  _buildDetailRow('Gastos Asociados', currencyFormatter.format(_expense.totalGastos)),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Utilidad Neta', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.mint)),
                      Text(currencyFormatter.format(_expense.utilidadNeta), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.mint)),
                    ],
                  ),
                ]),
              const SizedBox(height: 20),
            ],

            // ARTICULOS
            _buildSectionTitle('Artículos'),
            _buildCard(context, [
              ...order.items.map((i) => _buildItemRow(
                i.emoji,
                i.name,
                'x${i.quantity}',
                currencyFormatter.format(i.total),
              )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.w800)),
                  Text(currencyFormatter.format(order.total), style: TextStyle(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
                ],
              ),
            ]),
            const SizedBox(height: 24),

            // CAMBIAR ESTATUS
            _buildStatusActionButton(context),
            const SizedBox(height: 12),
            // CANCELAR
            if (!isCancelado && !isCerrado)...[
              OutlinedButton.icon(
                onPressed: _isProcessing ? null : _handleCancelAction,
                icon: _isProcessing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),)
                    : const Icon(Icons.cancel_rounded, color: Colors.red),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),),
                  side: BorderSide(color: AppColors.red),
                ),
                label: Text(_isProcessing ? 'Cancelando...' : 'Cancelar Pedido', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.red),),
              ),
              const SizedBox(height: 12),
            ],
            // COMPARTIR
            OutlinedButton.icon(
              onPressed: _shareReceiptImage,
              icon: const Icon(Icons.share_rounded, color: AppColors.accent),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),),
                side: BorderSide(color: AppColors.accent),
              ),
              label: const Text('Compartir comprobante',style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent),),
            ),
            const SizedBox(height: 12),
            // ELIMINAR (premium o bloqueado)
            if (isNuevo)...[
              OutlinedButton.icon(
                onPressed: _isProcessing ? null : () {
                  if (!isPremium) {
                    if (!isIOS) {
                      _showPremiumBlocked(context,
                        'Eliminar cotizaciones es exclusivo de Premium.',
                        isForPremium: true,);
                    }
                    return;
                  }
                  _showDeleteConfirmation();
                },
                icon: _isProcessing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2),)
                    : Icon(Icons.delete_rounded, color: isPremium ? Colors.red : Colors.grey,),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),),
                  side: BorderSide(color: AppColors.lightBg),
                ),
                label: Text(_isProcessing ? 'Eliminando...' : 'Eliminar Cotización', style: TextStyle(fontWeight: FontWeight.w900, color: isPremium ? Colors.red : Colors.grey,),),
              ),
              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyExpenseCard(BuildContext context) {
    final order = _order!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_rounded, size: 40, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('Sin gastos registrados', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14,),),
          const SizedBox(height: 6),
          const Text('Agrega gastos para conocer tu utilidad real en este evento.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600,),),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ExpenseScreen(pedidoId: order.id, noPedido: order.NoPedido)),
              );
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: AppColors.red.withOpacity(0.1),
              foregroundColor: AppColors.coral,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.coral),
              ),
            ),
            child: const Text('Agregar gasto', style: TextStyle(fontWeight: FontWeight.w900),),
          )
        ],
      ),
    );
  }

  Widget _buildPremiumActionTile(BuildContext context, {required String label, required VoidCallback onTap, required Color color}) {
    final isPremium = RentaFestApp.of(context).isPremium;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusActionButton(BuildContext context) {
    String label = '';
    IconData icon = Icons.check_rounded;
    Color color = AppColors.accent;

    switch (_order!.status) {
      case OrderStatus.nuevo:
        label = 'Confirmar Pedido';
        icon = Icons.check_circle_rounded;
        color = AppColors.mint;
        break;
      case OrderStatus.confirmado:
        label = 'Marcar En Camino';
        icon = Icons.local_shipping_rounded;
        color = Colors.orange;
        break;
      case OrderStatus.enCamino:
        label = 'Marcar como Entregado';
        icon = Icons.done_all_rounded;
        color = AppColors.accent;
        break;
      case OrderStatus.entregado:
        label = 'Cerrar Pedido';
        icon = Icons.archive_rounded;
        color = Colors.grey;
        break;
      case OrderStatus.cerrado:
        return const SizedBox.shrink();
      case OrderStatus.cancelado:
        return const SizedBox.shrink();
    }

    return ElevatedButton.icon(
      onPressed: _isUpdatingStatus ? null : _handleStatusChange,
      icon: _isUpdatingStatus
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),)
          : Icon(icon),
      label: Text(
        _isUpdatingStatus ? 'Actualizando...' : label,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildReceiptImageTemplate() {
    final currencyFormatter = NumberFormat.simpleCurrency(decimalDigits: 0);
    final isNew = _order!.status == OrderStatus.nuevo;

    return Material(
      color: const Color(0xFFF5F6FA),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
              ),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.black, fontFamily: 'Nunito'),
                child: Column(
                  children: [
                    const Text('🎪', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 8),
                    const Text('RentaFest', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.accent)),
                    const Text('Comprobante de Reserva', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
                    const SizedBox(height: 24),
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    const SizedBox(height: 24),
                    _buildReceiptRow('Pedido', '#${widget.order.NoPedido}'),
                    _buildReceiptRow('Cliente', _order!.clientName),
                    _buildReceiptRow('Fecha', _order!.fechaEventoFormateada),
                    _buildReceiptRow('Estado', _order!.statusLabel.toUpperCase()),
                    const SizedBox(height: 24),
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    const SizedBox(height: 24),
                    const Text(
                      'RESUMEN DE EQUIPO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._order!.items.map(
                          (item) => _buildReceiptItem(
                            '${item.emoji} ${item.name} (x${item.quantity})',
                            currencyFormatter.format(item.total),
                          ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL A PAGAR', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87)),
                          Text(currencyFormatter.format(_order!.total), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.accent)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                      child: const Column(
                        children: [
                          Text('• Antes de confirmar: Retención a discreción del dueño.', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600)),
                          Text('• Una vez confirmado: Se retendrá el 100% del cobro.', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('¡Gracias por elegirnos!', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87)),
                    const Text('Cualquier duda contáctanos al 33 1234 5678', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildReceiptItem(String name, String price) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
          Text(price, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.accent)),
        ],
      ),
    );
  }

  Widget _buildOrderStepper(BuildContext context, OrderModel order) {
    final status = order.status;

    // CASO CANCELADO
    if (status == OrderStatus.cancelado) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepCustom(label: 'Cancelado', color: Colors.red, isActive: true, icon: Icons.close,),
        ],
      );
    }

    // FLUJO NORMAL
    final isConfirmado = status == OrderStatus.confirmado || status == OrderStatus.enCamino || status == OrderStatus.entregado || status == OrderStatus.cerrado;
    final isEnCamino = status == OrderStatus.enCamino || status == OrderStatus.entregado || status == OrderStatus.cerrado;
    final isEntregado = status == OrderStatus.entregado || status == OrderStatus.cerrado;
    final isCerrado = status == OrderStatus.cerrado;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStep(context, 'Nuevo', status == OrderStatus.nuevo, isConfirmado),
        _buildStepLine(isConfirmado),
        _buildStep(context, 'Confirm.', status == OrderStatus.confirmado, isEnCamino),
        _buildStepLine(isEnCamino),
        _buildStep(context, 'Camino', status == OrderStatus.enCamino, isEntregado),
        _buildStepLine(isEntregado),
        _buildStep(context, 'Entreg.', status == OrderStatus.entregado, isCerrado),
        _buildStepLine(isCerrado),
        _buildStep(context, 'Cerrado', status == OrderStatus.cerrado, false),
      ],
    );
  }

  Widget _buildStepCustom({required String label, required Color color, required bool isActive, required IconData icon,}) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle,),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.red,),),
      ],
    );
  }

  Widget _buildStep(BuildContext context, String label, bool isCurrent, bool isDone) {
    final color = isDone ? AppColors.accent : (isCurrent ? AppColors.coral : Colors.grey.withOpacity(0.2));
    return Column(children: [
      Container(width: 28, height: 28, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(isDone ? Icons.check : Icons.circle, size: 14, color: Colors.white)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey)),
    ]);
  }

  Widget _buildStepLine(bool isActive) => Expanded(child: Container(height: 2, margin: const EdgeInsets.only(bottom: 14), color: isActive ? AppColors.accent : Colors.grey.withOpacity(0.1)));

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5)),
  );

  Widget _buildCard(BuildContext context, List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withOpacity(0.1))),
    child: Column(children: children),
  );

  Widget _buildDetailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
      Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
    ]),
  );

  Widget _buildItemRow(String emoji, String name, String qty, String price) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 24)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        Text(qty, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
      ])),
      Text(price, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.accent)),
    ]),
  );

  Widget _qtyButton({required IconData icon, required bool enabled, required VoidCallback onTap,}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? Colors.white : Colors.grey,
        ),
      ),
    );
  }
}
