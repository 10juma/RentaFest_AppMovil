class ReporteMes {
  final String titulo;
  final int mes;
  final String NombreMes;
  final int totalPedidos;
  final double ingresos;
  final double gastos;
  final double utilidad;
  final double ticketPromedio;
  final double tasaEntrega;

  ReporteMes({
    required this.titulo,
    required this.mes,
    required this.NombreMes,
    required this.totalPedidos,
    required this.ingresos,
    required this.gastos,
    required this.utilidad,
    required this.ticketPromedio,
    required this.tasaEntrega,
  });

  factory ReporteMes.fromJson(Map<String, dynamic> json) {
    return ReporteMes(
      titulo: json['titulo'],
      mes: json['mes'],
      NombreMes: json['NombreMes'],
      totalPedidos: json['totalPedidos'],
      ingresos: (json['ingresos'] as num).toDouble(),
      gastos: (json['gastos'] as num).toDouble(),
      utilidad: (json['utilidad'] as num).toDouble(),
      ticketPromedio: (json['ticketPromedio'] as num).toDouble(),
      tasaEntrega: (json['tasaEntrega'] as num).toDouble(),
    );
  }
}

class ReporteCategoria {
  final String categoria;
  final String emoji;
  final double ingresoTotal;

  ReporteCategoria({
    required this.categoria,
    required this.emoji,
    required this.ingresoTotal,
  });

  factory ReporteCategoria.fromJson(Map<String, dynamic> json) {
    return ReporteCategoria(
      categoria: json['categoria'],
      emoji: json['emoji'] ?? '',
      ingresoTotal: (json['ingresoTotal'] as num).toDouble(),
    );
  }
}