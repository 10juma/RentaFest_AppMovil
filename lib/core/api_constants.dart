class ApiConstants {
  static const String baseUrl = 'https://rentafestapi.globalappsuite.com.mx/api';
  
  // Auth
  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';
  static const String solicitarAcceso = '$baseUrl/auth/solicitar-acceso';
  static const String updatePlan = '$baseUrl/auth/plan';
  static const String redeemCode = '$baseUrl/auth/redeem-code';
  static const String refresh = '$baseUrl/auth/refresh';
  static const String resetPassword = '$baseUrl/auth/reset-password';

  // Usuario
  static const String perfil = '$baseUrl/usuario/perfil';
  static const String deleteAccount = '$baseUrl/usuario/cuenta';

  // Soporte
  static const String soporte = '$baseUrl/soporte';

  // Artículos (Inventario)
  static const String articulos = '$baseUrl/articulos';
  static const String categorias = '$baseUrl/articulos/categorias';

  // Pedidos
  static const String pedidos = '$baseUrl/pedidos';
  static String pedidoEstatus(int id) => '$baseUrl/pedidos/$id/estatus';
  static String pedidoUtilidad(int id) => '$baseUrl/pedidos/$id/utilidad';

  // Dashboard
  static const String dashboard = '$baseUrl/dashboard';

  // Reportes
  static const String reportes = '$baseUrl/reportes/ingresos';

  // Gastos
  static const String gastos = '$baseUrl/gastos';

  // Calendario
  static const calendario = '$baseUrl/calendario';
}
