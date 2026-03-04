import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'admin_bottom_nav.dart';

class GestionHorariosScreen extends StatefulWidget {
  const GestionHorariosScreen({super.key});

  @override
  State<GestionHorariosScreen> createState() => _GestionHorariosScreenState();
}

class _GestionHorariosScreenState extends State<GestionHorariosScreen> {
  List<dynamic> _horarios = [];
  List<dynamic> _maestros = [];
  bool _isLoading = true;
  String? _error;

  static const List<String> _dias = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];
  static const List<String> _diasCompletos = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  /// Agrupa horarios por id de usuario (maestro).
  Map<int, List<dynamic>> _horariosPorMaestro() {
    final map = <int, List<dynamic>>{};
    for (final h in _horarios) {
      final u = h['usuario'];
      final id = u is int ? u : (u is Map ? u['id'] as int? : null);
      if (id != null) {
        map.putIfAbsent(id, () => []).add(h);
      }
    }
    for (final m in _maestros) {
      final id = m['id'] as int?;
      if (id != null) map.putIfAbsent(id, () => []);
    }
    for (final list in map.values) {
      list.sort(
        (a, b) => (a['dia_semana'] as int).compareTo(b['dia_semana'] as int),
      );
    }
    return map;
  }

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getHorarios(),
        ApiService.getMaestros(),
      ]);
      if (mounted) {
        setState(() {
          _horarios = List<dynamic>.from(results[0]);
          _maestros = List<dynamic>.from(results[1]);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'No se pudo cargar la lista de horarios';
        });
      }
    }
  }

  Future<void> _cargarHorarios() async {
    try {
      final lista = await ApiService.getHorarios();
      if (mounted) setState(() => _horarios = lista);
    } catch (_) {}
  }

  /// Convierte "HH:MM" o "HH:MM:SS" del backend a TimeOfDay.
  TimeOfDay _parseTimeOfDay(dynamic v, {TimeOfDay? fallback}) {
    fallback ??= const TimeOfDay(hour: 9, minute: 0);
    if (v == null) return fallback;
    final parts = v.toString().split(':');
    if (parts.length >= 2) {
      return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? fallback.hour,
        minute: int.tryParse(parts[1]) ?? fallback.minute,
      );
    }
    return fallback;
  }

  /// Formatea TimeOfDay a "HH:MM:00" para el backend.
  String _timeOfDayToBackend(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
  }

  void _mostrarFormularioHorario({
    Map<String, dynamic>? horario,
    int? maestroIdPreseleccionado,
    int? diaPreseleccionado,
  }) {
    final esEdicion = horario != null;
    final id = horario?['id'] as int?;
    final usuario = horario?['usuario'];
    int? usuarioId = usuario is int
        ? usuario
        : (usuario is Map ? (usuario['id'] as int?) : null);
    usuarioId ??= maestroIdPreseleccionado;
    if (usuarioId == null && _maestros.isNotEmpty) {
      usuarioId = _maestros.first['id'] as int?;
    }
    int diaSemana = horario?['dia_semana'] as int? ?? diaPreseleccionado ?? 0;
    TimeOfDay horaEntrada = _parseTimeOfDay(
      horario?['hora_entrada'],
      fallback: const TimeOfDay(hour: 9, minute: 0),
    );
    TimeOfDay horaSalida = _parseTimeOfDay(
      horario?['hora_salida'],
      fallback: const TimeOfDay(hour: 17, minute: 0),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  esEdicion ? 'Editar horario' : 'Nuevo horario',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B2D8B),
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<int>(
                  initialValue: usuarioId,
                  decoration: InputDecoration(
                    labelText: 'Maestro',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _maestros.map((m) {
                    final mid = m['id'] as int;
                    final name = m['nombre'] ?? 'Usuario $mid';
                    return DropdownMenuItem(
                      value: mid,
                      child: Text(name.toString()),
                    );
                  }).toList(),
                  onChanged: (v) => usuarioId = v,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: diaSemana,
                  decoration: InputDecoration(
                    labelText: 'Día',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: List.generate(
                    7,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(_diasCompletos[i]),
                    ),
                  ),
                  onChanged: (v) => diaSemana = v ?? 0,
                ),
                const SizedBox(height: 14),
                // ── Selector de hora entrada ──
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: horaEntrada,
                      builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          alwaysUse24HourFormat: true,
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setDialogState(() => horaEntrada = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Hora entrada',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(
                        Icons.login,
                        color: Color(0xFF6B2D8B),
                      ),
                      suffixIcon: const Icon(
                        Icons.access_time,
                        color: Color(0xFF6B2D8B),
                      ),
                    ),
                    child: Text(
                      '${horaEntrada.hour.toString().padLeft(2, '0')}:${horaEntrada.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // ── Selector de hora salida ──
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: horaSalida,
                      builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          alwaysUse24HourFormat: true,
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setDialogState(() => horaSalida = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Hora salida',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(
                        Icons.logout,
                        color: Color(0xFF6B2D8B),
                      ),
                      suffixIcon: const Icon(
                        Icons.access_time,
                        color: Color(0xFF6B2D8B),
                      ),
                    ),
                    child: Text(
                      '${horaSalida.hour.toString().padLeft(2, '0')}:${horaSalida.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (esEdicion) ...[
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Eliminar horario'),
                              content: const Text('¿Eliminar este horario?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFC62828),
                                  ),
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await ApiService.deleteHorario(id!);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Horario eliminado'),
                                  backgroundColor: Color(0xFF2E7D32),
                                ),
                              );
                              _cargarHorarios();
                            }
                          }
                        },
                        child: const Text(
                          'Eliminar',
                          style: TextStyle(color: Color(0xFFC62828)),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (usuarioId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Selecciona un maestro'),
                            ),
                          );
                          return;
                        }
                        final he = _timeOfDayToBackend(horaEntrada);
                        final hs = _timeOfDayToBackend(horaSalida);

                        Navigator.pop(ctx);

                        if (esEdicion) {
                          final res = await ApiService.updateHorario(
                            id!,
                            usuarioId: usuarioId,
                            diaSemana: diaSemana,
                            horaEntrada: he,
                            horaSalida: hs,
                          );
                          if (res.isNotEmpty && res.containsKey('id')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Horario actualizado'),
                                backgroundColor: Color(0xFF2E7D32),
                              ),
                            );
                            _cargarHorarios();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_mensajeErrorHorario(res)),
                              ),
                            );
                          }
                        } else {
                          final res = await ApiService.createHorario(
                            usuarioId: usuarioId!,
                            diaSemana: diaSemana,
                            horaEntrada: he,
                            horaSalida: hs,
                          );
                          if (res.isNotEmpty && res.containsKey('id')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Horario creado'),
                                backgroundColor: Color(0xFF2E7D32),
                              ),
                            );
                            _cargarHorarios();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_mensajeErrorHorario(res)),
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B2D8B),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(esEdicion ? 'Guardar' : 'Crear'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  String _formatearHora(dynamic v) {
    if (v == null) return '--:--';
    final s = v.toString();
    if (s.length >= 5) return s.substring(0, 5);
    return s;
  }

  String _mensajeErrorHorario(Map<String, dynamic> res) {
    if (res.containsKey('detail')) return res['detail'].toString();
    for (final key in [
      'usuario',
      'dia_semana',
      'hora_entrada',
      'hora_salida',
      'non_field_errors',
    ]) {
      if (res[key] is List && (res[key] as List).isNotEmpty) {
        return (res[key] as List).first.toString();
      }
    }
    return 'Error al guardar';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, width),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6B2D8B),
                      ),
                    )
                  : _error != null
                  ? _buildError()
                  : _maestros.isEmpty
                  ? _buildEmptyMaestros()
                  : RefreshIndicator(
                      onRefresh: _cargarHorarios,
                      color: const Color(0xFF6B2D8B),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                        itemCount: _maestros.length,
                        itemBuilder: (context, index) {
                          final maestro =
                              _maestros[index] as Map<String, dynamic>;
                          final maestroId = maestro['id'] as int?;
                          final nombre =
                              maestro['nombre']?.toString() ?? 'Maestro';
                          final porMaestro = _horariosPorMaestro();
                          final lista = maestroId != null
                              ? (porMaestro[maestroId] ?? [])
                              : [];
                          return _buildCardMaestro(
                            nombre: nombre,
                            maestroId: maestroId ?? 0,
                            horarios: lista,
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormularioHorario(),
        backgroundColor: const Color(0xFF6B2D8B),
        tooltip: 'Agregar horario',
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: buildAdminBottomNav(context, 2),
    );
  }

  Widget _buildHeader(BuildContext context, double width) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: width * 0.06,
        vertical: width < 400 ? 18 : 28,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            color: const Color(0xFF6B2D8B),
            size: width < 400 ? 28 : 36,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Gestión de Horarios',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: width < 400 ? 20 : 26,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF6B2D8B),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Color(0xFF757575)),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                color: Color(0xFF757575),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _cargarTodo,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B2D8B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMaestros() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No hay maestros registrados.\nCrea usuarios con rol Maestro primero.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                color: Color(0xFF757575),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Una card por maestro: nombre + semana compacta + botón agregar.
  Widget _buildCardMaestro({
    required String nombre,
    required int maestroId,
    required List<dynamic> horarios,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado con nombre del maestro
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B2D8B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF6B2D8B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    nombre,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3D3D3D),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Semana: 7 filas (Lun a Dom) con entrada-salida o "—"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: List.generate(7, (dia) {
                final listDia = horarios
                    .where((e) => (e['dia_semana'] as int?) == dia)
                    .toList();
                final h = listDia.isEmpty
                    ? null
                    : listDia.first as Map<String, dynamic>?;
                final entrada = h != null
                    ? _formatearHora(h['hora_entrada'])
                    : null;
                final salida = h != null
                    ? _formatearHora(h['hora_salida'])
                    : null;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (h != null) {
                        _mostrarFormularioHorario(horario: h);
                      } else {
                        _mostrarFormularioHorario(
                          maestroIdPreseleccionado: maestroId,
                          diaPreseleccionado: dia,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Text(
                              _dias[dia],
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: entrada != null
                                    ? const Color(0xFF3D3D3D)
                                    : Colors.grey[500],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: entrada != null && salida != null
                                ? Text(
                                    '$entrada – $salida',
                                    style: const TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 13,
                                      color: Color(0xFF6B2D8B),
                                    ),
                                  )
                                : Text(
                                    'Sin horario',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                          ),
                          if (h != null)
                            Icon(Icons.edit, size: 18, color: Colors.grey[600])
                          else
                            Icon(
                              Icons.add_circle_outline,
                              size: 20,
                              color: Colors.grey[400],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextButton.icon(
              onPressed: () => _mostrarFormularioHorario(
                maestroIdPreseleccionado: maestroId,
              ),
              icon: const Icon(Icons.add, size: 20, color: Color(0xFF6B2D8B)),
              label: const Text(
                'Agregar día',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B2D8B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
