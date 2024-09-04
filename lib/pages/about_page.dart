import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acerca de la aplicación'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Image.asset('assets/images/NEXT.png'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Image.asset('assets/images/logoUnisucre.png'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Energyflow es una aplicación diseñada para monitorear y analizar el consumo energético en tiempo real en hogares. Nuestro objetivo es proporcionar a los usuarios una herramienta eficiente para gestionar su consumo de energía.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            const Text(
              'Desarrolladores:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('JOSÉ LUIS LÓPEZ PRADO'),
            const Text('JAVIER SIERRA CARRILLO'),
            const Text('ALEJANDRO GUERRERO HERNÁNDEZ'),
          ],
        ),
      ),
    );
  }
}