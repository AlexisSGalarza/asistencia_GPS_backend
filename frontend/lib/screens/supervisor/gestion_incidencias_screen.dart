import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'supervisor_bottom_nav.dart';

class GestionIncidenciasScreen extends StatefulWidget {
  const GestionIncidenciasScreen({super.key});

  @override
  State<GestionIncidenciasScreen> createState() =>
      _GestionIncidenciasScreenState();
}

class _GestionIncidenciasScreenState extends State<GestionIncidenciasScreen> {
  List<dynamic> _incidencias = [];
  List<dynamic> _maestros = [];
  bool _isLoading = true;
  String? _error;
  int? _maestroFiltro;
  String? _tipoFiltro;
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;

  static const List<Map<String, String?>> _tipos = [
    {'value': null, 'label': 'Todos'},
    {'value': 'falta', 'label': 'Falta'},
    {'value': 'retardo', 'label': 'Retardo'},
    {'value': 'salida_temprana', 'label': 'Salida temprana'},
    {'value': 'justificacion', 'label': 'Justificación'},
  ];

  @override
  void initState() {
    super.initState();
    _cargarMaestros();
    _cargarIncidencias();
  }

  Future<void> _cargarMaestros() async {
    try {
      final lista = await ApiService.getMaestros();
      if (mounted) setState(() => _maestros = lista);
    } catch (_) {}
  }

  Future<void> _cargarIncidencias() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final lista = await ApiService.getIncidencias(
        usuarioId: _maestroFiltro,
        fechaInicio: _fechaDesde != null
            ? '${_fechaDesde!.year}-${_fechaDesde!.month.toString().padLeft(2, '0')}-${_fechaDesde!.day.toString().padLeft(2, '0')}'
            : null,
        fechaFin: _fechaHasta != null
            ? '${_fechaHasta!.year}-${_fechaHasta!.month.toString().padLeft(2, '0')}-${_fechaHasta!.day.toString().padLeft(2, '0')}'
            : null,
        tipo: _tipoFiltro,
      );
      if (mounted) {
        setState(() {
          _incidencias = lista;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'No se pudo cargar las incidencias';
        });
      }
    }
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
            _buildFiltros(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6B2D8B),
                      ),
                    )
                  : _error != null
                  ? _buildError()
                  : _incidencias.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _cargarIncidencias,
                      color: const Color(0xFF6B2D8B),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                        itemCount: _incidencias.length,
                        itemBuilder: (context, index) {
                          return _buildIncidenciaCard(_incidencias[index]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: buildSupervisorBottomNav(context, 0),
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
            Icons.warning_amber_rounded,
            color: const Color(0xFF6B2D8B),
            size: width < 400 ? 28 : 36,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Gestión de Incidencias',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: width < 400 ? 18 : 24,
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

  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: const Color(0xFFF5F5F5),
      child: Column(
        children: [
          // Fila 1: Maestro + Tipo
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: _maestroFiltro,
                  decoration: InputDecoration(
                    labelText: 'Maestro',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Todos'),
                    ),
                    ..._maestros.map((m) {
                      final id = m['id'] as int?;
                      final nombre = m['nombre'] ?? 'Sin nombre';
                      return DropdownMenuItem<int?>(
                        value: id,
                        child: Text(nombre, overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _maestroFiltro = v;
                      _cargarIncidencias();
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _tipoFiltro,
                  decoration: InputDecoration(
                    labelText: 'Tipo',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: _tipos.map((t) {
                    return DropdownMenuItem<String?>(
                      value: t['value'],
                      child: Text(t['label']!, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setState(() {
                      _tipoFiltro = v;
                      _cargarIncidencias();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Fila 2: Fecha desde – hasta + limpiar
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _fechaDesde != null
                        ? 'Desde ${_fechaDesde!.day}/${_fechaDesde!.month}/${_fechaDesde!.year}'
                        : 'Desde',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _fechaDesde ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null && mounted) {
                      setState(() {
                        _fechaDesde = d;
                        _cargarIncidencias();
                      });
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B2D8B),
                    side: const BorderSide(color: Color(0xFF6B2D8B)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _fechaHasta != null
                        ? 'Hasta ${_fechaHasta!.day}/${_fechaHasta!.month}/${_fechaHasta!.year}'
                        : 'Hasta',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _fechaHasta ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null && mounted) {
                      setState(() {
                        _fechaHasta = d;
                        _cargarIncidencias();
                      });
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B2D8B),
                    side: const BorderSide(color: Color(0xFF6B2D8B)),
                  ),
                ),
              ),
              if (_fechaDesde != null || _fechaHasta != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  color: Colors.grey,
                  tooltip: 'Limpiar fechas',
                  onPressed: () {
                    setState(() {
                      _fechaDesde = null;
                      _fechaHasta = null;
                      _cargarIncidencias();
                    });
                  },
                ),
              ],
            ],
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
              onPressed: _cargarIncidencias,
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

  Widget _buildEmpty() {
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
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No hay incidencias en este filtro',
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

  Widget _buildIncidenciaCard(dynamic inc) {
    final usuarioNombre =
        inc['usuario_nombre'] ?? inc['usuario']?.toString() ?? 'Usuario';
    final tipo = inc['tipo'] ?? '';
    final tipoDisplay = inc['tipo_display'] ?? _tipoDisplay(tipo);
    final fecha = inc['fecha'] ?? '';
    final descripcion = inc['descripcion'] ?? '';

    Color color;
    IconData icono;
    switch (tipo.toString().toLowerCase()) {
      case 'retardo':
        color = const Color(0xFFE65100);
        icono = Icons.schedule;
        break;
      case 'falta':
        color = const Color(0xFFC62828);
        icono = Icons.cancel;
        break;
      case 'salida_temprana':
        color = const Color(0xFFE65100);
        icono = Icons.exit_to_app;
        break;
      case 'justificacion':
        color = const Color(0xFF1565C0);
        icono = Icons.description;
        break;
      default:
        color = Colors.grey;
        icono = Icons.help_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icono, color: color, size: 26),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  usuarioNombre,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3D3D3D),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  tipoDisplay,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                if (fecha.toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    fecha.toString(),
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      color: Color(0xFF757575),
                    ),
                  ),
                ],
                if (descripcion.toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    descripcion.toString(),
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      color: Color(0xFF757575),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _tipoDisplay(String tipo) {
    switch (tipo.toString().toLowerCase()) {
      case 'retardo':
        return 'Retardo';
      case 'falta':
        return 'Falta';
      case 'salida_temprana':
        return 'Salida temprana';
      case 'justificacion':
        return 'Justificación';
      default:
        return tipo.toString();
    }
  }
}
