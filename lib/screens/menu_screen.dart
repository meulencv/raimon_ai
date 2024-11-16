import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  Future<void> _createTeam(BuildContext context) async {
    final supabase = Supabase.instance.client;
    
    try {
      // Verificar si el usuario ya tiene un equipo
      final existingTeam = await supabase
          .from('teams')
          .select()
          .single();

      if (existingTeam != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ya tienes un equipo creado')),
          );
        }
        return;
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pushNamed(context, '/chat');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '¡HOLA!',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _createTeam(context),
              child: const Text('Crear Equipo'),
            ),
          ],
        ),
      ),
    );
  }
}