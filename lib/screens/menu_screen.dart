import 'dart:math';

import 'package:flutter/material.dart';
import 'package:raimon_ai/screens/team_confirmed_screen.dart';
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
  final TextEditingController _teamNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkTeamMembership();
    _loadUserStatus();
    // Añadir el usuario actual al equipo
    final currentUserId = supabase.auth.currentUser!.id;
    _teamMembers.add(currentUserId);
  }

  Future<void> _checkTeamMembership() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final teamData = await supabase
          .from('team_members')
          .select('team_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (teamData != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TeamConfirmedScreen(
              teamId: teamData['team_id'].toString(),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error verificando membresía: $e');
    }
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
        const SnackBar(content: Text('El equipo ya tiene el máximo de miembros (4)')),
      );
      return;
    }

    final TextEditingController controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir miembro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: "ID del miembro",
                labelText: "ID del miembro",
              ),
            ),
            if (_teamMembers.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Miembros actuales:'),
              ...(_teamMembers.map((member) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(member),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            setState(() {
                              _teamMembers.remove(member);
                            });
                            Navigator.pop(context);
                            _showAddMemberDialog();
                          },
                        ),
                      ],
                    ),
                  )).toList()),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                if (_teamMembers.contains(controller.text)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Este miembro ya está en el equipo')),
                  );
                  return;
                }
                setState(() {
                  _teamMembers.add(controller.text);
                });
                Navigator.pop(context);
                _showCreateTeamDialog();
              }
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  double _calculateAffinity(Map<String, dynamic> userScores, Map<String, dynamic> otherScores) {
    double affinity = 0;
    double maxPoints = 0;

    // Verificar objetivo común (30 puntos)
    bool isWinningTeam = userScores['objetivo'] == 'ganar';
    if (userScores['objetivo'] == otherScores['objetivo']) {
      affinity += 30;
    }
    maxPoints += 30;

    // Experiencia técnica y lenguajes (35 puntos)
    List<String> userLangs = List<String>.from(userScores['lenguajes'] ?? []);
    List<String> otherLangs = List<String>.from(otherScores['lenguajes'] ?? []);
    
    // Lenguajes en común (15 puntos)
    int commonLangs = userLangs.where((lang) => otherLangs.contains(lang)).length;
    affinity += (commonLangs / max(userLangs.length, 1)) * 15;
    maxPoints += 15;

    // Trabajo en equipo y productividad (25 puntos)
    if (isWinningTeam) {
      // Para equipos competitivos, valoramos similitud
      int teamDiff = (int.parse(userScores['trabajo_equipo'].toString()) - 
                     int.parse(otherScores['trabajo_equipo'].toString())).abs();
      int prodDiff = (int.parse(userScores['productividad'].toString()) - 
                     int.parse(otherScores['productividad'].toString())).abs();
      
      if (teamDiff <= 1) affinity += 15;
      if (prodDiff <= 1) affinity += 10;
    } else {
      // Para equipos no competitivos, valoramos creatividad y complementariedad
      int creativityScore = int.parse(otherScores['creatividad'].toString());
      affinity += (creativityScore / 5) * 25; // Más peso a la creatividad
    }
    maxPoints += 25;

    // Personalidad (10 puntos)
    List<String> userPersonality = List<String>.from(userScores['personalidad'] ?? []);
    List<String> otherPersonality = List<String>.from(otherScores['personalidad'] ?? []);
    int commonTraits = userPersonality
        .where((trait) => otherPersonality.contains(trait))
        .length;
    affinity += (commonTraits / max(userPersonality.length, 1)) * 10;
    maxPoints += 10;

    return (affinity / maxPoints) * 100;
  }

  Future<void> _findAffinityMembers() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      
      // Obtener información del usuario actual
      final userResult = await supabase
          .from('users_info')
          .select()
          .eq('user_id', userId)
          .single();

      // Obtener usuarios que buscan equipo
      final List<dynamic> otherUsers = await supabase
          .from('users_info')
          .select()
          .eq('looking_for_team', true)
          .neq('user_id', userId);

      // Calcular afinidad con cada usuario
      List<Map<String, dynamic>> affinities = [];
      
      for (var other in otherUsers) {
        // Verificar si el usuario ya está en el equipo
        if (_teamMembers.contains(other['user_id'])) continue;

        try {
          if (other['scores'] != null && userResult['scores'] != null) {
            double affinity = _calculateAffinity(
              Map<String, dynamic>.from(userResult['scores']), 
              Map<String, dynamic>.from(other['scores'])
            );
            
            affinities.add({
              'user_id': other['user_id'],
              'affinity': affinity,
              'scores': other['scores']
            });
          }
        } catch (e) {
          print('Error procesando usuario: ${other['user_id']}, Error: $e');
          continue;
        }
      }

      // Si no hay usuarios disponibles después de filtrar
      if (affinities.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay participantes afines disponibles')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Ordenar por afinidad y tomar los 5 mejores
      affinities.sort((a, b) => b['affinity'].compareTo(a['affinity']));
      final topMatches = affinities.take(5).toList();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Participantes Afines Disponibles'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: topMatches.length,
                itemBuilder: (context, index) {
                  final match = topMatches[index];
                  return ListTile(
                    title: Text('Usuario ${index + 1}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Afinidad: ${match['affinity'].toStringAsFixed(1)}%'),
                        Text('ID: ${match['user_id']}'),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        if (!_teamMembers.contains(match['user_id'])) {
                          setState(() {
                            _teamMembers.add(match['user_id']);
                          });
                          Navigator.pop(context);
                          _showCreateTeamDialog();
                        }
                      },
                    ),
                  );
                },
              ),
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
    } catch (e) {
      print('Error calculando afinidades: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error buscando participantes afines: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createTeam() async {
    if (_teamMembers.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se necesitan al menos 2 miembros para crear un equipo')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Crear el equipo
      final teamResponse = await supabase
          .from('teams')
          .insert({
            'name': _teamNameController.text,
          })
          .select()
          .single();

      // 2. Añadir miembros al equipo
      final teamId = teamResponse['id'];
      final memberInserts = _teamMembers.map((userId) => {
            'team_id': teamId,
            'user_id': userId,
          }).toList();

      await supabase.from('team_members').insert(memberInserts);

      // 3. Navegar a la pantalla de confirmación
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TeamConfirmedScreen(
              teamId: teamId.toString(),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creando el equipo: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showConfirmTeamDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Creación de Equipo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _teamNameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del Equipo',
                hintText: 'Introduce el nombre del equipo',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Miembros del equipo:'),
            ...(_teamMembers.map((member) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '• ${member == supabase.auth.currentUser!.id ? "$member (Tú)" : member}',
                  ),
                ))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _createTeam,
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Crear Equipo'),
          ),
        ],
      ),
    );
  }

  void _showCreateTeamDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tu Equipo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_teamMembers.length <= 1)
              const Text('Solo estás tú en el equipo')
            else ...[
              const Text('Miembros del equipo:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._teamMembers.map((member) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(member == supabase.auth.currentUser!.id ? "$member (Tú)" : member),
                    if (member != supabase.auth.currentUser!.id)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          setState(() {
                            _teamMembers.remove(member);
                          });
                          Navigator.pop(context);
                          _showCreateTeamDialog();
                        },
                      ),
                  ],
                ),
              )),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (_teamMembers.length < 4) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAddMemberDialog();
                      },
                      child: const Text('Añadir Miembro'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _findAffinityMembers();
                      },
                      child: const Text('Buscar por Afinidad'),
                    ),
                  ),
                ],
              ],
            ),
            if (_teamMembers.length > 1) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showConfirmTeamDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Crear Equipo'),
                ),
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