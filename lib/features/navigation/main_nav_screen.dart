import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../main.dart';
import '../dashboard/dashboard_screen.dart';
import '../inventory/inventory_screen.dart';
import '../orders/orders_screen.dart';
import '../calendar/calendar_screen.dart';
import '../reports/reports_screen.dart';
import '../reports/expense_screen.dart';
import '../auth/plans_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // Control directo del dashboard
  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey();
  final GlobalKey<CalendarScreenState> _calendarKey = GlobalKey();

  late final List<Widget> _screens = [
    DashboardScreen(
      key: _dashboardKey,
      onSeeAllOrders: () => _onTabTapped(2),
    ),
    const InventoryScreen(),
    const OrdersScreen(),
    CalendarScreen(key: _calendarKey),
    const ReportsScreen(),
    const ExpenseScreen(),
  ];

  void _onTabTapped(int index) {
    final appState = RentaFestApp.of(context);

    // Refresh Calendario
    if (index == 3) {
      _calendarKey.currentState?.refresh();
    }

    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    /// REPORTES -> requiere BASIC
    if (index == 4 && !appState.isAtLeastBasic) {

      /// Android muestra upsell
      if (!isIOS) {
        _showBlocked(
          context,
          'Reportes Financieros',
          'Accede a tus estadísticas a partir del Plan Básico.',
        );
      }

      /// IOS solo bloquea silenciosamente
      return;
    }

    /// GASTOS -> requiere PREMIUM
    if (index == 5 && !appState.isPremium) {

      /// Android muestra upsell
      if (!isIOS) {
        _showBlocked(
          context,
          'Control de Gastos',
          'El registro de egresos y utilidad neta es exclusivo del Plan Premium.',
          isForPremium: true,
        );
      }

      /// IOS solo bloquea
      return;
    }

    setState(() => _currentIndex = index);

    // Refresh dashboard
    if (index == 0) {
      _dashboardKey.currentState?.refresh();
    }
  }

  void _showBlocked(BuildContext context, String title, String message, {bool isForPremium = false}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isForPremium ? '👑 Exclusivo Premium' : '⭐ Función Pro',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PlansScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Ver Planes Disponibles',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = RentaFestApp.of(context);
    final isAtLeastBasic = appState.isAtLeastBasic;
    final isPremium = appState.isPremium;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Inicio'),
          const BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded),label: 'Inventario'),
          const BottomNavigationBarItem(icon: Icon(Icons.assignment_rounded), label: 'Pedidos'),
          const BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Calendario'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded, color: isAtLeastBasic ? null : Colors.grey.withOpacity(0.5)), label: 'Reportes',),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded, color: isPremium ? null : Colors.grey.withOpacity(0.5)), label: 'Gastos',),
        ],
      ),
    );
  }
}
