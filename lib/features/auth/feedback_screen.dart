import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/api_constants.dart';
import '../../core/api_service.dart';
import '../../core/ui_notifications.dart';
import '../../main.dart';

class FeedbackModal extends StatefulWidget {
  final String tipo;

  const FeedbackModal({super.key, required this.tipo,});

  @override
  State<FeedbackModal> createState() => _FeedbackModalState();
}

class _FeedbackModalState extends State<FeedbackModal> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final mensaje = _controller.text.trim();

    if (mensaje.isEmpty) {
      AppNotifications.showError(context, 'Escribe un mensaje');
      return;
    }

    if (_sending) return;

    setState(() => _sending = true);

    try {
      final appState = RentaFestApp.of(context);

      final response = await ApiService.post(
        ApiConstants.soporte,
        {
          "tipo": widget.tipo,
          "mensaje": mensaje,
          "empresa": appState.empresa,
          "telefono": appState.telefono,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['ok'] == true) {
        if (!mounted) return;
        Navigator.pop(context);
        AppNotifications.showSuccess(context, 'Recibimos tu mensaje 🙌');
      } else {
        throw Exception(data['mensaje'] ?? 'No se pudo enviar');
      }
    } catch (e) {
      if (!mounted) return;
      AppNotifications.showError(context, 'No se pudo enviar');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final esProblema = widget.tipo == 'problema';

    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: bottom + 20,),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.35),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Text(esProblema ? 'Reportar problema' : 'Enviar sugerencia', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18,),),
            const SizedBox(height: 8),
            Text(esProblema ? 'Cuéntanos qué pasó para revisarlo.' : 'Tus ideas nos ayudan a mejorar RentaFest.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600,),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: esProblema ? 'Describe el problema...' : 'Escribe tu sugerencia...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _sending ? null : _send,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),),),
              child: _sending ?
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,),) :
              const Text('Enviar', style: TextStyle(fontWeight: FontWeight.w900),),
            ),
          ],
        ),
      ),
    );
  }
}