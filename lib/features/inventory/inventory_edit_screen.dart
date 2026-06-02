import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../main.dart';
import '../../core/ui_notifications.dart';
import '../auth/plans_screen.dart';
import 'models/inventory_item.dart';
import '../../core/api_constants.dart';
import '../../core/api_service.dart';
import 'dart:convert';

class InventoryEditScreen extends StatefulWidget {
  final InventoryItem? item;
  const InventoryEditScreen({super.key, this.item});

  @override
  State<InventoryEditScreen> createState() => _InventoryEditScreenState();
}

class _InventoryEditScreenState extends State<InventoryEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _totalStockController;
  late TextEditingController _availableStockController;
  late String _selectedCategory;
  late bool _withOperator;
  late bool _isPublic; // Nuevo campo
  bool _isSaving = false;

  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _priceController = TextEditingController(text: widget.item?.price.toString() ?? '');
    _totalStockController = TextEditingController(text: widget.item?.totalStock.toString() ?? '');
    _availableStockController = TextEditingController(text: widget.item?.availableStock.toString() ?? '');
    _selectedCategory = widget.item?.category ?? '';
    _withOperator = widget.item?.withOperator ?? false;
    _isPublic = widget.item?.isPublic ?? true;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await ApiService.get(ApiConstants.categorias);
      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        final cats = (data['data'] as List)
            .map((e) => {
                  "id": e['Id'],
                  "nombre": e['Nombre'],
                  "emoji": e['Emoji'] ?? '📦'
                })
            .toList();

        setState(() {
          _categories = cats;
          if (_categories.isNotEmpty && _selectedCategory.isEmpty) {
            _selectedCategory = _categories.first['nombre'];
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _totalStockController.dispose();
    _availableStockController.dispose();
    super.dispose();
  }

  void _showLimitReached(String message) {
    // En iOS mostramos un mensaje neutral sin mencionar planes ni precios.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🚀 Límite del Plan Free', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PlansScreen())),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Ver Planes Premium', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Eliminar artículo?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Esta acción no se puede deshacer. ¿Seguro que quieres borrar "${widget.item?.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () async {
              try {
                final response = await ApiService.delete('${ApiConstants.articulos}/${widget.item?.id}');
                final data = jsonDecode(response.body);

                if (data['ok'] == true) {
                  if (!mounted) return;

                  Navigator.pop(dialogContext); // cerrar dialog
                  Navigator.pop(context, true); // regresar a inventario con refresh

                  AppNotifications.showSuccess(context, 'Artículo eliminado');
                } else {
                  throw Exception();
                }
              } catch (_) {
                if (!mounted) return;
                AppNotifications.showError(context, 'Error al eliminar');
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final theme = Theme.of(context);
    final isAtLeastBasic = RentaFestApp.of(context).isAtLeastBasic;
    final isPremium = RentaFestApp.of(context).isPremium;
    final isEditing = widget.item != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Artículo' : 'Nuevo Artículo', style: const TextStyle(fontWeight: FontWeight.w900)),
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionTitle('Información Básica'),
            _buildCard([
              _buildTextField('Nombre del artículo', 'Ej. Brincolin XL', _nameController),
              const SizedBox(height: 16),
              _buildDropdownField('Categoría'),
            ]),
            const SizedBox(height: 20),
            _buildSectionTitle('Catálogo y Operación'),
            _buildCard([
              _buildTextField('Precio por evento', '0.00', _priceController, keyboard: TextInputType.number),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Visible en Catálogo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey)),
                subtitle: const Text('Aparecerá al generar tu catálogo para clientes.', style: TextStyle(fontSize: 12)),
                value: _isPublic,
                onChanged: (val) {
                  if (!isPremium) {
                    if (!isIOS) {
                      _showLimitReached(
                          'La gestión avanzada del catálogo es exclusiva del Plan Premium.');
                    }
                    return;
                  }
                  setState(() => _isPublic = val);
                },
                activeColor: theme.colorScheme.primary,
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 24),
              SwitchListTile(
                title: const Text('Requiere operador', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey)),
                value: _withOperator,
                onChanged: (val) => setState(() => _withOperator = val),
                activeColor: theme.colorScheme.primary,
                contentPadding: EdgeInsets.zero,
              ),
            ]),
            const SizedBox(height: 20),
            _buildSectionTitle('Control de Stock'),
            _buildCard([
              Row(children: [
                Expanded(child: _buildTextField('Stock Total', '0', _totalStockController, keyboard: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField('Disponible hoy', '0', _availableStockController, keyboard: TextInputType.number)),
              ]),
            ]),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSaving ? null : () async {
                if (!isAtLeastBasic) {
                  final int stock = int.tryParse(_totalStockController.text) ?? 0;
                  if (stock > 2) {
                    if (!isIOS) {
                      _showLimitReached('En el Plan Free solo puedes tener hasta 2 piezas por tipo de artículo.');
                    }
                    return;
                  }
                }

                // --- BEGIN: Enhanced validation ---
                if (_selectedCategory.isEmpty) {
                  AppNotifications.showError(context, 'Selecciona una categoría');
                  return;
                }

                final total = int.tryParse(_totalStockController.text) ?? 0;
                final disponible = int.tryParse(_availableStockController.text) ?? 0;

                if (total <= 0) {
                  AppNotifications.showError(context, 'El stock total debe ser mayor a 0');
                  return;
                }

                if (disponible < 0 || disponible > total) {
                  AppNotifications.showError(context, 'Stock disponible inválido');
                  return;
                }

                final precio = double.tryParse(_priceController.text) ?? 0;
                if (precio <= 0) {
                  AppNotifications.showError(context, 'El precio debe ser mayor a 0');
                  return;
                }

                if (_nameController.text.isEmpty) {
                  AppNotifications.showError(context, 'El nombre es requerido');
                  return;
                }
                // --- END: Enhanced validation ---

                if (!_formKey.currentState!.validate()) return;

                setState(() => _isSaving = true);

                try {
                  final response = await ApiService.post(
                    ApiConstants.articulos,
                    {
                      "id": widget.item?.id ?? 0,
                      "categoriaId": _categories.firstWhere((c) => c['nombre'] == _selectedCategory)['id'],
                      "nombre": _nameController.text,
                      "descripcion": "",
                      "stockTotal": int.tryParse(_totalStockController.text) ?? 0,
                      "stockDisponible": int.tryParse(_availableStockController.text) ?? 0,
                      "precio": double.tryParse(_priceController.text) ?? 0,
                      "incluyeOperador": _withOperator,
                      "esPublico": _isPublic
                    },
                  );

                  final data = jsonDecode(response.body);

                  if (data['ok'] == true) {
                    if (mounted) {
                      Navigator.pop(context, true);
                      AppNotifications.showSuccess(context, isEditing ? 'Artículo actualizado' : 'Artículo creado');
                    }
                  } else {
                    throw Exception(data['mensaje']);
                  }
                } catch (e) {
                  if (mounted) {
                    AppNotifications.showError(context, 'Error al guardar');
                  }
                } finally {
                  if (mounted) setState(() => _isSaving = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving ?
              const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),) :
              Text(isEditing ? 'Guardar Cambios' : 'Agregar al Inventario', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),),
            ),
            if (isEditing) ...[
              const SizedBox(height: 12),
              TextButton(
                  onPressed: () {
                    if (!isPremium) {
                      if (!isIOS) {
                        _showLimitReached('Eliminar artículos es exclusivo del Plan Premium.');
                      }
                      return;
                    }

                    _confirmDelete();
                  },
                  child: Text('Eliminar artículo', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800))
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5)),
  );

  Widget _buildCard(List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withOpacity(0.1))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );

  Widget _buildTextField(String label, String hint, TextEditingController controller, {TextInputType keyboard = TextInputType.text, TextAlign textAlign = TextAlign.start}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        keyboardType: keyboard,
        textAlign: textAlign,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: (v) => v!.isEmpty ? 'Requerido' : null,
      ),
    ],
  );

  Widget _buildDropdownField(String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
      const SizedBox(height: 6),
      DropdownButtonFormField<int>(
        value: _categories.any((c) => c['nombre'] == _selectedCategory) ? _categories.firstWhere((c) => c['nombre'] == _selectedCategory)['id'] : null,
        decoration: InputDecoration(
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        items: _categories.map<DropdownMenuItem<int>>((cat) {
          return DropdownMenuItem<int>(
            value: cat['id'] as int,
            child: Row(
              children: [
                Text(cat['emoji'] ?? '📦'),
                const SizedBox(width: 8),
                Text(cat['nombre']),
              ],
            ),
          );
        }).toList(),
        onChanged: (val) {
          final selected = _categories.firstWhere((c) => c['id'] == val);
          setState(() => _selectedCategory = selected['nombre']);
        },
      ),
    ],
  );
}
