import 'package:flutter/material.dart';

class ConfiguracionHorariosScreen extends StatelessWidget {
  const ConfiguracionHorariosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1E9F8),
      appBar: AppBar(
        title: const Text(
          'Configuración de Horarios',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF6B2D8B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Text(
          'Aquí podrás configurar los horarios',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
