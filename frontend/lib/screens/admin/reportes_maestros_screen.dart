import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../../services/api_service.dart';
import 'admin_bottom_nav.dart';

class ReportesMaestrosScreen extends StatefulWidget {
  const ReportesMaestrosScreen({super.key});

  @override
  State<ReportesMaestrosScreen> createState() => _ReportesMaestrosScreenState();
}

class _ReportesMaestrosScreenState extends State<ReportesMaestrosScreen> {
  List<dynamic> _maestros = [];
  int? _maestroFiltro;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  bool _descargando = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fechaInicio = DateTime(now.year, now.month, 1);
    _fechaFin = now;
    _cargarMaestros();
  }

  Future<void> _cargarMaestros() async {
    try {
      final lista = await ApiService.getMaestros();
      if (mounted) setState(() => _maestros = lista);
    } catch (_) {}
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtDisplay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _descargar({
    required String tipo,
    required String formato,
  }) async {
    setState(() => _descargando = true);
    final params = <String>[];
    if (_fechaInicio != null) params.add('fecha_inicio=${_fmt(_fechaInicio!)}');
    if (_fechaFin != null) params.add('fecha_fin=${_fmt(_fechaFin!)}');
    if (_maestroFiltro != null) params.add('usuario=$_maestroFiltro');

    final ext = formato == 'pdf' ? '' : '/excel';
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final path = '/reportes/$tipo$ext/$query';

    try {
      final bytes = await ApiService.downloadReporte(path);
      if (bytes == null || bytes.isEmpty) {
        _snack('No se pudo generar el reporte', success: false);
        return;
      }
      final dir = await getTemporaryDirectory();
      final extension = formato == 'pdf' ? 'pdf' : 'xlsx';
      final filename =
          '${tipo}_${_fmt(_fechaInicio ?? DateTime.now())}.$extension';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
        _snack('Reporte guardado en: ${file.path}', success: true);
      }
    } catch (e) {
      _snack('Error: ${e.toString()}', success: false);
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  Future<void> _seleccionarFecha({required bool esInicio}) async {
    final d = await showDatePicker(
      context: context,
      initialDate: esInicio
          ? (_fechaInicio ?? DateTime.now())
          : (_fechaFin ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null && mounted) {
      setState(() => esInicio ? _fechaInicio = d : _fechaFin = d);
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
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Filtros ──
                        Container(
                          padding: const EdgeInsets.all(18),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Filtros del reporte',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3D3D3D),
                                ),
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<int?>(
                                initialValue: _maestroFiltro,
                                decoration: InputDecoration(
                                  labelText: 'Maestro (opcional)',
                                  isDense: true,
                                  prefixIcon: const Icon(
                                    Icons.person_outline,
                                    color: Color(0xFF6B2D8B),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('Todos los maestros'),
                                  ),
                                  ..._maestros.map(
                                    (m) => DropdownMenuItem<int?>(
                                      value: m['id'] as int?,
                                      child: Text(
                                        m['nombre'] ?? 'Sin nombre',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _maestroFiltro = v),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                      ),
                                      label: Text(
                                        _fechaInicio != null
                                            ? _fmtDisplay(_fechaInicio!)
                                            : 'Desde',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () =>
                                          _seleccionarFecha(esInicio: true),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF6B2D8B,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFF6B2D8B),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                      ),
                                      label: Text(
                                        _fechaFin != null
                                            ? _fmtDisplay(_fechaFin!)
                                            : 'Hasta',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () =>
                                          _seleccionarFecha(esInicio: false),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF6B2D8B,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFF6B2D8B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Asistencia ──
                        _buildSeccionTitulo(
                          'Asistencia',
                          Icons.how_to_reg,
                          const Color(0xFF6B2D8B),
                        ),
                        const SizedBox(height: 10),
                        _buildOpcionReporte(
                          icono: Icons.picture_as_pdf,
                          titulo: 'PDF de Asistencia',
                          subtitulo: 'Descargar historial en PDF',
                          color: const Color(0xFF6B2D8B),
                          onTap: () =>
                              _descargar(tipo: 'asistencia', formato: 'pdf'),
                        ),
                        const SizedBox(height: 10),
                        _buildOpcionReporte(
                          icono: Icons.table_chart,
                          titulo: 'Excel de Asistencia',
                          subtitulo: 'Descargar en hoja de cálculo',
                          color: const Color(0xFF2E7D32),
                          onTap: () =>
                              _descargar(tipo: 'asistencia', formato: 'excel'),
                        ),
                        const SizedBox(height: 20),

                        // ── Incidencias ──
                        _buildSeccionTitulo(
                          'Incidencias',
                          Icons.warning_amber_rounded,
                          const Color(0xFFC62828),
                        ),
                        const SizedBox(height: 10),
                        _buildOpcionReporte(
                          icono: Icons.picture_as_pdf,
                          titulo: 'PDF de Incidencias',
                          subtitulo: 'Faltas, retardos y más',
                          color: const Color(0xFFC62828),
                          onTap: () =>
                              _descargar(tipo: 'incidencias', formato: 'pdf'),
                        ),
                        const SizedBox(height: 10),
                        _buildOpcionReporte(
                          icono: Icons.table_chart,
                          titulo: 'Excel de Incidencias',
                          subtitulo: 'Descargar en hoja de cálculo',
                          color: const Color(0xFF1565C0),
                          onTap: () =>
                              _descargar(tipo: 'incidencias', formato: 'excel'),
                        ),
                        const SizedBox(height: 20),

                        // Nota
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
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
                              Icon(
                                Icons.info_outline,
                                color: Colors.grey[600],
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Los archivos se guardan en el directorio temporal y se abren automáticamente con la aplicación predeterminada del dispositivo.',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Overlay de carga
                  if (_descargando)
                    Container(
                      color: Colors.black26,
                      child: const Center(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  color: Color(0xFF6B2D8B),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Generando reporte...',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: buildAdminBottomNav(context, 4),
    );
  }

  Widget _buildSeccionTitulo(String titulo, IconData icono, Color color) {
    return Row(
      children: [
        Icon(icono, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
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
            Icons.insert_chart,
            color: const Color(0xFF6B2D8B),
            size: width < 400 ? 28 : 36,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Generar Reportes',
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

  Widget _buildOpcionReporte({
    required IconData icono,
    required String titulo,
    required String subtitulo,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _descargando ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
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
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icono, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3D3D3D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitulo,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.download, color: color, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String msg, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success
            ? const Color(0xFF2E7D32)
            : const Color(0xFFC62828),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
