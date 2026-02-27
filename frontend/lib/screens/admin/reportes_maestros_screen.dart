import 'package:flutter/material.dart';
import 'admin_bottom_nav.dart';

class ReportesMaestrosScreen extends StatefulWidget {
  const ReportesMaestrosScreen({super.key});

  @override
  State<ReportesMaestrosScreen> createState() => _ReportesMaestrosScreenState();
}

class _ReportesMaestrosScreenState extends State<ReportesMaestrosScreen> {
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Genera reportes de asistencia por período o por maestro.',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        color: Color(0xFF757575),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildOpcionReporte(
                      icono: Icons.calendar_month,
                      titulo: 'Reporte por período',
                      subtitulo: 'Asistencia entre dos fechas',
                      color: const Color(0xFF6B2D8B),
                      onTap: () => _mostrarSnackBar(context, 'Próximamente: reporte por período'),
                    ),
                    const SizedBox(height: 12),
                    _buildOpcionReporte(
                      icono: Icons.person_search,
                      titulo: 'Reporte por maestro',
                      subtitulo: 'Historial de un maestro',
                      color: const Color(0xFF1565C0),
                      onTap: () => _mostrarSnackBar(context, 'Próximamente: reporte por maestro'),
                    ),
                    const SizedBox(height: 12),
                    _buildOpcionReporte(
                      icono: Icons.download,
                      titulo: 'Exportar a Excel',
                      subtitulo: 'Descargar datos en hoja de cálculo',
                      color: const Color(0xFF2E7D32),
                      onTap: () => _mostrarSnackBar(context, 'Próximamente: exportar Excel'),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
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
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey[600], size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Los reportes usarán los datos del panel de supervisión y del historial de asistencia.',
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
            ),
          ],
        ),
      ),
      bottomNavigationBar: buildAdminBottomNav(context, 4),
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
          Icon(Icons.insert_chart, color: const Color(0xFF6B2D8B), size: width < 400 ? 28 : 36),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Reportes Maestros',
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
        onTap: onTap,
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
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarSnackBar(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: const Color(0xFF6B2D8B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
