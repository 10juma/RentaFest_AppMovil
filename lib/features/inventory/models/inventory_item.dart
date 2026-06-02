import 'package:flutter/material.dart';

class InventoryItem {
  final int id;
  final String name;
  final String category;
  final String emoji;
  final int totalStock;
  final int availableStock;
  final double price;
  final bool withOperator;
  final bool isPublic; // Nuevo campo para el catálogo

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.emoji,
    required this.totalStock,
    required this.availableStock,
    required this.price,
    this.withOperator = false,
    this.isPublic = true, // Por defecto todos son públicos
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['Id'],
      name: json['Nombre'],
      category: json['Categoria'],
      emoji: json['Emoji'] ?? '📦',
      totalStock: json['StockTotal'] ?? 0,
      availableStock: json['StockDisponible'] ?? 0,
      price: (json['PrecioPorEvento'] as num?)?.toDouble() ?? 0,
      withOperator: json['IncluyeOperador'] ?? false,
      isPublic: json['EsPublico'] ?? true,
    );
  }

  double get stockPercentage => availableStock / totalStock;
  
  Color get stockColor {
    if (availableStock == 0) return Colors.red;
    if (stockPercentage < 0.35) return Colors.orange;
    return const Color(0xFF43C6AC); // Mint color from demo
  }

  String get stockLabel {
    if (availableStock == 0) return 'Sin stock';
    if (stockPercentage < 0.35) return 'Solo $availableStock disponibles';
    return '$availableStock disponibles';
  }
}
