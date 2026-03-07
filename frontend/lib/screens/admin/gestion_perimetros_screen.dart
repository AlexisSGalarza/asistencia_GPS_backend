import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'admin_bottom_nav.dart';

class GestionPerimetrosScreen extends StatefulWidget {
  const GestionPerimetrosScreen({super.key});

  @override
  State<GestionPerimetrosScreen> createState() =>
      _GestionPerimetrosScreenState();
}

class _GestionPerimetrosScreenState extends State<GestionPerimetrosScreen> {
  // ─── Estado general ───
  bool _isLoading = true;

  // ─── Perímetro ───
  bool _editandoPerimetro = false;
  bool _isSavingPerimetro = false;
  Map<String, dynamic>? _perimetroActivo;
  final _formPerimetroKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _radioCtrl = TextEditingController();

  // ─── Redes Autorizadas ───
  List<Map<String, dynamic>> _redes = [];
  bool _isSavingRed = false;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _radioCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getPerimetros(),
        ApiService.getRedes(),
      ]);

      if (!mounted) return;

      final perimetros = results[0];
      final redes = results[1];

      final activos = perimetros.where((p) => p['activo'] == true).toList();
      final p = activos.isNotEmpty
          ? activos.first
          : (perimetros.isNotEmpty ? perimetros.first : null);

      setState(() {
        _perimetroActivo = p != null
            ? Map<String, dynamic>.from(p as Map)
            : null;
        _redes = redes.map((r) => Map<String, dynamic>.from(r as Map)).toList();
        _isLoading = false;
      });

      _popularFormularioPerimetro();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _error('Error al cargar: $e');
    }
  }

  void _popularFormularioPerimetro() {
    if (_perimetroActivo != null) {
      _nombreCtrl.text = _perimetroActivo!['nombre']?.toString() ?? '';
      _latCtrl.text = _perimetroActivo!['latitud']?.toString() ?? '';
      _lngCtrl.text = _perimetroActivo!['longitud']?.toString() ?? '';
      _radioCtrl.text = _perimetroActivo!['radio_metros']?.toString() ?? '100';
    }
  }

  // ────────── ACCIONES PERÍMETRO ──────────

  Future<void> _guardarPerimetro() async {
    if (!(_formPerimetroKey.currentState?.validate() ?? false)) return;

    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    final radio = int.tryParse(_radioCtrl.text.trim());

    setState(() => _isSavingPerimetro = true);

    final data = {
      'nombre': _nombreCtrl.text.trim(),
      'latitud': lat!.toStringAsFixed(6),
      'longitud': lng!.toStringAsFixed(6),
      'radio_metros': radio,
      'activo': true,
    };

    try {
      Map<String, dynamic>? result;
      if (_perimetroActivo != null) {
        result = await ApiService.updatePerimetro(
          _perimetroActivo!['id'] as int,
          data,
        );
      } else {
        result = await ApiService.createPerimetro(data);
      }

      if (!mounted) return;
      setState(() {
        _isSavingPerimetro = false;
        if (result != null) {
          _perimetroActivo = result;
          _editandoPerimetro = false;
        }
      });

      if (result != null) {
        _exito('✅ Perímetro guardado correctamente');
      } else {
        _error('No se pudo guardar el perímetro.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingPerimetro = false);
      _error('Error: $e');
    }
  }

  void _cancelarPerimetro() {
    _popularFormularioPerimetro();
    setState(() => _editandoPerimetro = false);
  }

  // ────────── ACCIONES REDES ──────────

  void _mostrarDialogoRed({Map<String, dynamic>? red}) {
    final ssidCtrl = TextEditingController(
      text: red?['ssid']?.toString() ?? '',
    );
    final bssidCtrl = TextEditingController(
      text: red?['bssid']?.toString() ?? '',
    );
    final nombreCtrl = TextEditingController(
      text: red?['nombre']?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();
    bool guardando = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            red == null ? 'Agregar Red WiFi' : 'Editar Red WiFi',
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B2D8B),
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(
                  'Nombre descriptivo',
                  nombreCtrl,
                  icon: Icons.label,
                  hint: 'Ej: Sala de maestros',
                ),
                const SizedBox(height: 14),
                _dialogField(
                  'SSID (nombre de la red)',
                  ssidCtrl,
                  icon: Icons.wifi,
                  hint: 'Ej: Escuela_WiFi',
                ),
                const SizedBox(height: 14),
                _dialogField(
                  'BSSID (MAC del router)',
                  bssidCtrl,
                  icon: Icons.qr_code,
                  hint: 'Ej: AA:BB:CC:DD:EE:FF',
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    final mac = RegExp(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$');
                    if (!mac.hasMatch(v.trim())) {
                      return 'Formato: XX:XX:XX:XX:XX:XX';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancelar',
                style: TextStyle(fontFamily: 'Montserrat', color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B2D8B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: guardando
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => guardando = true);

                      final data = {
                        'nombre': nombreCtrl.text.trim(),
                        'ssid': ssidCtrl.text.trim(),
                        'bssid': bssidCtrl.text.trim().toUpperCase(),
                        'activo': true,
                      };

                      Map<String, dynamic>? result;
                      try {
                        if (red == null) {
                          result = await ApiService.createRed(data);
                        } else {
                          result = await ApiService.updateRed(
                            red['id'] as int,
                            data,
                          );
                        }
                      } catch (_) {}

                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);

                      if (result != null) {
                        _exito('✅ Red guardada correctamente');
                        _cargarTodo();
                      } else {
                        _error(
                          'No se pudo guardar la red. ¿Ya existe ese SSID+BSSID?',
                        );
                      }
                    },
              child: guardando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Guardar',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarRed(Map<String, dynamic> red) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Eliminar red',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Eliminar la red "${red['nombre'] ?? red['ssid']}"? Esta acción no se puede deshacer.',
          style: const TextStyle(fontFamily: 'Merriweather', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSavingRed = true);
    await ApiService.deleteRed(red['id'] as int);
    if (!mounted) return;
    setState(() => _isSavingRed = false);
    _exito('Red eliminada');
    _cargarTodo();
  }

  // ────────── HELPERS UI ──────────

  void _error(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Montserrat')),
        backgroundColor: const Color(0xFFC62828),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _exito(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Montserrat')),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ────────── BUILD ──────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6B2D8B)),
                  )
                : RefreshIndicator(
                    onRefresh: _cargarTodo,
                    color: const Color(0xFF6B2D8B),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSeccionPerimetro(),
                          const SizedBox(height: 28),
                          _buildSeccionRedes(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: buildAdminBottomNav(context, 3),
    );
  }

  // ── Sección Perímetro ──
  Widget _buildSeccionPerimetro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_perimetroActivo == null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFF9800)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber, color: Color(0xFFFF9800)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sin perímetro. Los maestros no podrán registrar asistencia.',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const Text(
          '📍 Perímetro GPS',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3D3D3D),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Define el área válida para registrar asistencia.',
          style: TextStyle(
            fontFamily: 'Merriweather',
            fontSize: 12,
            color: Color(0xFF757575),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formPerimetroKey,
              child: Column(
                children: [
                  _buildField(
                    'Nombre del lugar',
                    _nombreCtrl,
                    enabled: _editandoPerimetro,
                    icon: Icons.place,
                    hint: 'Ej: Campus Principal',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          'Latitud',
                          _latCtrl,
                          enabled: _editandoPerimetro,
                          icon: Icons.my_location,
                          hint: '20.000000',
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: true,
                            decimal: true,
                          ),
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            if (n == null || n < -90 || n > 90) {
                              return '-90 a 90';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildField(
                          'Longitud',
                          _lngCtrl,
                          enabled: _editandoPerimetro,
                          icon: Icons.pin_drop,
                          hint: '-103.000000',
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: true,
                            decimal: true,
                          ),
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            if (n == null || n < -180 || n > 180) {
                              return '-180 a 180';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    'Radio (metros)',
                    _radioCtrl,
                    enabled: _editandoPerimetro,
                    icon: Icons.radar,
                    hint: '100',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 10 || n > 5000) return '10-5000 m';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 5),
                      const Expanded(
                        child: Text(
                          'Tip: Google Maps → mantén presionado → copia coordenadas.',
                          style: TextStyle(
                            fontFamily: 'Merriweather',
                            fontSize: 10,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _botonesPerimetro(context),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _botonesPerimetro(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 360;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        if (!_editandoPerimetro)
          ElevatedButton.icon(
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Editar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B2D8B),
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontFamily: 'Montserrat'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => setState(() => _editandoPerimetro = true),
          ),
        if (_editandoPerimetro) ...[
          SizedBox(
            width: isSmall ? double.infinity : null,
            child: ElevatedButton.icon(
              icon: _isSavingPerimetro
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save, size: 18),
              label: Text(_isSavingPerimetro ? 'Guardando...' : 'Guardar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B2D8B),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontFamily: 'Montserrat'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isSavingPerimetro ? null : _guardarPerimetro,
            ),
          ),
          SizedBox(
            width: isSmall ? double.infinity : null,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.cancel, size: 18),
              label: const Text('Cancelar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6B2D8B),
                side: const BorderSide(color: Color(0xFF6B2D8B)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _cancelarPerimetro,
            ),
          ),
        ],
      ],
    );
  }

  // ── Sección Redes ──
  Widget _buildSeccionRedes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📶 Redes WiFi Autorizadas',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3D3D3D),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Solo se validará asistencia si el maestro está en la red correcta.',
                    style: TextStyle(
                      fontFamily: 'Merriweather',
                      fontSize: 12,
                      color: Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B2D8B),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              onPressed: () => _mostrarDialogoRed(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_redes.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 6),
              ],
            ),
            child: const Center(
              child: Text(
                'No hay redes autorizadas.\nLos maestros necesitarán solo GPS para registrar asistencia.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Merriweather',
                  fontSize: 13,
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ),
          )
        else
          ...(_redes.map((red) => _buildRedCard(red))),
      ],
    );
  }

  Widget _buildRedCard(Map<String, dynamic> red) {
    final activo = red['activo'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activo
              ? const Color(0xFF6B2D8B).withOpacity(0.2)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.07),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: activo
                  ? const Color(0xFF6B2D8B).withOpacity(0.1)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.wifi,
              color: activo ? const Color(0xFF6B2D8B) : Colors.grey,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  red['nombre']?.toString() ?? 'Sin nombre',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF3D3D3D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'SSID: ${red['ssid'] ?? '—'}',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    color: Color(0xFF757575),
                  ),
                ),
                Text(
                  'BSSID: ${red['bssid'] ?? '—'}',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    color: Color(0xFF757575),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.edit,
                  color: Color(0xFF6B2D8B),
                  size: 20,
                ),
                onPressed: () => _mostrarDialogoRed(red: red),
                tooltip: 'Editar',
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFC62828),
                  size: 20,
                ),
                onPressed: _isSavingRed ? null : () => _eliminarRed(red),
                tooltip: 'Eliminar',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + (width < 400 ? 14 : 20),
        bottom: width < 400 ? 16 : 22,
        left: width * 0.06,
        right: width * 0.06,
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
            Icons.settings,
            color: const Color(0xFF6B2D8B),
            size: width < 400 ? 26 : 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Configuración',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: width < 400 ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF6B2D8B),
              ),
            ),
          ),
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF6B2D8B),
                    ),
                  )
                : const Icon(Icons.refresh, color: Color(0xFF6B2D8B)),
            onPressed: _isLoading ? null : _cargarTodo,
            tooltip: 'Recargar',
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    required bool enabled,
    IconData? icon,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(icon, color: const Color(0xFF6B2D8B), size: 20)
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6B2D8B), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFC62828)),
        ),
        labelStyle: const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
        hintStyle: TextStyle(
          fontFamily: 'Montserrat',
          color: Colors.grey.shade400,
          fontSize: 12,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
      style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
    );
  }

  Widget _dialogField(
    String label,
    TextEditingController ctrl, {
    IconData? icon,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      validator:
          validator ?? (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(icon, color: const Color(0xFF6B2D8B), size: 20)
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6B2D8B), width: 2),
        ),
        labelStyle: const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
        hintStyle: TextStyle(
          fontFamily: 'Montserrat',
          color: Colors.grey.shade400,
          fontSize: 12,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
      style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13),
    );
  }
}
