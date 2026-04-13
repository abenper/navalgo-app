import 'package:flutter/material.dart';

class FichajeScreen extends StatefulWidget {
  const FichajeScreen({super.key});

  @override
  State<FichajeScreen> createState() => _FichajeScreenState();
}

class _FichajeScreenState extends State<FichajeScreen> {
  bool _isPunchedIn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isPunchedIn ? Icons.timer : Icons.timer_off,
              size: 100,
              color: _isPunchedIn ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(
              _isPunchedIn ? 'Estado: Trabajando' : 'Estado: Fuera de turno',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                backgroundColor: _isPunchedIn ? Colors.red.shade700 : Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                setState(() {
                  _isPunchedIn = !_isPunchedIn;
                });
              },
              icon: Icon(_isPunchedIn ? Icons.stop : Icons.play_arrow),
              label: Text(
                _isPunchedIn ? 'Finalizar Turno' : 'Iniciar Turno',
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 40),
            const Text('Últimos registros:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            // Lista simulada de fichajes
            SizedBox(
              width: 350,
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.login, color: Colors.green),
                  title: const Text('Entrada'),
                  trailing: const Text('Hoy, 08:00 AM'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}