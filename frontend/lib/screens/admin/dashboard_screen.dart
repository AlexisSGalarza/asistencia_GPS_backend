import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/animated_list_item.dart';
import 'admin_bottom_nav.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _panel = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarPanel();
  }

  Future<void> _cargarPanel() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getPanelSupervision();
      if (mounted) {
        setState(() {
          _panel = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'No se pudo cargar el panel';
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
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6B2D8B),
                      ),
                    )
                  : _error != null
                  ? _buildError()
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildResumenCards(),
                          const SizedBox(height: 24),
                          _buildTituloLista(),
                          const SizedBox(height: 12),
                          _buildListaMaestros(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: buildAdminBottomNav(context, 0),
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
            Icons.dashboard,
            color: const Color(0xFF6B2D8B),
            size: width < 400 ? 28 : 36,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Dashboard Global',
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
              onPressed: _cargarPanel,
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

  Widget _buildResumenCards() {
    final maestros = _panel['maestros'] as List? ?? [];
    int enTurno = 0;
    int completados = 0;
    int sinRegistro = 0;
    for (final m in maestros) {
      final estado = m['estado'] ?? '';
      if (estado == 'en_turno') {
        enTurno++;
      } else if (estado == 'turno_completado')
        completados++;
      else if (estado == 'sin_registro')
        sinRegistro++;
    }

    return Row(
      children: [
        Expanded(
          child: _buildCardResumen(
            'Total',
            maestros.length.toString(),
            Icons.people,
            const Color(0xFF6B2D8B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCardResumen(
            'En turno',
            enTurno.toString(),
            Icons.person_pin_circle,
            const Color(0xFF1565C0),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCardResumen(
            'Completados',
            completados.toString(),
            Icons.check_circle,
            const Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCardResumen(
            'Sin registro',
            sinRegistro.toString(),
            Icons.schedule,
            const Color(0xFFE65100),
          ),
        ),
      ],
    );
  }

  Widget _buildCardResumen(
    String label,
    String valor,
    IconData icono,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 28),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 10,
              color: Color(0xFF757575),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTituloLista() {
    final fecha = _panel['fecha'] ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Asistencia hoy',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3D3D3D),
            ),
          ),
          if (fecha.isNotEmpty)
            Text(
              fecha,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                color: Color(0xFF757575),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildListaMaestros() {
    final maestros = _panel['maestros'] as List? ?? [];
    if (maestros.isEmpty) {
      return Container(
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
        child: const Center(
          child: Text(
            'No hay maestros registrados',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              color: Color(0xFF757575),
            ),
          ),
        ),
      );
    }

    return Column(
      children: maestros.asMap().entries.map<Widget>((entry) {
        final index = entry.key;
        final m = entry.value;
        final maestro = m['maestro'] as Map? ?? {};
        final nombre = maestro['nombre'] ?? 'Sin nombre';
        final estado = m['estado'] ?? '';
        final entrada = m['entrada'];
        final salida = m['salida'];
        String entradaStr = '--:--';
        String salidaStr = '--:--';
        if (entrada != null &&
            entrada is Map &&
            entrada['fecha_hora'] != null) {
          final dt = DateTime.tryParse(entrada['fecha_hora'].toString())?.toUtc().subtract(const Duration(hours: 6));
          if (dt != null) {
            entradaStr =
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          }
        }
        if (salida != null && salida is Map && salida['fecha_hora'] != null) {
          final dt = DateTime.tryParse(salida['fecha_hora'].toString())?.toUtc().subtract(const Duration(hours: 6));
          if (dt != null) {
            salidaStr =
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          }
        }

        Color estadoColor;
        IconData estadoIcono;
        String estadoTexto;
        switch (estado) {
          case 'en_turno':
            estadoColor = const Color(0xFF1565C0);
            estadoIcono = Icons.login;
            estadoTexto = 'En turno';
            break;
          case 'turno_completado':
            estadoColor = const Color(0xFF2E7D32);
            estadoIcono = Icons.check_circle;
            estadoTexto = 'Completado';
            break;
          case 'sin_registro':
            estadoColor = const Color(0xFFE65100);
            estadoIcono = Icons.schedule;
            estadoTexto = 'Sin registro';
            break;
          case 'fuera_de_perimetro':
            estadoColor = const Color(0xFFC62828);
            estadoIcono = Icons.wrong_location;
            estadoTexto = 'Fuera de perímetro';
            break;
          default:
            estadoColor = Colors.grey;
            estadoIcono = Icons.help_outline;
            estadoTexto = estado.toString();
        }

        return AnimatedListItem(
          index: index,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
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
                    color: estadoColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(estadoIcono, color: estadoColor, size: 26),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
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
                      Row(
                        children: [
                          Icon(Icons.login, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'E: $entradaStr',
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              color: Color(0xFF757575),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.logout, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'S: $salidaStr',
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              color: Color(0xFF757575),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: estadoColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    estadoTexto,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: estadoColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
