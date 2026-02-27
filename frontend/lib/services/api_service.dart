import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Servicio centralizado para comunicarse con el backend Django.
class ApiService {
  /// Emulador Android: 10.0.2.2. Celular real: usa la IP de tu PC/Mac en la red WiFi.
  static const bool _usarCelularReal = false;
  static const String _ipServidor =
      '192.168.1.100'; // Cambia por la IP de tu computadora
  static String get _baseUrl => _usarCelularReal
      ? 'http://$_ipServidor:8000/api'
      : 'http://10.0.2.2:8000/api';

  static String? _accessToken;
  static String? _refreshToken;
  static Map<String, dynamic>? _usuarioData;

  static const _storage = FlutterSecureStorage();

  // ─── Getters ───
  static String? get accessToken => _accessToken;
  static Map<String, dynamic>? get usuario => _usuarioData;
  static String get nombreUsuario => _usuarioData?['nombre'] ?? '';
  static String get correoUsuario => _usuarioData?['correo'] ?? '';
  static String get rolUsuario => _usuarioData?['rol_nombre'] ?? '';
  static String get creadoEn => _usuarioData?['created_at'] ?? '';
  static List<dynamic> get horarios => _usuarioData?['horarios'] ?? [];
  static bool get isAuthenticated => _accessToken != null;

