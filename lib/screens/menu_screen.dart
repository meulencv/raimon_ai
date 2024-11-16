import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final supabase = Supabase.instance.client;
  bool _isLookingForTeam = false;
  final List<String> _teamMembers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserStatus();
  }

  Future<void> _loadUserStatus() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final userData = await supabase
          .from('users_info')
          .select('looking_for_team')
          .eq('user_id', userId)
          .single();
      setState(() {
        _isLookingForTeam = userData['looking_for_team'];
      });
    } catch (e) {
      print('Error cargando estado del usuario: $e');
    }
  }

  Future<void> _toggleLookingForTeam() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('users_info').update({
        'looking_for_team': !_isLookingForTeam
      }).eq('user_id', userId);

      setState(() {
        _isLookingForTeam = !_isLookingForTeam;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isLookingForTeam
              ? 'Ahora estás buscando grupo'
              : 'Ya no estás buscando grupo'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error actualizando estado')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddMemberDialog() async {
    if (_teamMembers.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El grupo ya tiene el máximo de participantes')),
      );
      return;
    }

    final TextEditingController controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir participante'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Introduce el ID del participante",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _teamMembers.add(controller.text);
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  void _showCreateTeamDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear Grupo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Participantes:'),
            const SizedBox(height: 10),
            if (_teamMembers.isEmpty)
              const Text('No hay participantes añadidos')
            else
              ...(_teamMembers.map((member) => Text('• $member')).toList()),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _showAddMemberDialog,
              child: const Text('Añadir Participante'),
            ),
            if (_teamMembers.length < 4) ...[
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  // TODO: Implementar búsqueda de participantes afines
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Función de búsqueda en desarrollo'),
                    ),
                  );
                },
                child: const Text('Buscar Participantes Afines'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<bool> _hasExistingInterview() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final userData = await supabase
          .from('users_info')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return userData != null;
    } catch (e) {
      print('Error verificando usuario: $e');
      return false;
    }
  }

  void _navigateToChat() async {
    final hasInterview = await _hasExistingInterview();
    if (hasInterview) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ya has completado la entrevista inicial')),
        );
      }
      return;
    }
    
    if (mounted) {
      Navigator.pushNamed(context, '/chat');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú Principal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/');
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¡Hola, ${supabase.auth.currentUser?.email?.split('@')[0] ?? 'usuario'}!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _navigateToChat,
              child: const Text('Iniciar Entrevista'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _showCreateTeamDialog,
              child: const Text('Fundar Grupo'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isLoading ? null : _toggleLookingForTeam,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(_isLookingForTeam
                      ? 'Dejar de Buscar Grupo'
                      : 'Buscar Grupo'),
            ),
          ],
        ),
      ),
    );
  }
}