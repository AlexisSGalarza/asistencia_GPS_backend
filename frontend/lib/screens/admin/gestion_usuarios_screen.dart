import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/animated_list_item.dart';
import 'admin_bottom_nav.dart';

class GestionUsuariosScreen extends StatefulWidget {
  const GestionUsuariosScreen({super.key});

  @override
  State<GestionUsuariosScreen> createState() => _GestionUsuariosScreenState();
}

class _GestionUsuariosScreenState extends State<GestionUsuariosScreen> {
  List<dynamic> _usuarios = [];
  List<dynamic> _roles = [];
  bool _isLoading = true;
  String? _error;

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
        ApiService.getUsuarios(),
        ApiService.getRoles(),
      ]);
      if (mounted) {
        setState(() {
          _usuarios = List<dynamic>.from(results[0]);
          _roles = List<dynamic>.from(results[1]);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'No se pudo cargar la lista de usuarios';
        });
      }
    }
  }

  Future<void> _cargarUsuarios() async {
    try {
      final lista = await ApiService.getUsuarios();
      if (mounted) setState(() => _usuarios = lista);
    } catch (_) {}
  }

  void _mostrarFormularioUsuario({Map<String, dynamic>? usuario}) {
    final esEdicion = usuario != null;
    final id = usuario?['id'] as int?;
    final nombreController = TextEditingController(
      text: usuario?['nombre']?.toString() ?? '',
    );
    final correoController = TextEditingController(
      text: usuario?['correo']?.toString() ?? '',
    );
    final passwordController = TextEditingController();
    int? rolSeleccionado = usuario != null
        ? (usuario['rol'] is int
              ? usuario['rol'] as int?
              : (usuario['rol'] as Map?)?['id'] as int?)
        : null;
    if (rolSeleccionado == null && _roles.isNotEmpty) {
      rolSeleccionado = _roles.first['id'] as int?;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
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
                  esEdicion ? 'Editar usuario' : 'Nuevo usuario',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B2D8B),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nombreController,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: Color(0xFF6B2D8B),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: correoController,
                  enabled: !esEdicion,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: Color(0xFF6B2D8B),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: esEdicion
                        ? 'Nueva contraseña (dejar vacío para no cambiar)'
                        : 'Contraseña',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: Color(0xFF6B2D8B),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: rolSeleccionado,
                  decoration: InputDecoration(
                    labelText: 'Rol',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _roles.map((r) {
                    final rid = r['id'] as int;
                    final name =
                        r['nombre'] ?? r['nombre_display'] ?? 'Rol $rid';
                    return DropdownMenuItem(
                      value: rid,
                      child: Text(name.toString()),
                    );
                  }).toList(),
                  onChanged: (v) => rolSeleccionado = v,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (esEdicion && usuario['activo'] == true) ...[
                      OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final ok = await _confirmarDesactivar(id!);
                          if (ok) _cargarUsuarios();
                        },
                        icon: const Icon(Icons.person_off, size: 20),
                        label: const Text('Desactivar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFC62828),
                          side: const BorderSide(color: Color(0xFFC62828)),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ] else if (esEdicion && usuario['activo'] == false) ...[
                      OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await ApiService.activarUsuario(id!);
                          if (mounted) {
                            _snack('Usuario activado', success: true);
                          }
                          _cargarUsuarios();
                        },
                        icon: const Icon(Icons.person, size: 20),
                        label: const Text('Activar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2E7D32),
                          side: const BorderSide(color: Color(0xFF2E7D32)),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final nombre = nombreController.text.trim();
                        final correo = correoController.text.trim();
                        final password = passwordController.text;

                        if (nombre.isEmpty) {
                          _snack('Ingresa el nombre');
                          return;
                        }
                        if (correo.isEmpty) {
                          _snack('Ingresa el correo');
                          return;
                        }
                        if (!esEdicion && password.isEmpty) {
                          _snack('Ingresa la contraseña');
                          return;
                        }
                        if (!esEdicion && password.length < 6) {
                          _snack(
                            'La contraseña debe tener al menos 6 caracteres',
                          );
                          return;
                        }
                        if (rolSeleccionado == null) {
                          _snack('Selecciona un rol');
                          return;
                        }

                        Navigator.pop(ctx);

                        if (esEdicion) {
                          final res = await ApiService.updateUsuario(
                            id!,
                            nombre: nombre,
                            correo: correo,
                            password: password.isEmpty ? null : password,
                            rolId: rolSeleccionado,
                          );
                          if (res.isNotEmpty && res.containsKey('id')) {
                            _snack('Usuario actualizado', success: true);
                            _cargarUsuarios();
                          } else {
                            _snack(_mensajeError(res));
                          }
                        } else {
                          final res = await ApiService.createUsuario(
                            nombre: nombre,
                            correo: correo,
                            password: password,
                            rolId: rolSeleccionado!,
                          );
                          if (res.isNotEmpty && res.containsKey('id')) {
                            _snack('Usuario creado', success: true);
                            _cargarUsuarios();
                          } else {
                            _snack(_mensajeError(res));
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
    );
  }

  Future<bool> _confirmarDesactivar(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar usuario'),
        content: const Text(
          '¿Desactivar este usuario? No podrá iniciar sesión hasta que lo reactives editando su perfil.',
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
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (confirm != true) return false;
    await ApiService.desactivarUsuario(id);
    if (mounted) _snack('Usuario desactivado', success: true);
    return true;
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? const Color(0xFF2E7D32) : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _mensajeError(Map<String, dynamic> res) {
    if (res.containsKey('detail')) return res['detail'].toString();
    for (final key in ['correo', 'nombre', 'password', 'rol']) {
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
                  : _usuarios.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _cargarUsuarios,
                      color: const Color(0xFF6B2D8B),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        itemCount: _usuarios.length,
                        itemBuilder: (context, index) {
                          return AnimatedListItem(
                            index: index,
                            child: _buildUsuarioCard(_usuarios[index]),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormularioUsuario(),
        backgroundColor: const Color(0xFF6B2D8B),
        tooltip: 'Agregar usuario',
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: buildAdminBottomNav(context, 1),
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
            Icons.people,
            color: const Color(0xFF6B2D8B),
            size: width < 400 ? 28 : 36,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Gestión de Usuarios',
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
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
                  'No hay usuarios registrados',
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
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _mostrarFormularioUsuario(),
            icon: const Icon(Icons.add, size: 22),
            label: const Text('Crear primer usuario'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B2D8B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsuarioCard(dynamic u) {
    final nombre = u['nombre'] ?? 'Sin nombre';
    final correo = u['correo'] ?? '';
    final rol = u['rol_nombre'] ?? u['rol'] ?? 'Usuario';
    final activo = u['activo'] != false;

    return InkWell(
      onTap: () => _mostrarFormularioUsuario(usuario: u),
      borderRadius: BorderRadius.circular(18),
      child: Container(
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
                color: const Color(0xFF6B2D8B).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.person,
                color: Color(0xFF6B2D8B),
                size: 26,
              ),
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
                  if (correo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      correo,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        color: Color(0xFF757575),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.edit, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: activo
                    ? const Color(0xFF2E7D32).withOpacity(0.12)
                    : const Color(0xFF757575).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                rol is Map ? (rol['nombre'] ?? '') : rol.toString(),
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: activo
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF757575),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
