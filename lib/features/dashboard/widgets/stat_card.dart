import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String emoji;
  final String val;
  final String label;
  final String delta;
  final bool? isPositive;

  const StatCard({
    super.key,
    required this.emoji,
    required this.val,
    required this.label,
    required this.delta,
    this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    Color deltaColor = Colors.grey;
    if (isPositive == true) deltaColor = Colors.green;
    if (isPositive == false) deltaColor = Colors.orange;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const Spacer(),
          Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(delta, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: deltaColor)),
        ],
      ),
    );
  }
}
