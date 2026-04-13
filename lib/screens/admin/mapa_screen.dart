import 'package:flutter/material.dart';

class MapaScreen extends StatelessWidget {
  const MapaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // El mapa no suele llevar padding para ocupar toda la pantalla
      body: Stack(
        children: [
          // Fondo simulando un mapa (para el MVP)
          Container(
            color: Colors.blue.shade50,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
              ),
              itemBuilder: (context, index) => Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue.shade100, width: 0.5),
                ),
              ),
            ),
          ),
          
          const Center(
            child: Text(
              'Integración con Google Maps próximamente 🗺️', 
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)
            ),
          ),

          // Marcadores simulados
          Positioned(top: 150, left: 100, child: _buildMarker('Carlos M.')),
          Positioned(top: 300, right: 80, child: _buildMarker('Ana L.')),
          Positioned(top: 450, left: 200, child: _buildMarker('Juan P.')),
        ],
      ),
    );
  }

  // Widget personalizado para los pines del mapa
  Widget _buildMarker(String name) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        const Icon(Icons.location_on, color: Colors.red, size: 40),
      ],
    );
  }
}