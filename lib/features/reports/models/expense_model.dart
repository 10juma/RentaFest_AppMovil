import 'package:flutter/material.dart';

enum ExpenseCategory { gasolina, sueldos, mantenimiento, insumos, otros }

class ExpenseModel {
  final int id;
  final String description;
  final double amount;
  final DateTime date;
  final ExpenseCategory category;
  final int? orderId;
  final String? tipoGasto;
  final String? periodo;
  final String? creadoPor;

  ExpenseModel({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.category,
    this.orderId,
    this.tipoGasto,
    this.periodo,
    this.creadoPor,
  });

  String get categoryLabel {
    switch (category) {
      case ExpenseCategory.gasolina: return 'Gasolina';
      case ExpenseCategory.sueldos: return 'Sueldos';
      case ExpenseCategory.mantenimiento: return 'Mantenimiento';
      case ExpenseCategory.insumos: return 'Insumos';
      case ExpenseCategory.otros: return 'Otros';
    }
  }

  IconData get categoryIcon {
    switch (category) {
      case ExpenseCategory.gasolina: return Icons.local_gas_station_rounded;
      case ExpenseCategory.sueldos: return Icons.people_rounded;
      case ExpenseCategory.mantenimiento: return Icons.build_rounded;
      case ExpenseCategory.insumos: return Icons.shopping_bag_rounded;
      case ExpenseCategory.otros: return Icons.more_horiz_rounded;
    }
  }

  factory ExpenseModel.fromApi(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['Id'] ?? json['id'] ?? 0,
      description: json['Descripcion'] ?? '',
      amount: double.tryParse(json['Monto'].toString()) ?? 0,
      date: DateTime.tryParse(json['FechaGasto'].toString()) ?? DateTime.now(),
      category: _mapCategory(json['Categoria']),
      orderId: json['PedidoId'],
      tipoGasto: json['TipoGasto'],
      periodo: json['Periodo'],
      creadoPor: json['CreadoPor'],
    );
  }

  static ExpenseCategory _mapCategory(String? cat) {
    switch ((cat ?? '').toLowerCase()) {
      case 'gasolina': return ExpenseCategory.gasolina;
      case 'sueldos': return ExpenseCategory.sueldos;
      case 'mantenimiento': return ExpenseCategory.mantenimiento;
      case 'insumos': return ExpenseCategory.insumos;
      default: return ExpenseCategory.otros;
    }
  }
}
