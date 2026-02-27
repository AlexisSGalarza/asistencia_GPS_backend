import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash/logo.dart';
import 'screens/login/login_screen.dart';
import 'screens/maestro/marcar_asistencia_screen.dart';
import 'screens/admin/dashboard_screen.dart';
import 'screens/admin/gestion_usuarios_screen.dart';
import 'screens/admin/gestion_horarios_screen.dart';
import 'screens/admin/gestion_perimetros_screen.dart';
import 'screens/admin/reportes_maestros_screen.dart';
import 'screens/supervisor/gestion_incidencias_screen.dart';
import 'screens/supervisor/historial_equipo_screen.dart';
import 'screens/supervisor/visualizador_reportes_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asistencia GPS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFA98BC3)),
        useMaterial3: true,
        textTheme: GoogleFonts.montserratTextTheme(),
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/maestro': (_) => const MarcarAsistenciaScreen(),
        '/admin/dashboard': (_) => const DashboardScreen(),
        '/admin/usuarios': (_) => const GestionUsuariosScreen(),
        '/admin/horarios': (_) => const GestionHorariosScreen(),
        '/admin/config': (_) => const GestionPerimetrosScreen(),
        '/admin/reportes': (_) => const ReportesMaestrosScreen(),
        '/supervisor/incidencias': (_) => const GestionIncidenciasScreen(),
        '/supervisor/historial': (_) => const HistorialEquipoScreen(),
        '/supervisor/reportes': (_) => const VisualizadorReportesScreen(),
      },
    );
  }
}
