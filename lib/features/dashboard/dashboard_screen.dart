import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_constants.dart';
import '../../core/api_service.dart';
import '../../core/ui_notifications.dart';
import '../../main.dart';
import '../auth/profile_screen.dart';
import 'widgets/stat_card.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onSeeAllOrders;
  const DashboardScreen({super.key, this.onSeeAllOrders});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? stats;
  List<dynamic> alertas = [];

  String nombreEmpresa = '';
  String plan = '';

  bool _isLoading = true;

  final currency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final response = await ApiService.get(ApiConstants.dashboard);
      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        final appState = RentaFestApp.of(context);
        final planApi = (data['plan'] ?? 'free').toLowerCase();
        appState.setPlanFromString(planApi);

        setState(() {
          stats = data['stats'];
          alertas = data['alertas'] ?? [];
          nombreEmpresa = data['nombreEmpresa'] ?? 'Usuario';
          plan = (data['plan'] ?? 'free').toLowerCase();
          _isLoading = false;
        });
      } else {
        _error();
      }
    } catch (e) {
      _error();
    }
  }

  void _error() {
    setState(() => _isLoading = false);
    if (mounted) {
      AppNotifications.showError(context, 'Error al cargar dashboard');
    }
  }

  void refresh() => _loadDashboard();

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final appState = RentaFestApp.of(context);
    final isPremium = appState.isPremium;
    final isAtLeastBasic = plan == 'basic' || plan == 'premium';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('¡Hola, $nombreEmpresa! 👋', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                const SizedBox(width: 8),
                if (!isIOS)
                  _buildPlanBadge(theme, isAtLeastBasic),
              ],
            ),
            Text(
              isIOS ? 'Resumen de tu negocio' : plan == 'free' ? 'Plan Free · Límite de 2 eventos al mes' : 'Resumen de tu negocio',
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            icon: const Icon(Icons.person_outline_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStats(isPremium, isAtLeastBasic),
            const SizedBox(height: 24),
            _buildAlertas(),
            const SizedBox(height: 24),
            if (!isIOS)
              _buildFreeWarning(isAtLeastBasic),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanBadge(ThemeData theme, bool isAtLeastBasic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isAtLeastBasic ? theme.colorScheme.primary : Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        plan.toUpperCase(),
        style: TextStyle(
          color: isAtLeastBasic ? theme.colorScheme.primary : Colors.grey,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildStats(bool isPremium, bool isAtLeastBasic) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.4,
      children: [
        StatCard(
          emoji: '💰',
          val: currency.format(stats?['IngresosMes'] ?? 0),
          label: 'Ingresos mes',
          delta: '',
          isPositive: true,
        ),
        StatCard(
          emoji: '📋',
          val: '${stats?['PedidosActivos'] ?? 0}',
          label: 'Pedidos activos',
          delta: '',
          isPositive: true,
        ),
        StatCard(
          emoji: '📦',
          val: '${stats?['ArticulosRentadosHoy'] ?? 0}',
          label: 'Artículos hoy',
          delta: '',
          isPositive: null,
        ),
        isPremium
            ? StatCard(
          emoji: '📈',
          val: currency.format(stats?['UtilidadNetaMes'] ?? 0),
          label: 'Utilidad neta',
          delta: '',
          isPositive: true,
        )
            : StatCard(
          emoji: '📅',
          val: '${stats?['EventosHoy'] ?? 0}',
          label: 'Eventos hoy',
          delta: '',
          isPositive: null,
        ),
      ],
    );
  }

  Widget _buildAlertas() {
    if (alertas.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Alertas', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        ...alertas.map((a) {
          final isCritical = a['Alerta'] == 'sin_stock';

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isCritical ? Colors.red : Colors.orange).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${a['Emoji']} ${a['Nombre']} - ${isCritical ? 'Sin stock' : 'Stock bajo'}',
              style: TextStyle(color: isCritical ? Colors.red : Colors.orange, fontWeight: FontWeight.w700,),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFreeWarning(bool isAtLeastBasic) {
    // Solo aplica para plan FREE
    if (isAtLeastBasic) return const SizedBox();

    final pedidosActivos = stats?['PedidosActivos'] ?? 0;

    // Solo mostrar alerta si realmente alcanzó el límite (2)
    if (pedidosActivos < 2) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Has alcanzado el límite del plan Free.',
        style: TextStyle(
          color: Colors.orange,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}