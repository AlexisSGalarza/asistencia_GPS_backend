import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../maestro/marcar_asistencia_screen.dart';
import 'recuperar_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white, // Fondo blanco
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ========== PARTE SUPERIOR MORADA ==========
            _buildTopSection(size),

            // ========== FORMULARIO DE LOGIN (se superpone sobre el morado) ==========
            Transform.translate(
              offset: const Offset(0, -50),
              child: _buildLoginForm(size),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Sección superior con fondo morado ----------
  Widget _buildTopSection(Size size) {
    return SizedBox(
      width: size.width,
      height: size.height * 0.38,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Fondo morado (recto, sin curva)
          Container(
            width: size.width,
            height: size.height * 0.38,
            color: const Color(0xFFF1E9F8),
          ),
          // Textos
          Positioned(
            top: size.height * 0.08,
            left: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Hello!',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF6B2D8B),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Welcome back, Teacher',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF3D3D3D),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Imagen del profesor - pegada a la derecha
          Positioned(
            bottom: -40,
            right: 0,
            child: Image.asset(
              'assets/images/teacher.png',
              height: size.height * 0.38,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: size.height * 0.18,
                  width: size.height * 0.18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFA98BC3).withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 80,
                    color: Color(0xFF6B2D8B),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Formulario de login ----------
  Widget _buildLoginForm(Size size) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título "Login"
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Login',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF3D3D3D),
              ),
            ),
          ),
          const SizedBox(height: 25),

          // ---------- Campo Email ----------
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
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
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Email',
                hintStyle: TextStyle(
                  fontFamily: 'Montserrat',
                  color: Colors.grey[400],
                ),
                prefixIcon: const Icon(
                  Icons.mail_outline,
                  color: Color(0xFFA98BC3),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ---------- Campo Password ----------
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
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
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: TextStyle(
                  fontFamily: 'Montserrat',
                  color: Colors.grey[400],
                ),
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: Color(0xFFA98BC3),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey[400],
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ---------- Forgot Password ----------
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RecuperarPasswordScreen(),
                  ),
                );
              },
              child: Text(
                'Forgot Password?',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  color: const Color(0xFF6B2D8B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ---------- Botón LOGIN ----------
          SizedBox(
            width: double.infinity,
            height: 55,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFA98BC3), // Morado
                    Color(0xFFE8A0BF), // Rosa
                  ],
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
                onPressed: _isLoading ? null : _handleLogin,
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
                        'Login',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ---------- Función de login conectada al backend ----------
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor llena todos los campos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.login(email, password);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        final rol = ApiService.rolUsuario.toLowerCase();
        if (rol == 'administrador' || rol == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin/dashboard');
        } else if (rol == 'supervisor') {
          Navigator.pushReplacementNamed(context, '/supervisor/incidencias');
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MarcarAsistenciaScreen()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['mensaje'] ?? 'Error al iniciar sesión'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de conexión. Verifica tu red.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
