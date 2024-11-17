import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:raimon_ai/screens/qr_scanner_screen.dart';
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
      await supabase.from('users_info').update(
          {'looking_for_team': !_isLookingForTeam}).eq('user_id', userId);

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
        const SnackBar(
            content: Text('El equipo ya tiene el máximo de miembros (4)')),
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
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear QR'),
              onPressed: () async {
                Navigator.pop(context);
                final result = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(builder: (context) => const QRScannerScreen()),
                );

                if (result != null && mounted) {
                  if (!_teamMembers.contains(result)) {
                    setState(() {
                      _teamMembers.add(result);
                    });
                    _showCreateTeamDialog();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Este miembro ya está en el equipo')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A9D8F),
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
            if (_teamMembers.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Miembros actuales:'),
              ...(_teamMembers
                  .map((member) => Padding(
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
                      ))
                  .toList()),
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
                    const SnackBar(
                        content: Text('Este miembro ya está en el equipo')),
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

  double _calculateAffinity(
      Map<String, dynamic> userScores, Map<String, dynamic> otherScores) {
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
    int commonLangs =
        userLangs.where((lang) => otherLangs.contains(lang)).length;
    affinity += (commonLangs / max(userLangs.length, 1)) * 15;
    maxPoints += 15;

    // Trabajo en equipo y productividad (25 puntos)
    if (isWinningTeam) {
      // Para equipos competitivos, valoramos similitud
      int teamDiff = (int.parse(userScores['trabajo_equipo'].toString()) -
              int.parse(otherScores['trabajo_equipo'].toString()))
          .abs();
      int prodDiff = (int.parse(userScores['productividad'].toString()) -
              int.parse(otherScores['productividad'].toString()))
          .abs();

      if (teamDiff <= 1) affinity += 15;
      if (prodDiff <= 1) affinity += 10;
    } else {
      // Para equipos no competitivos, valoramos creatividad y complementariedad
      int creativityScore = int.parse(otherScores['creatividad'].toString());
      affinity += (creativityScore / 5) * 25; // Más peso a la creatividad
    }
    maxPoints += 25;

    // Personalidad (10 puntos)
    List<String> userPersonality =
        List<String>.from(userScores['personalidad'] ?? []);
    List<String> otherPersonality =
        List<String>.from(otherScores['personalidad'] ?? []);
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

      // Obtener información del usuario actual con todos los campos necesarios
      final userResult = await supabase
          .from('users_info')
          .select('''
            *,
            scores,
            non_filtering_info
          ''')
          .eq('user_id', userId)
          .single();

      // Obtener usuarios que buscan equipo con todos sus campos
      final List<dynamic> otherUsers = await supabase
          .from('users_info')
          .select('''
            *,
            scores,
            non_filtering_info
          ''')
          .eq('looking_for_team', true)
          .neq('user_id', userId);

      print('Debug - Datos obtenidos:');
      print('Usuario actual: $userResult');
      print('Otros usuarios: $otherUsers');

      // Calcular afinidad con cada usuario
      List<Map<String, dynamic>> affinities = [];

      for (var other in otherUsers) {
        if (_teamMembers.contains(other['user_id'])) continue;

        try {
          if (other['scores'] != null && userResult['scores'] != null) {
            double affinity = _calculateAffinity(
                Map<String, dynamic>.from(userResult['scores']),
                Map<String, dynamic>.from(other['scores']));

            affinities.add({
              'user_id': other['user_id'],
              'affinity': affinity,
              'scores': other['scores'],
              'non_filtering_info': other['non_filtering_info'] // Note la ortografía correcta
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
          const SnackBar(
              content: Text('No hay participantes afines disponibles')),
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
          builder: (context) => Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🤝 Participantes Afines',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2A9D8F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hemos encontrado estos perfiles compatibles:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: topMatches
                            .map((match) => _buildAffinityCard(match))
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStyledButton(
                    onPressed: () => Navigator.pop(context),
                    text: 'Cerrar',
                    icon: Icons.close,
                    isSecondary: true,
                  ),
                ],
              ),
            ),
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

  Widget _buildAffinityCard(Map<String, dynamic> match) {
    final double affinity = match['affinity'] as double;
    final Color cardColor = _getAffinityColor(affinity);
    final scores = Map<String, dynamic>.from(match['scores']);

    // Acceder correctamente a la información del formulario inicial
    final nonFilteringInfo = match['non_filtering_info'] as Map<String, dynamic>?;
    final formData = nonFilteringInfo?['initial_form_data'] as Map<String, dynamic>?;
    final yearOfStudy = formData?['year_of_study'] as String? ?? 'No especificado';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cardColor.withOpacity(0.1),
            cardColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cardColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (!_teamMembers.contains(match['user_id'])) {
              setState(() => _teamMembers.add(match['user_id']));
              Navigator.pop(context);
              _showCreateTeamDialog();
            }
          },
          child: ExpansionTile(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${affinity.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'ID: ${match['user_id'].toString().substring(0, 8)}...',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileSection('Experiencia',
                        scores['experiencia_tecnica'] ?? 'No especificada'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (yearOfStudy != 'No especificado')
                          _buildSkillChip('👨‍🎓 $yearOfStudy'),
                        _buildSkillChip(
                            '👩‍💻 ${scores['lenguajes']?.length ?? 0} lenguajes'),
                        _buildSkillChip(
                            '🎯 ${scores['objetivo'] == 'ganar' ? 'Competitivo' : 'Experiencia'}'),
                        _buildSkillChip(
                            '🤝 Equipo: ${scores['trabajo_equipo']}/5'),
                        _buildSkillChip('⚡ Prod: ${scores['productividad']}/5'),
                        _buildSkillChip('🎨 Creat: ${scores['creatividad']}/5'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.person_add_rounded, size: 18),
                          label: const Text('Añadir al equipo'),
                          onPressed: () {
                            if (!_teamMembers.contains(match['user_id'])) {
                              setState(
                                  () => _teamMembers.add(match['user_id']));
                              Navigator.pop(context);
                              _showCreateTeamDialog();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cardColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF2A9D8F),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSkillChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.black.withOpacity(0.7),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getAffinityColor(double affinity) {
    if (affinity >= 80) return const Color(0xFF2A9D8F);
    if (affinity >= 60) return const Color(0xFF4CAF50);
    if (affinity >= 40) return const Color(0xFFFFA000);
    return const Color(0xFFFF5722);
  }

  Future<void> _createTeam() async {
    if (_teamMembers.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Se necesitan al menos 2 miembros para crear un equipo')),
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
      final memberInserts = _teamMembers
          .map((userId) => {
                'team_id': teamId,
                'user_id': userId,
              })
          .toList();

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
    // Verificar si el usuario está buscando grupo
    if (_isLookingForTeam) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('No puedes crear un equipo mientras estás buscando uno'),
          backgroundColor: Color(0xFF2A9D8F),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tu Equipo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2A9D8F),
                ),
              ),
              const SizedBox(height: 16),
              if (_teamMembers.length <= 1)
                const Text(
                  'Solo estás tú en el equipo',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                )
              else ...[
                const Text(
                  'Miembros del equipo:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                ..._teamMembers.map((member) => _buildMemberTile(member)),
              ],
              const SizedBox(height: 24),
              if (_teamMembers.length < 4)
                Row(
                  children: [
                    Expanded(
                      child: _buildStyledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddMemberDialog();
                        },
                        text: 'Añadir Miembro',
                        icon: Icons.person_add,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStyledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _findAffinityMembers();
                        },
                        text: 'Buscar por Afinidad',
                        icon: Icons.search,
                        isSecondary: true,
                      ),
                    ),
                  ],
                ),
              if (_teamMembers.length > 1) ...[
                const SizedBox(height: 16),
                _buildStyledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showConfirmTeamDialog();
                  },
                  text: 'Crear Equipo',
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberTile(String member) {
    final bool isCurrentUser = member == supabase.auth.currentUser!.id;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A9D8F).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isCurrentUser ? "$member (Tú)" : member,
            style: TextStyle(
              color: Colors.black87,
              fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (!isCurrentUser)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  color: Colors.redAccent),
              onPressed: () {
                setState(() => _teamMembers.remove(member));
                Navigator.pop(context);
                _showCreateTeamDialog();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStyledButton({
    required VoidCallback onPressed,
    required String text,
    required IconData icon,
    Color? color,
    bool isSecondary = false,
  }) {
    final buttonColor = color ?? const Color(0xFF2A9D8F);
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSecondary ? Colors.white : buttonColor,
        foregroundColor: isSecondary ? buttonColor : Colors.white,
        elevation: isSecondary ? 0 : 2,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSecondary ? BorderSide(color: buttonColor) : BorderSide.none,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
          const SnackBar(
              content: Text('Ya has completado la entrevista inicial')),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.pushNamed(context, '/chat');
    }
  }

  void _showQRDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tu código QR',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2A9D8F),
                ),
              ),
              const SizedBox(height: 20),
              QrImageView(
                data: supabase.auth.currentUser!.id,
                version: QrVersions.auto,
                size: 200.0,
              ),
              const SizedBox(height: 20),
              Text(
                'ID: ${supabase.auth.currentUser!.id}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A9D8F),
                ),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleQRScan() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );

    if (result != null && mounted) {
      if (!_teamMembers.contains(result)) {
        setState(() {
          _teamMembers.add(result);
        });
        _showCreateTeamDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este miembro ya está en el equipo')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = screenWidth > 600 ? 400.0 : screenWidth * 0.85;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFF5F5F5),
              Color(0xFFE8F5E9),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header con información del usuario y botón de logout
                  Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¡Hola!',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 2),
                                    blurRadius: 4,
                                    color: Colors.black.withOpacity(0.1),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              supabase.auth.currentUser?.email?.split('@')[0] ??
                                  'usuario',
                              style: const TextStyle(
                                fontSize: 20,
                                color: Color(0xFF2A9D8F),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.logout_rounded,
                              color: Color(0xFF2A9D8F),
                              size: 24,
                            ),
                          ),
                          onPressed: () async {
                            await supabase.auth.signOut();
                            if (context.mounted) {
                              Navigator.of(context).pushReplacementNamed('/');
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  // Tarjetas de acciones principales
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildActionCard(
                        icon: Icons.chat_bubble_outline,
                        title: 'Entrevista Inicial',
                        description:
                            'Completa tu perfil para encontrar el equipo perfecto',
                        onTap: _navigateToChat,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2A9D8F), Color(0xFF264653)],
                        ),
                      ),
                      _buildActionCard(
                        icon: Icons.group_add_outlined,
                        title: 'Fundar Grupo',
                        description:
                            'Crea tu propio equipo y lidera el proyecto',
                        onTap: _showCreateTeamDialog,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE9C46A), Color(0xFFF4A261)],
                        ),
                      ),
                      _buildActionCard(
                        icon: Icons.qr_code,
                        title: 'Mi QR',
                        description: 'Muestra tu código QR para unirte a un equipo',
                        onTap: _showQRDialog,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Botón de búsqueda de grupo
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 24),
                    child: _buildGlassButton(
                      onPressed: _isLoading ? null : _toggleLookingForTeam,
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isLookingForTeam
                                      ? Icons.search_off
                                      : Icons.search,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isLookingForTeam
                                      ? 'Dejar de Buscar Grupo'
                                      : 'Buscar Grupo',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    required Gradient gradient,
  }) {
    final bool isDisabled = title == 'Fundar Grupo' && _isLookingForTeam;
    final finalGradient = isDisabled
        ? LinearGradient(
            colors: [Colors.grey.shade400, Colors.grey.shade500],
          )
        : gradient;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: finalGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isDisabled ? Colors.grey : gradient.colors.first)
                  .withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                color: isDisabled ? Colors.white70 : Colors.white, size: 32),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: isDisabled ? Colors.white70 : Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isDisabled ? 'No disponible mientras buscas grupo' : description,
              style: TextStyle(
                color: (isDisabled ? Colors.white70 : Colors.white)
                    .withOpacity(0.9),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required Widget child,
    required VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2A9D8F).withOpacity(0.9),
            const Color(0xFF2A9D8F).withOpacity(0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2A9D8F).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: child,
          ),
        ),
      ),
    );
  }
}
