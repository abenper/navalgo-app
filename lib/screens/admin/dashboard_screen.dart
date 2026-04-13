import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Sección de KPIs (Indicadores)
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(context, 'Partes Activos', '14', Icons.assignment, Colors.blue),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiCard(context, 'Mecánicos', '8/10', Icons.people, Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(context, 'Urgencias', '2', Icons.warning, Colors.red),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiCard(context, 'Terminados Hoy', '5', Icons.check_circle, Colors.teal),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Sección de Actividad
          Text('Actividad Reciente', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history, color: Colors.grey),
              title: const Text('Parte #1042 marcado como "Terminado"'),
              subtitle: const Text('Mecánico: Juan Pérez - Hace 10 min'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(BuildContext context, String title, String value, IconData icon, MaterialColor color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color.shade700, size: 32),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}