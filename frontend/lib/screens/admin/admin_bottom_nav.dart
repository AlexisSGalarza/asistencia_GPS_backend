import 'package:flutter/material.dart';
import '../../services/api_service.dart';

/// Barra de navegación inferior del panel admin.
/// [currentIndex]: 0=Dashboard, 1=Usuarios, 2=Horarios, 3=Configuración, 4=Reportes, 5=Salir.
Widget buildAdminBottomNav(BuildContext context, int currentIndex) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(25),
        topRight: Radius.circular(25),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.2),
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
        currentIndex: currentIndex,
        onTap: (index) {
          if (index == 5) {
            _confirmarLogout(context);
            return;
          }
          if (index == currentIndex) return;
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/admin/dashboard');
          } else if (index == 1) {
            Navigator.pushReplacementNamed(context, '/admin/usuarios');
          } else if (index == 2) {
            Navigator.pushReplacementNamed(context, '/admin/horarios');
          } else if (index == 3) {
            Navigator.pushReplacementNamed(context, '/admin/config');
          } else if (index == 4) {
            Navigator.pushReplacementNamed(context, '/admin/reportes');
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF6B2D8B),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 10,
        ),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Usuarios',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.schedule_outlined),
            activeIcon: Icon(Icons.schedule),
            label: 'Horarios',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Config',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.insert_chart_outlined),
            activeIcon: Icon(Icons.insert_chart),
            label: 'Reportes',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.logout, color: Color(0xFFC62828)),
            activeIcon: Icon(Icons.logout, color: Color(0xFFC62828)),
            label: 'Salir',
          ),
        ],
      ),
    ),
  );
}

void _confirmarLogout(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Cerrar sesión'),
      content: const Text(
        '¿Estás seguro de que deseas cerrar sesión?',
        style: TextStyle(fontFamily: 'Montserrat'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await ApiService.logout();
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC62828),
            foregroundColor: Colors.white,
          ),
          child: const Text('Salir'),
        ),
      ],
    ),
  );
}
