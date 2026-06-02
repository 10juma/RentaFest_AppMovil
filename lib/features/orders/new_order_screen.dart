import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/ui_notifications.dart'; // Importar notificaciones
import '../inventory/models/inventory_item.dart';
import 'models/order_model.dart';

import '../../core/api_service.dart';
import '../../core/api_constants.dart';
import 'dart:convert';

class NewOrderScreen extends StatefulWidget {
  final OrderModel? order;

  const NewOrderScreen({super.key, this.order});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  final Map<int, int> _selectedItems = {};

  List<InventoryItem> _availableItems = [];
  bool _isLoadingItems = true;
  bool _isSaving = false;

  DateTime _parseInitialDate() {
    final rawDate = widget.order?.date;

    if (rawDate == null || rawDate.trim().isEmpty) {
      return DateTime.now();
    }

    try {
      return DateTime.parse(rawDate).toLocal();
    } catch (_) {
      try {
        return DateFormat('dd/MM/yyyy').parse(rawDate);
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  void _hydrateItemsForEdit() {
    if (widget.order == null || widget.order!.items.isEmpty || _availableItems.isEmpty) {
      return;
    }

    _selectedItems.clear();

    for (final orderItem in widget.order!.items) {
      final matches = _availableItems.where((i) => i.id == orderItem.articuloId);

      if (matches.isNotEmpty) {
        final inventoryItem = matches.first;

        final safeQty = orderItem.quantity > inventoryItem.availableStock
            ? inventoryItem.availableStock
            : orderItem.quantity;

        if (safeQty > 0) {
          _selectedItems[inventoryItem.id] = safeQty;
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadInventory();
    _selectedDate = _parseInitialDate();
    _selectedTime = _parseInitialTime();
    _nameController = TextEditingController(text: widget.order?.clientName ?? '');
    _phoneController = TextEditingController(text: widget.order?.clientPhone ?? '');
    _addressController = TextEditingController(text: widget.order?.address ?? '');
  }

  TimeOfDay _parseInitialTime() {
    final raw = widget.order?.hours;

    if (raw == null || raw.trim().isEmpty) {
      return const TimeOfDay(hour: 10, minute: 0);
    }

    try {
      final partes = raw.split(':');
      final hora = int.parse(partes[0]);
      final minuto = int.parse(partes[1]);

      return TimeOfDay(hour: hora, minute: minuto);
    } catch (_) {
      return const TimeOfDay(hour: 10, minute: 0);
    }
  }

  Future<void> _loadInventory() async {
    try {
      final response = await ApiService.get(ApiConstants.articulos);
      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        final items = (data['data'] as List)
            .map((e) => InventoryItem.fromJson(e))
            .toList();

        setState(() {
          _availableItems = items;
          _hydrateItemsForEdit();
          _isLoadingItems = false;
        });
      } else {
        throw Exception();
      }
    } catch (e) {
      setState(() => _isLoadingItems = false);
      if (mounted) {
        AppNotifications.showError(context, 'Error al cargar inventario');
      }
    }
  }

  String _buildApiErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['mensaje'] != null && data['mensaje'].toString().trim().isNotEmpty) {
        return data['mensaje'].toString();
      }

      final errors = data['errors'];
      if (errors is Map) {
        final messages = <String>[];

        errors.forEach((key, value) {
          if (value is List && value.isNotEmpty) {
            messages.add(value.first.toString());
          } else if (value != null) {
            messages.add(value.toString());
          }
        });

        if (messages.isNotEmpty) {
          return messages.join('\n');
        }
      }

      if (data['title'] != null && data['title'].toString().trim().isNotEmpty) {
        return data['title'].toString();
      }
    }

    return 'Error al guardar pedido';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  double get _totalPrice {
    double total = 0;

    _selectedItems.forEach((id, qty) {
      final matches = _availableItems.where((i) => i.id == id);
      if (matches.isNotEmpty) {
        total += matches.first.price * qty;
      }
    });

    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingItems) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.simpleCurrency(decimalDigits: 0);
    final isEditing = widget.order != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Pedido' : 'Nuevo Pedido', style: const TextStyle(fontWeight: FontWeight.w900)),
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context),),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionTitle('Datos del Cliente'),
            _buildCard([
              _buildTextField('Nombre completo', 'Ej. María García', _nameController),
              const SizedBox(height: 12),
              _buildTextField('Teléfono', '33 1234 5678', _phoneController, keyboard: TextInputType.phone),
              const SizedBox(height: 12),
              _buildTextField('Dirección del evento', 'Calle, colonia, ciudad', _addressController),
            ]),
            const SizedBox(height: 20),

            _buildSectionTitle('Fecha y Hora'),
            _buildCard([
              Row(
                children: [
                  Expanded(
                    child: _buildPickerTile(
                      icon: Icons.calendar_today_rounded,
                      label: 'Fecha',
                      value: DateFormat('dd/MM/yyyy').format(_selectedDate),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setState(() => _selectedDate = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPickerTile(
                      icon: Icons.access_time_rounded,
                      label: 'Hora',
                      value: _selectedTime.format(context),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                        );
                        if (picked != null) setState(() => _selectedTime = picked);
                      },
                    ),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 20),

            _buildSectionTitle('Seleccionar Artículos'),
            _buildCard(
              _availableItems.map((item) => _buildItemPicker(item)).toList(),
            ),
            const SizedBox(height: 20),

            _buildSectionTitle('Resumen'),
            _buildCard([
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total estimado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(currencyFormatter.format(_totalPrice),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: theme.colorScheme.primary)
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isSaving ? null : () async {
                if (!_formKey.currentState!.validate()) return;

                if (_selectedItems.isEmpty) {
                  AppNotifications.showError(context, 'Agrega al menos un artículo');
                  return;
                }

                if (_phoneController.text.trim().isEmpty) {
                  AppNotifications.showError(context, 'Captura el teléfono del cliente');
                  return;
                }

                if (_addressController.text.trim().isEmpty) {
                  AppNotifications.showError(context, 'Captura la dirección del evento');
                  return;
                }

                setState(() => _isSaving = true);

                try {
                  final detalle = _selectedItems.entries.map((e) => {
                    "ArticuloId": e.key,
                    "Cantidad": e.value,
                    "ConOperador": false
                  }).toList();

                  final response = await ApiService.post(
                    ApiConstants.pedidos,
                    {
                      "pedidoId": widget.order?.id ?? 0,
                      "clienteNombre": _nameController.text.trim(),
                      "clienteTel": _phoneController.text.trim(),
                      "direccion": _addressController.text.trim(),
                      "fechaEvento": DateFormat('yyyy-MM-dd').format(_selectedDate),
                      "horaEvento": "${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}:00",
                      "notas": "",
                      "detalle": detalle
                    },
                  );

                  final data = jsonDecode(response.body);

                  if (response.statusCode == 200 && data['ok'] == true) {
                    if (!mounted) return;
                    setState(() => _isSaving = false);
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    AppNotifications.showSuccess(context, isEditing ? 'Pedido actualizado' : 'Pedido guardado');
                  } else {
                    throw Exception(_buildApiErrorMessage(data));
                  }

                } catch (e) {
                  setState(() => _isSaving = false);
                  if (!mounted) return;
                  AppNotifications.showError(context, e.toString().replaceFirst('Exception: ', ''));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    isEditing ? 'Guardar cambios' : 'Crear pedido',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5)
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildTextField(String label, String hint, TextEditingController controller, {TextInputType keyboard = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboard,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
        ),
      ],
    );
  }

  Widget _buildPickerTile({required IconData icon, required String label, required String value, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.accent),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w700)),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemPicker(InventoryItem item) {
    final qty = _selectedItems[item.id] ?? 0;

    // 🔒 Seguridad extra: nunca permitir exceder stock
    if (qty > item.availableStock) {
      _selectedItems[item.id] = item.availableStock;
    }

    final isOutOfStock = item.availableStock <= 0;
    final isSelected = qty > 0;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSelected ? theme.colorScheme.primary.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? theme.colorScheme.primary : Colors.transparent),
      ),
      child: Row(
        children: [
          Text(item.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                Text(
                  'Disponibles: ${item.availableStock}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isOutOfStock ? Colors.red : Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text('\$${item.price.toInt()}/evento', style: TextStyle(color: theme.colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (!isSelected)
            IconButton(
              onPressed: isOutOfStock
                  ? null
                  : () => setState(() => _selectedItems[item.id] = 1),
              icon: Icon(
                Icons.add_circle_outline_rounded,
                color: isOutOfStock ? Colors.grey.withOpacity(0.3) : Colors.grey,
              ),
            )
          else
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() {
                    if (_selectedItems[item.id] == 1) {
                      _selectedItems.remove(item.id);
                    } else {
                      _selectedItems[item.id] = _selectedItems[item.id]! - 1;
                    }
                  }),
                  icon: const Icon(Icons.remove_circle_rounded, color: AppColors.accent),
                ),
                Text('$qty', style: const TextStyle(fontWeight: FontWeight.w900)),
                IconButton(
                  onPressed: (_selectedItems[item.id]! >= item.availableStock)
                      ? null
                      : () => setState(() => _selectedItems[item.id] = _selectedItems[item.id]! + 1),
                  icon: const Icon(Icons.add_circle_rounded, color: AppColors.accent),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
