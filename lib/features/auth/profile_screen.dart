import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_constants.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../main.dart';
import '../../core/ui_notifications.dart';
import 'feedback_screen.dart';
import 'plans_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  bool _loading = true;
  bool _saving = false;
  bool _openedWeb = false;

  final _businessController = TextEditingController();
  final _phoneController = TextEditingController();
  String _email = '';

  static const _webProfileUrl = 'https://rentafest.globalappsuite.com.mx/Cuenta/Perfil';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPerfil();
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
      final response = await ApiService.post(ApiConstants.refresh, {});
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['ok'] == true) {
        await ApiService.setToken(data['token']);
        if (mounted) {
          RentaFestApp.of(context).setPlanFromString(data['plan'] ?? 'free');
          setState(() {}); // refresca el badge del plan
        }
      }
    } catch (_) {}
  }

  Future<void> _openWebProfile() async {
    _openedWeb = true;
    final uri = Uri.parse(_webProfileUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _loadPerfil() async {
    try {
      final response = await ApiService.get(ApiConstants.perfil);
      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        final perfil = data['data'];

        setState(() {
          _businessController.text = perfil['NombreEmpresa'] ?? '';
          _phoneController.text = perfil['TelefonoEmpresa'] ?? '';
          _email = perfil['Email'] ?? '';
          _loading = false;
        });
      } else {
        throw Exception(data['mensaje']);
      }
    } catch (e) {
      setState(() => _loading = false);
      AppNotifications.showError(context, 'Error cargando perfil');
    }
  }

  Future<void> _savePerfil() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final response = await ApiService.put(
        ApiConstants.perfil,
        {
          "nombreEmpresa": _businessController.text.trim(),
          "telefonoEmpresa": _phoneController.text.trim(),
        },
      );

      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        AppNotifications.showSuccess(context, 'Perfil actualizado');

        // actualizar appState
        final appState = RentaFestApp.of(context);
        appState.setEmpresaData(
          _businessController.text.trim(),
          _phoneController.text.trim(),
        );
      } else {
        throw Exception(data['mensaje']);
      }
    } catch (e) {
      AppNotifications.showError(context, 'Error al guardar perfil');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showDeleteAccountConfirmation() async {
    final appState = RentaFestApp.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar cuenta', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.red)),
        content: const Text(
          'Esta acción es permanente y no se puede deshacer. Se eliminarán todos tus datos, inventario, pedidos y reportes.\n\n¿Estás seguro de que deseas eliminar tu cuenta?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar cuenta', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final response = await ApiService.delete(ApiConstants.deleteAccount);

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) {
          appState.logout();
          return;
        }
        final data = jsonDecode(body);
        if (data['ok'] == true) {
          appState.logout();
        } else {
          throw Exception(data['mensaje'] ?? 'Error al eliminar cuenta');
        }
      } else {
        throw Exception('Error ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) AppNotifications.showError(context, 'Error al eliminar la cuenta');
    }
  }

  void _showLogoutConfirmation() {
    // Capturamos el appState antes de entrar al diálogo para evitar problemas de contexto
    final appState = RentaFestApp.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('¿Estás seguro de que quieres salir de RentaFest?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar diálogo
              appState.logout(); // Usar la referencia capturada
            },
            child: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = RentaFestApp.of(context);
    final currentPlan = appState.plan;
    final isPremium = appState.isPremium;
    final isBasic = currentPlan == AppPlan.basic;
    final isFree = currentPlan == AppPlan.free;
    final initials = (_businessController.text.isNotEmpty) ? _businessController.text.trim().split(' ').map((e) => e[0]).take(2).join() : 'RF';

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: Text(initials.toUpperCase(), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
                ),
                const SizedBox(height: 16),
                Text(_email, style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600)),
                if (!Platform.isIOS) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isFree ? Colors.grey : theme.colorScheme.primary).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (isFree ? Colors.grey : theme.colorScheme.primary).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      isPremium ? 'PLAN PREMIUM' : (isBasic ? 'PLAN BÁSICO' : 'PLAN FREE'),
                      style: TextStyle(
                        color: isFree ? Colors.grey : theme.colorScheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 40),
          _buildSectionTitle('Configuración de la App'),
          _buildCard([
            const Text('Modo de Visualización', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildThemeChip(context, 'Sistema', ThemeMode.system, Icons.brightness_auto_rounded),
                _buildThemeChip(context, 'Claro', ThemeMode.light, Icons.light_mode_rounded),
                _buildThemeChip(context, 'Oscuro', ThemeMode.dark, Icons.dark_mode_rounded),
              ],
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionTitle('Información Personal'),
          _buildCard([
            _buildTextField('Nombre del Negocio', _businessController),
            const SizedBox(height: 16),
            _buildTextField('Teléfono de contacto', _phoneController, keyboard: TextInputType.phone),
          ]),
          if (!Platform.isIOS) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('Mi Suscripción'),
            _buildCard([
              _buildSupportItem(
                icon: Icons.workspace_premium_rounded,
                title: 'Ver Planes y Beneficios',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PlansScreen()),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _savePerfil,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),),
            ),
            child: _saving ?
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,),) :
            const Text('Guardar Cambios', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),),
          ),
          const SizedBox(height: 10),
          Text('Los cambios se guardan automáticamente en tu cuenta', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600,),),
          const SizedBox(height: 32),
          _buildSectionTitle('Soporte'),
          _buildCard([
            _buildSupportItem(
              icon: Icons.feedback_rounded,
              title: 'Enviar sugerencia',
              onTap: () => _openFeedback('sugerencia'),
            ),
            const SizedBox(height: 12),
            _buildSupportItem(
              icon: Icons.report_problem_rounded,
              title: 'Reportar problema',
              onTap: () => _openFeedback('problema'),
            ),
          ]),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _showLogoutConfirmation,
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _showDeleteAccountConfirmation,
            child: const Text(
              'Eliminar cuenta',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildThemeChip(BuildContext context, String label, ThemeMode mode, IconData icon) {
    final appState = RentaFestApp.of(context);
    final isSelected = appState.themeMode == mode;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => appState.toggleTheme(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? theme.colorScheme.primary : Colors.grey.withOpacity(0.2)),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : Colors.grey)),
        ]),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5)),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType keyboard = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSupportItem({required IconData icon, required String title, required VoidCallback onTap,}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13,),),),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ],
      ),
    );
  }

  void _openFeedback(String tipo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => FeedbackModal(tipo: tipo),
    );
  }
}
