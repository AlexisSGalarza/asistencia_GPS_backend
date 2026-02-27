import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'login_screen.dart';

class RecuperarPasswordScreen extends StatefulWidget {
  const RecuperarPasswordScreen({super.key});

  @override
  State<RecuperarPasswordScreen> createState() =>
      _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState extends State<RecuperarPasswordScreen> {
  final _emailController = TextEditingController();
  final _codigoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarController = TextEditingController();

  bool _isLoading = false;
  bool _codigoEnviado = false;
  bool _obscurePassword = true;
  bool _obscureConfirmar = true;
  String? _codigoDebug; // Solo para desarrollo

  @override
  void dispose() {
    _emailController.dispose();
    _codigoController.dispose();
    _passwordController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _solicitarCodigo() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _mostrarError('Ingresa tu correo electrónico');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.solicitarRecuperacion(email);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        // Siempre avanzamos al Paso 2 (el backend retorna 200 en ambos casos
        // por seguridad y no revela si el correo está registrado)
        setState(() {
          _codigoEnviado = true;
          _codigoDebug = result['codigo_debug']
              ?.toString(); // null si correo no existe
        });
        _mostrarExito('Si el correo está registrado, recibirás un código.');
      } else {
        // Error real (ej. fallo de red devuelto por el servidor)
        _mostrarError(result['mensaje'] ?? 'Error al solicitar recuperación');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _mostrarError('Error de conexión. Verifica tu red.');
    }
  }

