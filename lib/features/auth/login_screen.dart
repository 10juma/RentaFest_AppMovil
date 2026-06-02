import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/api_constants.dart';
import '../../core/api_service.dart';
import '../../core/ui_notifications.dart';
import '../../main.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text;

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');

    if (email.isEmpty) {
      AppNotifications.showError(context, 'El correo es obligatorio');
      return;
    }

    if (!emailRegex.hasMatch(email)) {
      AppNotifications.showError(context, 'Correo inválido');
      return;
    }

    if (password.isEmpty) {
      AppNotifications.showError(context, 'La contraseña es obligatoria');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.post(ApiConstants.login, {
        'email': email,
        'password': password,
      });

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['ok'] == true) {
        ApiService.setToken(data['token']);
        final appState = RentaFestApp.of(context);
        appState.setPlanFromString(data['plan'] ?? 'free');

        appState.setEmpresaData(
          data['nombreEmpresa'] ?? '',
          data['telefono'] ?? '',
        );

        if (mounted) {
          AppNotifications.showSuccess(context, '¡Bienvenido de nuevo!');
          widget.onLogin();
        }
      } else {
        if (mounted) {
          AppNotifications.showError(context, data['mensaje'] ?? 'Error al iniciar sesión');
        }
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showError(context, 'No se pudo conectar con el servidor');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRedeemCode({required String codigo, required String nombreEmpresa, required String email, required String password,}) async {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');

    if (codigo.trim().isEmpty) {
      AppNotifications.showError(context, 'El código es obligatorio');
      return;
    }

    if (nombreEmpresa.trim().isEmpty) {
      AppNotifications.showError(context, 'El nombre del negocio es obligatorio');
      return;
    }

    if (!emailRegex.hasMatch(email.trim())) {
      AppNotifications.showError(context, 'Correo inválido');
      return;
    }

    if (password.length < 6) {
      AppNotifications.showError(context, 'La contraseña debe tener al menos 6 caracteres');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.post(ApiConstants.redeemCode, {
        'codigo': codigo.trim().toUpperCase(),
        'nombreEmpresa': nombreEmpresa.trim(),
        'email': email.trim(),
        'password': password,
        'telefono': '',
      });

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['ok'] == true) {
        ApiService.setToken(data['token']);

        final appState = RentaFestApp.of(context);

        appState.setPlanFromString(data['plan'] ?? 'premium');

        appState.setEmpresaData(
          data['nombreEmpresa'] ?? '',
          data['telefono'] ?? '',
        );

        if (mounted) {
          AppNotifications.showSuccess(context,'Código activado. Tienes Premium por 10 días.',);
          widget.onLogin();
        }
      } else {
        if (mounted) {
          AppNotifications.showError(context, data['mensaje'] ?? 'Código inválido',);
        }
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showError(context, 'No se pudo conectar con el servidor');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showResetPasswordDialog(BuildContext context) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isUpdating = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Recuperar contraseña', style: TextStyle(fontWeight: FontWeight.w900),),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingresa tu correo y tu nueva contraseña.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            // Correo
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'correo@ejemplo.com',
                filled: true,
                fillColor: Colors.grey.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Nueva contraseña
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Nueva contraseña',
                filled: true,
                fillColor: Colors.grey.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancelar',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          StatefulBuilder(
            builder: (context, setDialogState) {
              return ElevatedButton(
                onPressed: isUpdating ? null : () async {
                  final email = emailController.text.trim();
                  final newPassword = passwordController.text.trim();

                  if (email.isEmpty) {
                    AppNotifications.showError(context, 'El correo es obligatorio',);
                    return;
                  }

                  if (newPassword.length < 6) {
                    AppNotifications.showError(context, 'La contraseña debe tener al menos 6 caracteres',);
                    return;
                  }

                  setDialogState(() => isUpdating = true);

                  try {
                    final response = await ApiService.post(
                      ApiConstants.resetPassword,
                      {
                        'email': email,
                        'newPassword': newPassword,
                      },
                    );

                    final data = jsonDecode(response.body);

                    if (response.statusCode == 200 && data['ok'] == true) {
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }

                      if (context.mounted) {
                        AppNotifications.showSuccess(context, data['mensaje'] ?? 'Contraseña actualizada correctamente',);
                      }
                    } else {
                      if (context.mounted) {
                        AppNotifications.showError(context, data['mensaje'] ?? 'No se pudo actualizar la contraseña',);
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppNotifications.showError(context, 'No se pudo conectar con el servidor',);
                    }
                  } finally {
                    if (dialogContext.mounted) {
                      setDialogState(() => isUpdating = false);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),),
                ),
                child: isUpdating ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ) :
                const Text('Actualizar', style: TextStyle(fontWeight: FontWeight.bold,),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showCodeDialog(BuildContext context) {
    final codigoController = TextEditingController();
    final nombreController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Activar código', style: TextStyle(fontWeight: FontWeight.w900),),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ingresa tu código y crea tu acceso Premium temporal.', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500,),),
              const SizedBox(height: 20),

              _dialogField(controller: codigoController, hint: 'CÓDIGO', icon: Icons.confirmation_number_rounded, uppercase: true,),
              const SizedBox(height: 12),
              _dialogField(controller: nombreController, hint: 'Nombre del negocio', icon: Icons.storefront_rounded,),
              const SizedBox(height: 12),
              _dialogField(controller: emailController, hint: 'Correo electrónico', icon: Icons.email_rounded, keyboardType: TextInputType.emailAddress,),
              const SizedBox(height: 12),
              _dialogField(controller: passwordController, hint: 'Contraseña', icon: Icons.lock_rounded, isPassword: true,),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold,),),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _handleRedeemCode(
                codigo: codigoController.text,
                nombreEmpresa: nombreController.text,
                email: emailController.text,
                password: passwordController.text,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Activar', style: TextStyle(fontWeight: FontWeight.bold),),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Hero Section
              Column(
                children: [
                  const Text('🎪', style: TextStyle(fontSize: 72)),
                  Text('RentaFest', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
                  Text(
                    Platform.isIOS ? 'Gestión para negocios de eventos' : 'Administra tu negocio de rentas',
                    style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600,),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      Platform.isIOS ? '✨ Plataforma profesional' : '✨ Empieza gratis',
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w800, fontSize: 12,),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              // Form Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTextField(
                    context,
                    'Email',
                    'correo@ejemplo.com',
                    _emailController,
                    false,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    context,
                    'Contraseña',
                    '••••••••',
                    _passwordController,
                    true,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading ?
                    const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2,),) :
                    const Text('Entrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900,),),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _showResetPasswordDialog(context),
                    child: Text(
                      '🔑 ¿Olvidaste tu contraseña?',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  /// IOS
                  if (Platform.isIOS) ...[
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RegisterScreen(
                              onRegister: widget.onLogin,
                            ),
                          ),
                        );
                      },
                      child: Text(
                        '📩 Solicitar acceso',
                        style: TextStyle(
                          color: theme.hintColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  /// ANDROID
                  if (!Platform.isIOS) ...[
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RegisterScreen(
                              onRegister: widget.onLogin,
                            ),
                          ),
                        );
                      },
                      child: Text(
                        '📝 Crear cuenta gratis',
                        style: TextStyle(
                          color: theme.hintColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    TextButton(
                      onPressed: () => _showCodeDialog(context),
                      child: Text(
                        '🎟️ Tengo un código',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Text(
                      'Al registrarte entras al plan Free automáticamente',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(BuildContext context, String label, String hint, TextEditingController controller, bool isPassword) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5)
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _dialogField({required TextEditingController controller, required String hint, required IconData icon, bool isPassword = false, bool uppercase = false, TextInputType keyboardType = TextInputType.text,}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      textCapitalization:
      uppercase ? TextCapitalization.characters : TextCapitalization.none,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      style: TextStyle(
        fontWeight: uppercase ? FontWeight.bold : FontWeight.w600,
        letterSpacing: uppercase ? 1.5 : 0,
      ),
      textAlign: TextAlign.start,
    );
  }
}
