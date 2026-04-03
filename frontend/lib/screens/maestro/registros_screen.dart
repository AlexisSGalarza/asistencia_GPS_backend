import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/animated_list_item.dart';
import '../login/login_screen.dart';
import 'marcar_asistencia_screen.dart';
import 'horario_screen.dart';
import 'perfil_screen.dart';

class RegistrosScreen extends StatefulWidget {
  const RegistrosScreen({super.key});

  @override
  State<RegistrosScreen> createState() => _RegistrosScreenState();
}

class _RegistrosScreenState extends State<RegistrosScreen> {
  List<Map<String, dynamic>> _registros = [];
  List<Map<String, dynamic>> _registrosFiltrados = [];
  bool _isLoading = true;
  int _asistencias = 0;
  int _retardos = 0;
  int _faltas = 0;

  // Filtros
  String? _filtroSemana; // null = todas, 'esta', 'pasada'
  String?
  _filtroTipo; // null = todas, o 'Completo','Falta','Retardo','Salida Temprana','Olvidó Salida'

  @override
  void initState() {
    super.initState();
    _cargarRegistros();
  }

  Future<void> _cargarRegistros() async {
    try {
      final historial = await ApiService.getHistorial();
      final incidencias = await ApiService.getIncidencias();

      final List<Map<String, dynamic>> registros = [];
      int asistencias = 0;
      int retardos = 0;
      int faltas = 0;

      // Agrupar asistencias por fecha
      final Map<String, Map<String, dynamic>> porFecha = {};
      for (final a in historial) {
        final fechaHora = DateTime.tryParse(a['fecha_hora'] ?? '');
        if (fechaHora == null) continue;
        final fechaKey =
            '${fechaHora.year}-${fechaHora.month.toString().padLeft(2, '0')}-${fechaHora.day.toString().padLeft(2, '0')}';

        porFecha.putIfAbsent(
          fechaKey,
          () => {
            'fechaKey': fechaKey,
            'fecha': fechaKey,
            'entrada': '--:--',
            'salida': '--:--',
            'estado': 'Completo',
          },
        );

        if (a['tipo'] == 'entrada') {
          porFecha[fechaKey]!['entrada'] =
              '${fechaHora.hour.toString().padLeft(2, '0')}:${fechaHora.minute.toString().padLeft(2, '0')}';
        } else if (a['tipo'] == 'salida') {
          porFecha[fechaKey]!['salida'] =
              '${fechaHora.hour.toString().padLeft(2, '0')}:${fechaHora.minute.toString().padLeft(2, '0')}';
        }
      }

      // Mapear incidencias por fecha para asignar estado correcto
      final Map<String, String> incidenciasPorFecha = {};
      for (final i in incidencias) {
        final tipo = i['tipo'] ?? '';
        final fecha = i['fecha'] ?? '';
        if (tipo == 'retardo') retardos++;
        if (tipo == 'falta') faltas++;
        if (fecha.toString().isNotEmpty) {
          // Prioridad: falta > retardo > salida_temprana > olvido_salida
          const prioridad = {
            'falta': 4,
            'retardo': 3,
            'salida_temprana': 2,
            'olvido_salida': 1,
          };
          final existente = incidenciasPorFecha[fecha];
          final pNuevo = prioridad[tipo] ?? 0;
          final pExistente = prioridad[existente] ?? 0;
          if (existente == null || pNuevo > pExistente) {
            incidenciasPorFecha[fecha] = tipo;
          }
        }
      }

      // Asignar estado a cada día basado en incidencias
      for (final entry in porFecha.entries) {
        final incTipo = incidenciasPorFecha[entry.key];
        if (incTipo == 'retardo') {
          entry.value['estado'] = 'Retardo';
        } else if (incTipo == 'falta') {
          entry.value['estado'] = 'Falta';
        } else if (incTipo == 'salida_temprana') {
          entry.value['estado'] = 'Salida Temprana';
        } else if (incTipo == 'olvido_salida') {
          entry.value['estado'] = 'Olvidó Salida';
        } else {
          entry.value['estado'] = 'Completo';
        }
      }

      // Agregar días con falta pero sin asistencia registrada
      for (final inc in incidencias) {
        if (inc['tipo'] != 'falta') continue; // solo faltas sin entrada
        final fecha = inc['fecha']?.toString() ?? '';
        if (fecha.isEmpty) continue;
        if (!porFecha.containsKey(fecha)) {
          porFecha[fecha] = {
            'fechaKey': fecha,
            'fecha': fecha,
            'entrada': '--:--',
            'salida': '--:--',
            'estado': 'Falta',
          };
        }
      }

      // Ordenar por fecha descendente ANTES de formatear
      final sortedKeys = porFecha.keys.toList()..sort((a, b) => b.compareTo(a));

      // Formatear fechas y construir lista final
      final meses = [
        'Enero',
        'Febrero',
        'Marzo',
        'Abril',
        'Mayo',
        'Junio',
        'Julio',
        'Agosto',
        'Septiembre',
        'Octubre',
        'Noviembre',
        'Diciembre',
      ];

      for (final key in sortedKeys) {
        final entry = porFecha[key]!;
        final partes = key.split('-');
        final dia = int.parse(partes[2]);
        final mes = int.parse(partes[1]);
        final anio = partes[0];
        entry['fecha'] = '$dia de ${meses[mes - 1]} $anio';

        if (entry['estado'] != 'Falta' &&
            entry['estado'] != 'Retardo' &&
            entry['estado'] != 'Salida Temprana') {
          asistencias++; // Olvidó Salida sí cuenta como asistencia (el maestro sí fue)
        }
        registros.add(entry);
      }

      if (mounted) {
        setState(() {
          _registros = registros;
          _registrosFiltrados = List.from(
            registros,
          ); // sin filtros inicialmente
          _asistencias = asistencias;
          _retardos = retardos;
          _faltas = faltas;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _aplicarFiltros() {
    List<Map<String, dynamic>> resultado = List.from(_registros);

    // Filtro por semana
    if (_filtroSemana != null) {
      final ahora = DateTime.now();
      final inicioSemana = ahora.subtract(Duration(days: ahora.weekday - 1));
      DateTime desde;
      DateTime hasta;
      if (_filtroSemana == 'esta') {
        desde = DateTime(
          inicioSemana.year,
          inicioSemana.month,
          inicioSemana.day,
        );
        hasta = desde.add(const Duration(days: 6));
      } else {
        desde = DateTime(
          inicioSemana.year,
          inicioSemana.month,
          inicioSemana.day,
        ).subtract(const Duration(days: 7));
        hasta = desde.add(const Duration(days: 6));
      }
      resultado = resultado.where((r) {
        final key = r['fechaKey']?.toString() ?? '';
        if (key.isEmpty) return false;
        final fecha = DateTime.tryParse(key);
        if (fecha == null) return false;
        return !fecha.isBefore(desde) && !fecha.isAfter(hasta);
      }).toList();
    }

    // Filtro por tipo de estado
    if (_filtroTipo != null) {
      resultado = resultado.where((r) => r['estado'] == _filtroTipo).toList();
    }

    setState(() => _registrosFiltrados = resultado);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF1E9F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(size),
            const SizedBox(height: 15),
            _isLoading
                ? const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6B2D8B),
                      ),
                    ),
                  )
                : Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          _buildResumenAsistencia(),
                          const SizedBox(height: 10),
                          _buildFiltros(),
                          const SizedBox(height: 10),
                          if (_registrosFiltrados.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(40),
                              child: Text(
                                'No hay registros para los filtros seleccionados',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Merriweather',
                                  fontSize: 14,
                                  color: Color(0xFF757575),
                                ),
                              ),
                            )
                          else
                            ..._registrosFiltrados.asMap().entries.map(
                              (e) => AnimatedListItem(
                                index: e.key,
                                child: _buildRegistroCard(e.value),
                              ),
                            ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ---------- Filtros ----------
  Widget _buildFiltros() {
    const semanas = [
      (label: 'Todas', val: null),
      (label: 'Esta semana', val: 'esta'),
      (label: 'Sem. pasada', val: 'pasada'),
    ];
    const tipos = [
      (label: 'Todos', val: null),
      (label: 'Asistencia', val: 'Completo'),
      (label: 'Falta', val: 'Falta'),
      (label: 'Retardo', val: 'Retardo'),
      (label: 'S. Temprana', val: 'Salida Temprana'),
      (label: 'Olvidó Salida', val: 'Olvidó Salida'),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Período',
            style: TextStyle(
              fontFamily: 'Merriweather',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF757575),
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: semanas.map((s) {
                final selected = _filtroSemana == s.val;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _filtroSemana = s.val);
                      _aplicarFiltros();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF6B2D8B)
                            : const Color(0xFFF1E9F8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        s.label,
                        style: TextStyle(
                          fontFamily: 'Merriweather',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF6B2D8B),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tipo',
            style: TextStyle(
              fontFamily: 'Merriweather',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF757575),
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tipos.map((t) {
                final selected = _filtroTipo == t.val;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _filtroTipo = t.val);
                      _aplicarFiltros();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF6B2D8B)
                            : const Color(0xFFF1E9F8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        t.label,
                        style: TextStyle(
                          fontFamily: 'Merriweather',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF6B2D8B),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Encabezado ----------
  Widget _buildHeader(Size size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Mis Registros',
                  style: TextStyle(
                    fontFamily: 'Merriweather',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B2D8B),
                  ),
                ),
                Text(
                  'Historial de asistencia',
                  style: TextStyle(
                    fontFamily: 'Merriweather',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3D3D3D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF6B2D8B), width: 2),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/teacher.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.person,
                    size: 35,
                    color: Color(0xFF6B2D8B),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Resumen de asistencia ----------
  Widget _buildResumenAsistencia() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildResumenItem(
            'Asistencias',
            _asistencias.toString(),
            const Color(0xFF2E7D32),
            Icons.check_circle,
          ),
          Container(width: 1, height: 45, color: const Color(0xFFE0E0E0)),
          _buildResumenItem(
            'Retardos',
            _retardos.toString(),
            const Color(0xFFE65100),
            Icons.warning_amber_rounded,
          ),
          Container(width: 1, height: 45, color: const Color(0xFFE0E0E0)),
          _buildResumenItem(
            'Faltas',
            _faltas.toString(),
            const Color(0xFFC62828),
            Icons.cancel,
          ),
        ],
      ),
    );
  }

  Widget _buildResumenItem(
    String label,
    String valor,
    Color color,
    IconData icono,
  ) {
    return Flexible(
      child: Column(
        children: [
          Icon(icono, color: color, size: 26),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: TextStyle(
                fontFamily: 'Merriweather',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Merriweather',
                fontSize: 11,
                color: Color(0xFF757575),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Card de registro ----------
  Widget _buildRegistroCard(Map<String, dynamic> registro) {
    Color estadoColor;
    IconData estadoIcono;

    switch (registro['estado']) {
      case 'Completo':
        estadoColor = const Color(0xFF2E7D32);
        estadoIcono = Icons.check_circle;
        break;
      case 'Retardo':
        estadoColor = const Color(0xFFE65100);
        estadoIcono = Icons.warning_amber_rounded;
        break;
      case 'Falta':
        estadoColor = const Color(0xFFC62828);
        estadoIcono = Icons.cancel;
        break;
      case 'Salida Temprana':
        estadoColor = const Color(0xFFE65100);
        estadoIcono = Icons.exit_to_app;
        break;
      case 'Olvidó Salida':
        estadoColor = const Color(0xFF7B1FA2);
        estadoIcono = Icons.timer_off_rounded;
        break;
      default:
        estadoColor = Colors.grey;
        estadoIcono = Icons.help_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10, left: 20, right: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icono de estado
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: estadoColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(estadoIcono, color: estadoColor, size: 26),
          ),
          const SizedBox(width: 15),
          // Info del registro
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  registro['fecha'],
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontFamily: 'Merriweather',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3D3D3D),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.login, size: 14, color: Color(0xFF9E9E9E)),
                    const SizedBox(width: 4),
                    Text(
                      registro['entrada'],
                      style: const TextStyle(
                        fontFamily: 'Merriweather',
                        fontSize: 12,
                        color: Color(0xFF757575),
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Icon(
                      Icons.logout,
                      size: 14,
                      color: Color(0xFF9E9E9E),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      registro['salida'],
                      style: const TextStyle(
                        fontFamily: 'Merriweather',
                        fontSize: 12,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Badge de estado
          Flexible(
            flex: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: estadoColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                registro['estado'],
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Merriweather',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: estadoColor,
                ),
              ),
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
                fontFamily: 'Merriweather',
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
                fontFamily: 'Merriweather',
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
                      fontFamily: 'Merriweather',
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
                      fontFamily: 'Merriweather',
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
          currentIndex: 2,
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const MarcarAsistenciaScreen(),
                ),
              );
            } else if (index == 1) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HorarioScreen()),
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
            fontFamily: 'Merriweather',
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Merriweather',
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
