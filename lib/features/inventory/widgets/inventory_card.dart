import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../main.dart';
import '../../auth/plans_screen.dart';
import '../models/inventory_item.dart';
import '../inventory_edit_screen.dart';

class InventoryCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onUpdated;

  const InventoryCard({
    super.key,
    required this.item,
    required this.onUpdated,
  });

  void _showPremiumBlocked(BuildContext context, String message) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⭐ Función Pro', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
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
              child: const Text('Ver Planes', style: TextStyle(fontWeight: FontWeight.w900)),
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
    final theme = Theme.of(context);
    final isAtLeastBasic = RentaFestApp.of(context).isAtLeastBasic;

    return GestureDetector(
      onTap: () async {
        if (!isAtLeastBasic) {
          if (!isIOS) {
            _showPremiumBlocked(context, 'La edición de artículos de tu inventario está disponible a partir del Plan Básico.');
          }
          return;
        }

        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InventoryEditScreen(item: item),
          ),
        );

        if (result == true && context.mounted) {
          onUpdated();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withAlpha(20),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(item.emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  Text(item.withOperator ? '👤 Con operador' : 'Sin operador', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.stockColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${item.stockLabel} de ${item.totalStock}', style: TextStyle(color: item.stockColor, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 6),
                  // Barra de stock
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: item.stockPercentage,
                      minHeight: 4,
                      backgroundColor: Colors.grey.withOpacity(0.1),
                      color: item.stockColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('\$${item.price.toInt()}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }
}
