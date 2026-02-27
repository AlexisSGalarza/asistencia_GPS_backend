import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../login/login_screen.dart';
import 'marcar_asistencia_screen.dart';
import 'registros_screen.dart';
import 'perfil_screen.dart';

class HorarioScreen extends StatefulWidget {
  const HorarioScreen({super.key});

  @override
  State<HorarioScreen> createState() => _HorarioScreenState();
}

class _HorarioScreenState extends State<HorarioScreen> {
  List<Map<String, String>> _horarioSemanal = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarHorarios();
  }

  Future<void> _cargarHorarios() async {
    try {
      final horarios = ApiService.horarios;
      final List<Map<String, String>> lista = [];
      for (final h in horarios) {
        lista.add({
          'dia': h['dia_semana_display'] ?? '',
          'entrada': (h['hora_entrada'] ?? '').toString().substring(0, 5),
          'salida': (h['hora_salida'] ?? '').toString().substring(0, 5),
        });
      }
      if (mounted) {
        setState(() {
          _horarioSemanal = lista;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1E9F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildHeader() {
    final diasNombres = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final hoy = diasNombres[DateTime.now().weekday - 1];

    // Buscar el horario de hoy
    String? entradaHoy;
    String? salidaHoy;
    for (final h in _horarioSemanal) {
      if (h['dia'] == hoy) {
        entradaHoy = h['entrada'];
        salidaHoy = h['salida'];
        break;
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6B2D8B), Color(0xFFA98BC3)],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B2D8B).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.calendar_month,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mi Horario',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Horario semanal asignado',
                      style: TextStyle(
                        fontFamily: 'Merriweather',
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (entradaHoy != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF81C784),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Hoy ($hoy)',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$entradaHoy - $salidaHoy',
                    style: const TextStyle(
                      fontFamily: 'Merriweather',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6B2D8B)),
      );
    }

    if (_horarioSemanal.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 60,
              color: const Color(0xFF6B2D8B).withValues(alpha: 0.4),
            ),
            const SizedBox(height: 15),
            const Text(
              'No hay horarios asignados',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                color: Color(0xFF757575),
              ),
            ),
          ],
        ),
      );
    }

    final diasNombres = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final hoy = diasNombres[DateTime.now().weekday - 1];

    final diasAbrev = {
      'Lunes': 'LUN',
      'Martes': 'MAR',
      'Miércoles': 'MIÉ',
      'Jueves': 'JUE',
      'Viernes': 'VIE',
      'Sábado': 'SÁB',
      'Domingo': 'DOM',
    };

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      itemCount: _horarioSemanal.length,
      itemBuilder: (context, index) {
        final dia = _horarioSemanal[index];
        final bool esHoy = dia['dia'] == hoy;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: esHoy
                ? Border.all(color: const Color(0xFF6B2D8B), width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: esHoy
                    ? const Color(0xFF6B2D8B).withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.08),
                blurRadius: esHoy ? 12 : 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Ícono del día
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: esHoy
                        ? const LinearGradient(
                            colors: [Color(0xFF6B2D8B), Color(0xFFA98BC3)],
                          )
                        : LinearGradient(
                            colors: [
                              const Color(0xFFA98BC3).withValues(alpha: 0.2),
                              const Color(0xFFE8A0BF).withValues(alpha: 0.2),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        diasAbrev[dia['dia']] ??
                            dia['dia']!.substring(0, 3).toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: esHoy ? Colors.white : const Color(0xFF6B2D8B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                // Nombre del día
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            dia['dia']!,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 15,
                              fontWeight: esHoy
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: esHoy
                                  ? const Color(0xFF6B2D8B)
                                  : const Color(0xFF3D3D3D),
                            ),
                          ),
                          if (esHoy) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFA98BC3),
                                    Color(0xFFE8A0BF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'HOY',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${dia['entrada']} - ${dia['salida']}',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Horas de entrada y salida
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildTimePill(
                      Icons.login,
                      dia['entrada']!,
                      const Color(0xFF2E7D32),
                    ),
                    const SizedBox(height: 6),
                    _buildTimePill(
                      Icons.logout,
                      dia['salida']!,
                      const Color(0xFFC62828),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimePill(IconData icon, String time, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            time,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Barra de navegación inferior ----------
  // ---------- Confirmar logout ----------
  void _mostrarConfirmarLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFC62828).withValues(alpha: 0.15),
              radius: 35,
              child: const Icon(
                Icons.logout,
                color: Color(0xFFC62828),
                size: 35,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '¿Cerrar sesión?',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3D3D3D),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '¿Estás seguro de que deseas cerrar tu sesión?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 13,
                color: Color(0xFF757575),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF6B2D8B)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B2D8B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ApiService.logout().then((_) {
                      Navigator.pop(ctx);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Salir',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        child: BottomNavigationBar(
          currentIndex: 1,
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const MarcarAsistenciaScreen(),
                ),
              );
            } else if (index == 2) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const RegistrosScreen()),
              );
            } else if (index == 3) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const PerfilScreen()),
              );
            } else if (index == 4) {
              _mostrarConfirmarLogout();
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF6B2D8B),
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 10,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.location_on_outlined),
              activeIcon: Icon(Icons.location_on),
              label: 'Marcar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Horario',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'Registros',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.logout, color: Colors.red),
              label: 'Salir',
            ),
          ],
        ),
      ),
    );
  }
}