  Future<void> _confirmarRecuperacion() async {
    final email = _emailController.text.trim();
    final codigo = _codigoController.text.trim();
    final password = _passwordController.text;
    final confirmar = _confirmarController.text;

    if (codigo.isEmpty || password.isEmpty || confirmar.isEmpty) {
      _mostrarError('Completa todos los campos');
      return;
    }

    if (codigo.length != 6) {
      _mostrarError('El código debe tener 6 dígitos');
      return;
    }

    if (password.length < 6) {
      _mostrarError('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    if (password != confirmar) {
      _mostrarError('Las contraseñas no coinciden');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.confirmarRecuperacion(
        email,
        codigo,
        password,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  backgroundColor: const Color(
                    0xFF2E7D32,
                  ).withValues(alpha: 0.15),
                  radius: 35,
                  child: const Icon(
                    Icons.check_circle,
                    color: Color(0xFF2E7D32),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '¡Contraseña actualizada!',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Ya puedes iniciar sesión con tu nueva contraseña.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
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
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Ir al Login',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
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
      } else {
        _mostrarError(result['mensaje'] ?? 'Error al recuperar contraseña');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _mostrarError('Error de conexión. Verifica tu red.');
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: const TextStyle(fontFamily: 'Montserrat'),
        ),
        backgroundColor: const Color(0xFFC62828),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: const TextStyle(fontFamily: 'Montserrat'),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
              _buildTopSection(size),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1.0 - value)),
                    child: child,
                  ),
                ),
                child: Transform.translate(
                  offset: const Offset(0, -40),
                  child: _buildFormSection(size),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection(Size size) {
    return SizedBox(
      width: size.width,
      height: size.height * 0.30,
      child: Stack(
        children: [
          Container(
            width: size.width,
            height: size.height * 0.30,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFA98BC3), Color(0xFFE8A0BF)],
              ),
            ),
          ),
          // Botón de regresar
          Positioned(
            top: size.height * 0.06,
            left: 15,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Color(0xFF6B2D8B),
                  size: 20,
                ),
              ),
            ),
          ),
          // Contenido
          Positioned(
            top: size.height * 0.08,
            left: 30,
            right: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA98BC3), Color(0xFFE8A0BF)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFA98BC3).withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_reset,
                    color: Colors.white,
                    size: 35,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Recuperar\nContraseña',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Te ayudaremos a restablecer tu acceso\npaso a paso.',
                  style: TextStyle(
                    fontFamily: 'Merriweather',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection(Size size) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Paso 1 o Paso 2
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFA98BC3), Color(0xFFE8A0BF)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    _codigoEnviado ? '2' : '1',
                    style: const TextStyle(
                      fontFamily: 'Merriweather',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _codigoEnviado
                    ? 'Ingresa el código y nueva contraseña'
                    : 'Ingresa tu correo electrónico',
                style: const TextStyle(
                  fontFamily: 'Merriweather',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3D3D3D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _codigoEnviado
                ? 'Ingresa el código de 6 dígitos que recibiste y tu nueva contraseña.'
                : 'Te enviaremos un código de verificación para restablecer tu contraseña.',
            style: const TextStyle(
              fontFamily: 'Merriweather',
              fontSize: 12,
              color: Color(0xFF757575),
            ),
          ),
          const SizedBox(height: 25),

          // Campo de correo (siempre visible pero deshabilitado en paso 2)
          _buildTextField(
            controller: _emailController,
            hint: 'Correo electrónico',
            icon: Icons.email_outlined,
            enabled: !_codigoEnviado,
            keyboardType: TextInputType.emailAddress,
          ),

          if (_codigoEnviado) ...[
            const SizedBox(height: 15),

            // Código debug (solo desarrollo)
            if (_codigoDebug != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFB74D)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bug_report,
                      color: Color(0xFFE65100),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Código de desarrollo: $_codigoDebug',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Campo de código
            _buildTextField(
              controller: _codigoController,
              hint: 'Código de 6 dígitos',
              icon: Icons.pin_outlined,
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: 15),

            // Nueva contraseña
            _buildTextField(
              controller: _passwordController,
              hint: 'Nueva contraseña',
              icon: Icons.lock_outline,
              obscure: _obscurePassword,
              onToggleObscure: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
            const SizedBox(height: 15),

            // Confirmar contraseña
            _buildTextField(
              controller: _confirmarController,
              hint: 'Confirmar contraseña',
              icon: Icons.lock_outline,
              obscure: _obscureConfirmar,
              onToggleObscure: () {
                setState(() => _obscureConfirmar = !_obscureConfirmar);
              },
            ),
          ],

          const SizedBox(height: 25),

          // Botón principal
          SizedBox(
            width: double.infinity,
            height: 55,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFA98BC3), Color(0xFFE8A0BF)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFA98BC3).withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (_codigoEnviado
                          ? _confirmarRecuperacion
                          : _solicitarCodigo),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        _codigoEnviado ? 'Cambiar Contraseña' : 'Enviar Código',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),

          if (_codigoEnviado) ...[
            const SizedBox(height: 15),
            // Reenviar código
            Center(
              child: TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _codigoEnviado = false;
                          _codigoController.clear();
                          _passwordController.clear();
                          _confirmarController.clear();
                        });
                      },
                child: const Text(
                  '← Cambiar correo o reenviar código',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B2D8B),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Volver al login
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: RichText(
                text: const TextSpan(
                  text: '¿Recordaste tu contraseña? ',
                  style: TextStyle(
                    fontFamily: 'Merriweather',
                    fontSize: 13,
                    color: Color(0xFF757575),
                  ),
                  children: [
                    TextSpan(
                      text: 'Iniciar sesión',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B2D8B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool enabled = true,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF5F0FA),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        obscureText: obscure,
        keyboardType: keyboardType,
        maxLength: maxLength,
        style: const TextStyle(fontFamily: 'Montserrat', fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: 'Montserrat',
            color: Colors.grey[400],
          ),
          prefixIcon: Icon(icon, color: const Color(0xFFA98BC3)),
          suffixIcon: onToggleObscure != null
              ? IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey[400],
                  ),
                  onPressed: onToggleObscure,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: enabled ? Colors.white : const Color(0xFFF5F0FA),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          counterText: '',
        ),
      ),
    );
  }
}
