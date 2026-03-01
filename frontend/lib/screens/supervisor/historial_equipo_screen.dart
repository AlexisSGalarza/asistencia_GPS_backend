import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/animated_list_item.dart';
import 'supervisor_bottom_nav.dart';

class HistorialEquipoScreen extends StatefulWidget {
  const HistorialEquipoScreen({super.key});

  @override
  State<HistorialEquipoScreen> createState() => _HistorialEquipoScreenState();
}

class _HistorialEquipoScreenState extends State<HistorialEquipoScreen> {
  List<dynamic> _registros = [];
  List<dynamic> _maestros = [];
  bool _isLoading = true;
  String? _error;
  int? _maestroFiltro;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  String? _tipoFiltro; // 'entrada' | 'salida' | null
  bool? _estadoFiltro; // true=válido | false=inválido | null=todos

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fechaInicio = DateTime(now.year, now.month, 1);
    _fechaFin = now;
    _cargarMaestros();
    _cargarRegistros();
  }

  Future<void> _cargarMaestros() async {
    try {
      final lista = await ApiService.getMaestros();
      if (mounted) setState(() => _maestros = lista);
    } catch (_) {}
  }

  Future<void> _cargarRegistros() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final lista = await ApiService.getRegistrosEquipo(
        usuarioId: _maestroFiltro,
        fechaInicio: _fechaInicio != null
            ? '${_fechaInicio!.year}-${_fechaInicio!.month.toString().padLeft(2, '0')}-${_fechaInicio!.day.toString().padLeft(2, '0')}'
            : null,
        fechaFin: _fechaFin != null
            ? '${_fechaFin!.year}-${_fechaFin!.month.toString().padLeft(2, '0')}-${_fechaFin!.day.toString().padLeft(2, '0')}'
            : null,
        tipo: _tipoFiltro,
        soloValidos: _estadoFiltro,
      );
      if (mounted) {
        setState(() {
          _registros = lista;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'No se pudo cargar el historial';
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
                  : _registros.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _cargarRegistros,
                      color: const Color(0xFF6B2D8B),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                        itemCount: _registros.length,
                        itemBuilder: (context, index) {
                          return AnimatedListItem(
                            index: index,
                            child: _buildRegistroCard(_registros[index]),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: buildSupervisorBottomNav(context, 1),
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
            Icons.history,
            color: const Color(0xFF6B2D8B),
            size: width < 400 ? 28 : 36,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Historial de Equipo',
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
                      _cargarRegistros();
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
                  items: const [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todos'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'entrada',
                      child: Text('Entrada'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'salida',
                      child: Text('Salida'),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _tipoFiltro = v;
                      _cargarRegistros();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Fila 2: Estado
          DropdownButtonFormField<bool?>(
            value: _estadoFiltro,
            decoration: InputDecoration(
              labelText: 'Estado',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: const [
              DropdownMenuItem<bool?>(value: null, child: Text('Todos')),
              DropdownMenuItem<bool?>(value: true, child: Text('Válido')),
              DropdownMenuItem<bool?>(value: false, child: Text('Inválido')),
            ],
            onChanged: (v) {
              setState(() {
                _estadoFiltro = v;
                _cargarRegistros();
              });
            },
          ),
          const SizedBox(height: 8),
          // Fila 3: Rango de fechas
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    _fechaInicio != null
                        ? '${_fechaInicio!.day}/${_fechaInicio!.month}/${_fechaInicio!.year}'
                        : 'Desde',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _fechaInicio ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null && mounted) {
                      setState(() {
                        _fechaInicio = d;
                        _cargarRegistros();
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
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    _fechaFin != null
                        ? '${_fechaFin!.day}/${_fechaFin!.month}/${_fechaFin!.year}'
                        : 'Hasta',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _fechaFin ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null && mounted) {
                      setState(() {
                        _fechaFin = d;
                        _cargarRegistros();
                      });
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B2D8B),
                    side: const BorderSide(color: Color(0xFF6B2D8B)),
                  ),
                ),
              ),
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
              onPressed: _cargarRegistros,
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
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No hay registros en el rango seleccionado',
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

  String _formatearFechaHora(dynamic v) {
    if (v == null) return '--:--';
    final dt = DateTime.tryParse(v.toString())?.toUtc().subtract(const Duration(hours: 6));
    if (dt == null) return v.toString();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildRegistroCard(dynamic r) {
    final usuarioNombre =
        r['usuario_nombre'] ?? r['usuario']?.toString() ?? 'Usuario';
    final tipo = r['tipo'] ?? r['tipo_display'] ?? '';
    final fechaHora = _formatearFechaHora(r['fecha_hora']);
    final valido = r['valido'] == true;

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
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color:
                  (valido ? const Color(0xFF2E7D32) : const Color(0xFFC62828))
                      .withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              r['tipo'] == 'entrada' ? Icons.login : Icons.logout,
              color: valido ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
              size: 26,
            ),
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
                  '${tipo.toString().toUpperCase()} · $fechaHora',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    color: Color(0xFF757575),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:
                  (valido ? const Color(0xFF2E7D32) : const Color(0xFFC62828))
                      .withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              valido ? 'Válido' : 'Inválido',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: valido
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFC62828),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
