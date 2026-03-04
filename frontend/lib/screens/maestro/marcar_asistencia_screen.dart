import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/api_service.dart';
import '../login/login_screen.dart';
import 'horario_screen.dart';
import 'registros_screen.dart';
import 'perfil_screen.dart';

class MarcarAsistenciaScreen extends StatefulWidget {
  const MarcarAsistenciaScreen({super.key});

  @override
  State<MarcarAsistenciaScreen> createState() => _MarcarAsistenciaScreenState();
}

class _MarcarAsistenciaScreenState extends State<MarcarAsistenciaScreen> {
  bool _dentroDelPerimetro = true;
  bool _entradaRegistrada = false;
  bool _salidaRegistrada = false;
  String _horaActual = '';
  String _fechaActual = '';
  Timer? _timer;

  // Ubicación
  LatLng? _ubicacionActual;
  bool _cargandoUbicacion = true;
  String? _errorUbicacion;
  final MapController _mapController = MapController();
  bool _mapaListo = false; // controla si el mapa ya fue construido

  // Perímetro del campus (se carga del backend)
  LatLng? _centroCampus;
  double _radioPerimetro = 100.0; // metros, fallback

  // WiFi
  String _wifiSSID = '';
  String _wifiBSSID = '';
  bool _cargandoWifi = true;
  String? _errorWifi;

