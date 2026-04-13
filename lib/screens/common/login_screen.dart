import 'package:flutter/material.dart';
import 'package:navalgo/viewmodels/login_view_model.dart';
import '../admin/admin_shell_screen.dart';
import '../worker/worker_shell_screen.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 1. Controladores: Estas variables "escuchan" lo que el usuario escribe.
  // Los usaremos más adelante para enviar el usuario y contraseña a tu API en SpringBoot.
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _recuerdame = false; // Se mantiene para la funcionalidad de "Recuérdame"

  // Es buena práctica "destruir" los controladores cuando la pantalla se cierra para liberar memoria.
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Usamos context.watch para que la UI se reconstruya cuando cambie el ViewModel
    final loginViewModel = context.watch<LoginViewModel>();

    // 2. Scaffold: Es el lienzo blanco principal de una pantalla.
    return Scaffold(
      // Un azul muy clarito de fondo, recordando el cielo o la espuma del mar
      backgroundColor: Colors.blue.shade50,
      
      // 3. Center y SingleChildScrollView: Centran todo y permiten hacer scroll 
      // por si el teclado del móvil tapa la pantalla al escribir.
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450), // Ideal para web/escritorio
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- ICONO Y LOGO ---
                    Icon(
                      Icons.sailing, // Un velero de icono (puramente náutico)
                      size: 80,
                      color: Colors.blue.shade900, // Azul marino
                    ),
                    const SizedBox(height: 16), // Espaciador
                    
                    const Text(
                      'NavalGO',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1), // Colors.blue.shade900
                        letterSpacing: 2, // Separa un poco las letras para darle elegancia
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Acceso al panel de gestión',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 40),
      
                    // --- CAMPO DE EMAIL ---
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Correo Electrónico',
                        prefixIcon: Icon(Icons.email, color: Colors.blue.shade700),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50, // Fondo gris muy claro para contrastar con la tarjeta
                      ),
                    ),
                    const SizedBox(height: 20),
      
                    // --- CAMPO DE CONTRASEÑA ---
                    TextField(
                      controller: _passwordController,
                      obscureText: true, // Esto convierte el texto en asteriscos
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: Icon(Icons.lock, color: Colors.blue.shade700),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 10), // Reducimos un poco el espacio aquí

                    // --- CHECKBOX RECUÉRDAME ---
                    Row(
                      children: [
                        Checkbox(
                          value: _recuerdame,
                          onChanged: (bool? newValue) {
                            setState(() {
                              _recuerdame = newValue ?? false;
                            });
                          },
                          activeColor: Colors.blue.shade900, // Color azul naval al marcar
                        ),
                        Text('Recuérdame', style: TextStyle(color: Colors.grey.shade700)),
                      ],
                    ),
                    const SizedBox(height: 10),
      
                    // --- BOTÓN DE LOGIN ---
                    SizedBox(
                      width: double.infinity, // Hace que el botón ocupe todo el ancho
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade900,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        onPressed: loginViewModel.isLoading ? null : () async {
                          bool success = await loginViewModel.login(
                            _emailController.text,
                            _passwordController.text,
                          );

                          if (mounted) { // Comprueba si el widget sigue en el árbol
                            if (success) {
                              if (loginViewModel.currentUser?.role == 'ADMIN') {
                                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const AdminShellScreen()));
                              } else { // Asumimos que cualquier otro rol es Mecánico por ahora
                                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const WorkerShellScreen()));
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(loginViewModel.errorMessage ?? 'Error desconocido')),
                              );
                            }
                          }
                        },
                        child: loginViewModel.isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Entrar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}