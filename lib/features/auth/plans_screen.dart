import 'dart:io';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../../core/theme.dart';
import 'package:url_launcher/url_launcher.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> with WidgetsBindingObserver {
  bool _isAnnual = false;
  bool _openedWeb = false;

  final String _webUrl = 'https://rentafest.globalappsuite.com.mx/Cuenta/Perfil'; // URL

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _openedWeb) {
      _openedWeb = false;
      _refreshPlan();
    }
  }

  Future<void> _refreshPlan() async {
    try {
      // Cerrar esta pantalla y regresar "true" para indicar
      // que el Dashboard debe refrescar su información.
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error actualizando plan: $e');
    }
  }

  Future<void> _openWebPlans() async {
    _openedWeb = true;
    final uri = Uri.parse(_webUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    // En iOS no mostramos planes ni precios para cumplir con App Store Guidelines 3.1.1.
    if (Platform.isIOS) {
      return _buildIOSLockedScreen(context);
    }

    final theme = Theme.of(context);
    final currentPlan = RentaFestApp.of(context).plan;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planes', style: TextStyle(fontWeight: FontWeight.w900),),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildHeader(context),
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCycleOption('Mensual', !_isAnnual),
                  _buildCycleOption('Anual', _isAnnual, hasDiscount: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildPlanCard('Free', 'Empieza sin costo', '\$0',
            [
              '3 tipos de artículos',
              '2 eventos al mes',
              'Funciones limitadas'
            ],
            currentPlan == AppPlan.free,
            Colors.grey,
          ),
          const SizedBox(height: 20),
          _buildPlanCard('Básico', 'Control completo de tu negocio', _isAnnual ? '\$1,990' : '\$199',
            [
              'Eventos ilimitados',
              'Reportes financieros',
              'Edición completa'
            ],
            currentPlan == AppPlan.basic,
            AppColors.accent,
            period: _isAnnual ? '/año' : '/mes',
          ),
          const SizedBox(height: 20),
          _buildPlanCard('Premium', 'Automatiza y escala tu operación', _isAnnual ? '\$3,990' : '\$399',
            [
              'Todo lo del plan básico',
              'Control de gastos',
              'Utilidad en tiempo real',
              'Contratos PDF',
              'Cotizaciones automáticas'
            ],
            currentPlan == AppPlan.premium,
            const Color(0xFFF39C12),
            isFeatured: true,
            period: _isAnnual ? '/año' : '/mes',
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _openWebPlans,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Administrar suscripción en web',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Los planes se administran desde la plataforma web para brindarte mayor control y seguridad en tu suscripción.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // Pantalla neutra para iOS: sin nombres de planes ni precios (cumple 3.1.1).
  Widget _buildIOSLockedScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Función no disponible', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'Acceso restringido',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Esta función no está disponible en tu cuenta actual. Para más información visita rentafest.globalappsuite.com.mx',
              style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Regresar', style: TextStyle(fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // HEADER
  Widget _buildHeader(BuildContext context) {
    final appState = RentaFestApp.of(context);

    return Column(
      children: [
        const Icon(Icons.workspace_premium_rounded, size: 40),
        const SizedBox(height: 12),
        const Text('Impulsa tu negocio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),),
        const SizedBox(height: 6),
        Text('Plan actual: ${appState.plan.name.toUpperCase()}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w700,),),
      ],
    );
  }

  // CICLO
  Widget _buildCycleOption(String label, bool isSelected, {bool hasDiscount = false}) {
    return GestureDetector(
      onTap: () => setState(() => _isAnnual = label == 'Anual'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isSelected ? Colors.white : Colors.grey,),),
            if (hasDiscount) ...[
              const SizedBox(width: 6),
              const Text('-20%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
            ],
          ],
        ),
      ),
    );
  }

  // CARD
  Widget _buildPlanCard(String name, String sub, String price, List<String> perks, bool isCurrent, Color color, {bool isFeatured = false, String period = '',}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isFeatured ? color : Colors.grey.withOpacity(0.2), width: isFeatured ? 2 : 1,),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),),
              if (isCurrent)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12),),
                  child: Text('ACTUAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color),),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(sub, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600,),),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),),
              if (period.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(period, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w700),),
                ),
            ],
          ),
          const Divider(height: 30),
          ...perks.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.check, size: 16, color: color),
                const SizedBox(width: 8),
                Text(p, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),),
              ],
            ),
          )),
        ],
      ),
    );
  }
}