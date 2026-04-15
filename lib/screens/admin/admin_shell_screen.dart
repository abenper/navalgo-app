import 'package:flutter/material.dart';
import '../common/login_screen.dart'; // Importamos el login para poder cerrar sesión
import 'admin_dashboard_screen.dart'; // Dashboard específico de Admin
import 'partes_screen.dart';
import 'flota_screen.dart';
import 'equipo_screen.dart';
import '../worker/fichaje_screen.dart'; // Nueva ubicación
import '../worker/vacaciones_screen.dart'; // El archivo físico sigue siendo vacaciones_screen.dart
import 'package:provider/provider.dart';
import '../../viewmodels/session_view_model.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _selectedIndex = 0;

  // Lista de nuestras pantallas. Al usar IndexedStack, estas mantendrán su estado.
  final List<Widget> _screens = [
    const AdminDashboardScreen(), // <-- Corregido aquí
    const PartesScreen(),
    const FlotaScreen(),
    const EquipoScreen(),
    const FichajeScreen(),
    const AusenciasScreen(),
  ];

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Títulos dinámicos para el AppBar global
  final List<String> _titles = const [
    'Dashboard',
    'Gestión de Partes',
    'Clientes y Flota',
    'Equipo',
    'Control Horario',
    'Ausencias',
  ];

  // Nuestro nuevo Navbar superior
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(_titles[_selectedIndex], style: const TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        PopupMenuButton<String>(
          offset: const Offset(0, 50), // Desplaza el menú un poco hacia abajo
          tooltip: 'Opciones de cuenta',
          onSelected: (value) async {
            if (value == 'salir') {
              await context.read<SessionViewModel>().clearSession();
              if (!mounted) {
                return;
              }
              // Cierra sesión y vuelve a la pantalla de Login
              Navigator.of(this.context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            } else {
              // Placeholder para futuras pantallas (Perfil, Ajustes)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Abriendo: $value')),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue.shade100,
                  // TODO: Cuando conectes la API, usa backgroundImage: NetworkImage(trabajador.fotoUrl)
                  child: Icon(Icons.person, size: 20, color: Colors.blue.shade900),
                ),
                const SizedBox(width: 8),
                // Ocultamos el texto en pantallas muy pequeñas (móviles estrechos)
                if (MediaQuery.of(context).size.width > 400) ...[
                  const Text(
                    'Hola, Admin', // TODO: Reemplazar con el nombre real
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ],
            ),
          ),
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'Mi Perfil',
              child: ListTile(
                leading: Icon(Icons.person_outline),
                title: Text('Mi Perfil'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem<String>(
              value: 'Cambiar Contraseña',
              child: ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Cambiar Contraseña'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'salir',
              child: ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder nos permite saber el ancho disponible de la pantalla.
    // Así podemos hacer la app adaptativa (SaaS B2B suele usarse en Web/Escritorio y Móvil).
    return LayoutBuilder(
      builder: (context, constraints) {
        // Si la pantalla es ancha (Web, Tablet, Desktop)
        if (constraints.maxWidth >= 600) {
          return Scaffold(
            appBar: _buildAppBar(context),
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onDestinationSelected,
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: IconThemeData(color: Colors.blue.shade900),
                  selectedLabelTextStyle: TextStyle(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text('Dashboard'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.assignment_outlined),
                      selectedIcon: Icon(Icons.assignment),
                      label: Text('Partes'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.directions_boat_outlined),
                      selectedIcon: Icon(Icons.directions_boat),
                      label: Text('Flota'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people),
                      label: Text('Equipo'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.access_time_outlined),
                      selectedIcon: Icon(Icons.access_time_filled),
                      label: Text('Fichaje'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.event_note_outlined),
                      selectedIcon: Icon(Icons.event_note),
                      label: Text('Ausencias'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                // IndexedStack envuelto en Expanded para que tome el resto del ancho
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _screens,
                  ),
                ),
              ],
            ),
          );
        }
        
        // Si la pantalla es estrecha (Teléfono Móvil) -> NavigationBar (Material 3)
        return Scaffold(
          appBar: _buildAppBar(context),
          body: IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            // Tinte sutil basado en el color primario
            indicatorColor: Colors.blue.shade100,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard, color: Color(0xFF0D47A1)), // shade900
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment, color: Color(0xFF0D47A1)),
                label: 'Partes',
              ),
              NavigationDestination(
                icon: Icon(Icons.directions_boat_outlined),
                selectedIcon: Icon(Icons.directions_boat, color: Color(0xFF0D47A1)),
                label: 'Flota',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people, color: Color(0xFF0D47A1)),
                label: 'Equipo',
              ),
              NavigationDestination(
                icon: Icon(Icons.access_time_outlined),
                selectedIcon: Icon(Icons.access_time_filled, color: Color(0xFF0D47A1)),
                label: 'Fichaje',
              ),
              NavigationDestination(
                icon: Icon(Icons.event_note_outlined),
                selectedIcon: Icon(Icons.event_note, color: Color(0xFF0D47A1)),
                label: 'Ausencias',
              ),
            ],
          ),
        );
      },
    );
  }
}