  // ─── Headers ───
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };

  static Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_accessToken',
  };

  // ─── SECURE STORAGE ───

  /// Guarda tokens de forma segura (Keychain/Keystore).
  static Future<void> _guardarTokens() async {
    if (_accessToken != null) {
      await _storage.write(key: 'access_token', value: _accessToken);
    }
    if (_refreshToken != null) {
      await _storage.write(key: 'refresh_token', value: _refreshToken);
    }
    if (_usuarioData != null) {
      await _storage.write(
        key: 'usuario_data',
        value: jsonEncode(_usuarioData),
      );
    }
  }

  /// Intenta restaurar sesión desde almacenamiento seguro.
  static Future<bool> restaurarSesion() async {
    try {
      _accessToken = await _storage.read(key: 'access_token');
      _refreshToken = await _storage.read(key: 'refresh_token');
      final userData = await _storage.read(key: 'usuario_data');
      if (userData != null) {
        _usuarioData = jsonDecode(userData);
      }

      if (_accessToken != null) {
        // Verificar que el token sigue siendo válido
        final response = await http.get(
          Uri.parse('$_baseUrl/auth/perfil/'),
          headers: _authHeaders,
        );
        if (response.statusCode == 200) {
          _usuarioData = jsonDecode(response.body);
          return true;
        }
        // Token expirado, intentar refresh
        if (_refreshToken != null) {
          final refreshed = await refreshAccessToken();
          if (refreshed) {
            await _guardarTokens();
            return true;
          }
        }
      }
    } catch (_) {}

    // No se pudo restaurar
    await _limpiarStorage();
    return false;
  }

  static Future<void> _limpiarStorage() async {
    await _storage.deleteAll();
    _accessToken = null;
    _refreshToken = null;
    _usuarioData = null;
  }

  // ─── AUTH ───

  /// Login: envía correo y password, guarda tokens y datos del usuario.
  static Future<Map<String, dynamic>> login(
    String correo,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login/'),
      headers: _headers,
      body: jsonEncode({'correo': correo, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken = data['tokens']['access'];
      _refreshToken = data['tokens']['refresh'];
      _usuarioData = data['usuario'];
      await _guardarTokens();
      return {'success': true, 'data': data};
    } else {
      final error = jsonDecode(response.body);
      String mensaje = 'Error al iniciar sesión';
      if (error is Map) {
        if (error.containsKey('non_field_errors')) {
          mensaje = (error['non_field_errors'] as List).first;
        } else if (error.containsKey('detail')) {
          mensaje = error['detail'];
        }
      }
      return {'success': false, 'mensaje': mensaje};
    }
  }

  /// Refresh token: obtiene un nuevo access token.
  static Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh/'),
        headers: _headers,
        body: jsonEncode({'refresh': _refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access'];
        await _guardarTokens();
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Logout: limpia tokens y datos del almacenamiento seguro.
  static Future<void> logout() async {
    await _limpiarStorage();
  }

  // ─── RECUPERACIÓN DE CONTRASEÑA ───

  /// Solicitar código de recuperación.
  static Future<Map<String, dynamic>> solicitarRecuperacion(
    String correo,
  ) async {
    final correoNorm = correo.trim().toLowerCase();
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/recuperar/solicitar/'),
      headers: _headers,
      body: jsonEncode({'correo': correoNorm}),
    );

    final data = jsonDecode(response.body);
    // El backend retorna HTTP 200 en ambos casos (correo existe o no)
    // por seguridad (no revela si el correo está registrado).
    // Siempre tratamos 200 como éxito y avanzamos al Paso 2.
    if (response.statusCode == 200) {
      return {
        'success': true,
        'mensaje': data['mensaje'],
        'codigo_debug':
            data['codigo_debug'], // Solo en desarrollo (null si correo no existe)
      };
    } else {
      return {
        'success': false,
        'mensaje': data['error'] ?? 'Error al solicitar recuperación',
      };
    }
  }

  /// Confirmar recuperación con código y nueva contraseña.
  static Future<Map<String, dynamic>> confirmarRecuperacion(
    String correo,
    String codigo,
    String nuevaPassword,
  ) async {
    final correoNorm = correo.trim().toLowerCase();
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/recuperar/confirmar/'),
      headers: _headers,
      body: jsonEncode({
        'correo': correoNorm,
        'codigo': codigo,
        'nueva_password': nuevaPassword,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'mensaje': data['mensaje']};
    } else {
      return {
        'success': false,
        'mensaje': data['error'] ?? 'Error al confirmar recuperación',
      };
    }
  }

  // ─── PERFIL ───

  /// Obtener perfil del usuario autenticado.
  static Future<Map<String, dynamic>> getPerfil() async {
    final response = await _getAuth('/auth/perfil/');
    if (response != null) {
      _usuarioData = response;
    }
    return response ?? {};
  }

  /// Cambiar contraseña.
  static Future<Map<String, dynamic>> cambiarPassword(
    String passwordActual,
    String passwordNuevo,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/cambiar-password/'),
      headers: _authHeaders,
      body: jsonEncode({
        'password_actual': passwordActual,
        'password_nuevo': passwordNuevo,
      }),
    );

    if (response.statusCode == 200) {
      return {
        'success': true,
        'mensaje': 'Contraseña actualizada correctamente',
      };
    } else {
      final error = jsonDecode(response.body);
      String mensaje = 'Error al cambiar contraseña';
      if (error is Map && error.containsKey('password_actual')) {
        mensaje = (error['password_actual'] as List).first;
      }
      return {'success': false, 'mensaje': mensaje};
    }
  }

  // ─── HORARIOS ───

  /// Obtener horarios del maestro autenticado.
  static Future<List<dynamic>> getHorarios() async {
    final response = await _getAuth('/horarios/');
    if (response == null) return [];
    if (response is List) return response;
    if (response is Map && response.containsKey('results')) {
      return response['results'] as List;
    }
    return [];
  }

  // ─── ASISTENCIA ───

  /// Obtener el estado de asistencia de hoy (entrada/salida registradas).
  /// También activa auto-salida si pasaron +10h en el backend.
  static Future<Map<String, dynamic>> getEstadoHoy() async {
    final response = await _getAuth('/asistencia/estado-hoy/');
    if (response != null && response is Map<String, dynamic>) {
      return response;
    }
    return {'entrada_registrada': false, 'salida_registrada': false};
  }

  /// Registrar asistencia (entrada o salida) enviando lat/lng + ssid/bssid.
  static Future<Map<String, dynamic>> registrarAsistencia({
    required String tipo,
    required double latitud,
    required double longitud,
    String ssid = '',
    String bssid = '',
  }) async {
    // Redondear a 6 decimales para evitar el error de validación del DecimalField en Django
    final latRounded = double.parse(latitud.toStringAsFixed(6));
    final lngRounded = double.parse(longitud.toStringAsFixed(6));

    final response = await http.post(
      Uri.parse('$_baseUrl/asistencia/registrar/'),
      headers: _authHeaders,
      body: jsonEncode({
        'tipo': tipo,
        'latitud': latRounded,
        'longitud': lngRounded,
        'ssid': ssid,
        'bssid': bssid,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return {'success': true, 'data': data};
    } else {
      final error = jsonDecode(response.body);
      String mensaje = 'Error al registrar asistencia';
      if (error is Map) {
        if (error.containsKey('non_field_errors')) {
          mensaje = (error['non_field_errors'] as List).first;
        } else if (error.containsKey('detail')) {
          mensaje = error['detail'];
        } else if (error.values.isNotEmpty) {
          final firstError = error.values.first;
          if (firstError is List && firstError.isNotEmpty) {
            mensaje = firstError.first.toString();
          } else {
            mensaje = firstError.toString();
          }
        }
      }
      return {'success': false, 'mensaje': mensaje};
    }
  }

  /// Obtener historial de asistencia del maestro.
  static Future<List<dynamic>> getHistorial({
    String? fechaInicio,
    String? fechaFin,
  }) async {
    String url = '/asistencia/historial/';
    final params = <String>[];
    if (fechaInicio != null) params.add('fecha_inicio=$fechaInicio');
    if (fechaFin != null) params.add('fecha_fin=$fechaFin');
    if (params.isNotEmpty) url += '?${params.join('&')}';

    final response = await _getAuth(url);
    if (response is List) {
      return response;
    }
    return [];
  }

  // ─── INCIDENCIAS ───

  /// Obtener incidencias del maestro (o del equipo si es supervisor).
  /// Supervisor puede filtrar: ?usuario=1&fecha=2026-02-21
  static Future<List<dynamic>> getIncidencias({
    int? usuarioId,
    String? fecha,
  }) async {
    final params = <String>[];
    if (usuarioId != null) params.add('usuario=$usuarioId');
    if (fecha != null && fecha.isNotEmpty) params.add('fecha=$fecha');
    String path = '/asistencia/incidencias/';
    if (params.isNotEmpty) path += '?${params.join('&')}';
    final response = await _getAuth(path);
    if (response == null) return [];
    if (response is List) return response;
    if (response is Map && response.containsKey('results')) {
      return response['results'] as List;
    }
    return [];
  }

  // ─── REDES AUTORIZADAS ───

  /// Obtener lista de redes Wi-Fi autorizadas activas.
  static Future<List<dynamic>> getRedesActivas() async {
    final response = await _getAuth('/asistencia/redes-activas/');
    if (response is List) {
      return response;
    }
    return [];
  }

  // ─── ADMIN / SUPERVISIÓN ───

  /// Panel de supervisión: estado de asistencia de hoy por maestro.
  /// GET /api/asistencia/panel/?fecha=YYYY-MM-DD
  static Future<Map<String, dynamic>> getPanelSupervision({
    String? fecha,
  }) async {
    String path = '/asistencia/panel/';
    if (fecha != null && fecha.isNotEmpty) {
      path += '?fecha=$fecha';
    }
    final response = await _getAuth(path);
    return response is Map<String, dynamic> ? response : {};
  }

  /// Lista de usuarios (admin). GET /api/usuarios/
  static Future<List<dynamic>> getUsuarios() async {
    final response = await _getAuth('/usuarios/');
    if (response == null) return [];
    if (response is List) return response;
    if (response is Map && response.containsKey('results')) {
      return response['results'] as List;
    }
    return [];
  }

  /// Lista de roles (admin). GET /api/roles/
  static Future<List<dynamic>> getRoles() async {
    final response = await _getAuth('/roles/');
    if (response == null) return [];
    if (response is List) return response;
    if (response is Map && response.containsKey('results')) {
      return response['results'] as List;
    }
    return [];
  }

  /// Crear usuario (admin). POST /api/usuarios/
  static Future<Map<String, dynamic>> createUsuario({
    required String nombre,
    required String correo,
    required String password,
    required int rolId,
    bool activo = true,
  }) async {
    final res = await _postAuth('/usuarios/', {
      'nombre': nombre,
      'correo': correo,
      'password': password,
      'rol': rolId,
      'activo': activo,
    });
    return res ?? {};
  }

  /// Actualizar usuario (admin). PATCH /api/usuarios/{id}/ (password opcional)
  static Future<Map<String, dynamic>> updateUsuario(
    int id, {
    String? nombre,
    String? correo,
    String? password,
    int? rolId,
    bool? activo,
  }) async {
    final body = <String, dynamic>{};
    if (nombre != null) body['nombre'] = nombre;
    if (correo != null) body['correo'] = correo;
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (rolId != null) body['rol'] = rolId;
    if (activo != null) body['activo'] = activo;
    final res = await _patchAuth('/usuarios/$id/', body);
    return res ?? {};
  }

  /// Desactivar usuario (admin). DELETE /api/usuarios/{id}/
  static Future<Map<String, dynamic>> desactivarUsuario(int id) async {
    return await _deleteAuth('/usuarios/$id/') ?? {};
  }

  /// Crear horario (admin). POST /api/horarios/
  static Future<Map<String, dynamic>> createHorario({
    required int usuarioId,
    required int diaSemana,
    required String horaEntrada,
    required String horaSalida,
  }) async {
    final res = await _postAuth('/horarios/', {
      'usuario': usuarioId,
      'dia_semana': diaSemana,
      'hora_entrada': horaEntrada,
      'hora_salida': horaSalida,
    });
    return res ?? {};
  }

  /// Actualizar horario (admin). PATCH /api/horarios/{id}/
  static Future<Map<String, dynamic>> updateHorario(
    int id, {
    int? usuarioId,
    int? diaSemana,
    String? horaEntrada,
    String? horaSalida,
  }) async {
    final body = <String, dynamic>{};
    if (usuarioId != null) body['usuario'] = usuarioId;
    if (diaSemana != null) body['dia_semana'] = diaSemana;
    if (horaEntrada != null) body['hora_entrada'] = horaEntrada;
    if (horaSalida != null) body['hora_salida'] = horaSalida;
    final res = await _patchAuth('/horarios/$id/', body);
    return res ?? {};
  }

  /// Eliminar horario (admin). DELETE /api/horarios/{id}/
  static Future<bool> deleteHorario(int id) async {
    final res = await _deleteAuth('/horarios/$id/');
    return res != null;
  }

  /// Lista de maestros (supervisor/admin). GET /api/usuarios/maestros/
  static Future<List<dynamic>> getMaestros() async {
    final response = await _getAuth('/usuarios/maestros/');
    if (response == null) return [];
    if (response is List) return response;
    return [];
  }

  /// Registros de asistencia del equipo (supervisor/admin).
  /// GET /api/asistencia/registros/?usuario=1&fecha_inicio=...&fecha_fin=...
  static Future<List<dynamic>> getRegistrosEquipo({
    int? usuarioId,
    String? fechaInicio,
    String? fechaFin,
  }) async {
    final params = <String>[];
    if (usuarioId != null) params.add('usuario=$usuarioId');
    if (fechaInicio != null) params.add('fecha_inicio=$fechaInicio');
    if (fechaFin != null) params.add('fecha_fin=$fechaFin');
    String path = '/asistencia/registros/';
    if (params.isNotEmpty) path += '?${params.join('&')}';
    final response = await _getAuth(path);
    if (response == null) return [];
    if (response is List) return response;
    if (response is Map && response.containsKey('results')) {
      return response['results'] as List;
    }
    return [];
  }

  /// Lista de perímetros (admin). GET /api/asistencia/perimetros/
  static Future<List<dynamic>> getPerimetros() async {
    final response = await _getAuth('/asistencia/perimetros/');
    if (response != null &&
        response is Map &&
        response.containsKey('results')) {
      return response['results'] as List;
    }
    if (response is List) return response;
    return [];
  }

  /// Actualiza un perímetro existente. PATCH /api/asistencia/perimetros/{id}/
  static Future<Map<String, dynamic>?> updatePerimetro(
    int id,
    Map<String, dynamic> data,
  ) async {
    final result = await _patchAuth('/asistencia/perimetros/$id/', data);
    if (result is Map<String, dynamic>) return result;
    return null;
  }

  /// Crea un perímetro nuevo. POST /api/asistencia/perimetros/
  static Future<Map<String, dynamic>?> createPerimetro(
    Map<String, dynamic> data,
  ) async {
    final result = await _postAuth('/asistencia/perimetros/', data);
    if (result is Map<String, dynamic>) return result;
    return null;
  }

  /// Lista de redes WiFi autorizadas. GET /api/asistencia/redes/
  static Future<List<dynamic>> getRedes() async {
    final response = await _getAuth('/asistencia/redes/');
    if (response != null &&
        response is Map &&
        response.containsKey('results')) {
      return response['results'] as List;
    }
    if (response is List) return response;
    return [];
  }

  /// Crea una red autorizada. POST /api/asistencia/redes/
  static Future<Map<String, dynamic>?> createRed(
    Map<String, dynamic> data,
  ) async {
    final result = await _postAuth('/asistencia/redes/', data);
    if (result is Map<String, dynamic>) return result;
    return null;
  }

  /// Actualiza una red autorizada. PATCH /api/asistencia/redes/{id}/
  static Future<Map<String, dynamic>?> updateRed(
    int id,
    Map<String, dynamic> data,
  ) async {
    final result = await _patchAuth('/asistencia/redes/$id/', data);
    if (result is Map<String, dynamic>) return result;
    return null;
  }

  /// Elimina una red autorizada. DELETE /api/asistencia/redes/{id}/
  static Future<bool> deleteRed(int id) async {
    final result = await _deleteAuth('/asistencia/redes/$id/');
    return result != null;
  }

  // ─── HELPERS ───

  /// GET autenticado con manejo de refresh automático.
  static Future<dynamic> _getAuth(String path) async {
    var response = await http.get(
      Uri.parse('$_baseUrl$path'),
      headers: _authHeaders,
    );

    if (response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        response = await http.get(
          Uri.parse('$_baseUrl$path'),
          headers: _authHeaders,
        );
      }
    }

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  static Future<dynamic> _postAuth(
    String path,
    Map<String, dynamic> body,
  ) async {
    var response = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: _authHeaders,
      body: jsonEncode(body),
    );

    if (response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        response = await http.post(
          Uri.parse('$_baseUrl$path'),
          headers: _authHeaders,
          body: jsonEncode(body),
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    if (response.body.isNotEmpty) {
      try {
        return jsonDecode(response.body);
      } catch (_) {}
    }
    return null;
  }

  static Future<dynamic> _patchAuth(
    String path,
    Map<String, dynamic> body,
  ) async {
    var response = await http.patch(
      Uri.parse('$_baseUrl$path'),
      headers: _authHeaders,
      body: jsonEncode(body),
    );

    if (response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        response = await http.patch(
          Uri.parse('$_baseUrl$path'),
          headers: _authHeaders,
          body: jsonEncode(body),
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    if (response.body.isNotEmpty) {
      try {
        return jsonDecode(response.body);
      } catch (_) {}
    }
    return null;
  }

  static Future<dynamic> _deleteAuth(String path) async {
    var response = await http.delete(
      Uri.parse('$_baseUrl$path'),
      headers: _authHeaders,
    );

    if (response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        response = await http.delete(
          Uri.parse('$_baseUrl$path'),
          headers: _authHeaders,
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isEmpty ? {} : jsonDecode(response.body);
    }
    return null;
  }
}
