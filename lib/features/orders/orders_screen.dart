import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../main.dart';
import '../auth/plans_screen.dart';
import '../../core/api_service.dart';
import '../../core/api_constants.dart';
import '../../core/ui_notifications.dart';
import 'models/order_model.dart';
import 'widgets/order_card.dart';
import 'new_order_screen.dart';
import 'dart:convert';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _selectedFilter = 'Todos';
  String _searchQuery = '';

  List<OrderModel> _orders = [];
  bool _isLoading = true;

  final List<String> _filters = [
    'Todos',
    'Nuevo',
    'Confirmado',
    'En camino',
    'Entregado',
    'Cancelado',
    'Cerrado'
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final response = await ApiService.get(ApiConstants.pedidos);
      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        setState(() {
          _orders = (data['data'] as List)
              .map((e) => OrderModel.fromApi(e))
              .toList();
          _isLoading = false;
        });
      } else {
        throw Exception();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppNotifications.showError(context, 'Error al cargar pedidos');
      }
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
            Text(message,textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PlansScreen()));
              },
              child: const Text('Ver Planes'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final isAtLeastBasic = RentaFestApp.of(context).isAtLeastBasic;
    final hasReachedLimit = !isAtLeastBasic && _orders.length >= 2;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // FILTRO + BÚSQUEDA (IMPORTANTE)
    final filteredOrders = _orders.where((order) {
      final matchesFilter = _selectedFilter == 'Todos' || order.statusLabel == _selectedFilter;
      final matchesSearch = order.clientName.toLowerCase().contains(_searchQuery.toLowerCase()) || order.itemsSummary.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesFilter && matchesSearch;
    }).toList();

    // CONTADOR CORRECTO (YA NO 0/2)
    final pedidosVisibles = isAtLeastBasic ? _orders.length : _orders.where((o) => o.status != OrderStatus.cancelado).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pedidos', style: TextStyle(fontWeight: FontWeight.w900)),
            Text(isAtLeastBasic ? '$pedidosVisibles pedidos totales' : '$pedidosVisibles pedidos activos', style: const TextStyle(fontSize: 12, color: Colors.grey),),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () async {
              if (!isAtLeastBasic && pedidosVisibles >= 2) {
                if (!isIOS) {
                  _showLimitReached('Límite de Pedidos',
                    'En el Plan Free solo puedes crear 2 pedidos activos al mes.',);
                }
                return;
              }

              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewOrderScreen()),
              );

              if (result == true) {
                await _loadOrders();
              }
            },
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: Column(
          children: [
            // BUSCADOR
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Buscar pedido...',
                  prefixIcon:
                  const Icon(Icons.search_rounded, color: Colors.grey),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),

            // FILTROS
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = _selectedFilter == filter;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedFilter = filter),
                      showCheckmark: false,
                      selectedColor:
                      Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.w800, fontSize: 12,),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.2),),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ...filteredOrders.map(
                        (order) => OrderCard(
                      order: order,
                      onUpdated: () async {
                        await _loadOrders();
                      },
                    ),
                  ),

                  // EMPTY STATE
                  if (filteredOrders.isEmpty) ...[
                    const SizedBox(height: 40),
                    Center(
                      child: Column(
                        children: const [
                          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No hay pedidos registrados', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.grey,),),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!isIOS && hasReachedLimit) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1),),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 32),
                    const SizedBox(height: 12),
                    const Text('¿Necesitas más pedidos?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),),
                    const SizedBox(height: 4),
                    const Text('El Plan Free permite 2 pedidos por mes. Pásate al Plan Básico para pedidos ilimitados.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600,),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PlansScreen()),
                      ),
                      child: const Text('Ver planes disponibles →', style: TextStyle(fontWeight: FontWeight.w800),),
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