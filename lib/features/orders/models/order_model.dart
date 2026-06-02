import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum OrderStatus { nuevo, confirmado, enCamino, entregado, cerrado, cancelado }

class OrderModel {
  final int id;
  final String clientName;
  final int NoPedido;
  final String itemsSummary;
  final String date;
  final String hours;
  final double total;
  final OrderStatus status;
  final Color avatarColor;
  final String initials;
  final String? clientPhone;
  final String? address;
  final List<OrderItem> items;

  OrderModel({
    required this.id,
    required this.clientName,
    required this.NoPedido,
    required this.itemsSummary,
    required this.date,
    required this.hours,
    required this.total,
    required this.status,
    required this.avatarColor,
    required this.initials,
    this.clientPhone,
    this.address,
    this.items = const [],
  });

  factory OrderModel.fromApi(Map<String, dynamic>? json) {
    if (json == null) return OrderModel.empty();
    final detalle = json['Detalle'] ?? json['detalle'];

    return OrderModel(
      id: int.tryParse((json['Id'] ?? json['id'] ?? 0).toString()) ?? 0,
      clientName: json['ClienteNombre'] ?? json['clienteNombre'] ?? '',
      NoPedido: int.tryParse((json['NoPedido'] ?? json['noPedido'] ?? 0).toString()) ?? 0,
      itemsSummary: json['ResumenArticulos'] ?? json['resumenArticulos'] ?? '',
      date: (json['FechaEvento'] ?? json['fechaEvento'] ?? '').toString(),
      hours: (json['HoraEvento'] ?? json['horaEvento'] ?? '').toString(),
      total: double.tryParse((json['Total'] ?? json['total'] ?? 0).toString()) ?? 0.0,
      status: _mapStatus(json['Estatus'] ?? json['estatus']),
      avatarColor: _getColorFromName(json['ClienteNombre'] ?? json['clienteNombre'] ?? ''),
      initials: _getInitials(json['ClienteNombre'] ?? json['clienteNombre'] ?? ''),
      clientPhone: json['ClienteTelefono'] ?? json['clienteTelefono'],
      address: json['EventoDireccion'] ?? json['eventoDireccion'],
      items: detalle is List
          ? detalle
              .where((e) => e != null && e is Map)
              .map((e) => OrderItem.fromApi(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  factory OrderModel.empty() {
    return OrderModel(
      id: 0,
      clientName: '',
      NoPedido: 0,
      itemsSummary: '',
      date: '',
      hours: '',
      total: 0,
      status: OrderStatus.nuevo,
      avatarColor: Colors.grey,
      initials: '',
    );
  }

  static OrderStatus _mapStatus(String? estatus) {
    final e = (estatus ?? '').toLowerCase().replaceAll(' ', '');

    switch (e) {
      case 'nuevo':
        return OrderStatus.nuevo;
      case 'confirmado':
        return OrderStatus.confirmado;
      case 'encamino':
        return OrderStatus.enCamino;
      case 'entregado':
        return OrderStatus.entregado;
      case 'cerrado':
        return OrderStatus.cerrado;
      case 'cancelado':
        return OrderStatus.cancelado;
      default:
        return OrderStatus.nuevo;
    }
  }

  static Color _getColorFromName(String name) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];
    return colors[name.hashCode % colors.length];
  }

  static String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '';
  }

  String get statusLabel {
    switch (status) {
      case OrderStatus.nuevo: return 'Nuevo';
      case OrderStatus.confirmado: return 'Confirmado';
      case OrderStatus.enCamino: return 'En camino';
      case OrderStatus.entregado: return 'Entregado';
      case OrderStatus.cerrado: return 'Cerrado';
      case OrderStatus.cancelado: return 'Cancelado';
    }
  }

  Color get statusColor {
    switch (status) {
      case OrderStatus.nuevo: return Colors.blue;
      case OrderStatus.confirmado: return const Color(0xFF43C6AC);
      case OrderStatus.enCamino: return Colors.orange;
      case OrderStatus.entregado: return const Color(0xFF6C63FF);
      case OrderStatus.cerrado: return Colors.grey;
      case OrderStatus.cancelado: return Colors.redAccent;
    }
  }

  String get fechaEventoFormateada {
    if (date.isEmpty) return '';

    try {
      final fecha = DateTime.parse(date);

      if (hours.isNotEmpty) {
        final partes = hours.split(':');
        final hora = int.tryParse(partes[0]) ?? 0;
        final minuto = int.tryParse(partes[1]) ?? 0;
        final fechaCompleta = DateTime(fecha.year, fecha.month, fecha.day, hora, minuto,);

        return DateFormat('dd MMM yyyy, hh:mm a', 'es_MX').format(fechaCompleta);
      }

      return DateFormat('dd MMM yyyy', 'es_MX').format(fecha);
    } catch (e) {
      return date;
    }
  }
}

class OrderItem {
  final int articuloId;
  final String name;
  final int quantity;
  final double total;
  final String emoji;

  OrderItem({
    required this.articuloId,
    required this.name,
    required this.quantity,
    required this.total,
    required this.emoji,
  });

  factory OrderItem.fromApi(Map<String, dynamic> json) {
    return OrderItem(
      articuloId: int.tryParse((json['ArticuloId'] ?? json['articuloId'] ?? 0).toString()) ?? 0,
      name: json['ArticuloNombre'] ?? json['articuloNombre'] ?? '',
      quantity: int.tryParse((json['Cantidad'] ?? json['cantidad'] ?? 0).toString()) ?? 0,
      total: double.tryParse((json['Subtotal'] ?? json['subtotal'] ?? 0).toString()) ?? 0.0,
      emoji: json['ArticuloEmoji'] ?? json['articuloEmoji'] ?? '📦',
    );
  }
}

class OrderExpense {
  final double ingreso;
  final double totalGastos;
  final double utilidadNeta;

  OrderExpense({
    required this.ingreso,
    required this.totalGastos,
    required this.utilidadNeta,
  });

  factory OrderExpense.fromApi(Map<String, dynamic>? json) {
    if (json == null) return OrderExpense.empty();

    return OrderExpense(
      ingreso: double.tryParse((json['Ingreso'] ?? json['ingreso'] ?? 0).toString()) ?? 0.0,
      totalGastos: double.tryParse((json['TotalGastos'] ?? json['totalGastos'] ?? 0).toString()) ?? 0.0,
      utilidadNeta: double.tryParse((json['UtilidadNeta'] ?? json['utilidadNeta'] ?? 0).toString()) ?? 0.0,
    );
  }

  factory OrderExpense.empty() {
    return OrderExpense(
      ingreso: 0,
      totalGastos: 0,
      utilidadNeta: 0,
    );
  }
}