  @override
  void initState() {
    super.initState();
    _actualizarReloj();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _actualizarReloj(),
    );
    _cargarPerimetro();
    _obtenerUbicacion();
    _cargarEstadoHoy();
    _detectarWifi();
  }

  /// Carga el perímetro activo y recalcula distancia si ya hay GPS.
  Future<void> _cargarPerimetro() async {
    try {
      final perimetros = await ApiService.getPerimetros();
      if (!mounted) return;
      final activos = perimetros.where((p) => p['activo'] == true).toList();
      if (activos.isNotEmpty) {
        final p = activos.first;
        final lat = double.tryParse(p['latitud'].toString()) ?? 0.0;
        final lng = double.tryParse(p['longitud'].toString()) ?? 0.0;
        final radio = (p['radio_metros'] as num?)?.toDouble() ?? 100.0;

        if (lat != 0.0 && lng != 0.0) {
          setState(() {
            _centroCampus = LatLng(lat, lng);
            _radioPerimetro = radio;
            if (_ubicacionActual != null) {
              final distancia = const Distance().as(
                LengthUnit.Meter,
                _ubicacionActual!,
                _centroCampus!,
              );
              _dentroDelPerimetro = distancia <= (_radioPerimetro + 35);
            }
          });
        }
      }
    } catch (_) {}
  }

  /// Lee SSID/BSSID del dispositivo y los guarda para enviarlos al servidor.
  /// La validación de si la red es autorizada la hace el backend.
  Future<void> _detectarWifi() async {
    setState(() {
      _cargandoWifi = true;
      _errorWifi = null;
    });

    // En emulador no hay hardware WiFi
    if (ApiService.isEmulador) {
      setState(() {
        _wifiSSID = 'EMULADOR';
        _wifiBSSID = '';
        _cargandoWifi = false;
      });
      return;
    }

    try {
      // Android 8+ requiere permiso de ubicación para leer el SSID
      final locationStatus = await Permission.location.request();
      if (!locationStatus.isGranted) {
        setState(() {
          _cargandoWifi = false;
          _errorWifi = 'Permiso de ubicación necesario para detectar WiFi';
        });
        return;
      }

      final info = NetworkInfo();
      String? ssid = await info.getWifiName();
      String? bssid = await info.getWifiBSSID();

      // Android envuelve el SSID en comillas, hay que limpiarlas
      ssid = ssid?.replaceAll('"', '').trim() ?? '';
      bssid = bssid?.trim().toUpperCase() ?? '';

      if (!mounted) return;
      setState(() {
        _wifiSSID = ssid!;
        _wifiBSSID = bssid!;
        _cargandoWifi = false;
        if (ssid.isEmpty || ssid == '<unknown ssid>' || ssid == '0x') {
          _errorWifi = 'No conectado a Wi-Fi';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoWifi = false;
        _errorWifi = 'Error al detectar Wi-Fi';
      });
    }
  }

  /// Consulta al backend si ya hay entrada/salida registrada hoy.
  Future<void> _cargarEstadoHoy() async {
    try {
      final estado = await ApiService.getEstadoHoy();
      if (!mounted) return;
      setState(() {
        _entradaRegistrada = estado['entrada_registrada'] == true;
        _salidaRegistrada = estado['salida_registrada'] == true;
      });
    } catch (_) {}
  }

  void _actualizarReloj() {
    final now = DateTime.now();
    setState(() {
      _horaActual =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
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
      final dias = [
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado',
        'Domingo',
      ];
      _fechaActual =
          '${dias[now.weekday - 1]}, ${now.day} de ${meses[now.month - 1]} ${now.year}';
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Obtiene la ubicación GPS del dispositivo.
  Future<void> _obtenerUbicacion() async {
    setState(() {
      _cargandoUbicacion = true;
      _errorUbicacion = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _cargandoUbicacion = false;
          _errorUbicacion = 'Activa el servicio de ubicación';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _cargandoUbicacion = false;
            _errorUbicacion = 'Permiso de ubicación denegado';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _cargandoUbicacion = false;
          _errorUbicacion = 'Permiso de ubicación denegado permanentemente';
        });
        return;
      }

      Position position =
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 5,
            ),
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Tiempo de espera agotado'),
          );

      if (!mounted) return;

      final nuevaUbicacion = LatLng(position.latitude, position.longitude);

      // Calcular si está dentro del perímetro (tolerancia de 35m sobre el radio)
      double distancia = 0;
      bool dentro = true;
      if (_centroCampus != null) {
        distancia = const Distance().as(
          LengthUnit.Meter,
          nuevaUbicacion,
          _centroCampus!,
        );
        dentro = distancia <= (_radioPerimetro + 35);
      }

      setState(() {
        _ubicacionActual = nuevaUbicacion;
        _cargandoUbicacion = false;
        _dentroDelPerimetro = dentro;
      });

      if (_mapaListo) {
        _mapController.move(nuevaUbicacion, 17.0);
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _cargandoUbicacion = false;
        _errorUbicacion = 'Tiempo agotado. Revisa tu GPS e intenta de nuevo';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoUbicacion = false;
        _errorUbicacion =
            'Error al obtener ubicación. Revisa que el GPS esté activo';
      });
    }
  }

  /// Registra asistencia llamando al backend.
  Future<void> _registrarAsistencia(String tipo) async {
    if (_ubicacionActual == null) {
      _mostrarAlerta(
        titulo: 'Ubicación pendiente',
        mensaje:
            'Aún obteniendo señal GPS. Espera unos segundos y vuelve a intentar.',
        color: const Color(0xFFC62828),
        icono: Icons.location_searching,
      );
      return;
    }

    final double lat = _ubicacionActual!.latitude;
    final double lng = _ubicacionActual!.longitude;

    try {
      final result = await ApiService.registrarAsistencia(
        tipo: tipo,
        latitud: lat,
        longitud: lng,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final data = result['data'] ?? {};
        final valido = data['valido'] == true;
        final estadoHorario = data['estado_horario'] ?? '';

        setState(() {
          if (tipo == 'entrada' && valido) {
            _entradaRegistrada = true;
          } else if (valido) {
            _salidaRegistrada = true;
          }
          _dentroDelPerimetro = valido;
        });

        // Determinar color e ícono según estado del horario
        Color alertColor;
        IconData alertIcon;
        String alertTitulo;

        if (!valido) {
          alertColor = const Color(0xFFC62828);
          alertIcon = Icons.wrong_location;
          alertTitulo = 'Fuera del perímetro';
        } else if (estadoHorario == 'retardo') {
          alertColor = const Color(0xFFE65100);
          alertIcon = Icons.warning_amber_rounded;
          alertTitulo = 'Retardo registrado';
        } else if (estadoHorario == 'salida_temprana') {
          alertColor = const Color(0xFFE65100);
          alertIcon = Icons.warning_amber_rounded;
          alertTitulo = 'Salida temprana';
        } else if (estadoHorario == 'sin_horario') {
          alertColor = const Color(0xFF1565C0);
          alertIcon = Icons.info_outline;
          alertTitulo = 'Sin horario hoy';
        } else {
          alertColor = const Color(0xFF2E7D32);
          alertIcon = Icons.check_circle;
          alertTitulo = tipo == 'entrada'
              ? 'Entrada a tiempo'
              : 'Salida registrada';
        }

        _mostrarAlerta(
          titulo: alertTitulo,
          mensaje: data['mensaje'] ?? 'Registrado correctamente',
          color: alertColor,
          icono: alertIcon,
        );
      } else {
        // En caso de error de perimetro el backend manda 400 y cae aquí directamente
        _mostrarAlerta(
          titulo: 'Fuera del perímetro',
          mensaje: result['mensaje'] ?? 'No se pudo registrar',
          color: const Color(0xFFC62828),
          icono: Icons.cancel,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _mostrarAlerta(
        titulo: 'Error de conexión',
        mensaje: 'No se pudo conectar con el servidor',
        color: const Color(0xFFC62828),
        icono: Icons.wifi_off,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF1E9F8),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(size),
              const SizedBox(height: 15),
              _buildMapaBlob(size),
              const SizedBox(height: 20),
              _buildFechaHora(),
              const SizedBox(height: 15),
              _buildWifiEstado(),
              const SizedBox(height: 10),
              _buildEstado(),
              const SizedBox(height: 20),
              _buildBotones(size),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
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
              children: [
                Text(
                  'Hello!',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B2D8B),
                  ),
                ),
                Text(
                  ApiService.nombreUsuario.isNotEmpty
                      ? ApiService.nombreUsuario
                      : 'Welcome Teacher',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
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

  // ---------- Mapa real con OpenStreetMap ----------
  Widget _buildMapaBlob(Size size) {
    return Center(
      child: SizedBox(
        width: size.width * 0.88,
        height: size.height * 0.30,
        child: ClipPath(
          clipper: _BlobClipper(),
          child: Stack(
            children: [
              if (_cargandoUbicacion)
                Container(
                  color: const Color(0xFFE8E0EF),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFF6B2D8B),
                          strokeWidth: 2.5,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Obteniendo ubicación...',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 13,
                            color: Color(0xFF6B2D8B),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_errorUbicacion != null)
                Container(
                  color: const Color(0xFFE8E0EF),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.location_off,
                          size: 40,
                          color: Color(0xFFC62828),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorUbicacion!,
                          style: const TextStyle(
                            fontFamily: 'Merriweather',
                            fontSize: 12,
                            color: Color(0xFFC62828),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _obtenerUbicacion,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text(
                            'Reintentar',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6B2D8B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter:
                        _centroCampus ??
                        const LatLng(
                          25.725394,
                          -100.313405,
                        ), // Monterrey default UI
                    initialZoom: 17.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onMapReady: () {
                      // El mapa ya está listo: podemos usar el controller con seguridad
                      setState(() => _mapaListo = true);
                      if (_ubicacionActual != null) {
                        _mapController.move(_ubicacionActual!, 17.0);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.asistencia_gps',
                    ),
                    // Círculo del perímetro
                    CircleLayer(
                      circles: [
                        if (_centroCampus != null)
                          CircleMarker(
                            point: _centroCampus!,
                            radius: _radioPerimetro,
                            useRadiusInMeter: true,
                            color: _dentroDelPerimetro
                                ? const Color(
                                    0xFF2E7D32,
                                  ).withValues(alpha: 0.15)
                                : const Color(
                                    0xFFC62828,
                                  ).withValues(alpha: 0.15),
                            borderColor: _dentroDelPerimetro
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFC62828),
                            borderStrokeWidth: 2,
                          ),
                      ],
                    ),
                    // Marcador del usuario
                    if (_ubicacionActual != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _ubicacionActual!,
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF6B2D8B),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF6B2D8B,
                                    ).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          // Marcador del centro del campus
                          if (_centroCampus != null)
                            Marker(
                              point: _centroCampus!,
                              width: 30,
                              height: 30,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8A0BF),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.school,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              // Botón mi ubicación
              Positioned(
                top: 15,
                right: 15,
                child: GestureDetector(
                  onTap: _obtenerUbicacion,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.my_location,
                      color: Color(0xFF6B2D8B),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Fecha y Hora ----------
  Widget _buildFechaHora() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.access_time, color: Color(0xFF6B2D8B), size: 24),
          const SizedBox(width: 12),
          Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _horaActual,
                  style: const TextStyle(
                    fontFamily: 'Merriweather',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B2D8B),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _fechaActual,
                  style: const TextStyle(
                    fontFamily: 'Merriweather',
                    fontSize: 12,
                    color: Color(0xFF757575),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Estado Wi-Fi ----------
  Widget _buildWifiEstado() {
    String texto;
    Color color;
    IconData icono;
    String subtexto = '';

    if (_cargandoWifi) {
      texto = 'Detectando Wi-Fi...';
      color = const Color(0xFF757575);
      icono = Icons.wifi_find;
    } else if (_errorWifi != null) {
      texto = _errorWifi!;
      color = const Color(0xFFC62828);
      icono = Icons.wifi_off;
    } else {
      texto = _wifiSSID.isNotEmpty ? _wifiSSID : 'Wi-Fi detectado';
      color = const Color(0xFF1565C0);
      icono = Icons.wifi;
      subtexto = _wifiBSSID.isNotEmpty ? _wifiBSSID : '';
    }

    return GestureDetector(
      onTap: _detectarWifi,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 30),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    texto,
                    style: TextStyle(
                      fontFamily: 'Merriweather',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (subtexto.isNotEmpty)
                    Text(
                      subtexto,
                      style: const TextStyle(
                        fontFamily: 'Merriweather',
                        fontSize: 11,
                        color: Color(0xFF757575),
                      ),
                    ),
                ],
              ),
            ),
            if (!_cargandoWifi)
              Icon(Icons.refresh, color: Colors.grey[400], size: 18),
          ],
        ),
      ),
    );
  }

  // ---------- Estado ----------
  Widget _buildEstado() {
    String texto;
    Color color;
    IconData icono;

    if (_ubicacionActual == null || _centroCampus == null) {
      texto = 'Calculando ubicación...';
      color = const Color(0xFF757575);
      icono = Icons.location_searching;
    } else if (!_dentroDelPerimetro) {
      texto = 'Fuera del perímetro';
      color = const Color(0xFFC62828);
      icono = Icons.cancel;
    } else if (_salidaRegistrada) {
      texto = 'Jornada completada';
      color = const Color(0xFF2E7D32);
      icono = Icons.check_circle;
    } else if (_entradaRegistrada) {
      texto = 'Entrada registrada';
      color = const Color(0xFF1565C0);
      icono = Icons.check_circle_outline;
    } else {
      texto = 'Listo para registrar';
      color = const Color(0xFF2E7D32);
      icono = Icons.check_circle;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, color: color, size: 24),
          const SizedBox(width: 10),
          Text(
            texto,
            style: TextStyle(
              fontFamily: 'Merriweather',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Botones de registro ----------
  Widget _buildBotones(Size size) {
    // Entrada activa si: tiene ubicación Y no ha registrado entrada (WiFi la valida el servidor)
    final bool entradaActiva = _ubicacionActual != null && !_entradaRegistrada;
    // Salida activa si: tiene ubicación Y ya registró entrada Y no ha registrado salida
    final bool salidaActiva =
        _ubicacionActual != null && _entradaRegistrada && !_salidaRegistrada;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Row(
        children: [
          // Botón de ENTRADA
          Expanded(
            child: SizedBox(
              height: 55,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: entradaActiva
                      ? const LinearGradient(
                          colors: [Color(0xFFA98BC3), Color(0xFFE8A0BF)],
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFBDBDBD), Color(0xFFE0E0E0)],
                        ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: entradaActiva
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFFA98BC3,
                            ).withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : [],
                ),
                child: ElevatedButton.icon(
                  onPressed: entradaActiva
                      ? () => _registrarAsistencia('entrada')
                      : null,
                  icon: Icon(
                    Icons.login,
                    color: entradaActiva ? Colors.white : Colors.grey[600],
                  ),
                  label: Text(
                    'Entrada',
                    style: TextStyle(
                      fontFamily: 'Merriweather',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: entradaActiva ? Colors.white : Colors.grey[600],
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          // Botón de SALIDA
          Expanded(
            child: SizedBox(
              height: 55,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: salidaActiva
                      ? const LinearGradient(
                          colors: [Color(0xFF6B2D8B), Color(0xFFA98BC3)],
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFBDBDBD), Color(0xFFE0E0E0)],
                        ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: salidaActiva
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF6B2D8B,
                            ).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : [],
                ),
                child: ElevatedButton.icon(
                  onPressed: salidaActiva
                      ? () => _registrarAsistencia('salida')
                      : null,
                  icon: Icon(
                    Icons.logout,
                    color: salidaActiva ? Colors.white : Colors.grey[600],
                  ),
                  label: Text(
                    'Salida',
                    style: TextStyle(
                      fontFamily: 'Merriweather',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: salidaActiva ? Colors.white : Colors.grey[600],
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Alerta personalizada ----------
  void _mostrarAlerta({
    required String titulo,
    required String mensaje,
    required Color color,
    required IconData icono,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              radius: 35,
              child: Icon(icono, color: color, size: 35),
            ),
            const SizedBox(height: 18),
            Text(
              titulo,
              style: TextStyle(
                fontFamily: 'Merriweather',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Merriweather',
                fontSize: 13,
                color: Color(0xFF757575),
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Aceptar',
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
    );
  }

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

  // ---------- Barra de navegación inferior ----------
  Widget _buildBottomNav() {
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
          currentIndex: 0,
          onTap: (index) {
            if (index == 1) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HorarioScreen()),
              );
            } else if (index == 2) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const RegistrosScreen()),
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

// ---------- Recortador personalizado para forma de mancha ----------
class _BlobClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w * 0.05, h * 0.15);
    path.cubicTo(w * 0.0, h * 0.0, w * 0.35, h * -0.05, w * 0.5, h * 0.03);
    path.cubicTo(w * 0.65, h * -0.02, w * 1.0, h * 0.0, w * 0.95, h * 0.18);
    path.cubicTo(w * 1.05, h * 0.35, w * 1.02, h * 0.65, w * 0.95, h * 0.80);
    path.cubicTo(w * 1.0, h * 1.0, w * 0.70, h * 1.05, w * 0.50, h * 0.98);
    path.cubicTo(w * 0.30, h * 1.05, w * 0.0, h * 1.0, w * 0.05, h * 0.82);
    path.cubicTo(w * -0.02, h * 0.65, w * -0.02, h * 0.35, w * 0.05, h * 0.15);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
