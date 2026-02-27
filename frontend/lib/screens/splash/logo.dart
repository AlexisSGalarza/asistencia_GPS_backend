import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../login/login_screen.dart';
import '../maestro/marcar_asistencia_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _iniciarApp();
  }

  Future<void> _iniciarApp() async {
    // Dar tiempo para mostrar el splash
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Intentar restaurar sesión
    final sesionActiva = await ApiService.restaurarSesion();

    if (!mounted) return;

    if (sesionActiva) {
      final rol = ApiService.rolUsuario.toLowerCase();
      if (rol == 'administrador' || rol == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin/dashboard');
      } else if (rol == 'supervisor') {
        Navigator.pushReplacementNamed(context, '/supervisor/incidencias');
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MarcarAsistenciaScreen()),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1E9F8), // Tu color #A98BC3
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo de la app
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                // Si ya tienes logo.png en assets/images/, usa Image.asset
                // Si no, muestra un ícono temporal
                child: Image.asset(
                  'assets/images/Logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Ícono temporal mientras no tengas el logo
                    return const Icon(
                      Icons.location_on,
                      size: 80,
                      color: Color(0xFFA98BC3),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Nombre de la app
            const Text(
              'Asistencia GPS',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 10),

            // Subtítulo
            Text(
              'Control de asistencia inteligente',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.8),
                letterSpacing: 1,
              ),
            ),

            const SizedBox(height: 50),

            // Indicador de carga
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
