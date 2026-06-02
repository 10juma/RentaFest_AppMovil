import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../main.dart';
import '../auth/plans_screen.dart';
import '../../core/api_constants.dart';
import '../../core/api_service.dart';
import '../../core/ui_notifications.dart';
import 'dart:convert';
import 'models/inventory_item.dart';
import 'widgets/inventory_card.dart';
import 'inventory_edit_screen.dart';
import 'digital_catalog_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  Future<void> refreshInventory() async {
    setState(() => _isLoading = true);
    await _loadInventory();
  }

  String _selectedCategory = 'Todos';
  String _searchQuery = '';

  List<InventoryItem> _items = [];
  bool _isLoading = true;

  List<String> _categories = ['Todos'];

  @override
  void initState() {
    super.initState();
    _loadInventory();
    _loadCategories();
  }

  Future<void> _loadInventory() async {
    try {
      final response = await ApiService.get(ApiConstants.articulos);
      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        setState(() {
          _items = (data['data'] as List)
              .map((e) => InventoryItem.fromJson(e))
              .toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Error en API');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppNotifications.showError(context, 'Error al cargar inventario');
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final response = await ApiService.get(ApiConstants.categorias);
      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        final cats = (data['data'] as List)
            .map((e) => (e['Nombre'] ?? '').toString())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();

        setState(() {
          _categories = ['Todos', ...cats];
        });
      }
    } catch (e) {
      // silencioso, no rompemos UI
    }
  }

  void _showLimitReached(String title, String message) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🚀 $title', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
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

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final appState = RentaFestApp.of(context);
    final isAtLeastBasic = appState.isAtLeastBasic;
    final isPremium = appState.isPremium;

    final hasReachedLimit = !isAtLeastBasic && _items.length >= 3;

    final filteredItems = _items.where((item) {
      final matchesCategory = _selectedCategory == 'Todos' || item.category == _selectedCategory;
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Inventario', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            Text(isAtLeastBasic
              ? '${_items.length} artículos · ${_categories.length - 1} categorías'
              : '${_items.length} artículos activos',
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)
            ),
          ],
        ),
        actions: [
          // BOTÓN DE CATÁLOGO (Solo Premium)
          IconButton(
            onPressed: () {
              /// SI NO ES PREMIUM -> NO ABRIR
              if (!isPremium) {
                /// ANDROID muestra paywall
                if (!isIOS) {
                  _showLimitReached(
                    'Catálogo Digital',
                    'La generación de catálogo visual para compartir es una función exclusiva del Plan Premium.',
                  );
                }

                /// IOS simplemente no hace nada
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DigitalCatalogScreen(items: _items, empresa: appState.empresa ?? '', telefono: appState.telefono ?? '',)),
              );
            },
            icon: Icon(
              Icons.auto_awesome_motion_rounded,
              color: isPremium ? const Color(0xFFF39C12) : Colors.grey
            ),
            tooltip: 'Generar Catálogo',
          ),
          IconButton(
            onPressed: () async {
              /// SI YA LLEGÓ AL LÍMITE -> NO ABRIR
              if (hasReachedLimit) {
                /// ANDROID muestra paywall
                if (!isIOS) {
                  _showLimitReached(
                    'Límite de Inventario',
                    'En el Plan Free solo puedes administrar hasta 3 tipos de artículos.',
                  );
                }

                /// IOS simplemente no hace nada
                return;
              }
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InventoryEditScreen()),
              );

              if (result == true) {
                await _loadInventory();
              }
            },
            icon: Icon(Icons.add_rounded, color: hasReachedLimit ? Colors.grey : null),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _isLoading = true);
          await Future.wait([
            _loadInventory(),
            _loadCategories(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Buscar artículo...',
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (val) => setState(() => _selectedCategory = cat),
                      showCheckmark: false,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.2),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            ...filteredItems.map((item) => InventoryCard(
                  item: item,
                  onUpdated: () async {
                    await refreshInventory();
                  },
                )),
            if (filteredItems.isEmpty) ...[
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: const [
                    Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No hay inventario registrado',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!isIOS && hasReachedLimit) ...[
              const SizedBox(height: 16),
              if (!isIOS)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 32),
                      const SizedBox(height: 12),
                      const Text('¿Necesitas más artículos?',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)
                      ),
                      const SizedBox(height: 4),
                      const Text('El Plan Free está limitado a 3 artículos. Pásate al Plan Básico para inventario ilimitado.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PlansScreen())),
                        child: const Text('Ver planes disponibles →', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }
}
